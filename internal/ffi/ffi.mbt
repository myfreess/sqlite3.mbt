///|
pub type Sqlite3

///|
pub type Sqlite3Stmt

///|
pub extern "c" fn sqlite3_allocate() -> Sqlite3 = "moonbit_sqlite3_allocate"

///|
#borrow(filename, db)
pub extern "c" fn sqlite3_open(filename : Bytes, db : Sqlite3) -> Int = "moonbit_sqlite3_open"

///|
#borrow(db)
pub extern "c" fn sqlite3_close(db : Sqlite3) -> Int = "moonbit_sqlite3_close"

///|
#borrow(db)
pub extern "c" fn sqlite3_errmsg(db : Sqlite3) -> Bytes = "moonbit_sqlite3_errmsg"

///|
#borrow(db)
pub extern "c" fn sqlite3_errcode(db : Sqlite3) -> Int = "moonbit_sqlite3_errcode"

///|
#borrow(db, sql)
pub extern "c" fn sqlite3_exec(db : Sqlite3, sql : Bytes) -> Int = "moonbit_sqlite3_exec"

///|
pub extern "c" fn sqlite3_stmt_allocate() -> Sqlite3Stmt = "moonbit_sqlite3_stmt_allocate"

///|
#borrow(db, sql, stmt)
pub extern "c" fn sqlite3_prepare_v2(
  db : Sqlite3,
  sql : Bytes,
  stmt : Sqlite3Stmt,
) -> Int = "moonbit_sqlite3_prepare_v2"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_step(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_step"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_reset(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_reset"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_finalize(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_finalize"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_count(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_column_count"

// --- Bind functions ---

///|
#borrow(stmt)
pub extern "c" fn sqlite3_bind_int(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int,
) -> Int = "moonbit_sqlite3_bind_int"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_bind_int64(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int64,
) -> Int = "moonbit_sqlite3_bind_int64"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_bind_double(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Double,
) -> Int = "moonbit_sqlite3_bind_double"

///|
#borrow(stmt, text)
pub extern "c" fn sqlite3_bind_text(
  stmt : Sqlite3Stmt,
  idx : Int,
  text : Bytes,
) -> Int = "moonbit_sqlite3_bind_text"

///|
#borrow(stmt, blob)
pub extern "c" fn sqlite3_bind_blob(
  stmt : Sqlite3Stmt,
  idx : Int,
  blob : Bytes,
) -> Int = "moonbit_sqlite3_bind_blob"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_bind_null(stmt : Sqlite3Stmt, idx : Int) -> Int = "moonbit_sqlite3_bind_null"

// --- Column functions ---

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_int(stmt : Sqlite3Stmt, idx : Int) -> Int = "moonbit_sqlite3_column_int"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_int64(stmt : Sqlite3Stmt, idx : Int) -> Int64 = "moonbit_sqlite3_column_int64"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_double(
  stmt : Sqlite3Stmt,
  idx : Int,
) -> Double = "moonbit_sqlite3_column_double"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_text(stmt : Sqlite3Stmt, idx : Int) -> Bytes = "moonbit_sqlite3_column_text"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_blob(stmt : Sqlite3Stmt, idx : Int) -> Bytes = "moonbit_sqlite3_column_blob"

///|
#borrow(stmt)
pub extern "c" fn sqlite3_column_type(stmt : Sqlite3Stmt, idx : Int) -> Int = "moonbit_sqlite3_column_type"
