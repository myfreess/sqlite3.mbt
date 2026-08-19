///|
#external
priv type DatabaseSync

///|
#external
priv type DatabaseSyncOptions

///|
#external
priv type NodeSqliteError

///|
#external
priv type DatabaseOpenResult

///|
#external
priv type DatabaseUnitResult

///|
struct Connection {
  db : DatabaseSync
  mut last_error : String
  mut live_statements : Int
  mut closed : Bool
}

///|
/// MoonBit currently lowers a `#module` function import to a call wrapper. The
/// callback keeps the normal static dependency, while `database_sync_new`
/// performs the one operation that the wrapper cannot express: `new` on the
/// imported class.
#module("node:sqlite")
extern "js" fn database_sync_import(
  filename : String,
  options : DatabaseSyncOptions,
) -> DatabaseSync = "DatabaseSync"

///|
extern "js" fn database_sync_options() -> DatabaseSyncOptions =
  #| () => ({
  #|   enableForeignKeyConstraints: false,
  #|   enableDoubleQuotedStringLiterals: true,
  #|   defensive: false,
  #|   readBigInts: true,
  #|   returnArrays: true,
  #| })

///|
extern "js" fn database_sync_new(
  database_sync : (String, DatabaseSyncOptions) -> DatabaseSync,
  filename : String,
  options : DatabaseSyncOptions,
) -> DatabaseOpenResult =
  #| function(_databaseSync, filename, options) {
  #|   try {
  #|     const { DatabaseSync } = globalThis.process.getBuiltinModule("node:sqlite");
  #|     return { ok: true, value: new DatabaseSync(filename, options) };
  #|   } catch (error) {
  #|     return { ok: false, error };
  #|   }
  #| }

///|
extern "js" fn DatabaseOpenResult::is_ok(self : Self) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn DatabaseOpenResult::database(self : Self) -> DatabaseSync =
  #| (result) => result.value

///|
extern "js" fn DatabaseOpenResult::error(self : Self) -> NodeSqliteError =
  #| (result) => result.error

///|
extern "js" fn database_sync_close(db : DatabaseSync) -> DatabaseUnitResult =
  #| function(db) {
  #|   try {
  #|     db.close();
  #|     return { ok: true };
  #|   } catch (error) {
  #|     return { ok: false, error };
  #|   }
  #| }

///|
extern "js" fn DatabaseUnitResult::is_ok(self : Self) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn DatabaseUnitResult::error(self : Self) -> NodeSqliteError =
  #| (result) => result.error

///|
extern "js" fn NodeSqliteError::sqlite_code(self : Self) -> Int =
  #| (error) => Number.isInteger(error?.errcode) ? error.errcode : 0

///|
extern "js" fn NodeSqliteError::message(self : Self) -> String =
  #| (error) => error?.message ?? String(error)

///|
fn node_error_rescode(error : NodeSqliteError, fallback : Int) -> Int {
  let extended = error.sqlite_code()
  if extended > 0 {
    extended % 256
  } else {
    fallback
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::open(
  filename : String,
  loc~ : SourceLoc,
) -> Connection raise SqliteError {
  let result = database_sync_new(
    database_sync_import,
    filename,
    database_sync_options(),
  )
  if !result.is_ok() {
    raise SqliteError(
      (node_error_rescode(result.error(), SQLITE_CANTOPEN), loc),
    )
  }
  {
    db: result.database(),
    last_error: "not an error",
    live_statements: 0,
    closed: false,
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::close(
  self : Connection,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  if self.closed {
    return
  }
  if self.live_statements > 0 {
    self.last_error = "unable to close due to unfinalized statements or unfinished backups"
    raise SqliteError((SQLITE_BUSY, loc))
  }
  let result = database_sync_close(self.db)
  if !result.is_ok() {
    let error = result.error()
    self.last_error = error.message()
    raise SqliteError((node_error_rescode(error, SQLITE_MISUSE), loc))
  }
  self.closed = true
}

///|
pub fn Connection::get_errmsg(self : Connection) -> String {
  self.last_error
}
