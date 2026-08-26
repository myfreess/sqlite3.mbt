///|
struct Sqlite3(Sqlite3Handle)

///|
struct Sqlite3Stmt(Sqlite3StmtHandle)

///|
struct Sqlite3Executor(Sqlite3ExecutorHandle)

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
pub fn sqlite3_executor_create(rescode : Ref[Int]) -> Sqlite3Executor {
  Sqlite3Executor(sqlite3_executor_create_impl(rescode))
}

///|
pub fn sqlite3_executor_release(executor : Sqlite3Executor) -> Unit {
  sqlite3_executor_release_impl(executor.0)
}

///|
pub fn sqlite3_open_v2(
  filename : Bytes,
  flags : Int,
  rescode : Ref[Int],
) -> Sqlite3 {
  Sqlite3(sqlite3_open_v2_impl(filename, flags, rescode))
}

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
pub fn sqlite3_close(database : Sqlite3) -> Int {
  sqlite3_close_impl(database.0)
}

///|
pub fn sqlite3_is_null(database : Sqlite3) -> Bool {
  sqlite3_is_null_impl(database.0)
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
pub fn sqlite3_step(statement : Sqlite3Stmt) -> Int {
  sqlite3_step_impl(statement.0)
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
  guard !self.is_ready() else { return }
  guard self.notification is Some(notification) else { return }
  errdefer (while !self.is_ready() {
    @async.sleep(1)
  })
  while !self.is_ready() {
    let signal = FixedArray::make(1, b'\x00')
    if notification.read(signal, max_len=1) == 0 {
      while !self.is_ready() {
        @async.sleep(1)
      }
    }
  }
}

///|
fn Sqlite3Job::is_ready(self : Sqlite3Job) -> Bool {
  sqlite3_job_is_ready_impl(self.handle)
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
pub fn Sqlite3StepJob::result(self : Sqlite3StepJob) -> (Int, Int, String) {
  (self.0.rescode(), self.0.extended_rescode(), self.0.message())
}

///|
pub fn Sqlite3StepJob::release(self : Sqlite3StepJob) -> Unit {
  self.0.close_notification()
  sqlite3_step_job_release_impl(self.0.handle)
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
pub fn sqlite3_reset(statement : Sqlite3Stmt) -> Int {
  sqlite3_reset_impl(statement.0)
}

///|
pub fn sqlite3_clear_bindings(statement : Sqlite3Stmt) -> Int {
  sqlite3_clear_bindings_impl(statement.0)
}

///|
pub fn sqlite3_changes64(database : Sqlite3) -> Int64 {
  sqlite3_changes64_impl(database.0)
}

///|
pub fn sqlite3_column_name(statement : Sqlite3Stmt, index : Int) -> String? {
  sqlite3_column_name_impl(statement.0, index)
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
  value : StringView,
) -> Int {
  sqlite3_bind_text_impl(
    statement.0,
    index,
    value.data(),
    value.start_offset(),
    value.length(),
  )
}

///|
pub fn sqlite3_bind_blob(
  statement : Sqlite3Stmt,
  index : Int,
  value : BytesView,
) -> Int {
  sqlite3_bind_blob_impl(
    statement.0,
    index,
    value.data(),
    value.start_offset(),
    value.length(),
  )
}

///|
pub fn sqlite3_bind_null(statement : Sqlite3Stmt, index : Int) -> Int {
  sqlite3_bind_null_impl(statement.0, index)
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
pub fn sqlite3_column_text(
  database : Sqlite3,
  statement : Sqlite3Stmt,
  index : Int,
  rescode : Ref[Int],
) -> String {
  sqlite3_column_text_impl(database.0, statement.0, index, rescode)
}

///|
pub fn sqlite3_column_blob(
  database : Sqlite3,
  statement : Sqlite3Stmt,
  index : Int,
  rescode : Ref[Int],
) -> Bytes {
  sqlite3_column_blob_impl(database.0, statement.0, index, rescode)
}

///|
pub fn sqlite3_column_type(statement : Sqlite3Stmt, index : Int) -> Int {
  sqlite3_column_type_impl(statement.0, index)
}
