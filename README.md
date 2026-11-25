# Grain

Grain is a free, open-source lightmeter for film photographers on Android
(iOS is not built yet). It meters with the phone camera, changes any value with
one swipe, knows your actual cameras and lenses, and keeps a frame-by-frame log
of each roll. There is no paywall, no ads and no tracking.

## Features

- One-swipe dials: one value per detent, in your camera's steps (full, half or
  third stops), with haptic feedback.
- Average metering over what the lens sees (centre-weighted) and spot metering
  (tap the preview).
- Aperture priority, shutter priority and manual modes, plus a free mode with
  no gear restrictions.
- Viewfinder crop.
- Histogram with film latitude markers.
- Gear library (bundled community bodies and lenses, your own profiles,
  favourites) and QR sharing of profiles.
- Rolls and a frame log with a reference snapshot per frame.
- CSV, JSON and zip export of rolls, and backup and restore.
- A map of where frames and readings were logged (with Save location on),
  drawn from bundled Natural Earth outlines.
- Works offline: no ads, no tracking, no Google Play Services. The meter never
  uses the network. The app holds the INTERNET permission only for the map's
  optional online tiles, and goes online only with an online map style
  chosen (Settings > Map, or the map's layers button); the default style is
  Offline. The styles load tiles from one of tiles.openfreemap.org
  (Streets, Minimal: OpenFreeMap vector tiles drawn in the app),
  tile.openstreetmap.org (Standard, Muted) or opentopomap.org
  (Topographic), and nothing else.

## Screenshots

To be added after the first device session.

## Build and run from source

You need:

- Flutter 3.50.1 (stable)
- JDK 17
- The Android SDK (platform 36 or 37, build-tools, platform-tools and the NDK
  that `flutter doctor` asks for; Gradle installs a missing NDK itself once the
  licences are accepted)
- A C compiler on the host (SQLite is compiled from the vendored source in
  `third_party/sqlite/`, also for the host tests)

Accept the Android licences with `flutter doctor --android-licenses` and check
`flutter doctor`.

The maintainer keeps a user-space toolchain in an environment script,
`~/.grain-env.sh`. You do not have that file; write your own with the paths of
your installation, for example:

```
export JAVA_HOME="$HOME/.local/jdk-17"
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$HOME/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

Source it in every shell (`source ~/my-grain-env.sh`), then:

```
flutter pub get
flutter run
```

## Tests

```
flutter test
flutter analyze
cd android && ./gradlew :app:testDebugUnitTest
```

`android/gradlew` is not in the repository; Flutter writes it on its first
Gradle build. On a fresh clone, run `flutter build apk --release` once before
the Gradle command.

The checks that need a real phone (camera, haptics, sharing) are listed in
`docs/testing/device-test-script.md`, one ordered session with an expected result
and a box to tick for each step; there is no automated device test.

## Release build

```
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Without `android/key.properties` this is debug-signed, which is fine for your
own phone. Signing, the unsigned F-Droid build and reproducibility notes are in
[docs/release.md](docs/release.md).

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

- Code: GPLv3, see [LICENSE](LICENSE).
- Gear library (`library/`): CC0 1.0, see `library/LICENSE`.
- Inter Tight font subset: SIL Open Font License, see `assets/fonts/OFL.txt`.
- SQLite (vendored in `third_party/sqlite/`): public domain.

### Third-party notices

The APK also contains code under other licences. The app shows all of these
notices under Settings > Licences.

- ZXing core 3.5.4 (`com.google.zxing:core`, QR code decoding): Apache
  License 2.0. The full text is in `assets/licenses/apache-2.0.txt`.
- The Flutter engine and framework and the pub packages (BSD, MIT and Apache
  2.0 licences): Flutter collects their notices into the build.
- Inter Tight: SIL Open Font License 1.1 (`assets/licenses/ofl-1.1.txt`).
- SQLite: public domain (`assets/licenses/sqlite.txt`).
- The gear library: CC0 1.0 (`assets/licenses/cc0-1.0.txt`).

The source will be at <https://github.com/wladiKrin/grain>.
