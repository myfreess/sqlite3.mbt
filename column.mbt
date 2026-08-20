///|
trait Column {
  fn column(Statement, Int) -> Self raise SqliteError
}

///|
pub impl Column for Int64 with fn column(stmt, index) {
  let (statement, _) = stmt.column_info(index)
  @ffi.sqlite3_column_int64(statement, index)
}

///|
pub impl Column for Double with fn column(stmt, index) {
  let (statement, _) = stmt.column_info(index)
  @ffi.sqlite3_column_double(statement, index)
}

///|
pub impl Column for Bytes with fn column(stmt, index) {
  let (statement, _) = stmt.column_info(index)
  let rescode = Ref(SQLITE_OK)
  let value = @ffi.sqlite3_column_blob(
    stmt.connection.handle(),
    statement,
    index,
    rescode,
  )
  if rescode.val != SQLITE_OK {
    // A conversion OOM marks the SQLite statement failed.
    stmt.has_row = false
    stmt.column_types = None
    raise stmt.error(rescode.val)
  }
  value
}

///|
pub impl Column for String with fn column(stmt, index) {
  let (statement, _) = stmt.column_info(index)
  let rescode = Ref(SQLITE_OK)
  let value = @ffi.sqlite3_column_text(
    stmt.connection.handle(),
    statement,
    index,
    rescode,
  )
  if rescode.val != SQLITE_OK {
    // A conversion OOM marks the SQLite statement failed.
    stmt.has_row = false
    stmt.column_types = None
    raise stmt.error(rescode.val)
  }
  value
}
