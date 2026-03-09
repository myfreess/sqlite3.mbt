#include "sqlite3.h"
#include <assert.h>
#include <moonbit.h>
#include <string.h>

/* ---------- External object: database connection ---------- */

typedef struct {
  sqlite3 *db;
} moonbit_sqlite3;

static void
moonbit_sqlite3_destroy(void *self) {
  moonbit_sqlite3 *wrapper = (moonbit_sqlite3 *)self;
  if (wrapper->db) {
    sqlite3_close_v2(wrapper->db);
    wrapper->db = NULL;
  }
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3 *
moonbit_sqlite3_allocate(void) {
  moonbit_sqlite3 *wrapper = (moonbit_sqlite3 *)moonbit_make_external_object(
    moonbit_sqlite3_destroy, sizeof(moonbit_sqlite3)
  );
  wrapper->db = NULL;
  return wrapper;
}

/* ---------- External object: prepared statement ---------- */

typedef struct {
  sqlite3_stmt *stmt;
  moonbit_sqlite3 *db_wrapper; /* incref'd reference to moonbit_sqlite3 */
} moonbit_sqlite3_stmt;

static void
moonbit_sqlite3_stmt_destroy(void *self) {
  moonbit_sqlite3_stmt *wrapper = (moonbit_sqlite3_stmt *)self;
  if (wrapper->stmt) {
    sqlite3_finalize(wrapper->stmt);
    wrapper->stmt = NULL;
  }
  if (wrapper->db_wrapper) {
    moonbit_decref(wrapper->db_wrapper);
    wrapper->db_wrapper = NULL;
  }
}

MOONBIT_FFI_EXPORT
moonbit_sqlite3_stmt *
moonbit_sqlite3_stmt_allocate(void) {
  moonbit_sqlite3_stmt *wrapper =
    (moonbit_sqlite3_stmt *)moonbit_make_external_object(
      moonbit_sqlite3_stmt_destroy, sizeof(moonbit_sqlite3_stmt)
    );
  wrapper->stmt = NULL;
  wrapper->db_wrapper = NULL;
  return wrapper;
}

/* ---------- FFI functions ---------- */

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_open(moonbit_bytes_t filename, moonbit_sqlite3 *db) {
  return (int32_t)sqlite3_open((const char *)filename, &db->db);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_close(moonbit_sqlite3 *wrapper) {
  int rc = SQLITE_OK;
  if (wrapper->db) {
    rc = sqlite3_close(wrapper->db);
    if (rc == SQLITE_OK) {
      wrapper->db = NULL;
    }
  }
  return (int32_t)rc;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_sqlite3_errmsg(moonbit_sqlite3 *wrapper) {
  assert(wrapper->db);
  const char *msg = sqlite3_errmsg(wrapper->db);
  int32_t len = (int32_t)strlen(msg);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, msg, len);
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_errcode(moonbit_sqlite3 *wrapper) {
  assert(wrapper->db);
  return (int32_t)sqlite3_errcode(wrapper->db);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_exec(moonbit_sqlite3 *db, moonbit_bytes_t sql) {
  assert(db->db);
  return (int32_t)sqlite3_exec(db->db, (const char *)sql, NULL, NULL, NULL);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_prepare_v2(
  moonbit_sqlite3 *db,
  moonbit_bytes_t sql,
  moonbit_sqlite3_stmt *stmt
) {
  assert(db->db);
  int32_t sql_len = Moonbit_array_length(sql);
  int rc =
    sqlite3_prepare_v2(db->db, (const char *)sql, sql_len, &stmt->stmt, NULL);
  if (rc == SQLITE_OK) {
    moonbit_incref(db);
    stmt->db_wrapper = db;
  }
  return (int32_t)rc;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_step(moonbit_sqlite3_stmt *wrapper) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_step(wrapper->stmt);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_reset(moonbit_sqlite3_stmt *wrapper) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_reset(wrapper->stmt);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_finalize(moonbit_sqlite3_stmt *wrapper) {
  assert(wrapper->stmt);
  int rc = sqlite3_finalize(wrapper->stmt);
  wrapper->stmt = NULL;
  return (int32_t)rc;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_column_count(moonbit_sqlite3_stmt *wrapper) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_column_count(wrapper->stmt);
}

/* ---------- Bind functions ---------- */

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_int(
  moonbit_sqlite3_stmt *wrapper,
  int32_t idx,
  int32_t value
) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_bind_int(wrapper->stmt, idx, value);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_int64(
  moonbit_sqlite3_stmt *wrapper,
  int32_t idx,
  int64_t value
) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_bind_int64(wrapper->stmt, idx, value);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_double(
  moonbit_sqlite3_stmt *wrapper,
  int32_t idx,
  double value
) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_bind_double(wrapper->stmt, idx, value);
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_text(
  moonbit_sqlite3_stmt *wrapper,
  int32_t idx,
  moonbit_bytes_t text
) {
  assert(wrapper->stmt);
  int32_t len = Moonbit_array_length(text);
  return (int32_t)sqlite3_bind_text(
    wrapper->stmt, idx, (const char *)text, len, SQLITE_TRANSIENT
  );
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_blob(
  moonbit_sqlite3_stmt *wrapper,
  int32_t idx,
  moonbit_bytes_t blob
) {
  assert(wrapper->stmt);
  int32_t len = Moonbit_array_length(blob);
  return (int32_t)sqlite3_bind_blob(
    wrapper->stmt, idx, (const void *)blob, len, SQLITE_TRANSIENT
  );
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_bind_null(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_bind_null(wrapper->stmt, idx);
}

/* ---------- Column functions ---------- */

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_column_int(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_column_int(wrapper->stmt, idx);
}

MOONBIT_FFI_EXPORT
int64_t
moonbit_sqlite3_column_int64(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  return sqlite3_column_int64(wrapper->stmt, idx);
}

MOONBIT_FFI_EXPORT
double
moonbit_sqlite3_column_double(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  return sqlite3_column_double(wrapper->stmt, idx);
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_sqlite3_column_text(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  const unsigned char *text = sqlite3_column_text(wrapper->stmt, idx);
  int32_t len = 0;
  if (text) {
    len = (int32_t)sqlite3_column_bytes(wrapper->stmt, idx);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  if (text && len > 0) {
    memcpy(bytes, text, len);
  }
  return bytes;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_sqlite3_column_blob(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  const void *blob = sqlite3_column_blob(wrapper->stmt, idx);
  int32_t len = 0;
  if (blob) {
    len = (int32_t)sqlite3_column_bytes(wrapper->stmt, idx);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  if (blob && len > 0) {
    memcpy(bytes, blob, len);
  }
  return bytes;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_sqlite3_column_type(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  return (int32_t)sqlite3_column_type(wrapper->stmt, idx);
}
