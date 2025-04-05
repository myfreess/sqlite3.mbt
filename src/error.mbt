///|
pub type! SqliteError (Int, SourceLoc) derive(Show)

///|
extern "c" fn sqlite3_errmsg(conn : Connection) -> Bytes = "moonbit_sqlite3_errmsg"

///|
pub fn Connection::get_errmsg(conn : Connection) -> String {
  let utf8str = sqlite3_errmsg(conn)
  @encoding.decode_lossy(@encoding.decoder(UTF8), utf8str)
}
