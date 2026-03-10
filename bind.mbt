///|
trait Bind {
  bind(Statement, Int, Self, loc~ : SourceLoc) -> Unit raise SqliteError
}

///|
pub impl Bind for Double with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_double(stmt.0, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_int(stmt.0, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int64 with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_int64(stmt.0, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Bytes with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_blob(stmt.0, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for String with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = @ffi.sqlite3_bind_text(stmt.0, param_index, @utf8.encode(value))
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
