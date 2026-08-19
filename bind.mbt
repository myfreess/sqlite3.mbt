///|
trait Bind {
  fn bind(Statement, Int, Self, loc~ : SourceLoc) -> Unit raise SqliteError
}

///|
pub impl Bind for Double with fn bind(
  stmt,
  param_index,
  value,
  loc~ : SourceLoc,
) {
  let rescode = @ffi.sqlite3_bind_double(stmt.handle(loc), param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_int(stmt.handle(loc), param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int64 with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_int64(stmt.handle(loc), param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Bytes with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_blob(stmt.handle(loc), param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for String with fn bind(
  stmt,
  param_index,
  value,
  loc~ : SourceLoc,
) {
  let rescode = @ffi.sqlite3_bind_text(stmt.handle(loc), param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
