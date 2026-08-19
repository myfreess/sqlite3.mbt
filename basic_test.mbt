///|
fn create_company(
  conn : @sqlite3.Connection,
) -> Unit raise @sqlite3.SqliteError {
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
  stmt.step_once()
  stmt.finalize()
}

///|
fn insert_company(
  conn : @sqlite3.Connection,
) -> Unit raise @sqlite3.SqliteError {
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
  stmt.step_once()
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
    let column0 : Int = stmt.column(index=0)
    assert_eq(column0, 1)
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
  set_encoding.step_once()
  set_encoding.finalize()
  let create = conn.prepare("CREATE TABLE 月球 (问候 TEXT)")
  create.step_once()
  create.finalize()
  let insert = conn.prepare("INSERT INTO 月球 (问候) VALUES (?)")
  insert.bind(index=1, "你好，MoonBit 🌙")
  insert.step_once()
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
  let mut prepare_failed = false
  try {
    let _ = conn.prepare("SELECT * FROM 不存在")
  } catch {
    _ => prepare_failed = true
  }
  assert_true(prepare_failed)
  assert_eq(conn.get_errmsg(), "no such table: 不存在")
  conn.close()
}

///|
test "UTF-16LE strings with a UTF-16BE database" {
  let conn = @sqlite3.Connection::open(":memory:")
  let set_encoding = conn.prepare("PRAGMA encoding = 'UTF-16be'")
  set_encoding.step_once()
  set_encoding.finalize()
  let create = conn.prepare("CREATE TABLE 文本 (内容 TEXT)")
  create.step_once()
  create.finalize()
  let insert = conn.prepare("INSERT INTO 文本 (内容) VALUES (?)")
  insert.bind(index=1, "数据库 🌙")
  insert.step_once()
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
    SqliteError((code, _)) => assert_eq(code, @sqlite3.SQLITE_MISUSE)
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
test "integer and blob values round trip across backends" {
  let conn = @sqlite3.Connection::open(":memory:")
  let create = conn.prepare("CREATE TABLE values_test (i INTEGER, b BLOB)")
  create.step_once()
  create.finalize()
  let expected_int = 9007199254740993L
  let expected_blob : Bytes = [0x00, 0x80, 0xFF]
  let insert = conn.prepare("INSERT INTO values_test VALUES (?, ?)")
  insert.bind(index=1, expected_int)
  insert.bind(index=2, expected_blob)
  insert.step_once()
  insert.finalize()
  let select = conn.prepare("SELECT i, b FROM values_test")
  assert_true(select.step())
  let actual_int : Int64 = select.column(index=0)
  let actual_blob : Bytes = select.column(index=1)
  assert_eq(actual_int, expected_int)
  assert_eq(actual_blob, expected_blob)
  select.finalize()
  conn.close()
}

///|
test "close preserves a connection with a live statement" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT 1")
  let close_error = @test.expect_error(() => conn.close())
  match close_error {
    SqliteError((code, _)) => assert_eq(code, @sqlite3.SQLITE_BUSY)
  }
  assert_true(stmt.step())
  let value : Int = stmt.column(index=0)
  assert_eq(value, 1)
  stmt.finalize()
  conn.close()
}

///|
test "errors use primary SQLite result codes" {
  let conn = @sqlite3.Connection::open(":memory:")
  let create = conn.prepare("CREATE TABLE unique_test (id INTEGER PRIMARY KEY)")
  create.step_once()
  create.finalize()
  let first = conn.prepare("INSERT INTO unique_test VALUES (1)")
  first.step_once()
  first.finalize()
  let duplicate = conn.prepare("INSERT INTO unique_test VALUES (1)")
  let insert_error = @test.expect_error(() => duplicate.step_once())
  match insert_error {
    SqliteError((code, _)) => assert_eq(code, @sqlite3.SQLITE_CONSTRAINT)
  }
  duplicate.finalize() catch {
    _ => ()
  }
  conn.close()
}
