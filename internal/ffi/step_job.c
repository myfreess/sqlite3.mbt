#include "executor.h"
#include "sqlite3.h"
#include <errno.h>
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

typedef struct moonbit_sqlite3_step_job {
  /* The executor job must remain first so the worker can invoke this typed job
   * without allocating a second queue node. */
  moonbit_sqlite3_executor_job_t executor_job;
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
} moonbit_sqlite3_step_job_t;

#ifdef _WIN32

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
moonbit_sqlite3_run_step_job(
  moonbit_sqlite3_executor_job_t *executor_job
) {
  moonbit_sqlite3_step_job_t *job =
    (moonbit_sqlite3_step_job_t *)executor_job;
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
  job->executor_job.run = moonbit_sqlite3_run_step_job;
  job->executor = executor;
  job->database = database;
  job->statement = statement;
  job->notification = duplicate;
  if (!moonbit_sqlite3_executor_submit(executor, &job->executor_job)) {
    moonbit_sqlite3_close_notification(duplicate);
    free(job);
    *rescode = SQLITE_IOERR;
    return NULL;
  }
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
