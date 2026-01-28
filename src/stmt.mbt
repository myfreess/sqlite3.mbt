///|
#external
pub type Statement

///|
#external
priv type StatementRef

///|
extern "c" fn StatementRef::malloc() -> StatementRef = "moonbit_sqlite3_mkref"

///|
extern "c" fn StatementRef::read(self : StatementRef) -> Statement = "moonbit_sqlite3_readref"

///|
#external
priv type UTF8StrRef

///|
extern "c" fn UTF8StrRef::malloc() -> UTF8StrRef = "moonbit_sqlite3_mkref"

// TODO: fix tail

///|
#borrow(stmt)
extern "c" fn sqlite3_prepare(
  conn : Connection,
  stmt : Bytes,
  len : Int,
  out : StatementRef,
  tail : UTF8StrRef,
) -> Int = "sqlite3_prepare_v2"

///|
extern "c" fn sqlite3_step(stmt : Statement) -> Int = "sqlite3_step"

///|
extern "c" fn sqlite3_finalize(stmt : Statement) -> Int = "sqlite3_finalize"

///|
#callsite(autofill(loc))
pub fn Connection::prepare(
  self : Connection,
  stmt : String,
  loc~ : SourceLoc,
) -> Statement raise SqliteError {
  let stmt = @utf8.encode(stmt)
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
#callsite(autofill(loc))
pub fn[T : Bind] Statement::bind(
  self : Statement,
  index~ : Int,
  val~ : T,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  T::bind(self, index, val, loc~)
}

///|
#callsite(autofill(loc))
pub fn Statement::bind_string_as_blob(
  self : Statement,
  index~ : Int,
  val~ : String,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_string(self, index, val, val.length() * 2)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub fn[T : Column] Statement::column(self : Statement, index~ : Int) -> T {
  T::column(self, index)
}

///|
pub fn Statement::column_blob_as_string(
  self : Statement,
  index~ : Int,
) -> String {
  sqlite3_column_string(self, index)
}

///|
#callsite(autofill(loc))
pub fn Statement::step(
  self : Statement,
  loc~ : SourceLoc,
) -> Bool raise SqliteError {
  let rescode = sqlite3_step(self)
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
  let rescode = sqlite3_finalize(self)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
