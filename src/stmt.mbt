///|
pub extern type Statement

///|
priv extern type StatementRef

///|
extern "c" fn StatementRef::malloc() -> StatementRef = "moonbit_sqlite3_mkref"

///|
extern "c" fn StatementRef::read(self : StatementRef) -> Statement = "moonbit_sqlite3_readref"

///|
priv extern type UTF8StrRef

///|
extern "c" fn UTF8StrRef::malloc() -> UTF8StrRef = "moonbit_sqlite3_mkref"

// TODO: fix tail
///|
extern "c" fn sqlite3_prepare(
  conn : Connection,
  stmt : Bytes,
  len : Int,
  out : StatementRef,
  tail : UTF8StrRef
) -> Int = "sqlite3_prepare_v2"

///|
extern "c" fn sqlite3_step(stmt : Statement) -> Int = "sqlite3_step"

///|
extern "c" fn sqlite3_finalize(stmt : Statement) -> Int = "sqlite3_finalize"

///|
pub fn Connection::prepare(
  self : Connection,
  stmt : String,
  loc~ : SourceLoc = _
) -> Statement!SqliteError {
  let stmt = @encoding.encode(UTF8, stmt)
  let len = stmt.length()
  let out = StatementRef::malloc()
  let tail = UTF8StrRef::malloc()
  let rescode = sqlite3_prepare(self, stmt, len, out, tail)
  if rescode == SQLITE_OK {
    let stmt_object = out.read()
    return stmt_object
  } else {
    raise SqliteError((rescode, loc))
  }
}

///|
pub fn Statement::bind[T : Bind](
  self : Statement,
  index~ : Int,
  val~ : T,
  loc~ : SourceLoc = _
) -> Unit!SqliteError {
  T::bind!(self, index, val, loc~)
}

///|
pub fn Statement::column[T : Column](self : Statement, index~ : Int) -> T {
  T::column(self, index)
}

///|
pub fn Statement::step(
  self : Statement,
  loc~ : SourceLoc = _
) -> Bool!SqliteError {
  let rescode = sqlite3_step(self)
  match rescode {
    SQLITE_DONE => false
    SQLITE_ROW => true
    _ => raise SqliteError((rescode, loc))
  }
}

///|
pub fn Statement::step_once(
  self : Statement,
  loc~ : SourceLoc = _
) -> Unit!SqliteError {
  if self.step!(loc~) {
    raise SqliteError((SQLITE_ROW, loc))
  }
}

///|
pub fn Statement::finalize(
  self : Statement,
  loc~ : SourceLoc = _
) -> Unit!SqliteError {
  let rescode = sqlite3_finalize(self)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
