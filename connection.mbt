///|
struct Connection(Ref[@ffi.Sqlite3?])

///|
fn Connection::handle(self : Connection) -> @ffi.Sqlite3 raise SqliteError {
  match self.0.val {
    Some(db) => db
    None => raise sqlite_misuse("sqlite3: connection is closed")
  }
}

///|
fn Connection::error(self : Connection, raw_code : Int) -> SqliteError {
  match self.0.val {
    Some(db) => sqlite_error(raw_code, @ffi.sqlite3_errmsg(db))
    None => sqlite_error(raw_code, "sqlite3: database connection is closed")
  }
}

///|
const SQLITE_OPEN_READWRITE : Int = 0x00000002

///|
const SQLITE_OPEN_CREATE : Int = 0x00000004

///|
pub fn Connection::open(filename : String) -> Connection raise SqliteError {
  if filename.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: filename contains a NUL code unit")
  }
  let filename = @utf8.encode(filename)
  let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
  let rescode = Ref(SQLITE_OK)
  let db = @ffi.sqlite3_open_v2(filename, flags, rescode)
  if rescode.val == SQLITE_OK {
    return Connection(Ref(Some(db)))
  } else {
    let error = if @ffi.sqlite3_is_null(db) {
      sqlite_error(rescode.val, "sqlite3: failed to allocate a database handle")
    } else {
      sqlite_error(rescode.val, @ffi.sqlite3_errmsg(db))
    }
    let _ = @ffi.sqlite3_close(db)
    raise error
  }
}

///|
pub fn Connection::close(self : Connection) -> Unit raise SqliteError {
  match self.0.val {
    None => ()
    Some(db) => {
      let rescode = @ffi.sqlite3_close(db)
      if rescode == SQLITE_OK {
        self.0.val = None
      } else {
        raise self.error(rescode)
      }
    }
  }
}
