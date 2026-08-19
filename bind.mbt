///|
trait Bind {
  fn bind(Statement, Int, Self, loc~ : SourceLoc) -> Unit raise SqliteError
}

///|
pub impl Bind for Double with fn bind(
  stmt,
  param_index,
  value,
  loc~ : SourceLoc,
) {
  stmt.bind_double(param_index, value, loc~)
}

///|
pub impl Bind for Int with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  stmt.bind_int(param_index, value, loc~)
}

///|
pub impl Bind for Int64 with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  stmt.bind_int64(param_index, value, loc~)
}

///|
pub impl Bind for Bytes with fn bind(stmt, param_index, value, loc~ : SourceLoc) {
  stmt.bind_blob(param_index, value, loc~)
}

///|
pub impl Bind for String with fn bind(
  stmt,
  param_index,
  value,
  loc~ : SourceLoc,
) {
  stmt.bind_text(param_index, value, loc~)
}
