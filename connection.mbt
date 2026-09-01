///|
priv struct ConnectionState {
  mut database : @ffi.Sqlite3?
  mut executor : @ffi.Sqlite3Executor?
  mut jobs_in_flight : Int
}

///|
struct Connection(Ref[ConnectionState])

///|
fn create_executor() -> @ffi.Sqlite3Executor raise SqliteError {
  let rescode = Ref(SQLITE_OK)
  let executor = @ffi.sqlite3_executor_create(rescode)
  if rescode.val != SQLITE_OK {
    raise sqlite_error(
      rescode.val,
      "sqlite3: failed to start the asynchronous executor",
    )
  }
  executor
}

///|
fn Connection::from_open_database(
  database : @ffi.Sqlite3,
  executor : @ffi.Sqlite3Executor?,
) -> Connection {
  Connection(Ref({ database: Some(database), executor, jobs_in_flight: 0, }))
}

///|
fn Connection::ensure_no_jobs(self : Connection) -> Unit raise SqliteError {
  if self.0.val.jobs_in_flight != 0 {
    raise sqlite_misuse("sqlite3: asynchronous operations are running")
  }
}

///|
fn Connection::handle(self : Connection) -> @ffi.Sqlite3 raise SqliteError {
  match self.0.val.database {
    Some(db) => db
    None => raise sqlite_misuse("sqlite3: connection is closed")
  }
}

///|
fn Connection::begin_job(
  self : Connection,
) -> (@ffi.Sqlite3, @ffi.Sqlite3Executor) raise SqliteError {
  let state = self.0.val
  match state.database {
    Some(database) => {
      let executor = match state.executor {
        Some(executor) => executor
        None => {
          let executor = create_executor()
          state.executor = Some(executor)
          executor
        }
      }
      state.jobs_in_flight += 1
      (database, executor)
    }
    None => raise sqlite_misuse("sqlite3: connection is closed")
  }
}

///|
fn Connection::finish_job(self : Connection) -> Unit {
  self.0.val.jobs_in_flight -= 1
}

///|
fn Connection::error(self : Connection, raw_code : Int) -> SqliteError {
  match self.0.val.database {
    Some(db) => sqlite_error(raw_code, @ffi.sqlite3_errmsg(db))
    None => sqlite_error(raw_code, "sqlite3: database connection is closed")
  }
}

///|
const SQLITE_OPEN_READWRITE : Int = 0x00000002

///|
const SQLITE_OPEN_CREATE : Int = 0x00000004

///|
const SQLITE_OPEN_FULLMUTEX : Int = 0x00010000

///|
pub fn Connection::open(filename : String) -> Connection raise SqliteError {
  if filename.contains_code_unit(0x0000) {
    raise sqlite_misuse("sqlite3: filename contains a NUL code unit")
  }
  let filename = @utf8.encode(filename)
  let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
  let rescode = Ref(SQLITE_OK)
  let db = @ffi.sqlite3_open_v2(filename, flags, rescode)
  if rescode.val == SQLITE_OK {
    // Failed open handles are valid only for error retrieval and close. Keep
    // them local so every handle stored by Connection is ready for database
    // operations.
    return Connection::from_open_database(db, None)
  } else {
    let error = if @ffi.sqlite3_is_null(db) {
      sqlite_error(rescode.val, "sqlite3: failed to allocate a database handle")
    } else {
      sqlite_error(rescode.val, @ffi.sqlite3_errmsg(db))
    }
    let _ = @ffi.sqlite3_close(db)
    raise error
  }
}

///|
/// Return the number of rows changed by the most recently completed `INSERT`,
/// `UPDATE`, or `DELETE` on this connection.
pub fn Connection::changes(self : Connection) -> Int64 raise SqliteError {
  let database = self.handle()
  @ffi.sqlite3_db_mutex_enter(database)
  defer @ffi.sqlite3_db_mutex_leave(database)
  @ffi.sqlite3_changes64(database)
}

///|
pub fn Connection::close(self : Connection) -> Unit raise SqliteError {
  self.ensure_no_jobs()
  match self.0.val.database {
    None => ()
    Some(db) => {
      // A successful close destroys the connection mutex, so close cannot use
      // the deferred unlock pattern used by statement operations. Callers must
      // exclude outstanding worker operations before this lifecycle step.
      let rescode = @ffi.sqlite3_close(db)
      if rescode == SQLITE_OK {
        if self.0.val.executor is Some(executor) {
          @ffi.sqlite3_executor_release(executor)
          self.0.val.executor = None
        }
        self.0.val.database = None
      } else {
        raise self.error(rescode)
      }
    }
  }
}
