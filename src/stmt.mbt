pub extern type Statement

// TODO: fix tail
extern "c" fn sqlite3_prepare(conn : Connection, stmt : Bytes, len : Int, out : Array[Statement], tail : Array[Bytes]) -> Int = "sqlite3_prepare_v2"
extern "c" fn sqlite3_step(stmt : Statement) -> Int = "sqlite3_step"
extern "c" fn sqlite3_bind_double(stmt : Statement, param_index : Int, value : Double) -> Int = "sqlite3_bind_double"
extern "c" fn sqlite3_bind_int(stmt : Statement, param_index : Int, value : Int) -> Int = "sqlite3_bind_int"
extern "c" fn sqlite3_bind_int64(stmt : Statement, param_index : Int, value : Int64) -> Int = "sqlite3_bind_int64"
extern "c" fn sqlite3_column_double(stmt : Statement, col_index : Int) -> Double = "sqlite3_column_double"
extern "c" fn sqlite3_column_int(stmt : Statement, col_index : Int) -> Int = "sqlite3_column_int"
extern "c" fn sqlite3_column_int64(stmt : Statement, col_index : Int) -> Int64 = "sqlite3_column_int64"
extern "c" fn sqlite3_finalize(stmt : Statement) -> Int = "sqlite3_finalize"


pub fn Connection::prepare(self : Connection, stmt : String) -> Statement!SqliteError {
  let stmt = @encoding.encode(UTF8, stmt)
  let len = stmt.length()
  let out = Array::new(capacity = 1)
  let tail = Array::new(capacity = 1)
  let rescode = sqlite3_prepare(self, stmt, len, out, tail)
  if rescode == SQLITE_OK {
    let stmt_object = out[0]
    return stmt_object
  } else {
    raise SqliteError(rescode)
  }
}

pub fn Statement::write[T : Writeable](self : Statement, index~ : Int, value~ : T) -> Unit!SqliteError {
  T::write!(self, index, value)
}

pub fn Statement::step(self : Statement) -> Bool!SqliteError {
  let rescode = sqlite3_step(self)
  match rescode {
    SQLITE_DONE => false
    SQLITE_ROW => true
    _ => raise SqliteError(rescode)
  }
}
