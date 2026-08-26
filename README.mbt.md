# SQLite3.mbt

`moonbit-community/sqlite3` is a lightweight, low-level SQLite3 binding for MoonBit. It exposes the core SQLite C API workflow for opening connections, preparing statements, binding parameters, stepping through results, and reading column values. It is intended for cases where you want a small and direct embedded database interface rather than an ORM or a full query framework.

This package supports the `native` and `wasm` targets. The native backend vendors SQLite `3.49.1` directly in the repository; the Wasm backend uses moonrun's `moonbitlang/sqlite` host imports. The pinned moonrun revision described in `dev.md` bundles SQLite `3.53.2`; other Wasm hosts control their own SQLite version.

## Features

- Thin wrapper design with a small API surface that stays close to SQLite's native workflow.
- Support for prepared statements, positional parameter binding, and row-by-row result reading.
- Explicit statement reuse, result-column metadata, and affected-row counts.
- Structured primary and extended error codes with the SQLite diagnostic message captured at the failure site.
- The native backend ships with `sqlite3.c` and `sqlite3.h`, so it does not rely on a system-installed SQLite.
- The Wasm backend keeps SQLite pointers inside the host and represents connections and statements with opaque handles.

## Installation

Add the dependency:

```bash
moon add moonbit-community/sqlite3
```

## Quick Start

The following example shows the basic workflow: open an in-memory database, create a table, insert one row, and query it back.

```mbt check
///|
test "quick start" {
  let conn = @sqlite3.Connection::open(":memory:")

  let create = conn.prepare(
    (
      #|CREATE TABLE users (
      #|  id INTEGER PRIMARY KEY,
      #|  name TEXT NOT NULL,
      #|  score REAL NOT NULL
      #|);
    ),
  )
  assert_eq(create.step(), false)
  create.finalize()

  let insert = conn.prepare(
    (
      #|INSERT INTO users (id, name, score) VALUES (?, ?, ?);
    ),
  )
  insert.bind(index=1, 1)
  insert.bind(index=2, "alice")
  insert.bind(index=3, 98.5)
  assert_eq(insert.step(), false)
  insert.finalize()

  let query = conn.prepare(
    (
      #|SELECT id, name, score FROM users;
    ),
  )
  assert_true(query.step())
  let id : Int64 = query.column(index=0)
  let name : String = query.column(index=1)
  let score : Double = query.column(index=2)
  assert_eq(id, 1L)
  assert_eq(name, "alice")
  assert_eq(score.to_int(), 98)
  assert_eq(query.step(), false)
  query.finalize()

  conn.close()
}
```

### Workflow Summary

1. `Connection::open` opens the database. Pass `":memory:"` for an in-memory database. File paths such as `"app.db"` work when the selected backend and runtime grant filesystem access.
2. `Connection::prepare` creates a prepared statement.
3. Call `Statement::step()` to advance the statement. Statements that do not return rows normally return `false` on the first call, meaning execution is complete.
4. For queries, call `Statement::step()` repeatedly. It returns `true` when a row is available and `false` when the result set is exhausted.
5. Use `Statement::column(index=...)` to read column values from the current row. It raises `SqliteError` with `code=Misuse` unless the preceding `step()` returned `true`.
6. Call `Statement::finalize()` to release the statement.
7. Call `Connection::close()` when you are done with the connection.

## Multi-Row Queries and BLOB Values

`Bytes` is bound as SQLite `BLOB` and can also be read back as `Bytes`:

