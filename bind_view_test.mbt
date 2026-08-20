///|
test "partial string and byte views bind only their selected range" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?1, ?2")
  let text = "xxmoonyy"
  let text_view : StringView = text[2:6]
  let blob = b"xxbityy"
  let blob_view : BytesView = blob[2:5]
  stmt.bind(index=1, text_view)
  stmt.bind(index=2, blob_view)
  assert_true(stmt.step())
  let bound_text : String = stmt.column(index=0)
  let bound_blob : Bytes = stmt.column(index=1)
  assert_eq(bound_text, "moon")
  assert_eq(bound_blob, b"bit")
  stmt.finalize()
  conn.close()
}
