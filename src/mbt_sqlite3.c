#include "sqlite3.h"
#include <moonbit.h>
#ifdef DEBUG
#include <stdio.h>
#define moonbit_sqlite3_trace(format, ...)                                          \
  fprintf(stderr, "%s: " format, __func__, __VA_ARGS__)
#else
#define moonbit_sqlite3_trace(...)
#endif

// int moonbit_sqlite3_bind_bytes(sqlite3_stmt *stmt, int param_index, const void* bytes, int len, void (*decref)(void*)) {
//   return sqlite3_bind_blob(stmt, param_index, bytes, len, moonbit_decref);
// }

