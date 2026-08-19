///|
trait Column {
  fn column(Statement, Int) -> Self
}

///|
pub impl Column for Int with fn column(stmt, index) {
  stmt.column_int(index)
}

///|
pub impl Column for Int64 with fn column(stmt, index) {
  stmt.column_int64(index)
}

///|
pub impl Column for Double with fn column(stmt, index) {
  stmt.column_double(index)
}

///|
pub impl Column for Bytes with fn column(stmt, index) {
  stmt.column_blob(index)
}

///|
pub impl Column for String with fn column(stmt, index) {
  stmt.column_text(index)
}
