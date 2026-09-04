///|
async fn execute(connection : @sqlite3.Connection, sql : String) -> Unit {
  let statement = connection.prepare_async(sql)
  defer statement.finalize()
  assert_true(statement.step_async() is @sqlite3.StepResult::Done(..))
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
        assert_eq(query.step_async(), @sqlite3.StepResult::Row)
        values[index] = query.column(index=0)
        assert_eq(query.step_async(), @sqlite3.StepResult::Done(changes=None))
      }
    }
  }
  assert_eq(values, [25L, 25L, 25L, 25L])
}

///|
async test "async step returns its own completion result" {
  let connection = @sqlite3.Connection::open_async(":memory:")
  defer connection.close()
  let create = connection.prepare_async("CREATE TABLE entries(value INTEGER)")
  assert_eq(create.step_async(), @sqlite3.StepResult::Done(changes=Some(0L)))
  create.finalize()
  let insert = connection.prepare_async("INSERT INTO entries VALUES (1), (2)")
  assert_eq(insert.step_async(), @sqlite3.StepResult::Done(changes=Some(2L)))
  insert.finalize()
  let no_op = connection.prepare_async(
    "UPDATE entries SET value = value WHERE 0",
  )
  assert_eq(no_op.step_async(), @sqlite3.StepResult::Done(changes=Some(0L)))
  no_op.finalize()
  let query = connection.prepare_async(
    "SELECT value FROM entries ORDER BY value",
  )
  assert_eq(query.step_async(), @sqlite3.StepResult::Row)
  assert_eq(query.step_async(), @sqlite3.StepResult::Row)
  assert_eq(query.step_async(), @sqlite3.StepResult::Done(changes=None))
  query.finalize()
  let returning = connection.prepare_async(
    "UPDATE entries SET value = value + 1 RETURNING value",
  )
  assert_eq(returning.step_async(), @sqlite3.StepResult::Row)
  assert_eq(returning.step_async(), @sqlite3.StepResult::Row)
  assert_eq(returning.step_async(), @sqlite3.StepResult::Done(changes=Some(2L)))
  returning.finalize()
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
  assert_eq(statement.step_async(), @sqlite3.StepResult::Row)
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
      assert_eq(statement.step_async(), @sqlite3.StepResult::Row)
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
async test "async SQLite work runs concurrently across connections" {
  let directory = @fs.tmpdir(prefix="sqlite3-async-concurrency")
  defer @fs.rmdir(directory, recursive=true)
  let database_path = "\{directory}/database.sqlite3"
  let blocker = @sqlite3.Connection::open_async(database_path)
  defer blocker.close()
  execute(blocker, "CREATE TABLE locked(value INTEGER)")
  execute(blocker, "INSERT INTO locked VALUES (1)")
  execute(blocker, "BEGIN")
  let held_read = blocker.prepare_async("SELECT value FROM locked")
  defer held_read.finalize()
  assert_eq(held_read.step_async(), @sqlite3.StepResult::Row)
  let rollback = blocker.prepare_async("ROLLBACK")
  defer rollback.finalize()

  let writer = @sqlite3.Connection::open_async(database_path)
  defer writer.close()
  let busy_timeout = writer.prepare_async("PRAGMA busy_timeout = 30000")
  assert_eq(busy_timeout.step_async(), @sqlite3.StepResult::Row)
  assert_eq(busy_timeout.step_async(), @sqlite3.StepResult::Done(changes=None))
  busy_timeout.finalize()
  execute(writer, "BEGIN IMMEDIATE")
  execute(writer, "UPDATE locked SET value = value + 1")
  let commit = writer.prepare_async("COMMIT")
  defer commit.finalize()

  let observer = @sqlite3.Connection::open_async(database_path)
  defer observer.close()
  let observer_read = observer.prepare_async("SELECT value FROM locked")
  defer observer_read.finalize()

  let other = @sqlite3.Connection::open_async(":memory:")
  defer other.close()
  let submitted = @async.Semaphore(1, initial_value=0)
  let commit_completed = Ref(false)
  @async.with_task_group() <| group => {
    errdefer {
      held_read.reset()
      ignore(rollback.step())
    }
    group.spawn_bg() <| () => {
      submitted.release()
      assert_true(commit.step_async() is @sqlite3.StepResult::Done(..))
      commit_completed.val = true
    }
    submitted.acquire()
    // BEGIN IMMEDIATE's RESERVED lock still permits readers. SQLITE_BUSY here
    // means the async COMMIT has entered sqlite3_step, acquired a PENDING lock,
    // and is waiting for held_read to release its SHARED lock.
    let mut commit_is_waiting = false
    let mut attempts = 0
    while !commit_is_waiting && attempts < 1000 {
      try observer_read.step() catch {
        @sqlite3.SqliteError(code=Busy, ..) => {
          commit_is_waiting = true
          observer_read.reset() catch {
            @sqlite3.SqliteError(code=Busy, ..) => ()
            error => raise error
          }
        }
        error => raise error
      } noraise {
        _ => observer_read.reset()
      }
      if !commit_is_waiting {
        @async.sleep(1)
      }
      attempts += 1
    }
    assert_true(commit_is_waiting)

    // COMMIT cannot finish until blocker is released below. Completing these
    // jobs proves that the unrelated connection has an independent worker.
    execute(other, "CREATE TABLE proof AS SELECT 42 AS value")
    let other_read = other.prepare_async("SELECT value FROM proof")
    assert_eq(other_read.step_async(), @sqlite3.StepResult::Row)
    let value : Int64 = other_read.column(index=0)
    assert_eq(value, 42L)
    other_read.finalize()
    assert_false(commit_completed.val)

    held_read.reset()
    assert_false(rollback.step())
  }
  assert_true(commit_completed.val)
  let result = writer.prepare_async("SELECT value FROM locked")
  defer result.finalize()
  assert_eq(result.step_async(), @sqlite3.StepResult::Row)
  let value : Int64 = result.column(index=0)
  assert_eq(value, 2L)
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
      assert_eq(statement.step_async(), @sqlite3.StepResult::Row)
    }
    started.acquire()
    try statement.reset() catch {
      SqliteError(code=Misuse, ..) => ()
      error => raise error
    } noraise {
      _ => fail("expected the in-flight statement to reject reset")
    }
    try statement.finalize() catch {
      SqliteError(code=Misuse, ..) => ()
      error => raise error
    } noraise {
      _ => fail("expected the in-flight statement to reject finalization")
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
  assert_eq(statement.step_async(), @sqlite3.StepResult::Row)
  let count : Int64 = statement.column(index=0)
  assert_eq(count, 0L)
  statement.finalize()
  connection.close()
}

///|
async test "async prepare and step share one connection worker" {
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
        assert_eq(
          statement.step_async(),
          @sqlite3.StepResult::Done(changes=Some(1L)),
        )
      }
    }
  }
  let query = connection.prepare_async("SELECT sum(value) FROM entries")
  defer query.finalize()
  assert_eq(query.step_async(), @sqlite3.StepResult::Row)
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
  assert_eq(query.step_async(), @sqlite3.StepResult::Row)
  let count : Int64 = query.column(index=0)
  assert_eq(count, 1L)
}

///|
#cfg(target="native")
async test "async completion survives immediate cleanup and cancellation" {
  let connection = @sqlite3.Connection::open_async(":memory:")
  defer connection.close()
  let mut cancellations = 0
  for index in 0..<256 {
    let statement = if index < 2 {
      prepare_slow_sum(connection)
    } else {
      connection.prepare_async("SELECT 1")
    }
    try @async.with_timeout(1, () => statement.step_async()) catch {
      @async.TimeoutError => cancellations += 1
      error => raise error
    } noraise {
      result => assert_eq(result, @sqlite3.StepResult::Row)
    }
    statement.finalize()
  }
  assert_true(cancellations > 0)
  execute(connection, "CREATE TABLE after_stress(value INTEGER)")
}
