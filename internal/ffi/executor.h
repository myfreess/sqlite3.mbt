#ifndef MOONBIT_SQLITE3_EXECUTOR_H
#define MOONBIT_SQLITE3_EXECUTOR_H

#include <moonbit.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct moonbit_sqlite3_executor moonbit_sqlite3_executor_t;
typedef struct moonbit_sqlite3_executor_job moonbit_sqlite3_executor_job_t;

struct moonbit_sqlite3_executor_job {
  moonbit_sqlite3_executor_job_t *next;
  void (*run)(moonbit_sqlite3_executor_job_t *job);
};

MOONBIT_FFI_EXPORT
moonbit_sqlite3_executor_t *
moonbit_sqlite3_executor_create(int32_t *rescode);

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_executor_release(moonbit_sqlite3_executor_t *executor);

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_executor_wait_idle(moonbit_sqlite3_executor_t *executor);

bool
moonbit_sqlite3_executor_submit(
  moonbit_sqlite3_executor_t *executor,
  moonbit_sqlite3_executor_job_t *job
);

void
moonbit_sqlite3_executor_lock(moonbit_sqlite3_executor_t *executor);

void
moonbit_sqlite3_executor_unlock(moonbit_sqlite3_executor_t *executor);

#endif
