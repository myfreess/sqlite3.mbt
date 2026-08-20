///|
struct Sqlite3(Sqlite3Handle)

///|
struct Sqlite3Stmt(Sqlite3StmtHandle)

///|
pub fn sqlite3_open_v2(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3 {
  Sqlite3(sqlite3_open_v2_impl(filename, flags, rescode))
}

///|
pub fn sqlite3_close(database : Sqlite3) -> Int {
  sqlite3_close_impl(database.0)
}

///|
pub fn sqlite3_errmsg(database : Sqlite3) -> String {
  sqlite3_errmsg_impl(database.0)
}

///|
pub fn sqlite3_errcode(database : Sqlite3) -> Int {
  sqlite3_errcode_impl(database.0)
}

///|
pub fn sqlite3_prepare16_v2(
  database : Sqlite3,
  sql : String,
  tail_offset : Ref[Int],
  rescode : Ref[Int],
) -> Sqlite3Stmt {
  Sqlite3Stmt(sqlite3_prepare16_v2_impl(database.0, sql, tail_offset, rescode))
}

///|
pub fn sqlite3_step(statement : Sqlite3Stmt) -> Int {
  sqlite3_step_impl(statement.0)
}

///|
pub fn sqlite3_finalize(statement : Sqlite3Stmt) -> Int {
  sqlite3_finalize_impl(statement.0)
}

///|
pub fn sqlite3_column_count(statement : Sqlite3Stmt) -> Int {
  sqlite3_column_count_impl(statement.0)
}

///|
pub fn sqlite3_bind_int(
  statement : Sqlite3Stmt,
  index : Int,
  value : Int,
) -> Int {
  sqlite3_bind_int_impl(statement.0, index, value)
}

///|
pub fn sqlite3_bind_int64(
  statement : Sqlite3Stmt,
  index : Int,
  value : Int64,
) -> Int {
  sqlite3_bind_int64_impl(statement.0, index, value)
}

///|
pub fn sqlite3_bind_double(
  statement : Sqlite3Stmt,
  index : Int,
  value : Double,
) -> Int {
  sqlite3_bind_double_impl(statement.0, index, value)
}

///|
pub fn sqlite3_bind_text(
  statement : Sqlite3Stmt,
  index : Int,
  value : String,
) -> Int {
  sqlite3_bind_text_impl(statement.0, index, value)
}

///|
pub fn sqlite3_bind_blob(
  statement : Sqlite3Stmt,
  index : Int,
  value : Bytes,
) -> Int {
  sqlite3_bind_blob_impl(statement.0, index, value)
}

///|
pub fn sqlite3_bind_null(statement : Sqlite3Stmt, index : Int) -> Int {
  sqlite3_bind_null_impl(statement.0, index)
}

///|
pub fn sqlite3_column_int(statement : Sqlite3Stmt, index : Int) -> Int {
  sqlite3_column_int_impl(statement.0, index)
}

///|
pub fn sqlite3_column_int64(statement : Sqlite3Stmt, index : Int) -> Int64 {
  sqlite3_column_int64_impl(statement.0, index)
}

///|
pub fn sqlite3_column_double(statement : Sqlite3Stmt, index : Int) -> Double {
  sqlite3_column_double_impl(statement.0, index)
}

///|
pub fn sqlite3_column_text(statement : Sqlite3Stmt, index : Int) -> String {
  sqlite3_column_text_impl(statement.0, index)
}

///|
pub fn sqlite3_column_blob(statement : Sqlite3Stmt, index : Int) -> Bytes {
  sqlite3_column_blob_impl(statement.0, index)
}

///|
pub fn sqlite3_column_type(statement : Sqlite3Stmt, index : Int) -> Int {
  sqlite3_column_type_impl(statement.0, index)
}
