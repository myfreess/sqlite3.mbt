- compile_flags.txt

```
-I/home/<user>/.moon/include
```

## Resource lifetime

SQLite connections and prepared statements use `#external` handles. They are
released only by explicit calls to `Connection::close()` and
`Statement::finalize()`; dropping the corresponding MoonBit values does not
release SQLite resources.

This is intentional. Planned WebAssembly adapters cannot observe MoonBit
reference-count release through a native free callback. Native-only finalizers
would therefore make resource lifetime depend on the selected backend: code
that accidentally omitted `close()` or `finalize()` could appear to work on
native while leaking on WebAssembly. Requiring explicit release gives every
backend the same contract.

The shared `Ref[Option[handle]]` state is also intentional. It makes copies of
a `Connection` or `Statement` observe the same closed or finalized state and
prevents a raw handle from being used again after explicit release.

## Native FFI adapters

Functions whose MoonBit native ABI already matches SQLite bind directly to the
corresponding `sqlite3_*` symbol. The C stub is reserved for actual adaptation:
reshaping open and prepare results, supplying omitted callback arguments, and
copying strings or blobs across the ownership boundary.
