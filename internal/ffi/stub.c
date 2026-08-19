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
  /* Strong reference keeps the connection wrapper alive with the statement. */
  moonbit_sqlite3 *db_wrapper;
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
moonbit_sqlite3_open_v2(
  moonbit_bytes_t filename,
  moonbit_sqlite3 *db,
  int32_t flags
) {
  /* SQLite's UTF-16 APIs use host order unless a BOM says otherwise. */
  const uint16_t one = 1;
  if (*(const unsigned char *)&one != 1) {
    return SQLITE_MISUSE;
  }
  return (int32_t)sqlite3_open_v2(
    (const char *)filename,
    &db->db,
    flags,
    NULL
  );
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
moonbit_string_t
moonbit_sqlite3_errmsg(moonbit_sqlite3 *wrapper) {
  assert(wrapper->db);
  const uint16_t *msg = (const uint16_t *)sqlite3_errmsg16(wrapper->db);
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
moonbit_sqlite3_prepare16_v2(
  moonbit_sqlite3 *db,
  moonbit_string_t sql,
  moonbit_sqlite3_stmt *stmt,
  int32_t *tail_offset
) {
  assert(db->db);
  *tail_offset = -1;
  int32_t sql_len = Moonbit_array_length(sql);
  if (sql_len > INT32_MAX / (int32_t)sizeof(uint16_t)) {
    return SQLITE_TOOBIG;
  }
  const void *tail = NULL;
  int rc = sqlite3_prepare16_v2(
    db->db,
    (const void *)sql,
    sql_len * (int32_t)sizeof(uint16_t),
    &stmt->stmt,
    &tail
  );
  if (rc != SQLITE_OK) {
    return (int32_t)rc;
  }
  if (!stmt->stmt) {
    return SQLITE_OK;
  }
  *tail_offset = (int32_t)((const uint16_t *)tail - sql);
  moonbit_incref(db);
  stmt->db_wrapper = db;
  return SQLITE_OK;
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
  moonbit_string_t text
) {
  assert(wrapper->stmt);
  sqlite3_uint64 byte_len =
    (sqlite3_uint64)Moonbit_array_length(text) * sizeof(uint16_t);
  return (int32_t)sqlite3_bind_text64(
    wrapper->stmt,
    idx,
    (const char *)text,
    byte_len,
    SQLITE_TRANSIENT,
    SQLITE_UTF16LE
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
moonbit_string_t
moonbit_sqlite3_column_text(moonbit_sqlite3_stmt *wrapper, int32_t idx) {
  assert(wrapper->stmt);
  const void *text = sqlite3_column_text16(wrapper->stmt, idx);
  int32_t byte_len = 0;
  if (text) {
    byte_len = (int32_t)sqlite3_column_bytes16(wrapper->stmt, idx);
  }
  assert(byte_len % (int32_t)sizeof(uint16_t) == 0);
  int32_t len = byte_len / (int32_t)sizeof(uint16_t);
  moonbit_string_t result = moonbit_make_string_raw(len);
  if (text && byte_len > 0) {
    memcpy(result, text, (size_t)byte_len);
  }
  return result;
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
