///|
fn main {
  try {
    let conn = @sqlite3.Connection::open!(":memory:")
    let create_project = conn.prepare!(
      #|CREATE TABLE IF NOT EXISTS PROJECT (ID INTEGER PRIMARY KEY);
    )
    create_project.step_once!()
    create_project.finalize!()
    println("table 'project' created!")
    conn.close!()
  } catch {
    SqliteError(err) => {
      println(err)
    }
  }
}
