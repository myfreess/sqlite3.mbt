///|
fn main {
  let conn = 
    try {
      @sqlite3.Connection::open!("test.db")
    } catch {
      SqliteError(code) => {
        println(code)
        panic()
      }
    }
  try {
    let create_project = conn.prepare!(
      #|CREATE TABLE IF NOT EXISTS PROJECT (ID INTEGER PRIMARY KEY);
    )
    // if create.step!() {
    //   println("table 'project' created!")
    // }
  } catch {
    SqliteError(code) => {
      println(code)
    }
  }
}
