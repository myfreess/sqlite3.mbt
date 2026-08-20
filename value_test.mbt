///|
test "dynamic values bind and preserve SQLite storage classes" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1, ?2, ?3, ?4, ?5, ?6, ?7")
  stmt.bind(index=1, @sqlite3.Value::Null)
  stmt.bind(index=2, @sqlite3.Value::Integer(5000000000L))
  stmt.bind(index=3, @sqlite3.Value::Real(1.5))
  stmt.bind(index=4, @sqlite3.Value::Text("moon"))
  stmt.bind(index=5, @sqlite3.Value::Blob(b"bit"))
  stmt.bind(index=6, @sqlite3.Value::Text(""))
  stmt.bind(index=7, @sqlite3.Value::Blob(b""))
  assert_true(stmt.step())
  let null : @sqlite3.Value = stmt.column(index=0)
  let integer : @sqlite3.Value = stmt.column(index=1)
  let real : @sqlite3.Value = stmt.column(index=2)
  let text : @sqlite3.Value = stmt.column(index=3)
  let blob : @sqlite3.Value = stmt.column(index=4)
  let empty_text : @sqlite3.Value = stmt.column(index=5)
  let empty_blob : @sqlite3.Value = stmt.column(index=6)
  assert_eq(null, @sqlite3.Value::Null)
  assert_eq(integer, @sqlite3.Value::Integer(5000000000L))
  assert_eq(real, @sqlite3.Value::Real(1.5))
  assert_eq(text, @sqlite3.Value::Text("moon"))
  assert_eq(blob, @sqlite3.Value::Blob(b"bit"))
  assert_eq(empty_text, @sqlite3.Value::Text(""))
  assert_eq(empty_blob, @sqlite3.Value::Blob(b""))
  stmt.finalize()
  conn.close()
}

///|
test "typed columns remain available beside dynamic values" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 42, NULL")
  assert_true(stmt.step())
  let typed : Int64 = stmt.column(index=0)
  let dynamic : @sqlite3.Value = stmt.column(index=1)
  assert_eq(typed, 42L)
  assert_eq(dynamic, @sqlite3.Value::Null)
  let out_of_range = @test.expect_error(() => {
    let _ : @sqlite3.Value = stmt.column(index=2)
  })
  match out_of_range {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.contains("column index 2"))
    }
  }
  stmt.finalize()
  conn.close()
}

///|
test "dynamic values preserve the initial storage class after typed reads" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 42, '42'")
  assert_true(stmt.step())
  let integer_as_text : String = stmt.column(index=0)
  let text_as_integer : Int64 = stmt.column(index=1)
  assert_eq(integer_as_text, "42")
  assert_eq(text_as_integer, 42L)
  let integer : @sqlite3.Value = stmt.column(index=0)
  let text : @sqlite3.Value = stmt.column(index=1)
  assert_eq(integer, @sqlite3.Value::Integer(42L))
  assert_eq(text, @sqlite3.Value::Text("42"))
  stmt.finalize()
  conn.close()
}
