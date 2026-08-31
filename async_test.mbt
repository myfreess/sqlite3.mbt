///|
async fn execute(connection : @sqlite3.Connection, sql : String) -> Unit {
  let statement = connection.prepare_async(sql)
  defer statement.finalize()
  assert_false(statement.step_async())
}

///|
#cfg(target="native")
fn prepare_slow_sum(
  connection : @sqlite3.Connection,
) -> @sqlite3.Statement raise @sqlite3.SqliteError {
  connection.prepare(
    (
      #|WITH RECURSIVE counter(value) AS (
      #|  VALUES(1)
      #|  UNION ALL
      #|  SELECT value + 1 FROM counter WHERE value < 1000000
      #|)
      #|SELECT sum(value) FROM counter
    ),
  )
}

///|
async test "async steps mutate independent connections concurrently" {
  let values = Array::make(4, 0L)
  @async.with_task_group() <| group => {
    for index in 0..<values.length() {
      group.spawn_bg() <| () => {
        let connection = @sqlite3.Connection::open_async(":memory:")
        defer connection.close()
        execute(
          connection, "CREATE TABLE entries(id INTEGER PRIMARY KEY, value INTEGER)",
        )
        execute(connection, "INSERT INTO entries VALUES (1, 10), (2, 20)")
        execute(connection, "UPDATE entries SET value = value + 5 WHERE id = 2")
        execute(connection, "DELETE FROM entries WHERE id = 1")
        let query = connection.prepare_async("SELECT value FROM entries")
        defer query.finalize()
        assert_true(query.step_async())
        values[index] = query.column(index=0)
        assert_false(query.step_async())
      }
    }
  }
  assert_eq(values, [25L, 25L, 25L, 25L])
}

///|
async test "async prepare owns errors and releases rejected statements" {
  let connection = @sqlite3.Connection::open_async(":memory:")
  try connection.prepare_async("SELECT FROM") catch {
    @sqlite3.SqliteError(code=Error, msg~, ..) => assert_true(msg.length() > 0)
    error => raise error
  } noraise {
    _ => fail("expected invalid SQL to fail during prepare")
  }
  try connection.prepare_async("SELECT 1; SELECT 2") catch {
    @sqlite3.SqliteError(code=Misuse, ..) => ()
    error => raise error
  } noraise {
    _ => fail("expected a second SQL statement to be rejected")
  }
  let statement = connection.prepare_async("SELECT 42")
  assert_true(statement.step_async())
  let value : Int64 = statement.column(index=0)
  assert_eq(value, 42L)
  statement.finalize()
  connection.close()
}

///|
#cfg(target="native")
async test "async step yields while native SQLite is running" {
  let connection = @sqlite3.Connection::open(":memory:")
  defer connection.close()
  let statement = prepare_slow_sum(connection)
  defer statement.finalize()
  let sibling_statement = connection.prepare("SELECT 42")
  defer sibling_statement.finalize()
  let started = @async.Semaphore(1, initial_value=0)
  let sibling_ran = Ref(false)
  let yielded = Ref(false)
  @async.with_task_group() <| group => {
    group.spawn_bg() <| () => {
      started.release()
      assert_true(statement.step_async())
      yielded.val = sibling_ran.val
    }
    started.acquire()
    group.spawn_bg() <| () => {
      assert_true(sibling_statement.step())
      let value : Int64 = sibling_statement.column(index=0)
      assert_eq(value, 42L)
      sibling_ran.val = true
    }
  }
  assert_true(yielded.val)
  let sum : Int64 = statement.column(index=0)
  assert_eq(sum, 500000500000L)
}

///|
#cfg(target="native")
async test "async step excludes synchronous use of the same statement" {
  let connection = @sqlite3.Connection::open(":memory:")
  defer connection.close()
  let statement = prepare_slow_sum(connection)
  defer statement.finalize()
  let started = @async.Semaphore(1, initial_value=0)
  @async.with_task_group() <| group => {
    group.spawn_bg() <| () => {
      started.release()
      assert_true(statement.step_async())
    }
    started.acquire()
    try statement.reset() catch {
      SqliteError(code=Misuse, ..) => ()
      error => raise error
    } noraise {
      _ => fail("expected the in-flight statement to reject reset")
    }
    try connection.close() catch {
      SqliteError(code=Misuse, ..) => ()
      error => raise error
    } noraise {
      _ => fail("expected the in-flight step to keep its connection open")
    }
  }
  let sum : Int64 = statement.column(index=0)
  assert_eq(sum, 500000500000L)
  statement.reset()
}

///|
#cfg(target="native")
async test "cancelling async step leaves its connection reusable" {
  let connection = @sqlite3.Connection::open(":memory:")
  defer connection.close()
  let statement = prepare_slow_sum(connection)
  try @async.with_timeout(1, () => statement.step_async()) catch {
    @async.TimeoutError => ()
    error => raise error
  } noraise {
    _ => fail("expected the asynchronous step to be cancelled")
  }
  statement.finalize()
  execute(connection, "CREATE TABLE after_cancel(value INTEGER)")
}

///|
async test "failed close preserves the connection executor" {
  let connection = @sqlite3.Connection::open(":memory:")
  execute(connection, "CREATE TABLE entries(value INTEGER)")
  let statement = connection.prepare("SELECT count(*) FROM entries")
  try connection.close() catch {
    @sqlite3.SqliteError(code=Busy, ..) => ()
    error => raise error
  } noraise {
    _ => fail("expected the open statement to keep the connection busy")
  }
  assert_true(statement.step_async())
  let count : Int64 = statement.column(index=0)
  assert_eq(count, 0L)
  statement.finalize()
  connection.close()
}

///|
async test "async prepare and step serialize on one connection" {
  let connection = @sqlite3.Connection::open_async(":memory:")
  defer connection.close()
  execute(connection, "CREATE TABLE entries(value INTEGER)")
  @async.with_task_group() <| group => {
    for value in [1, 2] {
      group.spawn_bg() <| () => {
        let statement = connection.prepare_async(
          "INSERT INTO entries VALUES (\{value})",
        )
        defer statement.finalize()
        assert_false(statement.step_async())
      }
    }
  }
  let query = connection.prepare_async("SELECT sum(value) FROM entries")
  defer query.finalize()
  assert_true(query.step_async())
  let sum : Int64 = query.column(index=0)
  assert_eq(sum, 3L)
}

///|
async test "async step owns its error diagnostics" {
  let connection = @sqlite3.Connection::open(":memory:")
  defer connection.close()
  execute(connection, "CREATE TABLE entries(value INTEGER UNIQUE)")
  execute(connection, "INSERT INTO entries VALUES (1)")
  let duplicate = connection.prepare("INSERT INTO entries VALUES (1)")
  try duplicate.step_async() catch {
    error =>
      assert_true(
        error
        is @sqlite3.SqliteError(
          code=Constraint,
          extended=Some(ConstraintUnique),
          ..
        ),
      )
  } noraise {
    _ => fail("expected a uniqueness error")
  }
  try duplicate.finalize() catch {
    _ => ()
  } noraise {
    _ => ()
  }
  let query = connection.prepare("SELECT count(*) FROM entries")
  defer query.finalize()
  assert_true(query.step_async())
  let count : Int64 = query.column(index=0)
  assert_eq(count, 1L)
}
