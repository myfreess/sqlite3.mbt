///|
/// Open a database without blocking the MoonBit event loop.
///
/// On native targets the worker created for this operation is retained by the
/// connection for later asynchronous operations. A wasm host may complete the
/// operation synchronously.
pub async fn Connection::open_async(filename : String) -> Connection {
  if filename.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: filename contains a NUL code unit")
  }
  let executor = create_executor()
  let mut executor_owned = true
  defer (if executor_owned { @ffi.sqlite3_executor_release(executor) })
  let database = @async.protect_from_cancel() <| () => {
    let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
    let submit_rescode = Ref(SQLITE_OK)
    let job = @ffi.sqlite3_open_job(
      executor,
      @utf8.encode(filename),
      flags,
      submit_rescode,
    )
    defer job.release()
    if submit_rescode.val != SQLITE_OK {
      raise sqlite_error(
        submit_rescode.val,
        "sqlite3: failed to submit asynchronous open",
      )
    }
    job.wait()
    let (rescode, extended_rescode, message) = job.result()
    if rescode != SQLITE_OK {
      raise sqlite_error(
        extended_rescode,
        if message == "" {
          "sqlite3: asynchronous open failed"
        } else {
          message
        },
      )
    }
    job.take_database()
  }
  if @async.is_being_cancelled() {
    let _ = @ffi.sqlite3_close(database)
    @async.pause()
  }
  executor_owned = false
  Connection::from_open_database(database, Some(executor))
}

///|
/// Prepare one SQL statement without blocking the MoonBit event loop.
///
/// Operations on the same connection are serialized. A wasm host may complete
/// the operation synchronously. Cancellation waits for an in-flight prepare
/// and finalizes its result before returning control to the caller.
pub async fn Connection::prepare_async(
  self : Connection,
  sql : String,
) -> Statement {
  if sql.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: SQL contains a NUL code unit")
  }
  self.0.val.job_gate.acquire()
  defer self.0.val.job_gate.release()
  let statement = @async.protect_from_cancel() <| () => {
    let (database, executor) = self.begin_job()
    defer self.finish_job()
    let submit_rescode = Ref(SQLITE_OK)
    let job = @ffi.sqlite3_prepare_job(executor, database, sql, submit_rescode)
    defer job.release()
    if submit_rescode.val != SQLITE_OK {
      raise sqlite_error(
        submit_rescode.val,
        "sqlite3: failed to submit asynchronous prepare",
      )
    }
    job.wait()
    let (rescode, extended_rescode, message, tail_offset) = job.result()
    if rescode != SQLITE_OK {
      raise sqlite_error(
        extended_rescode,
        if message == "" {
          "sqlite3: asynchronous prepare failed"
        } else {
          message
        },
      )
    }
    if tail_offset < 0 {
      raise sqlite_misuse("sqlite3: SQL does not contain a statement")
    }
    if tail_offset > sql.length() || !sql_tail_is_ignorable(sql, tail_offset) {
      raise sqlite_misuse("sqlite3: SQL contains more than one statement")
    }
    job.take_statement()
  }
  if @async.is_being_cancelled() {
    let _ = @ffi.sqlite3_finalize(statement)
    @async.pause()
  }
  {
    handle: Some(statement),
    has_row: false,
    column_types: None,
    connection: self,
  }
}

///|
/// Execute one step without blocking the MoonBit event loop.
///
/// Operations on the same connection are serialized. Operations on different
/// connections may run concurrently on their respective native workers. A
/// wasm host may complete the operation synchronously.
///
/// Synchronous operations on the connection are rejected while its
/// asynchronous step is running.
///
/// Cancellation waits for an in-flight SQLite step to finish before returning
/// the connection and statement to the caller.
pub async fn Statement::step_async(self : Statement) -> Bool {
  let connection = self.connection
  connection.0.val.job_gate.acquire()
  defer connection.0.val.job_gate.release()
  let result = @async.protect_from_cancel() <| () => {
    let statement = self.get_handle()
    let (database, executor) = connection.begin_job()
    defer connection.finish_job()
    self.has_row = false
    self.column_types = None
    let submit_rescode = Ref(SQLITE_OK)
    let job = @ffi.sqlite3_step_job(
      executor, database, statement, submit_rescode,
    )
    defer job.release()
    if submit_rescode.val != SQLITE_OK {
      raise sqlite_error(
        submit_rescode.val,
        "sqlite3: failed to submit asynchronous operation",
      )
    }
    job.wait()
    let (rescode, extended_rescode, message) = job.result()
    match self.apply_step_result(rescode) {
      Some(has_row) => has_row
      None =>
        raise sqlite_error(
          extended_rescode,
          if message == "" {
            "sqlite3: asynchronous operation failed"
          } else {
            message
          },
        )
    }
  }
  if @async.is_being_cancelled() {
    @async.pause()
  }
  result
}
