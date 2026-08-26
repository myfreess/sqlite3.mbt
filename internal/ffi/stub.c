#include "sqlite3.h"
#include <assert.h>
#include <errno.h>
#include <moonbit.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <fcntl.h>
#include <pthread.h>
#include <unistd.h>
#endif

/* ---------- SQLite-owned asynchronous jobs ---------- */

/* Each connection lazily owns one executor and therefore one worker. Jobs
 * never call into the MoonBit runtime from that worker; completion crosses
 * back through the per-job pipe. */

typedef struct moonbit_sqlite3_executor moonbit_sqlite3_executor_t;

typedef struct moonbit_sqlite3_step_job {
  moonbit_sqlite3_executor_t *executor;
  sqlite3 *database;
  sqlite3_stmt *statement;
  int32_t rescode;
  int32_t extended_rescode;
  uint16_t *message;
  int32_t message_length;
  bool ready;
#ifdef _WIN32
  HANDLE notification;
#else
  int notification;
#endif
  struct moonbit_sqlite3_step_job *next;
} moonbit_sqlite3_step_job_t;

struct moonbit_sqlite3_executor {
  moonbit_sqlite3_step_job_t *head;
  moonbit_sqlite3_step_job_t *tail;
  bool stopping;
#ifdef _WIN32
  CRITICAL_SECTION mutex;
  CONDITION_VARIABLE condition;
  HANDLE worker;
#else
  pthread_mutex_t mutex;
  pthread_cond_t condition;
  pthread_t worker;
#endif
};

#ifdef _WIN32

static unsigned __stdcall moonbit_sqlite3_worker(void *data);

static void
moonbit_sqlite3_executor_lock(moonbit_sqlite3_executor_t *executor) {
  EnterCriticalSection(&executor->mutex);
}

static void
moonbit_sqlite3_executor_unlock(moonbit_sqlite3_executor_t *executor) {
  LeaveCriticalSection(&executor->mutex);
}

static void
moonbit_sqlite3_executor_wait(moonbit_sqlite3_executor_t *executor) {
  SleepConditionVariableCS(
    &executor->condition,
    &executor->mutex,
    INFINITE
  );
}

static void
moonbit_sqlite3_executor_wake(moonbit_sqlite3_executor_t *executor) {
  WakeConditionVariable(&executor->condition);
}

static HANDLE
moonbit_sqlite3_duplicate_notification(HANDLE notification) {
  HANDLE duplicate = NULL;
  if (!DuplicateHandle(
        GetCurrentProcess(),
        notification,
        GetCurrentProcess(),
        &duplicate,
        0,
        FALSE,
        DUPLICATE_SAME_ACCESS
      )) {
    return NULL;
  }
  return duplicate;
}

static void
moonbit_sqlite3_close_notification(HANDLE notification) {
  CloseHandle(notification);
}

static void
moonbit_sqlite3_notify(HANDLE notification) {
  unsigned char signal = 1;
  DWORD written = 0;
  OVERLAPPED overlapped = { 0 };
  overlapped.hEvent = CreateEventW(NULL, TRUE, FALSE, NULL);
  if (!overlapped.hEvent) {
    return;
  }
  BOOL completed = WriteFile(
    notification,
    &signal,
    sizeof(signal),
    &written,
    &overlapped
  );
  if (!completed && GetLastError() == ERROR_IO_PENDING) {
    WaitForSingleObject(overlapped.hEvent, INFINITE);
    GetOverlappedResult(notification, &overlapped, &written, FALSE);
  }
  CloseHandle(overlapped.hEvent);
}

#else

static void *moonbit_sqlite3_worker(void *data);

static void
moonbit_sqlite3_executor_lock(moonbit_sqlite3_executor_t *executor) {
  pthread_mutex_lock(&executor->mutex);
}

static void
moonbit_sqlite3_executor_unlock(moonbit_sqlite3_executor_t *executor) {
  pthread_mutex_unlock(&executor->mutex);
}

static void
moonbit_sqlite3_executor_wait(moonbit_sqlite3_executor_t *executor) {
  pthread_cond_wait(&executor->condition, &executor->mutex);
}

static void
moonbit_sqlite3_executor_wake(moonbit_sqlite3_executor_t *executor) {
  pthread_cond_signal(&executor->condition);
}

static int
moonbit_sqlite3_duplicate_notification(int notification) {
  int duplicate = dup(notification);
  if (duplicate >= 0) {
    int flags = fcntl(duplicate, F_GETFD);
    if (flags >= 0) {
      (void)fcntl(duplicate, F_SETFD, flags | FD_CLOEXEC);
    }
  }
  return duplicate;
}

