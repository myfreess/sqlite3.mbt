
fn create_company(conn : @sqlite3.Connection) -> Unit!@sqlite3.SqliteError {
  let stmt = conn.prepare!(
    #|CREATE TABLE COMPANY(
    #|  ID INT PRIMARY KEY     NOT NULL,
    #|  NAME           BLOB    NOT NULL,
    #|  AGE            INT     NOT NULL,
    #|  ADDRESS        BLOB,
    #|  SALARY         REAL
    #|);
  )
  stmt.step_once!()
  stmt.finalize!()
}

fn insert_company(conn : @sqlite3.Connection) -> Unit!@sqlite3.SqliteError {
  let stmt = conn.prepare!(
    #|INSERT INTO COMPANY (ID,NAME,AGE,ADDRESS,SALARY) VALUES (?,?,?,?,?);
  )
  stmt.bind!(index = 1, val = 1)
  stmt.bind!(index = 2, val = "Paul")
  stmt.bind!(index = 3, val = 32)
  stmt.bind!(index = 4, val = "California")
  stmt.bind!(index = 5, val = 20000.00)
  stmt.step_once!()
  stmt.finalize!()
}

fn select_company(conn : @sqlite3.Connection) -> Unit!@sqlite3.SqliteError {
  let stmt = conn.prepare!(
    #|SELECT * from COMPANY
  )
  if stmt.step!() {
    let column0 : Int = stmt.column!(index = 0)
    println("column0 = \{column0}")
    let column1 : String = stmt.column!(index = 1)
    println("column1 = \{column1}")
    let column3 :  String = stmt.column!(index = 3)
    println("column3 = \{column3}")
    let column4 : Double = stmt.column!(index = 4)
    println("column4 = \{column4}")
  }
}


fn main {
  try {
    let conn = @sqlite3.Connection::open!(":memory:")
    try {
      create_company!(conn)
      insert_company!(conn)
      select_company!(conn)
    } catch {
      SqliteError(err) => {
        println(err)
        println(conn.get_errmsg())
      }
    }
  } catch {
      SqliteError(err) => {
        println(err)
      }
  }
}