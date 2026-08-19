///|
fn sql_tail_is_ignorable(sql : String, start : Int) -> Bool {
  let scanner = @lexbuf.StringScanner::{ data: sql[start:], cursor: 0 }
  for ;; {
    lexscan scanner with longest {
      re"^[ \t\n\f\r;\uFEFF]+" => continue
      re"^--[^\n]*(\n|$)" => continue
      re"^/[*]([^*]|[*]+[^*/])*[*]+/" => continue
      re"^/[*]([^*]|[*]+[^*/])*[*]*$" => return true
      re"^$" => return true
      _ => return false
    }
  }
}

///|
#callsite(autofill(loc))
pub fn[T : Bind] Statement::bind(
  self : Statement,
  index~ : Int,
  val : T,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  T::bind(self, index, val, loc~)
}

///|
pub fn[T : Column] Statement::column(self : Statement, index~ : Int) -> T {
  T::column(self, index)
}

///|
#callsite(autofill(loc))
pub fn Statement::step_once(
  self : Statement,
  loc~ : SourceLoc,
) -> Unit raise SqliteError {
  if self.step(loc~) {
    raise SqliteError((SQLITE_ROW, loc))
  }
}
