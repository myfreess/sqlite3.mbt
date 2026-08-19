///|
#external
priv type StatementSync

///|
#external
priv type SqliteBindings

///|
#external
priv type StatementIterator

///|
#external
priv type SqliteRow

///|
#external
priv type PrepareResult

///|
#external
priv type IterateResult

///|
#external
priv type NextResult

///|
struct Statement {
  connection : Connection
  mut statement : StatementSync?
  bindings : SqliteBindings
  mut iterator : StatementIterator?
  mut current_row : SqliteRow?
}

///|
extern "js" fn database_prepare(
  db : DatabaseSync,
  sql : String,
) -> PrepareResult =
  #| function(db, sql) {
  #|   try {
  #|     const statement = db.prepare(sql);
  #|     let source;
  #|     try {
  #|       source = statement.sourceSQL;
  #|     } catch (error) {
  #|       if (error?.code === "ERR_INVALID_STATE") {
  #|         return { ok: true, hasStatement: false };
  #|       }
  #|       throw error;
  #|     }
  #|     statement.setReadBigInts(true);
  #|     statement.setReturnArrays(true);
  #|     return {
  #|       ok: true,
  #|       hasStatement: true,
  #|       statement,
  #|       tailOffset: source.length,
  #|     };
  #|   } catch (error) {
  #|     return { ok: false, error };
  #|   }
  #| }

///|
extern "js" fn PrepareResult::is_ok(self : Self) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn PrepareResult::has_statement(self : Self) -> Bool =
  #| (result) => result.hasStatement

///|
extern "js" fn PrepareResult::statement(self : Self) -> StatementSync =
  #| (result) => result.statement

///|
extern "js" fn PrepareResult::tail_offset(self : Self) -> Int =
  #| (result) => result.tailOffset

///|
extern "js" fn PrepareResult::error(self : Self) -> NodeSqliteError =
  #| (result) => result.error

///|
extern "js" fn sqlite_bindings_new() -> SqliteBindings =
  #| () => []

///|
extern "js" fn sqlite_bindings_clear(bindings : SqliteBindings) -> Unit =
  #| (bindings) => { bindings.length = 0 }

///|
extern "js" fn sqlite_bindings_set_int(
  bindings : SqliteBindings,
  index : Int,
  value : Int,
) -> Unit =
  #| (bindings, index, value) => { bindings[index - 1] = value }

///|
extern "js" fn sqlite_bindings_set_int64(
  bindings : SqliteBindings,
  index : Int,
  value : Int64,
) -> Unit =
  #| (bindings, index, value) => { bindings[index - 1] = value }

///|
extern "js" fn sqlite_bindings_set_double(
  bindings : SqliteBindings,
  index : Int,
  value : Double,
) -> Unit =
  #| (bindings, index, value) => { bindings[index - 1] = value }

///|
extern "js" fn sqlite_bindings_set_text(
  bindings : SqliteBindings,
  index : Int,
  value : String,
) -> Unit =
  #| (bindings, index, value) => { bindings[index - 1] = value }

///|
extern "js" fn sqlite_bindings_set_blob(
  bindings : SqliteBindings,
  index : Int,
  value : Bytes,
) -> Unit =
  #| (bindings, index, value) => {
  #|   bindings[index - 1] = Uint8Array.from(value)
  #| }

///|
extern "js" fn statement_iterate(
  statement : StatementSync,
  bindings : SqliteBindings,
) -> IterateResult =
  #| function(statement, bindings) {
  #|   try {
  #|     const values = Array.from(
  #|       { length: bindings.length },
  #|       (_, index) => Object.hasOwn(bindings, index) ? bindings[index] : null,
  #|     );
  #|     return { ok: true, iterator: statement.iterate(...values) };
  #|   } catch (error) {
  #|     return { ok: false, error };
  #|   }
  #| }

///|
extern "js" fn IterateResult::is_ok(self : Self) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn IterateResult::iterator(self : Self) -> StatementIterator =
  #| (result) => result.iterator

///|
extern "js" fn IterateResult::error(self : Self) -> NodeSqliteError =
  #| (result) => result.error

///|
extern "js" fn statement_iterator_next(
  iterator : StatementIterator,
) -> NextResult =
  #| function(iterator) {
  #|   try {
  #|     const next = iterator.next();
  #|     return next.done
  #|       ? { ok: true, done: true }
  #|       : { ok: true, done: false, row: next.value };
  #|   } catch (error) {
  #|     return { ok: false, error };
  #|   }
  #| }

