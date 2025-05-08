#include "sqlite3.h"
#include <moonbit.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifdef DEBUG
#include <stdio.h>
#define moonbit_sqlite3_trace(format, ...)                                          \
  fprintf(stderr, "%s: " format, __func__, __VA_ARGS__)
#else
#define moonbit_sqlite3_trace(...)
#endif

const void** moonbit_sqlite3_mkref() {
  const void** ref = malloc(sizeof(void*));
  return ref;
}

const void* moonbit_sqlite3_readref(const void** object_ref) {
  return *object_ref;
}

int moonbit_sqlite3_bind_bytes(sqlite3_stmt *stmt, int param_index, const void* bytes, int len) {
  return sqlite3_bind_blob(stmt, param_index, bytes, len, SQLITE_TRANSIENT);
}

int moonbit_sqlite3_bind_string(sqlite3_stmt *stmt, int param_index, const void* string, int len) {
  return sqlite3_bind_blob(stmt, param_index, string, len, SQLITE_TRANSIENT);
}

moonbit_bytes_t moonbit_sqlite3_column_bytes(sqlite3_stmt *stmt, int col_index) {
  const void* blob = sqlite3_column_blob(stmt, col_index);
  if (NULL == blob) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = sqlite3_column_bytes(stmt, col_index);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, blob, len);
  return bytes;
}

moonbit_string_t moonbit_sqlite3_column_string(sqlite3_stmt *stmt, int col_index) {
  const void* blob = sqlite3_column_blob(stmt, col_index);
  if (NULL == blob) {
    return moonbit_make_string(0, 0);
  }
  size_t len = sqlite3_column_bytes(stmt, col_index);
  uint8_t *str = (uint8_t *)moonbit_make_string(len / 2, 0);
  memcpy(str, blob, len);
  return (moonbit_string_t)str;
}

moonbit_bytes_t moonbit_sqlite3_errmsg(sqlite3 *db) {
  const char *errmsg = sqlite3_errmsg(db);
  if (NULL == errmsg) {
    return moonbit_make_bytes(0, 0);
  }
  size_t len = strlen(errmsg);
  moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
  memcpy(bytes, errmsg, len);
  return bytes;
}