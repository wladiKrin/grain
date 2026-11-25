# Releasing Grain

## Release command

```
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
```

The APKs land in `build/app/outputs/flutter-apk/`. Keep `build/symbols/` of
every build you ship: `flutter symbolize` needs it to read that build's stack
traces.

With `--split-per-abi` Flutter adds `1000 * abi` to the version code, so
versionCode 1 becomes `1001` (armeabi-v7a), `2001` (arm64-v8a) and `4001`
(x86_64) in the three APKs. Bump `version:` in `pubspec.yaml` (and `appVersion`
in `lib/version.dart`) for each release, and add
`fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`, where
`<versionCode>` is the number after the `+` in `pubspec.yaml`.

## Signing

Without `android/key.properties` the release build is signed with the debug
key, so it installs but must not be distributed as a signed release. Releases
you publish yourself use your own keystore.

Create a keystore once:

```
keytool -genkeypair -v -keystore ~/grain-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias grain
```

Create `android/key.properties`:

```
storeFile=/home/you/grain-release.jks
storePassword=…
keyAlias=grain
keyPassword=…
```

`android/key.properties` and `*.jks` / `*.keystore` are gitignored. Never
commit them.

**Back up the keystore and its passwords somewhere safe and offline.** Android
only installs an update that is signed with the same key as the installed app;
if you lose the keystore, every existing install has to be uninstalled before a
new build can be installed.

Check which key signed an APK:

```
$ANDROID_HOME/build-tools/<version>/apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## Unsigned build (F-Droid, reproducibility checks)

`android/gradlew` and the Gradle wrapper jar are not in the repository (Flutter's
default `.gitignore`); Flutter writes them, with `android/local.properties`, on
its first Gradle build. On a fresh clone, run this once first:

```
flutter build apk --release
```

Then:

```
cd android && GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease
```

`GRAIN_UNSIGNED=1` takes precedence over `key.properties`. The output is
`build/app/outputs/apk/release/app-release-unsigned.apk`; F-Droid signs it with
its own key.

This plain Gradle build is not the same build as the published APKs: it passes
none of `--split-per-abi`, `--obfuscate` and `--split-debug-info`, so it is one
universal, unobfuscated APK. Do not compare it with the published split APKs.
Compare like with like: two plain Gradle builds, or a Gradle build with the
same options as the release command,
`GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease -Psplit-per-abi=true -Pdart-obfuscation=true -Psplit-debug-info="$PWD/../build/symbols"` (an absolute path).

## Reproducible builds

- Flutter is pinned to 3.50.1; build with exactly that version.
- `ndkVersion` comes from Flutter, so the NDK follows the Flutter version.
- SQLite is vendored (`third_party/`) and compiled from source; the build
  needs no download for it.
- Build with `--split-debug-info=build/symbols --obfuscate`.
- Build from a clean checkout, in the same absolute path each time (paths can
  end up in native binaries).
- To compare, do two clean builds (`flutter clean` between them, or two fresh
  checkouts at the same path) and compare the APKs, for example with
  `diffoscope`, or the unsigned APKs with `cmp`.

## F-Droid notes

- The build needs no network apart from pub and Gradle dependency resolution.
- Store text and the icon live in `fastlane/metadata/android/en-US/`
  (`title.txt`, `short_description.txt`, `full_description.txt`,
  `changelogs/<versionCode>.txt`, `images/icon.png`).
- Build the unsigned release with `GRAIN_UNSIGNED=1` as above.
- The app has no ads, no tracking and no Google Play Services.
- The app requests `INTERNET` only for the map's online tiles, loaded only
  with an online map style chosen in Settings > Map or on the map (the
  default style is Offline): tiles.openfreemap.org (Streets, Minimal;
  vector tiles drawn in the app by `vector_map_tiles`, OpenMapTiles schema
  under CC-BY 4.0, data © OpenStreetMap contributors under the ODbL),
  tile.openstreetmap.org (Standard, Muted) or opentopomap.org
  (Topographic). Every request names Grain in its User-Agent; at most two
  connections go to a raster server and four to OpenFreeMap. The tiles
  are cached on the phone (at most 50 MB raster, 40 MB vector, plus the
  OpenFreeMap style files) and nothing is fetched ahead. The meter and
  everything else work without the network; the offline map is drawn from
  bundled Natural Earth data (public domain, `assets/map/`, reproduced by
  `tool/basemap/`).
- `tool/icon/icon.svg` is the source of the store icon:
  `rsvg-convert -w 512 -h 512 tool/icon/icon.svg -o fastlane/metadata/android/en-US/images/icon.png`.

### Reproducibility spot check (2026-11-21)

Two release builds of the same tree with the documented command, with
`flutter clean` between them, in the same path. The arm64 APKs were compared
after extraction: every entry was byte-identical (`diff -rq` of the two
extracted trees is empty), including `lib/arm64-v8a/libapp.so`
(sha256 `7d61b774...1a52`) and `lib/arm64-v8a/libsqlite3.so`
(sha256 `bed1fbe8...8df5`). The APK files themselves differ in their sha256
(same size, 21,262,803 bytes); the cause was not investigated (zip container
metadata or the signature are the likely places), and no entry differs. Compare unsigned APKs for a bit-exact check; that was not done here.
