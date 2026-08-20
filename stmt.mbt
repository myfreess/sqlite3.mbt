///|
struct Statement(Ref[@ffi.Sqlite3Stmt?])

///|
fn Statement::handle(
  self : Statement,
  loc : SourceLoc,
) -> @ffi.Sqlite3Stmt raise SqliteError {
  match self.0.val {
    Some(handle) => handle
    None => raise SqliteError((SQLITE_MISUSE, loc))
  }
}

///|
fn Statement::handle_for_column(self : Statement) -> @ffi.Sqlite3Stmt {
  match self.0.val {
    Some(handle) => handle
    None => abort("sqlite3: column access after statement finalization")
  }
}

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
  let tail_offset = Ref(-1)
  let rescode = Ref(SQLITE_OK)
  let out = @ffi.sqlite3_prepare16_v2(
    self.handle(loc),
    stmt,
    tail_offset,
    rescode,
  )
  if rescode.val != SQLITE_OK {
    raise SqliteError((rescode.val, loc))
  }
  if tail_offset.val < 0 {
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  if tail_offset.val > stmt.length() ||
    !sql_tail_is_ignorable(stmt, tail_offset.val) {
    let _ = @ffi.sqlite3_finalize(out)
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  Statement(Ref(Some(out)))
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
/// Bind SQL `NULL` to a parameter.
///
/// Separate from `bind` because `Bind` decides the SQLite type from the value
/// it is handed, and `NULL` has no value to hand it. Parameter indexes start at
/// `1`, matching `bind` and the SQLite C API.
#callsite(autofill(loc))
pub fn Statement::bind_null(
  self : Statement,
  index~ : Int,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = @ffi.sqlite3_bind_null(self.handle(loc), index)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
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
  let rescode = @ffi.sqlite3_step(self.handle(loc))
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
  match self.0.val {
    None => ()
    Some(handle) => {
      // sqlite3_finalize consumes the statement even when it reports an error.
      self.0.val = None
      let rescode = @ffi.sqlite3_finalize(handle)
      if rescode != SQLITE_OK {
        raise SqliteError((rescode, loc))
      }
    }
  }
}