```mbt check
///|
test "blob round trip" {
  let conn = @sqlite3.Connection::open(":memory:")

  let create = conn.prepare(
    (
      #|CREATE TABLE files (
      #|  id INTEGER PRIMARY KEY,
      #|  payload BLOB NOT NULL
      #|);
    ),
  )
  assert_eq(create.step(), false)
  create.finalize()

  let insert1 = conn.prepare(
    (
      #|INSERT INTO files (id, payload) VALUES (?, ?);
    ),
  )
  insert1.bind(index=1, 1)
  insert1.bind(index=2, b"abc")
  assert_eq(insert1.step(), false)
  insert1.finalize()

  let insert2 = conn.prepare(
    (
      #|INSERT INTO files (id, payload) VALUES (?, ?);
    ),
  )
  insert2.bind(index=1, 2)
  insert2.bind(index=2, b"xyz")
  assert_eq(insert2.step(), false)
  insert2.finalize()

  let query = conn.prepare(
    (
      #|SELECT id, payload FROM files ORDER BY id;
    ),
  )

  assert_true(query.step())
  let first_id : Int64 = query.column(index=0)
  let first_payload : Bytes = query.column(index=1)
  assert_eq(first_id, 1L)
  assert_eq(first_payload, b"abc")

  assert_true(query.step())
  let second_id : Int64 = query.column(index=0)
  let second_payload : Bytes = query.column(index=1)
  assert_eq(second_id, 2L)
  assert_eq(second_payload, b"xyz")

  assert_eq(query.step(), false)
  query.finalize()

  conn.close()
}
```

## Error Handling

All public operations that can fail raise `SqliteError`. If you want explicit result-based handling, use `try?` to convert the raised error into a `Result`.

```mbt check
///|
test "error handling" {
  let conn = @sqlite3.Connection::open(":memory:")

  let error = @test.expect_error(() => conn.prepare("SELECT FROM"))
  match error {
    @sqlite3.SqliteError(code~, extended~, msg~) => {
      assert_eq(code, @sqlite3.ErrorCode::Error)
      assert_eq(extended, None)
      assert_true(msg.length() > 0)
    }
  }
  conn.close()
}
```

`SqliteError` contains a typed primary `ErrorCode`, an optional typed `ExtendedCode`, and SQLite's diagnostic message. The wrapper captures the message at the point of failure; callers do not need to query mutable connection error state.

## Public API Overview

### `Connection`

- `Connection::open(filename)`: open a database connection.
- `Connection::open_async(filename)`: open a database without blocking the MoonBit event loop.
- `Connection::prepare(sql)`: create a prepared statement.
- `Connection::prepare_async(sql)`: prepare one statement without blocking the MoonBit event loop.
- `Connection::changes()`: return the rows changed by the most recently completed `INSERT`, `UPDATE`, or `DELETE` on the connection.
- `Connection::close()`: close the database connection.

### `Statement`

- `Statement::bind(index, value)`: bind a parameter. Parameter indexes start at `1`, matching the SQLite C API.
- `Statement::step()`: advance the statement once. It returns `true` when a row is available and `false` when execution is complete. `CREATE`, `INSERT`, `UPDATE`, and `DELETE` statements without a `RETURNING` clause normally return `false` on the first call.
- `Statement::step_async()`: advance the statement without blocking the MoonBit event loop.
- `Statement::reset(clear_bindings?)`: rewind the statement for another execution. Existing parameter bindings are preserved by default; pass `clear_bindings=true` to replace them with SQL `NULL`.
- `Statement::column(index)`: read a column value from the current row. Column indexes start at `0`; calling it before `step()` yields a row, after `step()` returns `false`, or after finalization raises an error with `code=Misuse`.
- `Statement::column_count()` and `Statement::column_name(index)`: inspect result-column metadata independently of whether a row is currently available.
- `Statement::finalize()`: destroy the prepared statement and release its native resources.

### `Bind` and `Column`

The current public implementations support the following MoonBit types:

| MoonBit type | Bound as SQLite | Read from SQLite as |
| --- | --- | --- |
| `Int` | `INTEGER` | — |
| `Int64` | `INTEGER` | `Int64` |
| `Double` | `REAL` | `Double` |
| `String` | `TEXT` | `String` |
| `StringView` | `TEXT` | — |
| `Bytes` | `BLOB` | `Bytes` |
| `BytesView` | `BLOB` | — |
| `Value` | Exact SQLite storage class, including `NULL` | `Value` |

