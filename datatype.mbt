///|
/// SQLite's storage class for a value in the current row.
///
/// A storage class describes the value, not the column's declared type: a
/// column declared `INTEGER` reports `Text` if something stored text in it,
/// because text is what is actually there.
pub(all) enum ColumnType {
  Integer
  Float
  Text
  Blob
  Null
} derive(Debug, Eq)
