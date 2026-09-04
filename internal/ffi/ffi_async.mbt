///|
priv struct Sqlite3Job {
  handle : Sqlite3JobHandle
  mut notification : @pipe.PipeRead?
}

///|
struct Sqlite3OpenJob(Sqlite3Job)

///|
struct Sqlite3PrepareJob(Sqlite3Job)

///|
struct Sqlite3StepJob(Sqlite3Job)

///|
pub fn sqlite3_open_job(
  executor : Sqlite3Executor,
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3OpenJob raise {
  let (notification, notifier) = @pipe.pipe()
  defer notifier.close()
  Sqlite3OpenJob({
    handle: sqlite3_open_job_impl(
      executor.0,
      filename,
      flags,
      notifier.fd(),
      rescode,
    ),
    notification: Some(notification),
  })
}

///|
pub fn sqlite3_prepare_job(
  executor : Sqlite3Executor,
  database : Sqlite3,
  sql : String,
  rescode : Ref[Int],
) -> Sqlite3PrepareJob raise {
  let (notification, notifier) = @pipe.pipe()
  defer notifier.close()
  Sqlite3PrepareJob({
    handle: sqlite3_prepare_job_impl(
      executor.0,
      database.0,
      sql,
      notifier.fd(),
      rescode,
    ),
    notification: Some(notification),
  })
}

///|
pub fn sqlite3_step_job(
  executor : Sqlite3Executor,
  database : Sqlite3,
  statement : Sqlite3Stmt,
  rescode : Ref[Int],
) -> Sqlite3StepJob raise {
  let (notification, notifier) = @pipe.pipe()
  defer notifier.close()
  Sqlite3StepJob({
    handle: sqlite3_step_job_impl(
      executor.0,
      database.0,
      statement.0,
      notifier.fd(),
      rescode,
    ),
    notification: Some(notification),
  })
}

///|
async fn Sqlite3Job::wait(self : Sqlite3Job) -> Unit {
  guard self.notification is Some(notification) else {
    abort("sqlite3: asynchronous job lost its completion notification")
  }
  let signal = FixedArray::make(1, b'\x00')
  for ;; {
    ignore(notification.read(signal, max_len=1)) catch {
      @os_error.OSError(_) as error if error.is_EINTR() ||
        error.is_nonblocking_io_error() => continue
      _ => abort("sqlite3: asynchronous completion notification failed")
    }
    break
  }
  if !self.acquire_result() {
    abort("sqlite3: asynchronous job woke before publishing its result")
  }
}

///|
fn Sqlite3Job::acquire_result(self : Sqlite3Job) -> Bool {
  sqlite3_job_acquire_result_impl(self.handle)
}

///|
fn Sqlite3Job::rescode(self : Sqlite3Job) -> Int {
  sqlite3_job_rescode_impl(self.handle)
}

///|
fn Sqlite3Job::extended_rescode(self : Sqlite3Job) -> Int {
  sqlite3_job_extended_rescode_impl(self.handle)
}

///|
fn Sqlite3Job::message(self : Sqlite3Job) -> String {
  sqlite3_job_message_impl(self.handle)
}

///|
fn Sqlite3Job::close_notification(self : Sqlite3Job) -> Unit {
  if self.notification is Some(notification) {
    notification.close()
    self.notification = None
  }
}

///|
pub async fn Sqlite3OpenJob::wait(self : Sqlite3OpenJob) -> Unit {
  self.0.wait()
}

///|
pub fn Sqlite3OpenJob::result(self : Sqlite3OpenJob) -> (Int, Int, String) {
  (self.0.rescode(), self.0.extended_rescode(), self.0.message())
}

///|
pub fn Sqlite3OpenJob::take_database(self : Sqlite3OpenJob) -> Sqlite3 {
  Sqlite3(sqlite3_open_job_database_impl(self.0.handle))
}

///|
pub fn Sqlite3OpenJob::release(self : Sqlite3OpenJob) -> Unit {
  self.0.close_notification()
  sqlite3_open_job_release_impl(self.0.handle)
}

///|
pub async fn Sqlite3PrepareJob::wait(self : Sqlite3PrepareJob) -> Unit {
  self.0.wait()
}

///|
pub fn Sqlite3PrepareJob::result(
  self : Sqlite3PrepareJob,
) -> (Int, Int, String, Int) {
  (
    self.0.rescode(),
    self.0.extended_rescode(),
    self.0.message(),
    sqlite3_prepare_job_tail_offset_impl(self.0.handle),
  )
}

///|
pub fn Sqlite3PrepareJob::take_statement(
  self : Sqlite3PrepareJob,
) -> Sqlite3Stmt {
  Sqlite3Stmt(sqlite3_prepare_job_statement_impl(self.0.handle))
}

///|
pub fn Sqlite3PrepareJob::release(self : Sqlite3PrepareJob) -> Unit {
  self.0.close_notification()
  sqlite3_prepare_job_release_impl(self.0.handle)
}

///|
pub async fn Sqlite3StepJob::wait(self : Sqlite3StepJob) -> Unit {
  self.0.wait()
}

///|
pub fn Sqlite3StepJob::result(
  self : Sqlite3StepJob,
) -> (Int, Int, String, Int64?) {
  let changes = if sqlite3_step_job_has_changes_impl(self.0.handle) {
    Some(sqlite3_step_job_changes_impl(self.0.handle))
  } else {
    None
  }
  (self.0.rescode(), self.0.extended_rescode(), self.0.message(), changes)
}

///|
pub fn Sqlite3StepJob::release(self : Sqlite3StepJob) -> Unit {
  self.0.close_notification()
  sqlite3_step_job_release_impl(self.0.handle)
}