Use `Value` when a value may be `NULL` or its SQLite storage class is not
known statically. It uses the existing `bind` and `column` methods, so no
separate dynamic statement interface is required:

```mbt check
///|
test "dynamic value" {
  let conn = @sqlite3.Connection::open(":memory:")
  let stmt = conn.prepare("SELECT ?")
  stmt.bind(index=1, @sqlite3.Value::Null)
  assert_true(stmt.step())
  let value : @sqlite3.Value = stmt.column(index=0)
  assert_eq(value, @sqlite3.Value::Null)
  stmt.finalize()
  conn.close()
}
```

`Value::Integer` and typed integer columns use `Int64`, preserving SQLite's
full integer range. Convert to `Int` explicitly only when the application's
domain guarantees that the value fits. Request `Value` when distinguishing
`NULL` is significant.

## Constraints and Notes

- This is a manual resource management API. Every `Statement` must be explicitly `finalize()`d, and every `Connection` must be explicitly `close()`d. Dropping these values does not release SQLite resources on any backend.
- Native asynchronous operations use one lazily created worker per connection and serialize access to that connection. Different connections can run concurrently. Wasm hosts may complete the same APIs synchronously.
- The Wasm backend requires a runtime that provides the `moonbitlang/sqlite` imports. Filesystem access and SQL policy are enforced by the host runtime.
- The bundled native SQLite `3.49.1` build and the pinned moonrun SQLite `3.53.2` build both use SQLite's automatic reset behavior: calling `step()` again after it returns `false` reruns the statement with its existing bindings. Call `reset()` explicitly to rewind before rebinding; pass `clear_bindings=true` when old parameter values must not be reused.
- `Connection::prepare` and `Connection::prepare_async` accept exactly one SQL statement. Empty input, comment-only input, and additional statements after the first one raise an error with `code=Misuse`; trailing whitespace, comments, and empty semicolons are allowed.
- Parameter indexes start at `1`, while column indexes start at `0`. It is easy to mix these up.
- SQL and `String` values cross both backend boundaries as UTF-16 code units. Native targets require little-endian UTF-16, while WebAssembly memory is little-endian by definition. SQLite converts text when the database file uses a different encoding. Use `Bytes` when the value is raw binary data rather than text.
- `Connection::open` and `Connection::open_async` use `sqlite3_open_v2`, so a new database defaults to UTF-8. To select UTF-16LE or UTF-16BE storage, run `PRAGMA encoding` before creating any schema objects; this choice is independent of the native string API.
- The package exposes result-column counts and names, but not declared column types. `Value` reports the initial runtime storage class of a value in the current row. That class is cached before typed coercion, so reading the same cell through a typed decoder first does not change the later `Value` variant.
- The package is intentionally focused on SQLite basics and does not add transaction wrappers, batch helpers, or named-parameter support.

## Error Codes

`ErrorCode` represents SQLite's primary error categories, while `ExtendedCode` provides the additional classification returned by some SQLite operations. Unknown codes from a newer SQLite runtime are preserved as `Unknown(raw_code)`.

SQLite may allocate while converting a result to `TEXT` or `BLOB`. Both adapters check that conversion immediately and raise `SqliteError(code=NoMem, ...)` when SQLite attributes a new allocation failure to it, rather than returning an empty value. Genuine empty values and SQL `NULL` retain SQLite's typed conversion behavior; request `Value` when they must be distinguished.

## Development and Verification

This repository uses the standard MoonBit workflow:

```bash
moon check
moon test
moon info
moon fmt
```

Because this README is written as `README.mbt.md`, its `mbt check` code blocks are included in the test suite. If you update the examples, rerun `moon test` to verify that the documentation still matches the actual behavior.
