# SQLite3.mbt

`moonbit-community/sqlite3` is a lightweight, low-level SQLite3 binding for MoonBit. It exposes the core SQLite C API workflow for opening connections, preparing statements, binding parameters, stepping through results, and reading column values. It is intended for cases where you want a small and direct embedded database interface rather than an ORM or a full query framework.

This package supports the `native` and `wasm` targets. The native backend vendors the SQLite amalgamation source directly in the repository; the Wasm backend uses moonrun's `moonbitlang/sqlite` host imports. The bundled native SQLite version is `3.49.1`.

## Features

- Thin wrapper design with a small API surface that stays close to SQLite's native workflow.
- Support for prepared statements, positional parameter binding, and row-by-row result reading.
- Common SQLite result code constants exported for matching and diagnostics.
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
  create.step_once()
  create.finalize()

  let insert = conn.prepare(
    (
      #|INSERT INTO users (id, name, score) VALUES (?, ?, ?);
    ),
  )
  insert.bind(index=1, 1)
  insert.bind(index=2, "alice")
  insert.bind(index=3, 98.5)
  insert.step_once()
  insert.finalize()

  let query = conn.prepare(
    (
      #|SELECT id, name, score FROM users;
    ),
  )
  assert_true(query.step())
  let id : Int = query.column(index=0)
  let name : String = query.column(index=1)
  let score : Double = query.column(index=2)
  assert_eq(id, 1)
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
3. For statements that do not return rows, call `Statement::step_once()`.
4. For queries, call `Statement::step()` repeatedly. It returns `true` when a row is available and `false` when the result set is exhausted.
5. Use `Statement::column(index=...)` to read column values from the current row.
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
  create.step_once()
  create.finalize()

  let insert1 = conn.prepare(
    (
      #|INSERT INTO files (id, payload) VALUES (?, ?);
    ),
  )
  insert1.bind(index=1, 1)
  insert1.bind(index=2, b"abc")
  insert1.step_once()
  insert1.finalize()

  let insert2 = conn.prepare(
    (
      #|INSERT INTO files (id, payload) VALUES (?, ?);
    ),
  )
  insert2.bind(index=1, 2)
  insert2.bind(index=2, b"xyz")
  insert2.step_once()
  insert2.finalize()

  let query = conn.prepare(
    (
      #|SELECT id, payload FROM files ORDER BY id;
    ),
  )

  assert_true(query.step())
  let first_id : Int = query.column(index=0)
  let first_payload : Bytes = query.column(index=1)
  assert_eq(first_id, 1)
  assert_eq(first_payload, b"abc")

  assert_true(query.step())
  let second_id : Int = query.column(index=0)
  let second_payload : Bytes = query.column(index=1)
  assert_eq(second_id, 2)
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

  @test.assert_raise(() => conn.prepare("SELECT FROM"))

  assert_true(conn.get_errmsg().length() > 0)
  conn.close()
}
```

`SqliteError` currently wraps `(result_code, SourceLoc)`, so you can match on SQLite result codes while also retaining the call site for debugging.

## Public API Overview

### `Connection`

- `Connection::open(filename)`: open a database connection.
- `Connection::prepare(sql)`: create a prepared statement.
- `Connection::close()`: close the database connection.
- `Connection::get_errmsg()`: read the most recent error message from the connection.

### `Statement`

- `Statement::bind(index, value)`: bind a parameter. Parameter indexes start at `1`, matching the SQLite C API.
- `Statement::bind_null(index)`: bind SQL `NULL` to a parameter. This is separate from `bind` because `Bind` decides the SQLite type from the value it is handed, and `NULL` has no value to hand it.
- `Statement::step()`: execute one step. Query statements return `true` when a row is available and `false` when iteration is complete.
- `Statement::step_once()`: execute once and require that the statement produces no row. This is suitable for `CREATE`, `INSERT`, `UPDATE`, and `DELETE`. If the statement does return a row, it raises `SQLITE_ROW`.
- `Statement::column(index)`: read a column value from the current row. Column indexes start at `0`.
- `Statement::column_type(index)`: report the storage class of a column in the current row. Call it before reading the value: a `NULL` column read as an `Int` arrives as `0`, indistinguishable from a stored zero.
- `Statement::finalize()`: destroy the prepared statement and release its native resources.

### `Bind` and `Column`

The current public implementations support the following MoonBit types:

| MoonBit type | Bound as SQLite | Read from SQLite as |
| --- | --- | --- |
| `Int` | `INTEGER` | `Int` |
| `Int64` | `INTEGER` | `Int64` |
| `Double` | `REAL` | `Double` |
| `String` | `TEXT` | `String` |
| `Bytes` | `BLOB` | `Bytes` |

`NULL` is absent from this table because it is not a MoonBit type. Write it with `Statement::bind_null` and detect it with `Statement::column_type`.

### `ColumnType`

`Statement::column_type` reports SQLite's storage class for the value in the current row:

| `ColumnType` | SQLite storage class |
| --- | --- |
| `Integer` | `INTEGER` |
| `Float` | `REAL` |
| `Text` | `TEXT` |
| `Blob` | `BLOB` |
| `Null` | `NULL` |

A storage class describes the *value*, not the column's declared type: a column declared `INTEGER` reports `Text` if text is what was stored in it.

## Constraints and Notes

- This is a manual resource management API. Every `Statement` must be explicitly `finalize()`d, and every `Connection` must be explicitly `close()`d. Dropping these values does not release SQLite resources on any backend.
- The Wasm backend requires a runtime that provides the `moonbitlang/sqlite` imports. Filesystem access and SQL policy are enforced by the host runtime.
- The current public API does not expose `reset`, so a statement that has already been executed should generally be treated as a one-shot object. If you want to run it again, preparing a new statement is the simplest path.
- `Connection::prepare` accepts exactly one SQL statement. Empty input, comment-only input, and additional statements after the first one raise `SQLITE_MISUSE`; trailing whitespace, comments, and empty semicolons are allowed.
- Parameter indexes start at `1`, while column indexes start at `0`. It is easy to mix these up.
- SQL and `String` values cross both backend boundaries as UTF-16 code units. Native targets require little-endian UTF-16, while WebAssembly memory is little-endian by definition. SQLite converts text when the database file uses a different encoding. Use `Bytes` when the value is raw binary data rather than text.
- `Connection::open` uses `sqlite3_open_v2`, so a new database defaults to UTF-8. To select UTF-16LE or UTF-16BE storage, run `PRAGMA encoding` before creating any schema objects; this choice is independent of the native string API.
- `Statement::column_type` is only meaningful after `step` has returned `true`, and should be called before `column` reads the value: SQLite does not guarantee the reported type once a conversion has happened.
- The `SQLITE_INTEGER`, `SQLITE_FLOAT`, and `SQLITE_BLOB` constants are deprecated in favour of `ColumnType`. Nothing ever consumed them, which is why `SQLITE_BLOB` went unnoticed carrying the value 2 rather than 4.
- The package is intentionally focused on SQLite basics and does not add transaction wrappers, batch helpers, or named-parameter support.

## Result Code Constants

The package exports common SQLite result code constants, including:

- `SQLITE_OK`
- `SQLITE_ROW`
- `SQLITE_DONE`
- `SQLITE_ERROR`
- `SQLITE_BUSY`
- `SQLITE_MISUSE`
- `SQLITE_CONSTRAINT`
- `SQLITE_CANTOPEN`

These constants are useful for categorizing failures and producing clearer diagnostics in higher-level code.

## Development and Verification

This repository uses the standard MoonBit workflow:

```bash
moon check
moon test
moon info
moon fmt
```

Because this README is written as `README.mbt.md`, its `mbt check` code blocks are included in the test suite. If you update the examples, rerun `moon test` to verify that the documentation still matches the actual behavior.
