///|
struct Statement(@ffi.Sqlite3Stmt)

///|
#callsite(autofill(loc))
pub fn Connection::prepare(
  self : Connection,
  stmt : String,
  loc~ : SourceLoc,
) -> Statement raise SqliteError {
  let sql = @utf8.encode(stmt)
  let out = @ffi.sqlite3_stmt_allocate()
  let rescode = @ffi.sqlite3_prepare_v2(self.0, sql, out)
  if rescode == SQLITE_OK {
    return Statement(out)
  } else {
    raise SqliteError((rescode, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Bind] Statement::bind(
  self : Statement,
  index~ : Int,
  val : T,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  T::bind(self, index, val, loc~)
}

///|
pub fn[T : Column] Statement::column(self : Statement, index~ : Int) -> T {
  T::column(self, index)
}

///|
#callsite(autofill(loc))
pub fn Statement::step(
  self : Statement,
  loc~ : SourceLoc,
) -> Bool raise SqliteError {
  let rescode = @ffi.sqlite3_step(self.0)
  match rescode {
    SQLITE_DONE => false
    SQLITE_ROW => true
    _ => raise SqliteError((rescode, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Statement::step_once(
  self : Statement,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  if self.step(loc~) {
    raise SqliteError((SQLITE_ROW, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Statement::finalize(
  self : Statement,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = @ffi.sqlite3_finalize(self.0)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
