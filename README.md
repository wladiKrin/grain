# Grain

Grain is an open-source film lightmeter for Android (iOS to follow). It helps
film photographers read exposure with their phone and set aperture, shutter
speed and ISO. It is free software with no proprietary dependencies and no
network access.

## Toolchain

Install JDK 17, the Flutter stable SDK
(<https://docs.flutter.dev/get-started/install>) and the Android SDK
(command-line tools, platform-tools, a current platform and build-tools), then
accept licences with `flutter doctor --android-licenses` and check
`flutter doctor`.

On the maintainer's machine, `source ~/.grain-env.sh` sets up the user-space
toolchain (JDK 17, Android SDK, Flutter at `~/flutter`).

## Run and test

```
flutter run
flutter test
```

## Install from APK

```
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`--split-debug-info` keeps the Dart symbols out of the APK (about 1 MB
smaller). Keep `build/symbols/` of a build you ship: `flutter symbolize`
needs it to read that build's stack traces.

## Contributing gear

Every camera body and every lens is one JSON file, in the format described by
`library/schema/gear-1.schema.json`.

- Bodies go in `library/bodies/<make>/<id>.json`, where `<make>` is the make in
  lower case with spaces replaced by `-` (for example `library/bodies/canon/canon-a1.json`).
- Lenses go in `library/lenses/<mount>/<id>.json`, where `<mount>` is the
  lens mount id (for example `library/lenses/canon-fd/canon-fd-50-1.8.json`).
- The file name is the `id` plus `.json`. Ids are unique and use only
  `a-z`, `0-9`, `.` and `-`.
- Use the manufacturer's specifications: real shutter speeds (including B or
  T), ISO range, maximum and minimum aperture and zoom breakpoints.
- Every new directory needs an entry under `flutter: assets:` in `pubspec.yaml`.
- Run `flutter test test/library` to check your files against the schema and
  the layout rules. CI runs the same check.

All files in `library/` are dedicated to the public domain under CC0 1.0, see
`library/LICENSE`. By contributing you agree to that.

## Licence

GPLv3, see [LICENSE](LICENSE). The bundled Inter Tight font is licensed under
the SIL Open Font License, see `assets/fonts/OFL.txt`.
