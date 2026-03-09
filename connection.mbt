///|
struct Connection(@ffi.Sqlite3)

///|
#callsite(autofill(loc))
pub fn Connection::open(
  filename : String,
  loc~ : SourceLoc,
) -> Connection raise SqliteError {
  let filename = @utf8.encode(filename)
  let db = @ffi.sqlite3_allocate()
  let rescode = @ffi.sqlite3_open(filename, db)
  if rescode == SQLITE_OK {
    return Connection(db)
  } else {
    raise SqliteError((rescode, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::close(
  self : Connection,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = @ffi.sqlite3_close(self.0)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
