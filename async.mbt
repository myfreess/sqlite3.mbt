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
    let rescode = job.rescode()
    match self.apply_step_result(rescode) {
      Some(has_row) => has_row
      None => {
        let extended_rescode = job.extended_rescode()
        let message = job.message()
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
  }
  if @async.is_being_cancelled() {
    @async.pause()
  }
  result
}
