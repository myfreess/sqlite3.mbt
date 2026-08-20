///|
/// A dynamically typed SQLite value.
///
/// Use `Value` when the SQLite storage class is not known statically or when
/// SQL `NULL` must be preserved. Concrete `bind` and `column` calls remain the
/// simpler choice when the expected MoonBit type is already known.
pub(all) enum Value {
  Null
  Integer(Int64)
  Real(Double)
  Text(String)
  Blob(Bytes)
} derive(Debug, Eq)

///|
const SQLITE_INTEGER = 1

///|
const SQLITE_FLOAT = 2

///|
const SQLITE_TEXT = 3

///|
const SQLITE_BLOB = 4

///|
const SQLITE_NULL = 5

///|
pub impl Bind for Value with fn bind(stmt, param_index, value) {
  let handle = stmt.get_handle()
  let rescode = match value {
    Null => @ffi.sqlite3_bind_null(handle, param_index)
    Integer(value) => @ffi.sqlite3_bind_int64(handle, param_index, value)
    Real(value) => @ffi.sqlite3_bind_double(handle, param_index, value)
    Text(value) => @ffi.sqlite3_bind_text(handle, param_index, value[:])
    Blob(value) => @ffi.sqlite3_bind_blob(handle, param_index, value[:])
  }
  if rescode != SQLITE_OK {
    raise stmt.error(rescode)
  }
}

///|
pub impl Column for Value with fn column(stmt, index) {
  let (handle, storage_class) = stmt.column_info(index)
  match storage_class {
    SQLITE_INTEGER => Integer(@ffi.sqlite3_column_int64(handle, index))
    SQLITE_FLOAT => Real(@ffi.sqlite3_column_double(handle, index))
    SQLITE_TEXT => Text(stmt.column(index~))
    SQLITE_BLOB => Blob(stmt.column(index~))
    SQLITE_NULL => Null
    _ => abort("sqlite3: SQLite returned an invalid column type")
  }
}
