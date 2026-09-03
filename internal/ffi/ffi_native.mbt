///|
#external
priv type Sqlite3Handle

///|
#external
priv type Sqlite3StmtHandle

///|
#external
priv type Sqlite3MutexHandle

///|
extern "c" fn sqlite3_db_mutex_impl(
  database : Sqlite3Handle,
) -> Sqlite3MutexHandle = "sqlite3_db_mutex"

///|
extern "c" fn sqlite3_mutex_enter_raw(mutex : Sqlite3MutexHandle) -> Unit = "sqlite3_mutex_enter"

///|
extern "c" fn sqlite3_mutex_leave_raw(mutex : Sqlite3MutexHandle) -> Unit = "sqlite3_mutex_leave"

///|
fn sqlite3_db_mutex_enter_impl(database : Sqlite3Handle) -> Unit {
  sqlite3_mutex_enter_raw(sqlite3_db_mutex_impl(database))
}

///|
fn sqlite3_db_mutex_leave_impl(database : Sqlite3Handle) -> Unit {
  sqlite3_mutex_leave_raw(sqlite3_db_mutex_impl(database))
}

///|
#external
priv type Sqlite3ExecutorHandle

///|
#external
priv type Sqlite3JobHandle

///|
#borrow(rescode)
extern "c" fn sqlite3_executor_create_impl(
  rescode : Ref[Int],
) -> Sqlite3ExecutorHandle = "moonbit_sqlite3_executor_create"

///|
extern "c" fn sqlite3_executor_release_impl(
  executor : Sqlite3ExecutorHandle,
) -> Unit = "moonbit_sqlite3_executor_release"

///|
#borrow(filename, rescode)
extern "c" fn sqlite3_open_v2_impl(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3Handle = "moonbit_sqlite3_open_v2"

///|
#borrow(filename, rescode)
extern "c" fn sqlite3_open_job_impl(
  executor : Sqlite3ExecutorHandle,
  filename : Bytes,
  flags : Int,
  notification : @types.Fd,
  rescode : Ref[Int],
) -> Sqlite3JobHandle = "moonbit_sqlite3_open_job"

///|
extern "c" fn sqlite3_open_job_database_impl(
  job : Sqlite3JobHandle,
) -> Sqlite3Handle = "moonbit_sqlite3_open_job_database"

///|
extern "c" fn sqlite3_open_job_release_impl(job : Sqlite3JobHandle) -> Unit = "moonbit_sqlite3_open_job_release"

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
#borrow(sql, rescode)
extern "c" fn sqlite3_prepare_job_impl(
  executor : Sqlite3ExecutorHandle,
  db : Sqlite3Handle,
  sql : String,
  notification : @types.Fd,
  rescode : Ref[Int],
) -> Sqlite3JobHandle = "moonbit_sqlite3_prepare_job"

///|
extern "c" fn sqlite3_prepare_job_statement_impl(
  job : Sqlite3JobHandle,
) -> Sqlite3StmtHandle = "moonbit_sqlite3_prepare_job_statement"

///|
extern "c" fn sqlite3_prepare_job_tail_offset_impl(
  job : Sqlite3JobHandle,
) -> Int = "moonbit_sqlite3_prepare_job_tail_offset"

///|
extern "c" fn sqlite3_prepare_job_release_impl(job : Sqlite3JobHandle) -> Unit = "moonbit_sqlite3_prepare_job_release"

///|
extern "c" fn sqlite3_step_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_step"

///|
#borrow(rescode)
extern "c" fn sqlite3_step_job_impl(
  executor : Sqlite3ExecutorHandle,
  db : Sqlite3Handle,
  stmt : Sqlite3StmtHandle,
  notification : @types.Fd,
  rescode : Ref[Int],
) -> Sqlite3JobHandle = "moonbit_sqlite3_step_job"

///|
extern "c" fn sqlite3_job_is_ready_impl(job : Sqlite3JobHandle) -> Bool = "moonbit_sqlite3_job_is_ready"

///|
extern "c" fn sqlite3_job_rescode_impl(job : Sqlite3JobHandle) -> Int = "moonbit_sqlite3_job_rescode"

///|
extern "c" fn sqlite3_job_extended_rescode_impl(job : Sqlite3JobHandle) -> Int = "moonbit_sqlite3_job_extended_rescode"

///|
extern "c" fn sqlite3_job_message_impl(job : Sqlite3JobHandle) -> String = "moonbit_sqlite3_job_message"

///|
extern "c" fn sqlite3_step_job_release_impl(job : Sqlite3JobHandle) -> Unit = "moonbit_sqlite3_step_job_release"

///|
extern "c" fn sqlite3_finalize_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_finalize"

///|
extern "c" fn sqlite3_column_count_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_column_count"

///|
extern "c" fn sqlite3_reset_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_reset"

///|
extern "c" fn sqlite3_clear_bindings_impl(stmt : Sqlite3StmtHandle) -> Int = "sqlite3_clear_bindings"

///|
extern "c" fn sqlite3_changes64_impl(db : Sqlite3Handle) -> Int64 = "sqlite3_changes64"

///|
#borrow(available)
extern "c" fn sqlite3_column_name_copy_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  available : Ref[Int],
) -> String = "moonbit_sqlite3_column_name"

///|
fn sqlite3_column_name_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
) -> String? {
  let available = Ref(0)
  let name = sqlite3_column_name_copy_impl(statement, index, available)
  match available.val {
    0 => None
    1 => Some(name)
    _ => abort("sqlite3: native column-name bridge returned an invalid state")
  }
}

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
  text_offset : Int,
  text_length : Int,
) -> Int = "moonbit_sqlite3_bind_text"

///|
#borrow(blob)
extern "c" fn sqlite3_bind_blob_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
  blob : Bytes,
  blob_offset : Int,
  blob_length : Int,
) -> Int = "moonbit_sqlite3_bind_blob"

///|
extern "c" fn sqlite3_bind_null_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int = "sqlite3_bind_null"

// --- Column functions ---

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
/// SQLite reports conversion allocation failures through the connection, so
/// the adapter returns that result code alongside the copied value.
#borrow(rescode)
extern "c" fn sqlite3_column_text_impl(
  db : Sqlite3Handle,
  stmt : Sqlite3StmtHandle,
  idx : Int,
  rescode : Ref[Int],
) -> String = "moonbit_sqlite3_column_text"

///|
#borrow(rescode)
extern "c" fn sqlite3_column_blob_impl(
  db : Sqlite3Handle,
  stmt : Sqlite3StmtHandle,
  idx : Int,
  rescode : Ref[Int],
) -> Bytes = "moonbit_sqlite3_column_blob"

///|
extern "c" fn sqlite3_column_type_impl(
  stmt : Sqlite3StmtHandle,
  idx : Int,
) -> Int = "sqlite3_column_type"
