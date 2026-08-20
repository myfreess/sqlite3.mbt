- compile_flags.txt

```
-I/home/<user>/.moon/include
```

## Resource lifetime

SQLite connections and prepared statements use backend-specific opaque handles.
They are released only by explicit calls to `Connection::close()` and
`Statement::finalize()`; dropping the corresponding MoonBit values does not
release SQLite resources.

This is intentional. The WebAssembly host cannot observe MoonBit
reference-count release through a native free callback. Native-only finalizers
would therefore make resource lifetime depend on the selected backend: code
that accidentally omitted `close()` or `finalize()` could appear to work on
native while leaking on WebAssembly. Requiring explicit release gives every
backend the same contract.

Connections keep their optional handle in shared `Ref` state, while statements
use a mutable struct that also records current-row validity and retains the
originating connection for error-message capture. Copies therefore observe the
same closed or finalized state and cannot reuse a released raw handle.

## Native FFI adapters

Functions whose MoonBit native ABI already matches SQLite bind directly to the
corresponding `sqlite3_*` symbol. The C stub is reserved for actual adaptation:
reshaping open and prepare results, supplying omitted callback arguments, and
copying strings or blobs across the ownership boundary.

## Wasm FFI adapter

The Wasm adapter targets moonrun's `moonbitlang/sqlite` import ABI. Native
SQLite pointers never enter guest memory; moonrun owns them and returns typed
64-bit handles. SQL and text use MoonBit's UTF-16 storage directly, while
filenames and blobs use checked byte ranges. Variable-length results are
measured and copied into MoonBit-owned buffers during synchronous host calls.

Until these imports reach a released moonrun, build the known compatible
revision and select it with `MOONRUN_OVERRIDE`:

```bash
cargo +1.95.0 install --git https://github.com/moonbitlang/moon --rev ad3391f8452f8d72988e7ccc04f7cc6595ae882b --locked --root .moonrun --bin moonrun moonrun
MOONRUN_OVERRIDE="$PWD/.moonrun/bin/moonrun" moon test --target wasm
```

The pinned moonrun revision supports in-memory and policy-checked file-backed
databases. It uses `libsqlite3-sys` `0.38.2`, bundling SQLite `3.53.2`. File
access remains subject to the host runtime's filesystem policy.
