#ifndef MOONBIT_SQLITE3_JOB_H
#define MOONBIT_SQLITE3_JOB_H

#include "executor.h"
#include "sqlite3.h"
#include <stdbool.h>
#include <stdint.h>

#ifdef _WIN32
#include <windows.h>
typedef HANDLE moonbit_sqlite3_notification_t;
typedef volatile LONG moonbit_sqlite3_job_publication_t;
#else
#include <stdatomic.h>
typedef int moonbit_sqlite3_notification_t;
typedef atomic_bool moonbit_sqlite3_job_publication_t;
#endif

typedef struct moonbit_sqlite3_job {
  /* This must remain first so an executor job pointer is also a SQLite job
   * pointer. Concrete operation jobs preserve the same first-field rule. */
  moonbit_sqlite3_executor_job_t executor_job;
  int32_t rescode;
  int32_t extended_rescode;
  uint16_t *message;
  int32_t message_length;
  /* The worker release-publishes this after writing every result field. An
   * acquire load makes the complete result, including operation-specific
   * fields, visible and permits the waiter to release the job. */
  moonbit_sqlite3_job_publication_t result_published;
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
moonbit_sqlite3_job_publish_result(moonbit_sqlite3_job_t *job);

bool
moonbit_sqlite3_job_result_is_published(moonbit_sqlite3_job_t *job);

void
moonbit_sqlite3_job_dispose(moonbit_sqlite3_job_t *job);

#endif
