///|
struct Connection(Sqlite3)

///|
const SQLITE_OPEN_READWRITE : Int = 0x00000002

///|
const SQLITE_OPEN_CREATE : Int = 0x00000004

///|
#callsite(autofill(loc))
pub fn Connection::open(
  filename : String,
  loc~ : SourceLoc,
) -> Connection raise SqliteError {
  let filename = @utf8.encode(filename)
  let db = sqlite3_allocate()
  let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
  let rescode = sqlite3_open_v2(filename, db, flags)
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
  let rescode = sqlite3_close(self.0)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub fn Connection::get_errmsg(self : Connection) -> String {
  sqlite3_errmsg(self.0)
}
