trait Writeable {
  write(Statement, Int, Self) -> Unit!SqliteError
}

impl Writeable for Double with write(stmt, param_index, value) {
  let rescode = sqlite3_bind_double(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError(rescode)
  }
}

impl Writeable for Int with write(stmt, param_index, value) {
  let rescode = sqlite3_bind_int(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError(rescode)
  }
}

impl Writeable for Int64 with write(stmt, param_index, value) {
  let rescode = sqlite3_bind_int64(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError(rescode)
  }
}