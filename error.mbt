///|
pub suberror SqliteError {
  SqliteError((Int, SourceLoc))
} derive(Debug)

///|
pub fn Connection::get_errmsg(conn : Connection) -> String {
  @ffi.sqlite3_errmsg(conn.handle_for_errmsg())
}
