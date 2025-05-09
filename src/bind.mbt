///|
trait Bind {
  bind(Statement, Int, Self, loc~ : SourceLoc) -> Unit!SqliteError
}

///|
extern "c" fn sqlite3_bind_double(
  stmt : Statement,
  param_index : Int,
  value : Double
) -> Int = "sqlite3_bind_double"

///|
extern "c" fn sqlite3_bind_int(
  stmt : Statement,
  param_index : Int,
  value : Int
) -> Int = "sqlite3_bind_int"

///|
extern "c" fn sqlite3_bind_int64(
  stmt : Statement,
  param_index : Int,
  value : Int64
) -> Int = "sqlite3_bind_int64"

///|
extern "c" fn sqlite3_bind_bytes(
  stmt : Statement,
  param_index : Int,
  value : Bytes,
  len : Int
) -> Int = "moonbit_sqlite3_bind_bytes"

///|
extern "c" fn sqlite3_bind_string(
  stmt : Statement,
  param_index : Int,
  value : String,
  len : Int
) -> Int = "moonbit_sqlite3_bind_string"

///|
pub impl Bind for Double with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = sqlite3_bind_double(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = sqlite3_bind_int(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Int64 with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = sqlite3_bind_int64(stmt, param_index, value)
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for Bytes with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = sqlite3_bind_bytes(stmt, param_index, value, value.length())
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}

///|
pub impl Bind for String with bind(stmt, param_index, value, loc~ : SourceLoc) {
  let rescode = sqlite3_bind_string(
    stmt,
    param_index,
    value,
    value.length() * 2,
  )
  if rescode != SQLITE_OK {
    raise SqliteError((rescode, loc))
  }
}
