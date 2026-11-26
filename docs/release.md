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

Current keytool (JDK 9 and later) writes a PKCS12 keystore and asks for one
password only: the key uses the keystore's password, so `keyPassword` is the
same as `storePassword`.

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
- Prebuilt binaries: F-Droid's Inclusion Policy allows prebuilt FLOSS
  binaries from trusted Maven repositories, Maven Central among them
  (https://f-droid.org/docs/Inclusion_Policy/), which covers MapLibre's
  AAR and OkHttp; the Flutter SDK's own prebuilts are allowed too. A
  reviewer may still ask for MapLibre to be built from source: answer by
  pointing at the policy, or build it as a srclib.
- No anti-feature is expected: the online map styles use free services
  (OpenStreetMap, OpenFreeMap, OpenTopoMap), are off by default, and
  nothing is tracked.
- `docs/fdroid/io.github.wladikrin.grain.yml` is a draft recipe for
  fdroiddata: build it with fdroidserver first (it needs a `v1.0.0` tag,
  JDK 21 on the build server, and the release built unsigned; adjust the
  `output` path to the unsigned build if F-Droid signs it).
- The map is drawn by MapLibre Native for Android 13.7.1 (BSD-2, the
  `org.maplibre.gl:android-sdk-opengl` AAR from Maven Central, with a
  prebuilt `libmaplibre.so`) through the official `maplibre_gl` plugin
  0.28.1 (BSD-3). `android/gradle.properties` sets
  `maplibre_gl.playServicesLocation=false`, so nothing from Google is
  downloaded or compiled (0 `com/google/android/gms` in the dex files).
  MapLibre has no telemetry (no telemetry classes in the AAR or the dex;
  the plugin's telemetry calls are no-ops). The plugin's Android side is
  compiled for Java 21: build with JDK 21.
- MapLibre's manifest asks for `ACCESS_NETWORK_STATE` and
  `ACCESS_WIFI_STATE`; Grain removes both (`tools:node="remove"`), and tells
  MapLibre whether it is connected instead (`MapNetPlugin.kt`). The merged
  manifest has `CAMERA`, the two location permissions and `INTERNET`, plus
  AndroidX's own non-network `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`.
- The app requests `INTERNET` only for the map's online styles, loaded only
  with one chosen in Settings > Map or on the map (the default style is
  Offline: MapLibre is told it is offline, and the app's HTTP client refuses
  any request): tiles.openfreemap.org (Streets, Minimal; OpenFreeMap's
  vector styles, OpenMapTiles schema under CC-BY 4.0, data © OpenStreetMap
  contributors under the ODbL), tile.openstreetmap.org (Standard, Muted) or
  opentopomap.org (Topographic). Every request goes through Grain's OkHttp
  client, which names Grain in its User-Agent; at most two connections go
  to OpenStreetMap or OpenTopoMap and four to an OpenFreeMap host. MapLibre
  keeps what it loads in its own cache on the phone (its default ambient
  cache, about 50 MB) and fetches only what the screen needs. The meter
  and everything else work without the network; the offline map is drawn
  from bundled Natural Earth data (public domain, `assets/map/basemap.bin`,
  written once as GeoJSON to the app's cache directory) with bundled Noto
  Sans glyphs (OFL, `assets/map/glyphs/`), both reproduced by
  `tool/basemap/`.
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
