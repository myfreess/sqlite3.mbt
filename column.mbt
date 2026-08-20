///|
trait Column {
  fn column(Statement, Int) -> Self raise SqliteError
}

///|
pub impl Column for Int64 with fn column(stmt, index) {
  @ffi.sqlite3_column_int64(stmt.handle_for_column(index), index)
}

///|
pub impl Column for Double with fn column(stmt, index) {
  @ffi.sqlite3_column_double(stmt.handle_for_column(index), index)
}

///|
pub impl Column for Bytes with fn column(stmt, index) {
  @ffi.sqlite3_column_blob(stmt.handle_for_column(index), index)
}

///|
pub impl Column for String with fn column(stmt, index) {
  @ffi.sqlite3_column_text(stmt.handle_for_column(index), index)
}
