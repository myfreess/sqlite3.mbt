pub extern type Connection

extern "c" fn sqlite3_open(filename : Bytes, out : Array[Connection]) -> Int = "sqlite3_open"
extern "c" fn sqlite3_close(conn : Connection) -> Int = "sqlite3_close"

pub fn Connection::open(filename : String) -> Connection!SqliteError {
  let filename = @encoding.encode(UTF8, filename)
  let out = Array::new(capacity = 1)
  let rescode = sqlite3_open(filename, out)
  if rescode == SQLITE_OK {
    let sqlite3_object = out[0]
    return sqlite3_object
  } else {
    raise SqliteError(rescode)
  }
}

pub fn Connection::close(self : Connection) -> Unit!SqliteError {
  let rescode = sqlite3_close(self)
  if rescode != SQLITE_OK {
    raise SqliteError(rescode)
  }
}

