///|
priv type Sqlite3

///|
priv type Sqlite3Stmt

///|
extern "c" fn sqlite3_allocate() -> Sqlite3 = "moonbit_sqlite3_allocate"

///|
#borrow(filename, db)
extern "c" fn sqlite3_open_v2(
  filename : Bytes,
  db : Sqlite3,
  flags : Int,
) -> Int = "moonbit_sqlite3_open_v2"

///|
#borrow(db)
extern "c" fn sqlite3_close(db : Sqlite3) -> Int = "moonbit_sqlite3_close"

///|
#borrow(db)
extern "c" fn sqlite3_errmsg(db : Sqlite3) -> String = "moonbit_sqlite3_errmsg"

///|
extern "c" fn sqlite3_stmt_allocate() -> Sqlite3Stmt = "moonbit_sqlite3_stmt_allocate"

///|
/// `tail_offset` is measured in UTF-16 code units, or -1 when SQLite produces
/// no statement.
#borrow(db, sql, stmt, tail_offset)
extern "c" fn sqlite3_prepare16_v2(
  db : Sqlite3,
  sql : String,
  stmt : Sqlite3Stmt,
  tail_offset : Ref[Int],
) -> Int = "moonbit_sqlite3_prepare16_v2"

///|
#borrow(stmt)
extern "c" fn sqlite3_step(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_step"

///|
#borrow(stmt)
extern "c" fn sqlite3_finalize(stmt : Sqlite3Stmt) -> Int = "moonbit_sqlite3_finalize"

///|
#borrow(stmt)
extern "c" fn sqlite3_bind_int(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int,
) -> Int = "moonbit_sqlite3_bind_int"

///|
#borrow(stmt)
extern "c" fn sqlite3_bind_int64(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Int64,
) -> Int = "moonbit_sqlite3_bind_int64"

///|
#borrow(stmt)
extern "c" fn sqlite3_bind_double(
  stmt : Sqlite3Stmt,
  idx : Int,
  value : Double,
) -> Int = "moonbit_sqlite3_bind_double"

///|
#borrow(stmt, text)
extern "c" fn sqlite3_bind_text(
  stmt : Sqlite3Stmt,
  idx : Int,
  text : String,
) -> Int = "moonbit_sqlite3_bind_text"

///|
#borrow(stmt, blob)
extern "c" fn sqlite3_bind_blob(
  stmt : Sqlite3Stmt,
  idx : Int,
  blob : Bytes,
) -> Int = "moonbit_sqlite3_bind_blob"

///|
#borrow(stmt)
extern "c" fn sqlite3_column_int(stmt : Sqlite3Stmt, idx : Int) -> Int = "moonbit_sqlite3_column_int"

///|
#borrow(stmt)
extern "c" fn sqlite3_column_int64(stmt : Sqlite3Stmt, idx : Int) -> Int64 = "moonbit_sqlite3_column_int64"

///|
#borrow(stmt)
extern "c" fn sqlite3_column_double(stmt : Sqlite3Stmt, idx : Int) -> Double = "moonbit_sqlite3_column_double"

///|
#borrow(stmt)
extern "c" fn sqlite3_column_text(stmt : Sqlite3Stmt, idx : Int) -> String = "moonbit_sqlite3_column_text"

///|
#borrow(stmt)
extern "c" fn sqlite3_column_blob(stmt : Sqlite3Stmt, idx : Int) -> Bytes = "moonbit_sqlite3_column_blob"