///|
extern "js" fn NextResult::is_ok(self : Self) -> Bool =
  #| (result) => result.ok

///|
extern "js" fn NextResult::is_done(self : Self) -> Bool =
  #| (result) => result.done

///|
extern "js" fn NextResult::row(self : Self) -> SqliteRow =
  #| (result) => result.row

///|
extern "js" fn NextResult::error(self : Self) -> NodeSqliteError =
  #| (result) => result.error

///|
extern "js" fn statement_iterator_finish(iterator : StatementIterator) -> Unit =
  #| function(iterator) {
  #|   try {
  #|     iterator.return?.();
  #|   } catch (_) {
  #|     // Releasing adapter state must not hide the execution error.
  #|   }
  #| }

///|
extern "js" fn SqliteRow::column_int(self : Self, index : Int) -> Int =
  #| function(row, index) {
  #|   const value = row[index];
  #|   if (typeof value === "bigint") {
  #|     return Number(BigInt.asIntN(32, value));
  #|   }
  #|   if (typeof value === "number") {
  #|     return value | 0;
  #|   }
  #|   if (typeof value === "string") {
  #|     const parsed = Number.parseInt(value, 10);
  #|     return Number.isNaN(parsed) ? 0 : parsed | 0;
  #|   }
  #|   return 0;
  #| }

///|
extern "js" fn SqliteRow::column_int64(self : Self, index : Int) -> Int64 =
  #| function(row, index) {
  #|   const value = row[index];
  #|   if (typeof value === "bigint") {
  #|     return BigInt.asIntN(64, value);
  #|   }
  #|   if (typeof value === "number" && Number.isFinite(value)) {
  #|     return BigInt.asIntN(64, BigInt(Math.trunc(value)));
  #|   }
  #|   if (typeof value === "string") {
  #|     const match = /^[\s]*([+-]?[0-9]+)/.exec(value);
  #|     if (match !== null) {
  #|       return BigInt.asIntN(64, BigInt(match[1]));
  #|     }
  #|   }
  #|   return 0n;
  #| }

///|
extern "js" fn SqliteRow::column_double(self : Self, index : Int) -> Double =
  #| function(row, index) {
  #|   const value = row[index];
  #|   if (typeof value === "bigint" || typeof value === "number") {
  #|     return Number(value);
  #|   }
  #|   if (typeof value === "string") {
  #|     const parsed = Number.parseFloat(value);
  #|     return Number.isNaN(parsed) ? 0 : parsed;
  #|   }
  #|   return 0;
  #| }

///|
extern "js" fn SqliteRow::column_text(self : Self, index : Int) -> String =
  #| function(row, index) {
  #|   const value = row[index];
  #|   if (value === null || value === undefined) {
  #|     return "";
  #|   }
  #|   if (ArrayBuffer.isView(value)) {
  #|     return new TextDecoder().decode(value);
  #|   }
  #|   return String(value);
  #| }

///|
extern "js" fn SqliteRow::column_blob(self : Self, index : Int) -> Bytes =
  #| function(row, index) {
  #|   const value = row[index];
  #|   if (value === null || value === undefined) {
  #|     return new Uint8Array();
  #|   }
  #|   if (ArrayBuffer.isView(value)) {
  #|     return Uint8Array.from(
  #|       new Uint8Array(value.buffer, value.byteOffset, value.byteLength),
  #|     );
  #|   }
  #|   return new TextEncoder().encode(String(value));
  #| }

