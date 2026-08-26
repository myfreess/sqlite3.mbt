///|
struct Statement {
  mut handle : @ffi.Sqlite3Stmt?
  mut has_row : Bool
  mut column_types : Array[Int]?
  connection : Connection
}

///|
const SQLITE_NOMEM = 7

///|
fn Statement::get_handle(
  self : Statement,
) -> @ffi.Sqlite3Stmt raise SqliteError {
  let _ = self.connection.handle()
  match self.handle {
    Some(handle) => handle
    None => raise sqlite_misuse("sqlite3: statement is finalized")
  }
}

///|
fn Statement::apply_step_result(self : Statement, rescode : Int) -> Bool? {
  match rescode {
    SQLITE_DONE => Some(false)
    SQLITE_ROW => {
      self.has_row = true
      Some(true)
    }
    _ => None
  }
}

///|
fn Statement::column_info(
  self : Statement,
  index : Int,
) -> (@ffi.Sqlite3Stmt, Int) raise SqliteError {
  match (self.handle, self.has_row) {
    (Some(handle), true) => {
      let column_count = @ffi.sqlite3_column_count(handle)
      if index < 0 || index >= column_count {
        raise sqlite_misuse(
          "sqlite3: column index \{index} is outside 0..<\{column_count}",
        )
      }
      // SQLite only guarantees the initial storage class before a coercing
      // accessor runs. Cache it on the first read of each cell so typed and
      // dynamic reads remain order-independent within the current row.
      let types = match self.column_types {
        Some(types) => types
        None => {
          let types = Array::make(column_count, 0)
          self.column_types = Some(types)
          types
        }
      }
      if types[index] == 0 {
        types[index] = @ffi.sqlite3_column_type(handle, index)
      }
      (handle, types[index])
    }
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
  let scanner = @lexbuf.StringScanner::{ data: sql[start:], cursor: 0, }
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
  // Only a successful, non-empty prepare reaches this point. A handle from a
  // failed prepare is never stored in public Statement state.
  { handle: Some(out), has_row: false, column_types: None, connection: self, }
}

///|
/// Reset the statement to its initial state so it can be executed again.
///
/// Existing parameter bindings are preserved unless `clear_bindings` is true.
/// The current row, if any, is invalidated even when SQLite reports an error
/// from the previous execution.
pub fn Statement::reset(
  self : Statement,
  clear_bindings? : Bool = false,
) -> Unit raise SqliteError {
  let handle = self.get_handle()
  self.has_row = false
  self.column_types = None
  let rescode = @ffi.sqlite3_reset(handle)
  // sqlite3_reset() can report an error from the previous execution even
  // though it has rewound the statement. Capture that error before clearing
  // bindings can replace the connection's error message.
  let reset_error = if rescode == SQLITE_OK {
    None
  } else {
    Some(self.error(rescode))
  }
  let clear_rescode = if clear_bindings {
    @ffi.sqlite3_clear_bindings(handle)
  } else {
    SQLITE_OK
  }
  match reset_error {
    Some(error) => raise error
    None => if clear_rescode != SQLITE_OK { raise self.error(clear_rescode) }
  }
}

///|
/// Return the number of columns in the statement's result set.
///
/// Statements that do not return rows have zero columns.
pub fn Statement::column_count(self : Statement) -> Int raise SqliteError {
  @ffi.sqlite3_column_count(self.get_handle())
}

///|
/// Return the name assigned to a result column.
///
/// Column indexes start at zero. An explicit SQL `AS` alias determines the
/// name when present.
pub fn Statement::column_name(
  self : Statement,
  index~ : Int,
) -> String raise SqliteError {
  let handle = self.get_handle()
  let column_count = @ffi.sqlite3_column_count(handle)
  if index < 0 || index >= column_count {
    raise sqlite_misuse(
      "sqlite3: column index \{index} is outside 0..<\{column_count}",
    )
  }
  match @ffi.sqlite3_column_name(handle, index) {
    Some(name) => name
    None =>
      raise sqlite_error(
        SQLITE_NOMEM,
        "sqlite3: failed to allocate result column name",
      )
  }
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
  self.column_types = None
  let rescode = @ffi.sqlite3_step(handle)
  match self.apply_step_result(rescode) {
    Some(has_row) => has_row
    None => raise self.error(rescode)
  }
}

///|
pub fn Statement::finalize(self : Statement) -> Unit raise SqliteError {
  match self.handle {
    None => ()
    Some(handle) => {
      self.connection.ensure_no_job()
      // sqlite3_finalize consumes the statement even when it reports an error.
      self.handle = None
      self.has_row = false
      self.column_types = None
      let rescode = @ffi.sqlite3_finalize(handle)
      if rescode != SQLITE_OK {
        raise self.error(rescode)
      }
    }
  }
}
