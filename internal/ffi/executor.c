#include "executor.h"
#include "sqlite3.h"
#include <moonbit.h>
#include <stdlib.h>

#ifdef _WIN32
#include <process.h>
#include <windows.h>
#else
#include <pthread.h>
#endif

struct moonbit_sqlite3_executor {
  moonbit_sqlite3_executor_job_t *head;
  moonbit_sqlite3_executor_job_t *tail;
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

#endif

static moonbit_sqlite3_executor_job_t *
moonbit_sqlite3_executor_take(moonbit_sqlite3_executor_t *executor) {
  moonbit_sqlite3_executor_lock(executor);
  while (!executor->head && !executor->stopping) {
    moonbit_sqlite3_executor_wait(executor);
  }
  moonbit_sqlite3_executor_job_t *job = executor->head;
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
  for (moonbit_sqlite3_executor_job_t *job =
         moonbit_sqlite3_executor_take(executor);
       job;
       job = moonbit_sqlite3_executor_take(executor)) {
    job->run(job);
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

bool
moonbit_sqlite3_executor_submit(
  moonbit_sqlite3_executor_t *executor,
  moonbit_sqlite3_executor_job_t *job
) {
  moonbit_sqlite3_executor_lock(executor);
  if (executor->stopping) {
    moonbit_sqlite3_executor_unlock(executor);
    return false;
  }
  job->next = NULL;
  if (executor->tail) {
    executor->tail->next = job;
  } else {
    executor->head = job;
  }
  executor->tail = job;
  moonbit_sqlite3_executor_wake(executor);
  moonbit_sqlite3_executor_unlock(executor);
  return true;
}