///|
#callsite(autofill(loc))
pub fn Connection::prepare(
  self : Connection,
  sql : String,
  loc~ : SourceLoc,
) -> Statement raise SqliteError {
  if sql.contains_code_unit(0x0000) {
    self.last_error = "SQL contains a NUL code unit"
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  let result = database_prepare(self.db, sql)
  if !result.is_ok() {
    let error = result.error()
    self.last_error = error.message()
    raise SqliteError((node_error_rescode(error, SQLITE_ERROR), loc))
  }
  if !result.has_statement() {
    self.last_error = "SQL contains no statement"
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  let tail_offset = result.tail_offset()
  if tail_offset > sql.length() || !sql_tail_is_ignorable(sql, tail_offset) {
    self.last_error = "multiple SQL statements are not supported"
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  self.live_statements += 1
  {
    connection: self,
    statement: Some(result.statement()),
    bindings: sqlite_bindings_new(),
    iterator: None,
    current_row: None,
  }
}

///|
fn Statement::ensure_bindable(
  self : Statement,
  index : Int,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  if self.statement is None || self.iterator is Some(_) {
    self.connection.last_error = "statement is not ready for binding"
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  if index < 1 {
    self.connection.last_error = "column index out of range"
    raise SqliteError((SQLITE_RANGE, loc))
  }
}

///|
fn Statement::bind_double(
  self : Statement,
  index : Int,
  value : Double,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  self.ensure_bindable(index, loc~)
  sqlite_bindings_set_double(self.bindings, index, value)
}

///|
fn Statement::bind_int(
  self : Statement,
  index : Int,
  value : Int,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  self.ensure_bindable(index, loc~)
  sqlite_bindings_set_int(self.bindings, index, value)
}

///|
fn Statement::bind_int64(
  self : Statement,
  index : Int,
  value : Int64,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  self.ensure_bindable(index, loc~)
  sqlite_bindings_set_int64(self.bindings, index, value)
}

///|
fn Statement::bind_blob(
  self : Statement,
  index : Int,
  value : Bytes,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  self.ensure_bindable(index, loc~)
  sqlite_bindings_set_blob(self.bindings, index, value)
}

///|
fn Statement::bind_text(
  self : Statement,
  index : Int,
  value : String,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  self.ensure_bindable(index, loc~)
  sqlite_bindings_set_text(self.bindings, index, value)
}

///|
#callsite(autofill(loc))
pub fn Statement::step(
  self : Statement,
  loc~ : SourceLoc,
) -> Bool raise SqliteError {
  let statement = match self.statement {
    Some(statement) => statement
    None => {
      self.connection.last_error = "statement has been finalized"
      raise SqliteError((SQLITE_MISUSE, loc))
    }
  }
  let iterator = match self.iterator {
    Some(iterator) => iterator
    None => {
      let result = statement_iterate(statement, self.bindings)
      if !result.is_ok() {
        let error = result.error()
        self.connection.last_error = error.message()
        raise SqliteError((node_error_rescode(error, SQLITE_ERROR), loc))
      }
      let iterator = result.iterator()
      self.iterator = Some(iterator)
      iterator
    }
  }
  let result = statement_iterator_next(iterator)
  if !result.is_ok() {
    statement_iterator_finish(iterator)
    self.iterator = None
    self.current_row = None
    let error = result.error()
    self.connection.last_error = error.message()
    raise SqliteError((node_error_rescode(error, SQLITE_ERROR), loc))
  }
  if result.is_done() {
    self.iterator = None
    self.current_row = None
    false
  } else {
    self.current_row = Some(result.row())
    true
  }
}

///|
#callsite(autofill(loc))
pub fn Statement::finalize(
  self : Statement,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  guard self.statement is Some(_) else {
    self.connection.last_error = "statement has been finalized"
    raise SqliteError((SQLITE_MISUSE, loc))
  }
  match self.iterator {
    Some(iterator) => statement_iterator_finish(iterator)
    None => ()
  }
  self.statement = None
  self.iterator = None
  self.current_row = None
  sqlite_bindings_clear(self.bindings)
  self.connection.live_statements -= 1
}

///|
fn Statement::column_int(self : Statement, index : Int) -> Int {
  match self.current_row {
    Some(row) => row.column_int(index)
    None => 0
  }
}

///|
fn Statement::column_int64(self : Statement, index : Int) -> Int64 {
  match self.current_row {
    Some(row) => row.column_int64(index)
    None => 0L
  }
}

///|
fn Statement::column_double(self : Statement, index : Int) -> Double {
  match self.current_row {
    Some(row) => row.column_double(index)
    None => 0.0
  }
}

///|
fn Statement::column_blob(self : Statement, index : Int) -> Bytes {
  match self.current_row {
    Some(row) => row.column_blob(index)
    None => b""
  }
}

///|
fn Statement::column_text(self : Statement, index : Int) -> String {
  match self.current_row {
    Some(row) => row.column_text(index)
    None => ""
  }
}
