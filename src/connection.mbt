///|
pub extern type Connection

///|
priv extern type ConnectionRef

///|
extern "c" fn ConnectionRef::malloc() -> ConnectionRef = "moonbit_sqlite3_mkref"

///|
extern "c" fn ConnectionRef::read(self : ConnectionRef) -> Connection = "moonbit_sqlite3_readref"

///|
extern "c" fn sqlite3_open(filename : Bytes, out : ConnectionRef) -> Int = "sqlite3_open"

///|
extern "c" fn sqlite3_close(conn : Connection) -> Int = "sqlite3_close"

///|
pub fn Connection::open(
  filename : String,
  loc~ : SourceLoc = _
) -> Connection!SqliteError {
  let buf = @buffer.new(size_hint=filename.length() * 2)
  @encoding.encode_to(filename, buf, encoding=UTF8)
  buf.write_byte(0x00)
  let filename = buf.contents()
  let out = ConnectionRef::malloc()
  let rescode = sqlite3_open(filename, out)
  if rescode == SQLITE_OK {
    let sqlite3_object = out.read()
    return sqlite3_object
  } else {
    raise SqliteError((rescode, loc))
  }
}

///|
pub fn Connection::close(
  self : Connection,
  loc~ : SourceLoc = _
) -> Unit!SqliteError {
  let rescode = sqlite3_close(self)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
