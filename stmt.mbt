///|
struct Statement(@ffi.Sqlite3Stmt)

///|
fn sql_tail_is_ignorable(sql : String, start : Int) -> Bool {
  let scanner = @lexbuf.StringScanner::{ data: sql[start:], cursor: 0 }
  for ;; {
    lexscan scanner with longest {
      re"^[ \t\n\f\r;\uFEFF]+" => continue
      re"^--[^\n]*(\n|$)" => continue
      re"^/[*]([^*]|[*]+[^*/])*[*]+/" => continue
      re"^/[*]([^*]|[*]+[^*/])*[*]*$" => return true
      re"^$" => return true
      _ => return false
    }
  }
}

///|
#callsite(autofill(loc))
pub fn Connection::prepare(
  self : Connection,
  stmt : String,
  loc~ : SourceLoc,
) -> Statement raise SqliteError {
  if stmt.contains_code_unit(0x0000) {
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  let out = @ffi.sqlite3_stmt_allocate()
  let tail_offset = Ref(-1)
  let rescode = @ffi.sqlite3_prepare16_v2(self.0, stmt, out, tail_offset)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
  if tail_offset.val < 0 {
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  if tail_offset.val > stmt.length() ||
    !sql_tail_is_ignorable(stmt, tail_offset.val) {
    let _ = @ffi.sqlite3_finalize(out)
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  Statement(out)
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
