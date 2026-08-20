///|
fn create_company(conn : @sqlite3.Connection) -> Unit raise {
  let stmt = conn.prepare(
    (
      #|CREATE TABLE COMPANY(
      #|  ID INT PRIMARY KEY     NOT NULL,
      #|  NAME           BLOB    NOT NULL,
      #|  AGE            INT     NOT NULL,
      #|  ADDRESS        BLOB,
      #|  SALARY         REAL
      #|);
    ),
  )
  assert_eq(stmt.step(), false)
  stmt.finalize()
}

///|
fn insert_company(conn : @sqlite3.Connection) -> Unit raise {
  let stmt = conn.prepare(
    (
      #|INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY) VALUES (?,?,?,?,?);
    ),
  )
  stmt.bind(index=1, 1)
  stmt.bind(index=2, "Paul")
  stmt.bind(index=3, 32)
  stmt.bind(index=4, "California")
  stmt.bind(index=5, 20000.00)
  assert_eq(stmt.step(), false)
  stmt.finalize()
}

///|
fn select_company(conn : @sqlite3.Connection) -> Unit raise {
  let stmt = conn.prepare(
    (
      #|SELECT * from COMPANY
    ),
  )
  if stmt.step() {
    let column0 : Int64 = stmt.column(index=0)
    assert_eq(column0, 1L)
    let column1 : String = stmt.column(index=1)
    assert_eq(column1, "Paul")
    let column3 : String = stmt.column(index=3)
    assert_eq(column3, "California")
    let column4 : Double = stmt.column(index=4)
    assert_eq(column4.to_int(), 20000)
  }
  stmt.finalize()
}

///|
test "structured error types support equality operators" {
  let code = @sqlite3.ErrorCode::Constraint
  assert_true(code == Constraint)
  assert_true(code != Misuse)
  let extended = @sqlite3.ExtendedCode::ConstraintUnique
  assert_true(extended == ConstraintUnique)
  assert_true(extended != ConstraintPrimaryKey)
  let conn = @sqlite3.Connection::open(":memory:")
  let first_error = @test.expect_error(() => conn.prepare(""))
  let same_error = @test.expect_error(() => conn.prepare(""))
  assert_true(first_error == same_error)
  let different_error = @test.expect_error(() => {
    conn.prepare("SELECT 1; SELECT 2")
  })
  assert_true(first_error != different_error)
  conn.close()
}

///|
test {
  let conn = @sqlite3.Connection::open(":memory:")
  create_company(conn)
  insert_company(conn)
  select_company(conn)
  let encoding = conn.prepare("PRAGMA encoding")
  assert_true(encoding.step())
  let encoding_name : String = encoding.column(index=0)
  assert_eq(encoding_name, "UTF-8")
  encoding.finalize()
  conn.close()
}

///|
test "UTF-16LE strings with a UTF-16LE database" {
  let conn = @sqlite3.Connection::open(":memory:")
  let set_encoding = conn.prepare("PRAGMA encoding = 'UTF-16le'")
  assert_eq(set_encoding.step(), false)
  set_encoding.finalize()
  let create = conn.prepare("CREATE TABLE 月球 (问候 TEXT)")
  assert_eq(create.step(), false)
  create.finalize()
  let insert = conn.prepare("INSERT INTO 月球 (问候) VALUES (?)")
  insert.bind(index=1, "你好，MoonBit 🌙")
  assert_eq(insert.step(), false)
  insert.finalize()
  let select = conn.prepare("SELECT 问候 FROM 月球")
  assert_true(select.step())
  let greeting : String = select.column(index=0)
  assert_eq(greeting, "你好，MoonBit 🌙")
  select.finalize()
  let encoding = conn.prepare("PRAGMA encoding")
  assert_true(encoding.step())
  let encoding_name : String = encoding.column(index=0)
  assert_eq(encoding_name, "UTF-16le")
  encoding.finalize()
  let prepare_error = @test.expect_error(() => {
    conn.prepare("SELECT * FROM 不存在")
  })
  match prepare_error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Error)
      assert_eq(extended, None)
      assert_eq(msg, "no such table: 不存在")
    }
  }
  conn.close()
}

