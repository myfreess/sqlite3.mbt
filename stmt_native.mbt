///|
struct Statement(Sqlite3Stmt)

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
  let out = sqlite3_stmt_allocate()
  let tail_offset = Ref(-1)
  let rescode = sqlite3_prepare16_v2(self.0, stmt, out, tail_offset)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
  if tail_offset.val < 0 {
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  if tail_offset.val > stmt.length() ||
    !sql_tail_is_ignorable(stmt, tail_offset.val) {
    let _ = sqlite3_finalize(out)
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  Statement(out)
}

///|
#callsite(autofill(loc))
pub fn Statement::step(
  self : Statement,
  loc~ : SourceLoc,
) -> Bool raise SqliteError {
  let rescode = sqlite3_step(self.0)
  match rescode {
    SQLITE_DONE => false
    SQLITE_ROW => true
    _ => raise SqliteError((rescode, loc))
  }
}

///|
#callsite(autofill(loc))
pub fn Statement::finalize(
  self : Statement,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_finalize(self.0)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::bind_double(
  self : Statement,
  index : Int,
  value : Double,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_double(self.0, index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::bind_int(
  self : Statement,
  index : Int,
  value : Int,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_int(self.0, index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::bind_int64(
  self : Statement,
  index : Int,
  value : Int64,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_int64(self.0, index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::bind_blob(
  self : Statement,
  index : Int,
  value : Bytes,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_blob(self.0, index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::bind_text(
  self : Statement,
  index : Int,
  value : String,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  let rescode = sqlite3_bind_text(self.0, index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
fn Statement::column_int(self : Statement, index : Int) -> Int {
  sqlite3_column_int(self.0, index)
}

///|
fn Statement::column_int64(self : Statement, index : Int) -> Int64 {
  sqlite3_column_int64(self.0, index)
}

///|
fn Statement::column_double(self : Statement, index : Int) -> Double {
  sqlite3_column_double(self.0, index)
}

///|
fn Statement::column_blob(self : Statement, index : Int) -> Bytes {
  sqlite3_column_blob(self.0, index)
}

///|
fn Statement::column_text(self : Statement, index : Int) -> String {
  sqlite3_column_text(self.0, index)
}
