#include "job.h"
#include <moonbit.h>
#include <stdlib.h>
#include <string.h>

typedef struct moonbit_sqlite3_open_job {
  moonbit_sqlite3_job_t job;
  char *filename;
  int32_t flags;
  sqlite3 *database;
} moonbit_sqlite3_open_job_t;

static void
moonbit_sqlite3_run_open_job(
  moonbit_sqlite3_executor_job_t *executor_job
) {
  moonbit_sqlite3_open_job_t *open_job =
    (moonbit_sqlite3_open_job_t *)executor_job;
  moonbit_sqlite3_job_t *job = &open_job->job;
  const uint16_t one = 1;
  if (*(const unsigned char *)&one != 1) {
    job->rescode = SQLITE_MISUSE;
  } else {
    job->rescode = sqlite3_open_v2(
      open_job->filename,
      &open_job->database,
      open_job->flags,
      NULL
    );
  }
  free(open_job->filename);
  open_job->filename = NULL;
  if (job->rescode == SQLITE_OK) {
    job->extended_rescode = SQLITE_OK;
  } else {
    moonbit_sqlite3_job_capture_error(job, open_job->database);
    if (open_job->database) {
      sqlite3_close(open_job->database);
      open_job->database = NULL;
    }
  }
  moonbit_sqlite3_job_publish_result(job);
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3_job_t *
moonbit_sqlite3_open_job(
  moonbit_sqlite3_executor_t *executor,
  moonbit_bytes_t filename,
  int32_t flags,
  moonbit_sqlite3_notification_t notification,
  int32_t *rescode
) {
  int32_t filename_length = Moonbit_array_length(filename);
  moonbit_sqlite3_open_job_t *open_job = calloc(1, sizeof(*open_job));
  if (!open_job) {
    *rescode = SQLITE_NOMEM;
    return NULL;
  }
  open_job->filename = malloc((size_t)filename_length + 1);
  if (!open_job->filename) {
    free(open_job);
    *rescode = SQLITE_NOMEM;
    return NULL;
  }
  memcpy(open_job->filename, filename, (size_t)filename_length);
  open_job->filename[filename_length] = '\0';
  open_job->flags = flags;
  if (!moonbit_sqlite3_job_submit(
        &open_job->job,
        executor,
        notification,
        moonbit_sqlite3_run_open_job,
        rescode
      )) {
    free(open_job->filename);
    free(open_job);
    return NULL;
  }
  return &open_job->job;
}

MOONBIT_FFI_EXPORT
sqlite3 *
moonbit_sqlite3_open_job_database(moonbit_sqlite3_job_t *job) {
  if (!job || !moonbit_sqlite3_job_result_is_published(job) ||
      job->rescode != SQLITE_OK) {
    return NULL;
  }
  moonbit_sqlite3_open_job_t *open_job =
    (moonbit_sqlite3_open_job_t *)job;
  sqlite3 *database = open_job->database;
  open_job->database = NULL;
  return database;
}

MOONBIT_FFI_EXPORT
void
moonbit_sqlite3_open_job_release(moonbit_sqlite3_job_t *job) {
  if (!job || !moonbit_sqlite3_job_result_is_published(job)) {
    return;
  }
  moonbit_sqlite3_open_job_t *open_job =
    (moonbit_sqlite3_open_job_t *)job;
  free(open_job->filename);
  if (open_job->database) {
    sqlite3_close(open_job->database);
  }
  moonbit_sqlite3_job_dispose(job);
  free(open_job);
}
