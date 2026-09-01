///|
const SQLITE_OK = 0

///|
const SQLITE_NOMEM = 7

///|
fn sqlite3_null_handle_import() -> UInt64 = "moonbitlang/sqlite" "sqlite3_null_handle"

///|
#unsafe_skip_stub_check
#borrow(filename, database)
fn sqlite3_open_v2_import(
  filename : Bytes,
  filename_length : Int,
  database : Ref[UInt64],
  flags : Int,
  vfs : UInt64,
) -> Int = "moonbitlang/sqlite" "sqlite3_open_v2"

///|
fn sqlite3_errmsg16_length_import(database : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_errmsg16_length"

///|
#unsafe_skip_stub_check
#borrow(output)
fn sqlite3_errmsg16_import(
  database : UInt64,
  output : String,
  capacity : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_errmsg16"

///|
fn sqlite3_errcode_import(database : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_errcode"

///|
fn sqlite3_extended_errcode_import(database : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_extended_errcode"

///|
fn sqlite3_changes64_import(database : UInt64) -> Int64 = "moonbitlang/sqlite" "sqlite3_changes64"

///|
fn sqlite3_close_import(database : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_close"

///|
#unsafe_skip_stub_check
#borrow(sql, statement, tail)
fn sqlite3_prepare16_v2_import(
  database : UInt64,
  sql : String,
  sql_offset : Int,
  sql_length : Int,
  statement : Ref[UInt64],
  tail : Ref[Int],
) -> Int = "moonbitlang/sqlite" "sqlite3_prepare16_v2"

///|
fn sqlite3_bind_null_import(statement : UInt64, index : Int) -> Int = "moonbitlang/sqlite" "sqlite3_bind_null"

///|
fn sqlite3_bind_int64_import(
  statement : UInt64,
  index : Int,
  value : Int64,
) -> Int = "moonbitlang/sqlite" "sqlite3_bind_int64"

///|
fn sqlite3_bind_double_import(
  statement : UInt64,
  index : Int,
  value : Double,
) -> Int = "moonbitlang/sqlite" "sqlite3_bind_double"

///|
#unsafe_skip_stub_check
#borrow(value)
fn sqlite3_bind_text16_import(
  statement : UInt64,
  index : Int,
  value : String,
  value_offset : Int,
  value_length : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_bind_text16"

///|
#unsafe_skip_stub_check
#borrow(value)
fn sqlite3_bind_blob_import(
  statement : UInt64,
  index : Int,
  value : Bytes,
  value_offset : Int,
  value_length : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_bind_blob"

///|
fn sqlite3_step_import(statement : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_step"

///|
fn sqlite3_reset_import(statement : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_reset"

///|
fn sqlite3_clear_bindings_import(statement : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_clear_bindings"

///|
fn sqlite3_finalize_import(statement : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_finalize"

///|
fn sqlite3_column_count_import(statement : UInt64) -> Int = "moonbitlang/sqlite" "sqlite3_column_count"

///|
/// Return the UTF-16 content length, or `-1` when SQLite returns NULL.
fn sqlite3_column_name16_length_import(statement : UInt64, column : Int) -> Int = "moonbitlang/sqlite" "sqlite3_column_name16_length"

///|
/// Copy the UTF-16 content and return its full length, or `-1` when SQLite
/// returns NULL.
#unsafe_skip_stub_check
#borrow(output)
fn sqlite3_column_name16_import(
  statement : UInt64,
  column : Int,
  output : String,
  capacity : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_column_name16"

///|
fn sqlite3_column_type_import(statement : UInt64, column : Int) -> Int = "moonbitlang/sqlite" "sqlite3_column_type"

///|
fn sqlite3_column_int64_import(statement : UInt64, column : Int) -> Int64 = "moonbitlang/sqlite" "sqlite3_column_int64"

///|
fn sqlite3_column_double_import(statement : UInt64, column : Int) -> Double = "moonbitlang/sqlite" "sqlite3_column_double"

///|
fn sqlite3_column_text16_length_import(statement : UInt64, column : Int) -> Int = "moonbitlang/sqlite" "sqlite3_column_text16_length"

///|
#unsafe_skip_stub_check
#borrow(output)
fn sqlite3_column_text16_import(
  statement : UInt64,
  column : Int,
  output : String,
  capacity : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_column_text16"

///|
fn sqlite3_column_blob_length_import(statement : UInt64, column : Int) -> Int = "moonbitlang/sqlite" "sqlite3_column_blob_length"

///|
#unsafe_skip_stub_check
#borrow(output)
fn sqlite3_column_blob_import(
  statement : UInt64,
  column : Int,
  output : FixedArray[Byte],
  capacity : Int,
) -> Int = "moonbitlang/sqlite" "sqlite3_column_blob"

///|
priv struct Sqlite3Handle(UInt64)

///|
priv struct Sqlite3StmtHandle(UInt64)

///|
priv struct Sqlite3ExecutorHandle(Int)

///|
priv struct Sqlite3JobHandle {
  rescode : Int
  extended_rescode : Int
  message : String
  mut database : Sqlite3Handle?
  mut statement : Sqlite3StmtHandle?
  tail_offset : Int
}

///|
fn sqlite3_executor_create_impl(rescode : Ref[Int]) -> Sqlite3ExecutorHandle {
  rescode.val = SQLITE_OK
  Sqlite3ExecutorHandle(0)
}

///|
fn sqlite3_executor_release_impl(_executor : Sqlite3ExecutorHandle) -> Unit {
  ignore(_executor.0)
}

///|
fn sqlite3_db_mutex_enter_impl(_database : Sqlite3Handle) -> Unit {
  ignore(_database.0)
}

///|
fn sqlite3_db_mutex_leave_impl(_database : Sqlite3Handle) -> Unit {
  ignore(_database.0)
}

///|
fn sqlite3_open_v2_impl(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3Handle {
  let null_handle = sqlite3_null_handle_import()
  let database = Ref(null_handle)
  rescode.val = sqlite3_open_v2_import(
    filename,
    filename.length(),
    database,
    flags,
    null_handle,
  )
  Sqlite3Handle(database.val)
}

///|
fn sqlite3_open_job_impl(
  _executor : Sqlite3ExecutorHandle,
  filename : Bytes,
  flags : Int,
  notification : @types.Fd,
  submit_rescode : Ref[Int],
) -> Sqlite3JobHandle {
  ignore((_executor, notification))
  submit_rescode.val = SQLITE_OK
  let rescode = Ref(SQLITE_OK)
  let database = sqlite3_open_v2_impl(filename, flags, rescode)
  if rescode.val == SQLITE_OK {
    {
      rescode: SQLITE_OK,
      extended_rescode: SQLITE_OK,
      message: "",
      database: Some(database),
      statement: None,
      tail_offset: -1,
    }
  } else {
    let is_null = sqlite3_is_null_impl(database)
    let extended_rescode = if is_null {
      rescode.val
    } else {
      sqlite3_extended_errcode_import(database.0)
    }
    let message = if is_null { "" } else { sqlite3_errmsg_impl(database) }
    let _ = sqlite3_close_impl(database)
    {
      rescode: rescode.val,
      extended_rescode,
      message,
      database: None,
      statement: None,
      tail_offset: -1,
    }
  }
}

///|
fn sqlite3_open_job_database_impl(job : Sqlite3JobHandle) -> Sqlite3Handle {
  match job.database {
    Some(database) => {
      job.database = None
      database
    }
    None => Sqlite3Handle(sqlite3_null_handle_import())
  }
}

///|
fn sqlite3_open_job_release_impl(job : Sqlite3JobHandle) -> Unit {
  if job.database is Some(database) {
    let _ = sqlite3_close_impl(database)
    job.database = None
  }
}

///|
fn sqlite3_close_impl(database : Sqlite3Handle) -> Int {
  sqlite3_close_import(database.0)
}

///|
fn sqlite3_is_null_impl(database : Sqlite3Handle) -> Bool {
  database.0 == sqlite3_null_handle_import()
}

///|
fn sqlite3_errmsg_impl(database : Sqlite3Handle) -> String {
  let length = sqlite3_errmsg16_length_import(database.0)
  let output = String::make(length, '\u0000')
  let copied = sqlite3_errmsg16_import(database.0, output, output.length())
  if copied != length {
    abort("sqlite3: error message changed while being copied")
  }
  output
}

///|
fn sqlite3_errcode_impl(database : Sqlite3Handle) -> Int {
  sqlite3_errcode_import(database.0)
}

///|
fn sqlite3_changes64_impl(database : Sqlite3Handle) -> Int64 {
  sqlite3_changes64_import(database.0)
}

///|
fn sqlite3_prepare16_v2_impl(
  database : Sqlite3Handle,
  sql : String,
  tail_offset : Ref[Int],
  rescode : Ref[Int],
) -> Sqlite3StmtHandle {
  let null_handle = sqlite3_null_handle_import()
  let statement = Ref(null_handle)
  let tail = Ref(0)
  rescode.val = sqlite3_prepare16_v2_import(
    database.0,
    sql,
    0,
    sql.length(),
    statement,
    tail,
  )
  if rescode.val == 0 && statement.val != null_handle {
    tail_offset.val = tail.val
  } else {
    tail_offset.val = -1
  }
  Sqlite3StmtHandle(statement.val)
}

///|
fn sqlite3_prepare_job_impl(
  _executor : Sqlite3ExecutorHandle,
  database : Sqlite3Handle,
  sql : String,
  notification : @types.Fd,
  submit_rescode : Ref[Int],
) -> Sqlite3JobHandle {
  ignore((_executor, notification))
  submit_rescode.val = SQLITE_OK
  let tail_offset = Ref(-1)
  let rescode = Ref(SQLITE_OK)
  let statement = sqlite3_prepare16_v2_impl(database, sql, tail_offset, rescode)
  if rescode.val == SQLITE_OK {
    let statement = if tail_offset.val < 0 { None } else { Some(statement) }
    {
      rescode: SQLITE_OK,
      extended_rescode: SQLITE_OK,
      message: "",
      database: None,
      statement,
      tail_offset: tail_offset.val,
    }
  } else {
    if statement.0 != sqlite3_null_handle_import() {
      let _ = sqlite3_finalize_impl(statement)
    }
    {
      rescode: rescode.val,
      extended_rescode: sqlite3_extended_errcode_import(database.0),
      message: sqlite3_errmsg_impl(database),
      database: None,
      statement: None,
      tail_offset: -1,
    }
  }
}

///|
fn sqlite3_prepare_job_statement_impl(
  job : Sqlite3JobHandle,
) -> Sqlite3StmtHandle {
  match job.statement {
    Some(statement) => {
      job.statement = None
      statement
    }
    None => Sqlite3StmtHandle(sqlite3_null_handle_import())
  }
}

///|
fn sqlite3_prepare_job_tail_offset_impl(job : Sqlite3JobHandle) -> Int {
  job.tail_offset
}

///|
fn sqlite3_prepare_job_release_impl(job : Sqlite3JobHandle) -> Unit {
  if job.statement is Some(statement) {
    let _ = sqlite3_finalize_impl(statement)
    job.statement = None
  }
}

///|
fn sqlite3_step_impl(statement : Sqlite3StmtHandle) -> Int {
  sqlite3_step_import(statement.0)
}

///|
fn sqlite3_step_job_impl(
  _executor : Sqlite3ExecutorHandle,
  database : Sqlite3Handle,
  statement : Sqlite3StmtHandle,
  notification : @types.Fd,
  submit_rescode : Ref[Int],
) -> Sqlite3JobHandle {
  ignore((_executor, notification))
  submit_rescode.val = SQLITE_OK
  let rescode = sqlite3_step_import(statement.0)
  let extended_rescode = sqlite3_extended_errcode_import(database.0)
  let message = if rescode == 100 || rescode == 101 {
    ""
  } else {
    sqlite3_errmsg_impl(database)
  }
  {
    rescode,
    extended_rescode,
    message,
    database: None,
    statement: None,
    tail_offset: -1,
  }
}

///|
fn sqlite3_job_is_ready_impl(_job : Sqlite3JobHandle) -> Bool {
  true
}

///|
fn sqlite3_job_rescode_impl(job : Sqlite3JobHandle) -> Int {
  job.rescode
}

///|
fn sqlite3_job_extended_rescode_impl(job : Sqlite3JobHandle) -> Int {
  job.extended_rescode
}

///|
fn sqlite3_job_message_impl(job : Sqlite3JobHandle) -> String {
  job.message
}

///|
fn sqlite3_step_job_release_impl(_job : Sqlite3JobHandle) -> Unit {

}

///|
fn sqlite3_reset_impl(statement : Sqlite3StmtHandle) -> Int {
  sqlite3_reset_import(statement.0)
}

///|
fn sqlite3_clear_bindings_impl(statement : Sqlite3StmtHandle) -> Int {
  sqlite3_clear_bindings_import(statement.0)
}

///|
fn sqlite3_finalize_impl(statement : Sqlite3StmtHandle) -> Int {
  sqlite3_finalize_import(statement.0)
}

///|
fn sqlite3_column_count_impl(statement : Sqlite3StmtHandle) -> Int {
  sqlite3_column_count_import(statement.0)
}

///|
fn sqlite3_column_name_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
) -> String? {
  let length = sqlite3_column_name16_length_import(statement.0, index)
  if length == -1 {
    return None
  }
  if length < -1 {
    abort("sqlite3: column-name length import returned an invalid value")
  }
  if length == 0 {
    return Some("")
  }
  let output = String::make(length, '\u0000')
  let copied = sqlite3_column_name16_import(
    statement.0,
    index,
    output,
    output.length(),
  )
  if copied == -1 {
    return None
  }
  if copied < -1 {
    abort("sqlite3: column-name copy import returned an invalid value")
  }
  if copied != length {
    abort("sqlite3: result column name changed while being copied")
  }
  Some(output)
}

///|
fn sqlite3_bind_int_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
  value : Int,
) -> Int {
  sqlite3_bind_int64_import(statement.0, index, value.to_int64())
}

///|
fn sqlite3_bind_int64_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
  value : Int64,
) -> Int {
  sqlite3_bind_int64_import(statement.0, index, value)
}

///|
fn sqlite3_bind_double_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
  value : Double,
) -> Int {
  sqlite3_bind_double_import(statement.0, index, value)
}

///|
fn sqlite3_bind_text_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
  value : String,
  value_offset : Int,
  value_length : Int,
) -> Int {
  sqlite3_bind_text16_import(
    statement.0,
    index,
    value,
    value_offset,
    value_length,
  )
}

///|
fn sqlite3_bind_blob_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
  value : Bytes,
  value_offset : Int,
  value_length : Int,
) -> Int {
  sqlite3_bind_blob_import(
    statement.0,
    index,
    value,
    value_offset,
    value_length,
  )
}

///|
fn sqlite3_bind_null_impl(statement : Sqlite3StmtHandle, index : Int) -> Int {
  sqlite3_bind_null_import(statement.0, index)
}

///|
fn sqlite3_column_int64_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
) -> Int64 {
  sqlite3_column_int64_import(statement.0, index)
}

///|
fn sqlite3_column_double_impl(
  statement : Sqlite3StmtHandle,
  index : Int,
) -> Double {
  sqlite3_column_double_import(statement.0, index)
}

///|
fn sqlite3_column_text_impl(
  database : Sqlite3Handle,
  statement : Sqlite3StmtHandle,
  index : Int,
  rescode : Ref[Int],
) -> String {
  let prior_code = sqlite3_errcode_import(database.0)
  let length = sqlite3_column_text16_length_import(statement.0, index)
  if length == 0 {
    // The host deliberately makes no further SQLite call when the value
    // accessor returns NULL, leaving this error available to the guest.
    let code = sqlite3_errcode_import(database.0)
    // Connection error state is persistent, so only a transition to NOMEM can
    // be attributed to this conversion rather than another statement.
    rescode.val = if code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM {
      code
    } else {
      SQLITE_OK
    }
    return ""
  }
  rescode.val = SQLITE_OK
  let output = String::make(length, '\u0000')
  let copied = sqlite3_column_text16_import(
    statement.0,
    index,
    output,
    output.length(),
  )
  if copied != length {
    abort("sqlite3: text column changed while being copied")
  }
  output
}

///|
fn sqlite3_column_blob_impl(
  database : Sqlite3Handle,
  statement : Sqlite3StmtHandle,
  index : Int,
  rescode : Ref[Int],
) -> Bytes {
  let prior_code = sqlite3_errcode_import(database.0)
  let length = sqlite3_column_blob_length_import(statement.0, index)
  if length == 0 {
    let code = sqlite3_errcode_import(database.0)
    // Zero-length BLOBs and SQL NULL also produce a null pointer.
    rescode.val = if code == SQLITE_NOMEM && prior_code != SQLITE_NOMEM {
      code
    } else {
      SQLITE_OK
    }
    return b""
  }
  rescode.val = SQLITE_OK
  let output : FixedArray[Byte] = FixedArray::make(length, 0)
  let copied = sqlite3_column_blob_import(
    statement.0,
    index,
    output,
    output.length(),
  )
  if copied != length {
    abort("sqlite3: blob column changed while being copied")
  }
  Bytes::from_array(output)
}

///|
fn sqlite3_column_type_impl(statement : Sqlite3StmtHandle, index : Int) -> Int {
  sqlite3_column_type_import(statement.0, index)
}
