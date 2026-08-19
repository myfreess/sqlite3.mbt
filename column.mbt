///|
trait Column {
  fn column(Statement, Int) -> Self
}

///|
pub impl Column for Int with fn column(stmt, index) {
  @ffi.sqlite3_column_int(stmt.0, index)
}

///|
pub impl Column for Int64 with fn column(stmt, index) {
  @ffi.sqlite3_column_int64(stmt.0, index)
}

///|
pub impl Column for Double with fn column(stmt, index) {
  @ffi.sqlite3_column_double(stmt.0, index)
}

///|
pub impl Column for Bytes with fn column(stmt, index) {
  @ffi.sqlite3_column_blob(stmt.0, index)
}

///|
pub impl Column for String with fn column(stmt, index) {
  @ffi.sqlite3_column_text(stmt.0, index)
}
