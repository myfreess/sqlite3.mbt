///|
struct Connection(Ref[@ffi.Sqlite3?])

///|
fn Connection::handle(
  self : Connection,
  loc : SourceLoc,
) -> @ffi.Sqlite3 raise SqliteError {
  match self.0.val {
    Some(db) => db
    None => raise SqliteError((SQLITE_MISUSE, loc))
  }
}

///|
fn Connection::handle_for_errmsg(self : Connection) -> @ffi.Sqlite3 {
  match self.0.val {
    Some(db) => db
    None => abort("sqlite3: error message requested after connection close")
  }
}

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
  let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
  let rescode = Ref(SQLITE_OK)
  let db = @ffi.sqlite3_open_v2(filename, flags, rescode)
  if rescode.val == SQLITE_OK {
    return Connection(Ref(Some(db)))
  } else {
    let _ = @ffi.sqlite3_close(db)
    raise SqliteError((rescode.val, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::close(
  self : Connection,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  match self.0.val {
    None => ()
    Some(db) => {
      let rescode = @ffi.sqlite3_close(db)
      if rescode == SQLITE_OK {
        self.0.val = None
      } else {
        raise SqliteError((rescode, loc))
      }
    }
  }
}
