///|
#external
priv type Sqlite3Handle

///|
#external
priv type Sqlite3StmtHandle

///|
#borrow(filename, rescode)
extern "c" fn sqlite3_open_v2_impl(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3Handle = "moonbit_sqlite3_open_v2"

///|
extern "c" fn sqlite3_close_impl(db : Sqlite3Handle) -> Int = "sqlite3_close"

///|
extern "c" fn sqlite3_is_null_impl(db : Sqlite3Handle) -> Bool = "moonbit_sqlite3_is_null"

///|
extern "c" fn sqlite3_errmsg_impl(db : Sqlite3Handle) -> String = "moonbit_sqlite3_errmsg"

///|
extern "c" fn sqlite3_errcode_impl(db : Sqlite3Handle) -> Int = "sqlite3_errcode"

///|
/// `tail_offset` is measured in UTF-16 code units, or -1 when SQLite produces
/// no statement.
#borrow(sql, tail_offset, rescode)
extern "c" fn sqlite3_prepare16_v2_impl(
  db : Sqlite3Handle,
  sql : String,
  tail_offset : Ref[Int],
  rescode : Ref[Int],
) -> Sqlite3StmtHandle = "moonbit_sqlite3_prepare16_v2"

///|
extern "c" fn sqlite3_step_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_step"

///|
extern "c" fn sqlite3_finalize_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_finalize"

///|
extern "c" fn sqlite3_column_count_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_column_count"

// --- Bind functions ---

///|
extern "c" fn sqlite3_bind_int_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  value : Int,
) -> Int = "sqlite3_bind_int"

///|
extern "c" fn sqlite3_bind_int64_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  value : Int64,
) -> Int = "sqlite3_bind_int64"

///|
extern "c" fn sqlite3_bind_double_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  value : Double,
) -> Int = "sqlite3_bind_double"

///|
#borrow(text)
extern "c" fn sqlite3_bind_text_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  text : String,
) -> Int = "moonbit_sqlite3_bind_text"

///|
#borrow(blob)
extern "c" fn sqlite3_bind_blob_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  blob : Bytes,
) -> Int = "moonbit_sqlite3_bind_blob"

///|
extern "c" fn sqlite3_bind_null_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int = "sqlite3_bind_null"

// --- Column functions ---

///|
extern "c" fn sqlite3_column_int_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int = "sqlite3_column_int"

///|
extern "c" fn sqlite3_column_int64_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int64 = "sqlite3_column_int64"

///|
extern "c" fn sqlite3_column_double_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Double = "sqlite3_column_double"

///|
extern "c" fn sqlite3_column_text_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> String = "moonbit_sqlite3_column_text"

///|
extern "c" fn sqlite3_column_blob_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Bytes = "moonbit_sqlite3_column_blob"

///|
extern "c" fn sqlite3_column_type_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int = "sqlite3_column_type"
