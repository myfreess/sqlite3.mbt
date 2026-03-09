///|
pub suberror SqliteError {
  SqliteError((Int, SourceLoc))
} derive(Show)

///|
pub fn Connection::get_errmsg(conn : Connection) -> String {
  let utf8str = @ffi.sqlite3_errmsg(conn.0)
  @utf8.decode_lossy(utf8str)
}
