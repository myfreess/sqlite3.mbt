#include "job.h"
#include <moonbit.h>
#include <stdlib.h>

typedef struct moonbit_sqlite3_step_job {
  moonbit_sqlite3_job_t job;
  sqlite3 *database;
  sqlite3_stmt *statement;
} moonbit_sqlite3_step_job_t;

static void
moonbit_sqlite3_run_step_job(
  moonbit_sqlite3_executor_job_t *executor_job
) {
  moonbit_sqlite3_step_job_t *step_job =
    (moonbit_sqlite3_step_job_t *)executor_job;
  moonbit_sqlite3_job_t *job = &step_job->job;
  sqlite3_mutex *mutex = sqlite3_db_mutex(step_job->database);
  if (mutex) {
    sqlite3_mutex_enter(mutex);
  }
  job->rescode = sqlite3_step(step_job->statement);
  if (job->rescode == SQLITE_ROW || job->rescode == SQLITE_DONE) {
    job->extended_rescode = job->rescode;
  } else {
    moonbit_sqlite3_job_capture_error(job, step_job->database);
  }
  if (mutex) {
    sqlite3_mutex_leave(mutex);
  }
  moonbit_sqlite3_job_complete(job);
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3_job_t *
moonbit_sqlite3_step_job(
  moonbit_sqlite3_executor_t *executor,
  sqlite3 *database,
  sqlite3_stmt *statement,
  moonbit_sqlite3_notification_t notification,
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  if (!database || !statement || sqlite3_db_handle(statement) != database) {
    *rescode = SQLITE_MISUSE;
    return NULL;
  }
  moonbit_sqlite3_step_job_t *step_job = calloc(1, sizeof(*step_job));
  if (!step_job) {
    *rescode = SQLITE_NOMEM;
    return NULL;
  }
  step_job->database = database;
  step_job->statement = statement;
  if (!moonbit_sqlite3_job_submit(
        &step_job->job,
        executor,
        notification,
        moonbit_sqlite3_run_step_job,
        rescode
      )) {
    free(step_job);
    return NULL;
  }
  return &step_job->job;
}

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_step_job_release(moonbit_sqlite3_job_t *job) {
  if (!job || !moonbit_sqlite3_job_ready(job)) {
    return;
  }
  moonbit_sqlite3_job_dispose(job);
  free(job);
}
