///|
pub(all) enum ErrorCode {
  Error
  Internal
  Perm
  Abort
  Busy
  Locked
  NoMem
  ReadOnly
  Interrupt
  IoErr
  Corrupt
  NotFound
  Full
  CantOpen
  Protocol
  Empty
  Schema
  TooBig
  Constraint
  Mismatch
  Misuse
  NoLfs
  Auth
  Format
  Range
  NotADb
  Notice
  Warning
  Unknown(Int)
} derive(Debug, Eq)

///|
pub(all) enum ExtendedCode {
  ErrorMissingCollSeq
  ErrorRetry
  ErrorSnapshot
  IoErrRead
  IoErrShortRead
  IoErrWrite
  IoErrFsync
  IoErrDirFsync
  IoErrTruncate
  IoErrFstat
  IoErrUnlock
  IoErrReadLock
  IoErrDelete
  IoErrBlocked
  IoErrNoMem
  IoErrAccess
  IoErrCheckReservedLock
  IoErrLock
  IoErrClose
  IoErrDirClose
  IoErrShmOpen
  IoErrShmSize
  IoErrShmLock
  IoErrShmMap
  IoErrSeek
  IoErrDeleteNoEntry
  IoErrMmap
  IoErrGetTempPath
  IoErrConvertPath
  IoErrVNode
  IoErrAuth
  IoErrBeginAtomic
  IoErrCommitAtomic
  IoErrRollbackAtomic
  IoErrData
  IoErrCorruptFs
  IoErrInPage
  LockedSharedCache
  LockedVTab
  BusyRecovery
  BusySnapshot
  BusyTimeout
  CantOpenNoTempDir
  CantOpenIsDir
  CantOpenFullPath
  CantOpenConvertPath
  CantOpenDirtyWal
  CantOpenSymlink
  CorruptVTab
  CorruptSequence
  CorruptIndex
  ReadOnlyRecovery
  ReadOnlyCantLock
  ReadOnlyRollback
  ReadOnlyDbMoved
  ReadOnlyCantInit
  ReadOnlyDirectory
  AbortRollback
  ConstraintCheck
  ConstraintCommitHook
  ConstraintForeignKey
  ConstraintFunction
  ConstraintNotNull
  ConstraintPrimaryKey
  ConstraintTrigger
  ConstraintUnique
  ConstraintVTab
  ConstraintRowId
  ConstraintPinned
  ConstraintDatatype
  NoticeRecoverWal
  NoticeRecoverRollback
  NoticeRbu
  WarningAutoIndex
  AuthUser
  Unknown(Int)
} derive(Debug, Eq)

///|
pub suberror SqliteError {
  SqliteError(code~ : ErrorCode, extended~ : ExtendedCode?, msg~ : String)
} derive(Debug, Eq)

///|
fn decode_error_code(raw_code : Int) -> ErrorCode {
  match raw_code & 0xFF {
    1 => Error
    2 => Internal
    3 => Perm
    4 => Abort
    5 => Busy
    6 => Locked
    7 => NoMem
    8 => ReadOnly
    9 => Interrupt
    10 => IoErr
    11 => Corrupt
    12 => NotFound
    13 => Full
    14 => CantOpen
    15 => Protocol
    16 => Empty
    17 => Schema
    18 => TooBig
    19 => Constraint
    20 => Mismatch
    21 => Misuse
    22 => NoLfs
    23 => Auth
    24 => Format
    25 => Range
    26 => NotADb
    27 => Notice
    28 => Warning
    code => Unknown(code)
  }
}

///|
fn decode_extended_code(raw_code : Int) -> ExtendedCode? {
  if raw_code == (raw_code & 0xFF) {
    return None
  }
  Some(
    match raw_code {
      257 => ErrorMissingCollSeq
      513 => ErrorRetry
      769 => ErrorSnapshot
      266 => IoErrRead
      522 => IoErrShortRead
      778 => IoErrWrite
      1034 => IoErrFsync
      1290 => IoErrDirFsync
      1546 => IoErrTruncate
      1802 => IoErrFstat
      2058 => IoErrUnlock
      2314 => IoErrReadLock
      2570 => IoErrDelete
      2826 => IoErrBlocked
      3082 => IoErrNoMem
      3338 => IoErrAccess
      3594 => IoErrCheckReservedLock
      3850 => IoErrLock
      4106 => IoErrClose
      4362 => IoErrDirClose
      4618 => IoErrShmOpen
      4874 => IoErrShmSize
      5130 => IoErrShmLock
      5386 => IoErrShmMap
      5642 => IoErrSeek
      5898 => IoErrDeleteNoEntry
      6154 => IoErrMmap
      6410 => IoErrGetTempPath
      6666 => IoErrConvertPath
      6922 => IoErrVNode
      7178 => IoErrAuth
      7434 => IoErrBeginAtomic
      7690 => IoErrCommitAtomic
      7946 => IoErrRollbackAtomic
      8202 => IoErrData
      8458 => IoErrCorruptFs
      8714 => IoErrInPage
      262 => LockedSharedCache
      518 => LockedVTab
      261 => BusyRecovery
      517 => BusySnapshot
      773 => BusyTimeout
      270 => CantOpenNoTempDir
      526 => CantOpenIsDir
      782 => CantOpenFullPath
      1038 => CantOpenConvertPath
      1294 => CantOpenDirtyWal
      1550 => CantOpenSymlink
      267 => CorruptVTab
      523 => CorruptSequence
      779 => CorruptIndex
      264 => ReadOnlyRecovery
      520 => ReadOnlyCantLock
      776 => ReadOnlyRollback
      1032 => ReadOnlyDbMoved
      1288 => ReadOnlyCantInit
      1544 => ReadOnlyDirectory
      516 => AbortRollback
      275 => ConstraintCheck
      531 => ConstraintCommitHook
      787 => ConstraintForeignKey
      1043 => ConstraintFunction
      1299 => ConstraintNotNull
      1555 => ConstraintPrimaryKey
      1811 => ConstraintTrigger
      2067 => ConstraintUnique
      2323 => ConstraintVTab
      2579 => ConstraintRowId
      2835 => ConstraintPinned
      3091 => ConstraintDatatype
      283 => NoticeRecoverWal
      539 => NoticeRecoverRollback
      795 => NoticeRbu
      284 => WarningAutoIndex
      279 => AuthUser
      code => Unknown(code)
    },
  )
}

///|
fn sqlite_error(raw_code : Int, message : String) -> SqliteError {
  SqliteError(
    code=decode_error_code(raw_code),
    extended=decode_extended_code(raw_code),
    msg=message,
  )
}

///|
fn sqlite_misuse(message : String) -> SqliteError {
  SqliteError(code=Misuse, extended=None, msg=message)
}
