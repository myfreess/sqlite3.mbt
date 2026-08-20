///|
struct Statement {
  mut handle : @ffi.Sqlite3Stmt?
  mut has_row : Bool
  connection : Connection
}

///|
fn Statement::get_handle(
  self : Statement,
) -> @ffi.Sqlite3Stmt raise SqliteError {
  match self.handle {
    Some(handle) => handle
    None => raise sqlite_misuse("sqlite3: statement is finalized")
  }
}

///|
fn Statement::handle_for_column(
  self : Statement,
) -> @ffi.Sqlite3Stmt raise SqliteError {
  match (self.handle, self.has_row) {
    (Some(handle), true) => handle
    (None, _) => raise sqlite_misuse("sqlite3: statement is finalized")
    _ => raise sqlite_misuse("sqlite3: statement has no current row")
  }
}

///|
fn Statement::error(self : Statement, raw_code : Int) -> SqliteError {
  self.connection.error(raw_code)
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
pub fn Connection::prepare(
  self : Connection,
  stmt : String,
) -> Statement raise SqliteError {
  if stmt.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: SQL contains a NUL code unit")
  }
  let db = self.handle()
  let tail_offset = Ref(-1)
  let rescode = Ref(SQLITE_OK)
  let out = @ffi.sqlite3_prepare16_v2(db, stmt, tail_offset, rescode)
  if rescode.val != SQLITE_OK {
    raise sqlite_error(rescode.val, @ffi.sqlite3_errmsg(db))
  }
  if tail_offset.val < 0 {
    raise sqlite_misuse("sqlite3: SQL does not contain a statement")
  }
  if tail_offset.val > stmt.length() ||
    !sql_tail_is_ignorable(stmt, tail_offset.val) {
    let _ = @ffi.sqlite3_finalize(out)
    raise sqlite_misuse("sqlite3: SQL contains more than one statement")
  }
  { handle: Some(out), has_row: false, connection: self }
}

///|
pub fn[T : Bind] Statement::bind(
  self : Statement,
  index~ : Int,
  val : T,
) -> Unit raise SqliteError {
  T::bind(self, index, val)
}

///|
pub fn[T : Column] Statement::column(
  self : Statement,
  index~ : Int,
) -> T raise SqliteError {
  T::column(self, index)
}

///|
pub fn Statement::step(self : Statement) -> Bool raise SqliteError {
  let handle = self.get_handle()
  self.has_row = false
  let rescode = @ffi.sqlite3_step(handle)
  match rescode {
    SQLITE_DONE => false
    SQLITE_ROW => {
      self.has_row = true
      true
    }
    _ => raise self.error(rescode)
  }
}

///|
pub fn Statement::finalize(self : Statement) -> Unit raise SqliteError {
  match self.handle {
    None => ()
    Some(handle) => {
      // sqlite3_finalize consumes the statement even when it reports an error.
      self.handle = None
      self.has_row = false
      let rescode = @ffi.sqlite3_finalize(handle)
      if rescode != SQLITE_OK {
        raise self.error(rescode)
      }
    }
  }
}