///|
test "UTF-16LE strings with a UTF-16BE database" {
  let conn = @sqlite3.Connection::open(":memory:")
  let set_encoding = conn.prepare("PRAGMA encoding = 'UTF-16be'")
  assert_eq(set_encoding.step(), false)
  set_encoding.finalize()
  let create = conn.prepare("CREATE TABLE 文本 (内容 TEXT)")
  assert_eq(create.step(), false)
  create.finalize()
  let insert = conn.prepare("INSERT INTO 文本 (内容) VALUES (?)")
  insert.bind(index=1, "数据库 🌙")
  assert_eq(insert.step(), false)
  insert.finalize()
  let select = conn.prepare("SELECT 内容 FROM 文本")
  assert_true(select.step())
  let content : String = select.column(index=0)
  assert_eq(content, "数据库 🌙")
  select.finalize()
  let encoding = conn.prepare("PRAGMA encoding")
  assert_true(encoding.step())
  let encoding_name : String = encoding.column(index=0)
  assert_eq(encoding_name, "UTF-16be")
  encoding.finalize()
  conn.close()
}

///|
test "prepare accepts exactly one SQL statement" {
  let conn = @sqlite3.Connection::open(":memory:")
  let empty_error = @test.expect_error(() => conn.prepare(""))
  match empty_error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  @test.assert_raise(() => conn.prepare("-- comment only"))
  @test.assert_raise(() => conn.prepare("SELECT '🌙'; SELECT 2"))
  @test.assert_raise(() => conn.prepare("SELECT 1; /* comment */ SELECT 2"))
  @test.assert_raise(() => conn.prepare("SELECT 1;\u{00}SELECT 2"))
  let trailing_unclosed_comment = conn.prepare("SELECT 1; /*")
  trailing_unclosed_comment.finalize()
  let stmt = conn.prepare(
    (
      #|SELECT '🌙';
      #|-- trailing line comment
      #|/* trailing block comment */ ;
    ),
  )
  assert_true(stmt.step())
  let value : String = stmt.column(index=0)
  assert_eq(value, "🌙")
  assert_eq(stmt.step(), false)
  stmt.finalize()
  conn.close()
}

///|
test "statement aliases share row and finalization state" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 1")
  let stmt_copy = stmt
  assert_true(stmt.step())
  let value : Int64 = stmt_copy.column(index=0)
  assert_eq(value, 1L)
  assert_eq(stmt_copy.step(), false)
  let after_done = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  assert_true(
    after_done
    is @sqlite3.SqliteError(
      code=Misuse,
      extended=None,
      msg="sqlite3: statement has no current row"
    ),
  )
  assert_true(stmt.step())
  stmt_copy.finalize()
  let after_finalize = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  assert_true(
    after_finalize
    is @sqlite3.SqliteError(
      code=Misuse,
      extended=None,
      msg="sqlite3: statement is finalized"
    ),
  )
  stmt_copy.finalize()
  let error = @test.expect_error(() => stmt.step())
  match error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  conn.close()
}

///|
test "connection aliases share close state" {
  let conn = @sqlite3.Connection::open(":memory:")
  let conn_copy = conn
  conn.close()
  conn_copy.close()
  let error = @test.expect_error(() => conn_copy.prepare("SELECT 1"))
  match error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
}

///|
test "close keeps a busy connection open" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 1")
  let error = @test.expect_error(() => conn.close())
  match error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Busy)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  assert_true(stmt.step())
  stmt.finalize()
  conn.close()
}

///|
test "finalize consumes a statement after an execution error" {
  let conn = @sqlite3.Connection::open(":memory:")
  let create = conn.prepare("CREATE TABLE unique_values (value INTEGER UNIQUE)")
  assert_eq(create.step(), false)
  create.finalize()
  let first = conn.prepare("INSERT INTO unique_values VALUES (1)")
  assert_eq(first.step(), false)
  first.finalize()
  let duplicate = conn.prepare("INSERT INTO unique_values VALUES (1)")
  let step_error = @test.expect_error(() => ignore(duplicate.step()))
  match step_error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Constraint)
      // Extended result codes are disabled on the connection, so this API
      // returns the primary constraint code.
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  let finalize_error = @test.expect_error(() => duplicate.finalize())
  match finalize_error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Constraint)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  duplicate.finalize()
  conn.close()
}

