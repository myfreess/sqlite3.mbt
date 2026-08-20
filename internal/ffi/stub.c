#include "sqlite3.h"
#include <assert.h>
#include <moonbit.h>
#include <stdbool.h>
#include <string.h>

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
  moonbit_string_t text
) {
  sqlite3_uint64 byte_len =
    (sqlite3_uint64)Moonbit_array_length(text) * sizeof(uint16_t);
  return (int32_t)sqlite3_bind_text64(
    stmt,
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
  sqlite3_stmt *stmt,
  int32_t idx,
  moonbit_bytes_t blob
) {
  int32_t len = Moonbit_array_length(blob);
  return (int32_t)sqlite3_bind_blob(
    stmt, idx, (const void *)blob, len, SQLITE_TRANSIENT
  );
}

/* ---------- Column functions ---------- */

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_column_text(sqlite3_stmt *stmt, int32_t idx) {
  const void *text = sqlite3_column_text16(stmt, idx);
  int32_t byte_len = 0;
  if (text) {
    byte_len = (int32_t)sqlite3_column_bytes16(stmt, idx);
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
moonbit_sqlite3_column_blob(sqlite3_stmt *stmt, int32_t idx) {
  const void *blob = sqlite3_column_blob(stmt, idx);
  int32_t len = 0;
  if (blob) {
    len = (int32_t)sqlite3_column_bytes(stmt, idx);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  if (blob && len > 0) {
    memcpy(bytes, blob, len);
  }
  return bytes;
}
