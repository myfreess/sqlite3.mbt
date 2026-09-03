#ifndef MOONBIT_SQLITE3_JOB_H
#define MOONBIT_SQLITE3_JOB_H

#include "executor.h"
#include "sqlite3.h"
#include <stdbool.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
typedef HANDLE moonbit_sqlite3_notification_t;
#else
typedef int moonbit_sqlite3_notification_t;
#endif

typedef struct moonbit_sqlite3_job {
  /* This must remain first so an executor job pointer is also a SQLite job
   * pointer. Concrete operation jobs preserve the same first-field rule. */
  moonbit_sqlite3_executor_job_t executor_job;
  moonbit_sqlite3_executor_t *executor;
  int32_t rescode;
  int32_t extended_rescode;
  uint16_t *message;
  int32_t message_length;
  bool ready;
  moonbit_sqlite3_notification_t notification;
} moonbit_sqlite3_job_t;

bool
moonbit_sqlite3_job_submit(
  moonbit_sqlite3_job_t *job,
  moonbit_sqlite3_executor_t *executor,
  moonbit_sqlite3_notification_t notification,
  void (*run)(moonbit_sqlite3_executor_job_t *job),
  int32_t *rescode
);

void
moonbit_sqlite3_job_capture_error(
  moonbit_sqlite3_job_t *job,
  sqlite3 *database
);

void
moonbit_sqlite3_job_complete(moonbit_sqlite3_job_t *job);

bool
moonbit_sqlite3_job_ready(moonbit_sqlite3_job_t *job);

void
moonbit_sqlite3_job_dispose(moonbit_sqlite3_job_t *job);

#endif
