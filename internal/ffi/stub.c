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
  moonbit_string_t text,
  int32_t text_offset,
  int32_t text_length
) {
  const uint16_t *start = (const uint16_t *)text + text_offset;
  sqlite3_uint64 byte_len = (sqlite3_uint64)text_length * sizeof(uint16_t);
  return (int32_t)sqlite3_bind_text64(
    stmt,
    idx,
    (const char *)start,
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
  moonbit_bytes_t blob,
  int32_t blob_offset,
  int32_t blob_length
) {
  const uint8_t *start = (const uint8_t *)blob + blob_offset;
  return (int32_t)sqlite3_bind_blob(
    stmt, idx, (const void *)start, blob_length, SQLITE_TRANSIENT
  );
}

/* ---------- Column functions ---------- */

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_column_name(
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *available
) {
  /* sqlite3_column_name16() has no result-code return. In the bundled SQLite,
   * a conversion OOM is reported only as NULL and does not update the
   * connection error code, so expose pointer availability rather than
   * manufacturing a SQLite result code. The MoonBit API validates idx. */
  const uint16_t *name = (const uint16_t *)sqlite3_column_name16(stmt, idx);
  if (!name) {
    *available = 0;
    return moonbit_make_string_raw(0);
  }
  *available = 1;
  int32_t len = 0;
  while (name[len] != 0) {
    len++;
  }
  moonbit_string_t result = moonbit_make_string_raw(len);
  memcpy(result, name, (size_t)len * sizeof(uint16_t));
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_string_t
moonbit_sqlite3_column_text(
  sqlite3 *db,
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  int32_t prior_code = sqlite3_errcode(db);
  const void *text = sqlite3_column_text16(stmt, idx);
  if (!text) {
    int32_t code = sqlite3_errcode(db);
    /* SQLite does not clear older connection errors on successful reads.
     * Treat NOMEM as local to this conversion only when this call introduced
     * it; an already-recorded NOMEM may belong to another statement. */
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_string_raw(0);
  }
  int32_t byte_len = (int32_t)sqlite3_column_bytes16(stmt, idx);
  if (byte_len == 0) {
    int32_t code = sqlite3_errcode(db);
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_string_raw(0);
  }
  assert(byte_len % (int32_t)sizeof(uint16_t) == 0);
  int32_t len = byte_len / (int32_t)sizeof(uint16_t);
  moonbit_string_t result = moonbit_make_string_raw(len);
  memcpy(result, text, (size_t)byte_len);
  return result;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_sqlite3_column_blob(
  sqlite3 *db,
  sqlite3_stmt *stmt,
  int32_t idx,
  int32_t *rescode
) {
  *rescode = SQLITE_OK;
  int32_t prior_code = sqlite3_errcode(db);
  const void *blob = sqlite3_column_blob(stmt, idx);
  if (!blob) {
    int32_t code = sqlite3_errcode(db);
    /* Zero-length blobs and SQL NULL also return NULL. As above, require a
     * transition to NOMEM instead of propagating connection-wide history. */
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_bytes(0, 0);
  }
  int32_t len = (int32_t)sqlite3_column_bytes(stmt, idx);
  if (len == 0) {
    int32_t code = sqlite3_errcode(db);
    *rescode =
      code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM ? code : SQLITE_OK;
    return moonbit_make_bytes(0, 0);
  }
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, blob, len);
  return bytes;
}
