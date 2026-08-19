///|
#external
pub type Sqlite3

///|
#external
pub type Sqlite3Stmt

///|
#borrow(filename, rescode)
pub extern "c" fn sqlite3_open_v2(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3 = "moonbit_sqlite3_open_v2"

///|
pub extern "c" fn sqlite3_close(db : Sqlite3) -> Int = "sqlite3_close"

///|
pub extern "c" fn sqlite3_errmsg(db : Sqlite3) -> String = "moonbit_sqlite3_errmsg"

///|
pub extern "c" fn sqlite3_errcode(db : Sqlite3) -> Int = "sqlite3_errcode"

///|
#borrow(sql)
pub extern "c" fn sqlite3_exec(db : Sqlite3, sql : Bytes) -> Int = "moonbit_sqlite3_exec"

///|
/// `tail_offset` is measured in UTF-16 code units, or -1 when SQLite produces
/// no statement.
#borrow(sql, tail_offset, rescode)
pub extern "c" fn sqlite3_prepare16_v2(
  db : Sqlite3,
  sql : String,
  tail_offset : Ref[Int],
  rescode : Ref[Int],
) -> Sqlite3Stmt = "moonbit_sqlite3_prepare16_v2"

///|
pub extern "c" fn sqlite3_step(stmt : Sqlite3Stmt) -> Int = "sqlite3_step"

///|
pub extern "c" fn sqlite3_reset(stmt : Sqlite3Stmt) -> Int = "sqlite3_reset"

///|
pub extern "c" fn sqlite3_finalize(stmt : Sqlite3Stmt) -> Int = "sqlite3_finalize"

///|
pub extern "c" fn sqlite3_column_count(stmt : Sqlite3Stmt) -> Int = "sqlite3_column_count"

// --- Bind functions ---

///|
pub extern "c" fn sqlite3_bind_int(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int,
) -> Int = "sqlite3_bind_int"

///|
pub extern "c" fn sqlite3_bind_int64(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int64,
) -> Int = "sqlite3_bind_int64"

///|
pub extern "c" fn sqlite3_bind_double(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Double,
) -> Int = "sqlite3_bind_double"

///|
#borrow(text)
pub extern "c" fn sqlite3_bind_text(
  stmt : Sqlite3Stmt,
  idx : Int,
  text : String,
) -> Int = "moonbit_sqlite3_bind_text"

///|
#borrow(blob)
pub extern "c" fn sqlite3_bind_blob(
  stmt : Sqlite3Stmt,
  idx : Int,
  blob : Bytes,
) -> Int = "moonbit_sqlite3_bind_blob"

///|
pub extern "c" fn sqlite3_bind_null(stmt : Sqlite3Stmt, idx : Int) -> Int = "sqlite3_bind_null"

// --- Column functions ---

///|
pub extern "c" fn sqlite3_column_int(stmt : Sqlite3Stmt, idx : Int) -> Int = "sqlite3_column_int"

///|
pub extern "c" fn sqlite3_column_int64(stmt : Sqlite3Stmt, idx : Int) -> Int64 = "sqlite3_column_int64"

///|
pub extern "c" fn sqlite3_column_double(
  stmt : Sqlite3Stmt,
  idx : Int,
) -> Double = "sqlite3_column_double"

///|
pub extern "c" fn sqlite3_column_text(stmt : Sqlite3Stmt, idx : Int) -> String = "moonbit_sqlite3_column_text"

///|
pub extern "c" fn sqlite3_column_blob(stmt : Sqlite3Stmt, idx : Int) -> Bytes = "moonbit_sqlite3_column_blob"

///|
pub extern "c" fn sqlite3_column_type(stmt : Sqlite3Stmt, idx : Int) -> Int = "sqlite3_column_type"