static void
moonbit_sqlite3_close_notification(int notification) {
  close(notification);
}

static void
moonbit_sqlite3_notify(int notification) {
  unsigned char signal = 1;
  while (write(notification, &signal, sizeof(signal)) < 0 && errno == EINTR) {
  }
}

#endif

static void
moonbit_sqlite3_copy_job_message(moonbit_sqlite3_step_job_t *job) {
  const uint16_t *message = (const uint16_t *)sqlite3_errmsg16(job->database);
  if (!message) {
    return;
  }
  size_t length = 0;
  while (message[length] != 0) {
    length++;
  }
  if (length == 0) {
    return;
  }
  if (length > INT32_MAX || length > SIZE_MAX / sizeof(uint16_t)) {
    job->rescode = SQLITE_TOOBIG;
    job->extended_rescode = SQLITE_TOOBIG;
    return;
  }
  job->message = malloc(length * sizeof(uint16_t));
  if (!job->message) {
    job->rescode = SQLITE_NOMEM;
    job->extended_rescode = SQLITE_NOMEM;
    return;
  }
  memcpy(job->message, message, length * sizeof(uint16_t));
  job->message_length = (int32_t)length;
}

static void
moonbit_sqlite3_run_step_job(moonbit_sqlite3_step_job_t *job) {
  sqlite3_mutex *mutex = sqlite3_db_mutex(job->database);
  if (mutex) {
    sqlite3_mutex_enter(mutex);
  }
  job->rescode = sqlite3_step(job->statement);
  job->extended_rescode = sqlite3_extended_errcode(job->database);
  if (job->rescode != SQLITE_ROW && job->rescode != SQLITE_DONE) {
    moonbit_sqlite3_copy_job_message(job);
  }
  if (mutex) {
    sqlite3_mutex_leave(mutex);
  }

#ifdef _WIN32
  HANDLE notification = job->notification;
#else
  int notification = job->notification;
#endif
  moonbit_sqlite3_executor_t *executor = job->executor;
  moonbit_sqlite3_executor_lock(executor);
  job->ready = true;
  moonbit_sqlite3_executor_unlock(executor);
  /* `ready` lets the MoonBit owner release `job`, so the worker must use only
   * local state from this point onward. */
  moonbit_sqlite3_notify(notification);
  moonbit_sqlite3_close_notification(notification);
}

static moonbit_sqlite3_step_job_t *
moonbit_sqlite3_take_job(moonbit_sqlite3_executor_t *executor) {
  moonbit_sqlite3_executor_lock(executor);
  while (!executor->head && !executor->stopping) {
    moonbit_sqlite3_executor_wait(executor);
  }
  moonbit_sqlite3_step_job_t *job = executor->head;
  if (job) {
    executor->head = job->next;
    if (!executor->head) {
      executor->tail = NULL;
    }
    job->next = NULL;
  }
  moonbit_sqlite3_executor_unlock(executor);
  return job;
}

