///|
test "reset preserves or clears bindings" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1")
  let stmt_copy = stmt
  stmt.bind(index=1, 41L)
  assert_true(stmt.step())
  let first : Int64 = stmt_copy.column(index=0)
  assert_eq(first, 41L)

  stmt_copy.reset()
  let invalidated_row = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  assert_true(
    invalidated_row
    is @sqlite3.SqliteError(
      code=Misuse,
      extended=None,
      msg="sqlite3: statement has no current row"
    ),
  )
  assert_true(stmt.step())
  let preserved : Int64 = stmt.column(index=0)
  assert_eq(preserved, 41L)
  assert_eq(stmt.step(), false)

  let bind_before_reset = @test.expect_error(() => stmt.bind(index=1, 42L))
  assert_true(bind_before_reset is @sqlite3.SqliteError(code=Misuse, ..))
  stmt.reset()
  stmt.bind(index=1, 42L)
  assert_true(stmt.step())
  let rebound : Int64 = stmt.column(index=0)
  assert_eq(rebound, 42L)
  assert_eq(stmt.step(), false)

  stmt.reset(clear_bindings=true)
  assert_true(stmt.step())
  let cleared : @sqlite3.Value = stmt.column(index=0)
  assert_eq(cleared, @sqlite3.Value::Null)
  stmt.finalize()
  let reset_after_finalize = @test.expect_error(() => stmt_copy.reset())
  assert_true(reset_after_finalize is @sqlite3.SqliteError(code=Misuse, ..))
  let clear_after_finalize = @test.expect_error(() => {
    stmt_copy.reset(clear_bindings=true)
  })
  assert_true(clear_after_finalize is @sqlite3.SqliteError(code=Misuse, ..))
  conn.close()
}

///|
test "reset can clear bindings while abandoning an active row" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1")
  let stmt_copy = stmt
  stmt.bind(index=1, "bound text")
  assert_true(stmt.step())

  stmt_copy.reset(clear_bindings=true)
  let error = @test.expect_error(() => {
    let _ : String = stmt.column(index=0)
  })
  assert_true(
    error
    is @sqlite3.SqliteError(
      code=Misuse,
      extended=None,
      msg="sqlite3: statement has no current row"
    ),
  )
  assert_true(stmt.step())
  let cleared : @sqlite3.Value = stmt.column(index=0)
  assert_eq(cleared, @sqlite3.Value::Null)
  assert_eq(stmt.step(), false)
  stmt.finalize()
  conn.close()
}

///|
test "reset surfaces the previous execution error and still rewinds" {
  let conn = @sqlite3.Connection::open(":memory:")
  let create = conn.prepare("CREATE TABLE values_(value INTEGER UNIQUE)")
  assert_eq(create.step(), false)
  create.finalize()

  let insert = conn.prepare("INSERT INTO values_ VALUES (?1)")
  insert.bind(index=1, 1L)
  assert_eq(insert.step(), false)
  insert.reset()
  insert.bind(index=1, 1L)
  let step_error = @test.expect_error(() => ignore(insert.step()))
  assert_true(step_error is @sqlite3.SqliteError(code=Constraint, ..))
  let reset_error = @test.expect_error(() => insert.reset(clear_bindings=true))
  assert_true(reset_error is @sqlite3.SqliteError(code=Constraint, ..))

  // reset() rewound the statement and honored clear_bindings even though it
  // reported the previous constraint error. Re-execution therefore binds
  // SQL NULL instead of repeating the duplicate value.
  assert_eq(insert.step(), false)
  insert.reset()
  insert.bind(index=1, 2L)
  assert_eq(insert.step(), false)
  insert.finalize()
  conn.close()
}

///|
test "result column metadata is available independently of row state" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 1 AS identifier, 2 AS 月球, 3 AS \"\"")
  assert_eq(stmt.column_count(), 3)
  assert_eq(stmt.column_name(index=0), "identifier")
  assert_eq(stmt.column_name(index=1), "月球")
  assert_eq(stmt.column_name(index=2), "")

  let negative = @test.expect_error(() => ignore(stmt.column_name(index=-1)))
  assert_true(negative is @sqlite3.SqliteError(code=Misuse, ..))
  let too_large = @test.expect_error(() => ignore(stmt.column_name(index=3)))
  assert_true(too_large is @sqlite3.SqliteError(code=Misuse, ..))

  assert_true(stmt.step())
  assert_eq(stmt.column_name(index=1), "月球")
  stmt.reset()
  assert_eq(stmt.column_count(), 3)
  assert_eq(stmt.column_name(index=0), "identifier")
  stmt.finalize()

  let after_finalize = @test.expect_error(() => ignore(stmt.column_count()))
  assert_true(after_finalize is @sqlite3.SqliteError(code=Misuse, ..))
  conn.close()
}
