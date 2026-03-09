///|
trait Column {
  column(Statement, Int) -> Self
}

///|
pub impl Column for Int with column(stmt, index) {
  @ffi.sqlite3_column_int(stmt.0, index)
}

///|
pub impl Column for Int64 with column(stmt, index) {
  @ffi.sqlite3_column_int64(stmt.0, index)
}

///|
pub impl Column for Double with column(stmt, index) {
  @ffi.sqlite3_column_double(stmt.0, index)
}

///|
pub impl Column for Bytes with column(stmt, index) {
  @ffi.sqlite3_column_blob(stmt.0, index)
}
