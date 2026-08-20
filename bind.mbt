///|
trait Bind {
  fn bind(Statement, Int, Self) -> Unit raise SqliteError
}

///|
pub impl Bind for Double with fn bind(stmt, param_index, value) {
  let rescode = @ffi.sqlite3_bind_double(stmt.get_handle(), param_index, value)
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}

///|
pub impl Bind for Int with fn bind(stmt, param_index, value) {
  let rescode = @ffi.sqlite3_bind_int(stmt.get_handle(), param_index, value)
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}

///|
pub impl Bind for Int64 with fn bind(stmt, param_index, value) {
  let rescode = @ffi.sqlite3_bind_int64(stmt.get_handle(), param_index, value)
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}

///|
pub impl Bind for Bytes with fn bind(stmt, param_index, value) {
  let rescode = @ffi.sqlite3_bind_blob(stmt.get_handle(), param_index, value)
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}

///|
pub impl Bind for String with fn bind(stmt, param_index, value) {
  let rescode = @ffi.sqlite3_bind_text(stmt.get_handle(), param_index, value)
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}
