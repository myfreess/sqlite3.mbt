///|
test "changes reports the most recently completed data modification" {
  let conn = @sqlite3.Connection::open(":memory:")
  assert_eq(conn.changes(), 0L)

  let create = conn.prepare("CREATE TABLE changes_(id INTEGER PRIMARY KEY)")
  assert_eq(create.step(), false)
  create.finalize()
  assert_eq(conn.changes(), 0L)

  let insert = conn.prepare("INSERT INTO changes_ VALUES (1), (2), (3)")
  assert_eq(insert.step(), false)
  insert.finalize()
  assert_eq(conn.changes(), 3L)

  let update = conn.prepare("UPDATE changes_ SET id = id + 10 WHERE id < 3")
  assert_eq(update.step(), false)
  update.finalize()
  assert_eq(conn.changes(), 2L)

  let select = conn.prepare("SELECT id FROM changes_ ORDER BY id")
  while select.step() {
    let _ : Int64 = select.column(index=0)
  }
  select.finalize()
  assert_eq(conn.changes(), 2L)

  let delete = conn.prepare("DELETE FROM changes_ WHERE id < 0")
  assert_eq(delete.step(), false)
  delete.finalize()
  assert_eq(conn.changes(), 0L)

  conn.close()
  let after_close = @test.expect_error(() => ignore(conn.changes()))
  assert_true(after_close is @sqlite3.SqliteError(code=Misuse, ..))
}
