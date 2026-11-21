# SQLite amalgamation (vendored)

Grain builds SQLite from these sources instead of downloading a prebuilt
`libsqlite3.so` (F-Droid builds must not use prebuilt binaries or fetch
anything). `pubspec.yaml` points the `package:sqlite3` build hook here with
`hooks: user_defines: sqlite3: source: source`.

- Version: 3.54.1 (see `VERSION`)
- Source: <https://sqlite.org/2026/sqlite-amalgamation-3540100.zip>, listed on
  <https://sqlite.org/download.html>
- SHA3-256 of the zip file itself (not of its contents), as published on the
  download page and checked on download:
  `92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30`
- Files taken from the zip unchanged: `sqlite3.c`, `sqlite3.h`,
  `sqlite3ext.h` (`shell.c` is not needed). Their SHA3-256, so a checkout
  can be verified without downloading the zip again:

  | File | SHA3-256 |
  |---|---|
  | `sqlite3.c` | `e2b869d3003b33c942b7dd7063604fbc53553e1b66609570df39b9b7b558ee81` |
  | `sqlite3.h` | `15ef3f5dbc4a7a980f828fa0d1e473cee5a124e7bb77e9bc70fc0bfa3f9a2af8` |
  | `sqlite3ext.h` | `5e113c4c0442f2f1b3345d44cbe4b82fad45f2fc0c35f0ed4eef27fb8f1cb394` |

  Check them from this directory with
  `for f in sqlite3.c sqlite3.h sqlite3ext.h; do python3 -c "import hashlib,sys;print(hashlib.sha3_256(open(sys.argv[1],'rb').read()).hexdigest(), sys.argv[1])" $f; done`

## Licence

SQLite is in the public domain: <https://sqlite.org/copyright.html>. No
licence file is required.

## Updating

1. Pick the newest release on <https://sqlite.org/download.html> that the
   resolved `package:sqlite3` version supports (its CHANGELOG names the
   SQLite version it bundles).
2. Download `sqlite-amalgamation-<NNNNNNN>.zip` into an empty scratch
   directory and compare its SHA3-256 with the one on the download page:
   `python3 -c "import hashlib,sys;print(hashlib.sha3_256(open(sys.argv[1],'rb').read()).hexdigest())" <zip>`
3. Copy `sqlite3.c`, `sqlite3.h` and `sqlite3ext.h` here, write the new
   version to `VERSION`, and update the URL, the zip hash and the three file
   hashes above.
4. `rm -rf .dart_tool/hooks_runner/shared/sqlite3` and run
   `flutter test test/release` (it checks that the loaded SQLite reports the
   version in `VERSION`).