#ifdef _WIN32
static unsigned __stdcall
moonbit_sqlite3_worker(void *data) {
#else
static void *
moonbit_sqlite3_worker(void *data) {
#endif
  moonbit_sqlite3_executor_t *executor = data;
  for (moonbit_sqlite3_step_job_t *job = moonbit_sqlite3_take_job(executor);
       job;
       job = moonbit_sqlite3_take_job(executor)) {
    moonbit_sqlite3_run_step_job(job);
  }
#ifdef _WIN32
  return 0;
#else
  return NULL;
#endif
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3_executor_t *
moonbit_sqlite3_executor_create(int32_t *rescode) {
  *rescode = SQLITE_OK;
  moonbit_sqlite3_executor_t *executor = calloc(1, sizeof(*executor));
  if (!executor) {
    *rescode = SQLITE_NOMEM;
    return NULL;
  }
#ifdef _WIN32
  InitializeCriticalSection(&executor->mutex);
  InitializeConditionVariable(&executor->condition);
  uintptr_t worker = _beginthreadex(
    NULL,
    0,
    moonbit_sqlite3_worker,
    executor,
    0,
    NULL
  );
  if (worker == 0) {
    DeleteCriticalSection(&executor->mutex);
    free(executor);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
  executor->worker = (HANDLE)worker;
#else
  if (pthread_mutex_init(&executor->mutex, NULL) != 0) {
    free(executor);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
  if (pthread_cond_init(&executor->condition, NULL) != 0) {
    pthread_mutex_destroy(&executor->mutex);
    free(executor);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
  if (pthread_create(
        &executor->worker,
        NULL,
        moonbit_sqlite3_worker,
        executor
      ) != 0) {
    pthread_cond_destroy(&executor->condition);
    pthread_mutex_destroy(&executor->mutex);
    free(executor);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
#endif
  return executor;
}

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_executor_release(moonbit_sqlite3_executor_t *executor) {
  if (!executor) {
    return;
  }
  moonbit_sqlite3_executor_lock(executor);
  executor->stopping = true;
  moonbit_sqlite3_executor_wake(executor);
  moonbit_sqlite3_executor_unlock(executor);
#ifdef _WIN32
  WaitForSingleObject(executor->worker, INFINITE);
  CloseHandle(executor->worker);
  DeleteCriticalSection(&executor->mutex);
#else
  pthread_join(executor->worker, NULL);
  pthread_cond_destroy(&executor->condition);
  pthread_mutex_destroy(&executor->mutex);
#endif
  free(executor);
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3_step_job_t *
moonbit_sqlite3_step_job(
  moonbit_sqlite3_executor_t *executor,
  sqlite3 *database,
  sqlite3_stmt *statement,
#ifdef _WIN32
  HANDLE notification,
#else
  int notification,
#endif
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  if (!executor || !database || !statement ||
      sqlite3_db_handle(statement) != database) {
    *rescode = SQLITE_MISUSE;
    return NULL;
  }
#ifdef _WIN32
  HANDLE duplicate = moonbit_sqlite3_duplicate_notification(notification);
  if (!duplicate) {
#else
  int duplicate = moonbit_sqlite3_duplicate_notification(notification);
  if (duplicate < 0) {
#endif
    *rescode = SQLITE_IOERR;
    return NULL;
  }
  moonbit_sqlite3_step_job_t *job = calloc(1, sizeof(*job));
  if (!job) {
    moonbit_sqlite3_close_notification(duplicate);
    *rescode = SQLITE_NOMEM;
    return NULL;
  }
  job->executor = executor;
  job->database = database;
  job->statement = statement;
  job->notification = duplicate;

  moonbit_sqlite3_executor_lock(executor);
  if (executor->stopping) {
    moonbit_sqlite3_executor_unlock(executor);
    moonbit_sqlite3_close_notification(duplicate);
    free(job);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
  if (executor->tail) {
    executor->tail->next = job;
  } else {
    executor->head = job;
  }
  executor->tail = job;
  moonbit_sqlite3_executor_wake(executor);
  moonbit_sqlite3_executor_unlock(executor);
  return job;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_step_job_is_ready(moonbit_sqlite3_step_job_t *job) {
  if (!job) {
    return 1;
  }
  moonbit_sqlite3_executor_t *executor = job->executor;
  moonbit_sqlite3_executor_lock(executor);
  bool ready = job->ready;
  moonbit_sqlite3_executor_unlock(executor);
  return ready ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_step_job_rescode(moonbit_sqlite3_step_job_t *job) {
  return job ? job->rescode : SQLITE_MISUSE;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_step_job_extended_rescode(moonbit_sqlite3_step_job_t *job) {
  return job ? job->extended_rescode : SQLITE_MISUSE;
}

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_step_job_message(moonbit_sqlite3_step_job_t *job) {
  int32_t length = job ? job->message_length : 0;
  moonbit_string_t message = moonbit_make_string_raw(length);
  if (length > 0) {
    memcpy(message, job->message, (size_t)length * sizeof(uint16_t));
  }
  return message;
}

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_step_job_release(moonbit_sqlite3_step_job_t *job) {
  if (!job) {
    return;
  }
  moonbit_sqlite3_executor_t *executor = job->executor;
  moonbit_sqlite3_executor_lock(executor);
  bool ready = job->ready;
  moonbit_sqlite3_executor_unlock(executor);
  if (!ready) {
    return;
  }
  free(job->message);
  free(job);
}

/* ---------- FFI functions ---------- */

MOONBIT_FFI_EXPORT
sqlite3 *
moonbit_sqlite3_open_v2(
  moonbit_bytes_t filename,
  int32_t flags,
  int32_t *rescode
) {
  /* SQLite's UTF-16 APIs use host order unless a BOM says otherwise. */
  const uint16_t one = 1;
  if (*(const unsigned char *)&one != 1) {
    *rescode = SQLITE_MISUSE;
    return NULL;
  }
  sqlite3 *db = NULL;
  *rescode = sqlite3_open_v2((const char *)filename, &db, flags, NULL);
  return db;
}

MOONBIT_FFI_EXPORT
bool
moonbit_sqlite3_is_null(sqlite3 *db) {
  return db == NULL;
}

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_errmsg(sqlite3 *db) {
  const uint16_t *msg = (const uint16_t *)sqlite3_errmsg16(db);
  if (!msg) {
    return moonbit_make_string_raw(0);
  }
  int32_t len = 0;
  while (msg[len] != 0) {
    len++;
  }
  moonbit_string_t result = moonbit_make_string_raw(len);
  memcpy(result, msg, (size_t)len * sizeof(uint16_t));
  return result;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_exec(sqlite3 *db, moonbit_bytes_t sql) {
  return (int32_t)sqlite3_exec(db, (const char *)sql, NULL, NULL, NULL);
}

MOONBIT_FFI_EXPORT
sqlite3_stmt *
moonbit_sqlite3_prepare16_v2(
  sqlite3 *db,
  moonbit_string_t sql,
  int32_t *tail_offset,
  int32_t *rescode
) {
  *tail_offset = -1;
  int32_t sql_len = Moonbit_array_length(sql);
  if (sql_len > INT32_MAX / (int32_t)sizeof(uint16_t)) {
    *rescode = SQLITE_TOOBIG;
    return NULL;
  }
  const void *tail = NULL;
  sqlite3_stmt *stmt = NULL;
  *rescode = sqlite3_prepare16_v2(
    db,
    (const void *)sql,
    sql_len * (int32_t)sizeof(uint16_t),
    &stmt,
    &tail
  );
  if (*rescode == SQLITE_OK && stmt) {
    *tail_offset = (int32_t)((const uint16_t *)tail - sql);
  }
  return stmt;
}

/* ---------- Bind functions ---------- */

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_text(
  sqlite3_stmt *stmt,
  int32_t idx,
  moonbit_string_t text,
  int32_t text_offset,
  int32_t text_length
) {
  const uint16_t *start = (const uint16_t *)text + text_offset;
  sqlite3_uint64 byte_len = (sqlite3_uint64)text_length * sizeof(uint16_t);
  return (int32_t)sqlite3_bind_text64(
    stmt,
    idx,
    (const char *)start,
    byte_len,
    SQLITE_TRANSIENT,
    SQLITE_UTF16LE
  );
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_blob(
  sqlite3_stmt *stmt,
  int32_t idx,
  moonbit_bytes_t blob,
  int32_t blob_offset,
  int32_t blob_length
) {
  const uint8_t *start = (const uint8_t *)blob + blob_offset;
  return (int32_t)sqlite3_bind_blob(
    stmt, idx, (const void *)start, blob_length, SQLITE_TRANSIENT
  );
}

/* ---------- Column functions ---------- */

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_column_name(
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *available
) {
  /* sqlite3_column_name16() has no result-code return. In the bundled SQLite,
   * a conversion OOM is reported only as NULL and does not update the
   * connection error code, so expose pointer availability rather than
   * manufacturing a SQLite result code. The MoonBit API validates idx. */
  const uint16_t *name = (const uint16_t *)sqlite3_column_name16(stmt, idx);
  if (!name) {
    *available = 0;
    return moonbit_make_string_raw(0);
  }
  *available = 1;
  int32_t len = 0;
  while (name[len] != 0) {
    len++;
  }
  moonbit_string_t result = moonbit_make_string_raw(len);
  memcpy(result, name, (size_t)len * sizeof(uint16_t));
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_column_text(
  sqlite3 *db,
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  int32_t prior_code = sqlite3_errcode(db);
  const void *text = sqlite3_column_text16(stmt, idx);
  if (!text) {
    int32_t code = sqlite3_errcode(db);
    /* SQLite does not clear older connection errors on successful reads.
     * Treat NOMEM as local to this conversion only when this call introduced
     * it; an already-recorded NOMEM may belong to another statement. */
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_string_raw(0);
  }
  int32_t byte_len = (int32_t)sqlite3_column_bytes16(stmt, idx);
  if (byte_len == 0) {
    int32_t code = sqlite3_errcode(db);
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_string_raw(0);
  }
  assert(byte_len % (int32_t)sizeof(uint16_t) == 0);
  int32_t len = byte_len / (int32_t)sizeof(uint16_t);
  moonbit_string_t result = moonbit_make_string_raw(len);
  memcpy(result, text, (size_t)byte_len);
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_sqlite3_column_blob(
  sqlite3 *db,
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  int32_t prior_code = sqlite3_errcode(db);
  const void *blob = sqlite3_column_blob(stmt, idx);
  if (!blob) {
    int32_t code = sqlite3_errcode(db);
    /* Zero-length blobs and SQL NULL also return NULL. As above, require a
     * transition to NOMEM instead of propagating connection-wide history. */
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)sqlite3_column_bytes(stmt, idx);
  if (len == 0) {
    int32_t code = sqlite3_errcode(db);
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, blob, len);
  return bytes;
}
