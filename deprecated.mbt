// Storage class constants that predate `ColumnType`.
//
// Nothing ever consumed these: the package had no public column-type
// inspection API to compare them against, so `SQLITE_BLOB` went unnoticed with
// the wrong value — SQLite's blob storage class is 4, not 2 — and `SQLITE_TEXT`
// and `SQLITE_NULL` were never written at all. `Statement::column_type` returns
// a `ColumnType` instead, which is exhaustive and cannot be off by a number.

///|
#deprecated("use ColumnType::Integer, returned by Statement::column_type")
pub const SQLITE_INTEGER : Int = 1

///|
#deprecated("use ColumnType::Float, returned by Statement::column_type")
pub const SQLITE_FLOAT : Int = 2

///|
#deprecated("use ColumnType::Blob, returned by Statement::column_type; the value 2 here is wrong, SQLITE_BLOB is 4")
pub const SQLITE_BLOB : Int = 2