///|
test "value edge cases round trip" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1, ?2, ?3")
  stmt.bind(index=1, 5000000000L)
  stmt.bind(index=2, "")
  stmt.bind(index=3, b"")
  assert_true(stmt.step())
  let integer : Int64 = stmt.column(index=0)
  let text : String = stmt.column(index=1)
  let blob : Bytes = stmt.column(index=2)
  assert_eq(integer, 5000000000L)
  assert_eq(text, "")
  assert_eq(blob, b"")
  stmt.finalize()
  conn.close()
}

///|
test "empty and null text and blobs are not stale SQLite errors" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT '', x'', NULL, NULL")
  assert_true(stmt.step())
  // Leave a real connection error after stepping. Column access must
  // distinguish empty/NULL values from the unrelated prior failure.
  let bind_error = @test.expect_error(() => stmt.bind(index=1, 1))
  assert_true(bind_error is @sqlite3.SqliteError(code=Misuse, ..))
  let empty_text : String = stmt.column(index=0)
  let empty_blob : Bytes = stmt.column(index=1)
  let null_text : String = stmt.column(index=2)
  let null_blob : Bytes = stmt.column(index=3)
  assert_eq(empty_text, "")
  assert_eq(empty_blob, b"")
  assert_eq(null_text, "")
  assert_eq(null_blob, b"")
  stmt.finalize()
  conn.close()
}

///|
test "public misuse reports structured errors" {
  let invalid_filename = @test.expect_error(() => {
    @sqlite3.Connection::open("sqlite3-test\u{00}suffix.db")
  })
  match invalid_filename {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.contains("NUL"))
    }
  }

  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 1")
  let before_step = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  match before_step {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  assert_true(stmt.step())
  let value : Int64 = stmt.column(index=0)
  assert_eq(value, 1L)
  assert_eq(stmt.step(), false)
  let after_done = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  match after_done {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  stmt.finalize()
  let after_finalize = @test.expect_error(() => {
    let _ : Int64 = stmt.column(index=0)
  })
  match after_finalize {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  conn.close()
  let after_close = @test.expect_error(() => conn.prepare("SELECT 1"))
  match after_close {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Misuse)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
}

///|
test "step after completion reruns the statement with existing bindings" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1")
  stmt.bind(index=1, 42L)
  assert_true(stmt.step())
  let first : Int64 = stmt.column(index=0)
  assert_eq(first, 42L)
  assert_eq(stmt.step(), false)
  assert_true(stmt.step())
  let second : Int64 = stmt.column(index=0)
  assert_eq(second, 42L)
  assert_eq(stmt.step(), false)
  stmt.finalize()
  conn.close()
}

///|
test "bind errors include SQLite diagnostics" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1")
  let error = @test.expect_error(() => stmt.bind(index=2, 1))
  match error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Range)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  stmt.finalize()
  conn.close()
}

///|
test "file-backed database persists after reopen" {
  // Keep the reusable fixture under Moon's ignored build directory. Resetting
  // the table makes reruns independent of backend-specific file cleanup APIs.
  let filename = "_build/sqlite3-persistence-test.db"
  let conn = @sqlite3.Connection::open(filename)
  let reset = conn.prepare("DROP TABLE IF EXISTS persisted")
  assert_eq(reset.step(), false)
  reset.finalize()
  let create = conn.prepare("CREATE TABLE persisted(value TEXT)")
  assert_eq(create.step(), false)
  create.finalize()
  let insert = conn.prepare("INSERT INTO persisted VALUES (?)")
  insert.bind(index=1, "persisted 🌙")
  assert_eq(insert.step(), false)
  insert.finalize()
  conn.close()

  let reopened = @sqlite3.Connection::open(filename)
  let query = reopened.prepare("SELECT value FROM persisted")
  assert_true(query.step())
  let value : String = query.column(index=0)
  assert_eq(value, "persisted 🌙")
  assert_eq(query.step(), false)
  query.finalize()
  reopened.close()
}
