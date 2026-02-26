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
  stmt.bind(index=1, val=1)
  stmt.bind_string_as_blob(index=2, val="Paul")
  stmt.bind(index=3, val=32)
  stmt.bind_string_as_blob(index=4, val="California")
  stmt.bind(index=5, val=20000.00)
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
    let column1 : String = stmt.column_blob_as_string(index=1)
    assert_eq(column1, "Paul")
    let column3 : String = stmt.column_blob_as_string(index=3)
    assert_eq(column3, "California")
    let column4 : Double = stmt.column(index=4)
    assert_eq(column4.to_int(), 20000)
  }
}

///|
test {
  let conn = @sqlite3.Connection::open(":memory:")
  create_company(conn)
  insert_company(conn)
  select_company(conn)
}
