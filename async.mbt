///|
/// The outcome of one asynchronous call to `Statement::step_async`.
///
/// `Done(changes=None)` means SQLite classified the statement as read-only.
/// For a potentially writing statement, `Done(changes=Some(count))` carries
/// the connection's direct row-change count captured before its mutex was
/// released.
pub(all) enum StepResult {
  Row
  Done(changes~ : Int64?)
} derive(Debug, Eq)

///|
/// Open a database without blocking the MoonBit event loop.
///
/// The worker created for this operation is retained by the connection for
/// later asynchronous operations.
pub async fn Connection::open_async(filename : String) -> Connection {
  if filename.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: filename contains a NUL code unit")
  }
  let executor = create_executor()
  let mut executor_owned = true
  defer (if executor_owned { @ffi.sqlite3_executor_release(executor) })
  let database = @async.protect_from_cancel() <| () => {
    let flags = SQLITE_OPEN_READWRITE |
      SQLITE_OPEN_CREATE |
      SQLITE_OPEN_FULLMUTEX
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
/// Jobs for one connection share its worker. Cancellation waits for an
/// in-flight prepare and finalizes its result before returning control to the
/// caller.
pub async fn Connection::prepare_async(
  self : Connection,
  sql : String,
) -> Statement {
  if sql.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: SQL contains a NUL code unit")
  }
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
    let database = self.handle()
    @ffi.sqlite3_db_mutex_enter(database)
    defer @ffi.sqlite3_db_mutex_leave(database)
    let _ = @ffi.sqlite3_finalize(statement)
    @async.pause()
  }
  {
    handle: Some(statement),
    step_in_flight: Ref(false),
    has_row: false,
    column_types: None,
    connection: self,
  }
}

///|
/// Execute one step without blocking the MoonBit event loop.
///
/// Jobs for one connection share its worker. Operations on different
/// connections may run concurrently on their respective workers.
///
/// Synchronous operations on other statements may run while this step is in
/// flight, but can block behind SQLite's serialized connection access. The
/// statement being stepped rejects synchronous use until the step completes.
///
/// Cancellation waits for an in-flight SQLite step to finish before returning
/// the connection and statement to the caller.
pub async fn Statement::step_async(self : Statement) -> StepResult {
  let connection = self.connection
  let result = @async.protect_from_cancel() <| () => {
    let statement = self.get_handle()
    self.step_in_flight.val = true
    defer {
      self.step_in_flight.val = false
    }
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
    let (rescode, extended_rescode, message, changes) = job.result()
    match rescode {
      SQLITE_ROW => {
        self.has_row = true
        Row
      }
      SQLITE_DONE => Done(changes~)
      _ =>
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
