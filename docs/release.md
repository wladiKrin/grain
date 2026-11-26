# Releasing Grain

## Release command

```
flutter build apk --release --split-per-abi
```

The APKs land in `build/app/outputs/flutter-apk/`. The release is not
obfuscated (no `--obfuscate`, no `--split-debug-info`): Grain is FLOSS, so
obfuscation gains nothing, and F-Droid's reproducible build compares with a
plain build.

With `--split-per-abi` Flutter adds `1000 * abi` to the version code, so
versionCode 1 becomes `1001` (armeabi-v7a), `2001` (arm64-v8a) and `4001`
(x86_64) in the three APKs. Bump `version:` in `pubspec.yaml` (and `appVersion`
in `lib/version.dart`) for each release, and add the release's "What's new"
text as `fastlane/metadata/android/en-US/changelogs/<code>.txt` for each of
the three APK version codes, `1000 + N`, `2000 + N` and `4000 + N`, where `N`
is the number after the `+` in `pubspec.yaml` (for `1.0.1+2`: `1002.txt`,
`2002.txt` and `4002.txt`, the same text; at most 500 characters). F-Droid
shows the file for the versionCode it built. `changelogs/1.txt` is the 1.0.0
text from before this rule; F-Droid shows no changelog for 1.0.0.

Phone screenshots for F-Droid are in
`fastlane/metadata/android/en-US/images/phoneScreenshots/` (1080 px wide,
status and navigation bars cropped, demo data only; see
`tool/demo/demo_backup_test.dart`). F-Droid reads the store metadata from the
tagged source, so changes show from the next release.

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

This plain Gradle build is not the same build as the published APKs: it does
not pass `--split-per-abi`, so it is one universal APK. Do not compare it with
the published split APKs.

## Reproducible builds

- Flutter is pinned to 3.50.1; build with exactly that version.
- `ndkVersion` comes from Flutter, so the NDK follows the Flutter version.
- SQLite is vendored (`third_party/`) and compiled from source; the build
  needs no download for it.
- No `--obfuscate` and no `--split-debug-info`.
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
- `docs/fdroid/io.github.wladikrin.grain.yml` is the fdroiddata recipe; it
  passed `fdroid build` locally (see "Submitting to F-Droid" below).
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

## Submitting to F-Droid

The recipe is `docs/fdroid/io.github.wladikrin.grain.yml`; the merge-request
text is `docs/fdroid/merge-request.md`. F-Droid builds from the tag's full
commit hash, signs with its own key (no `AllowedAPKSigningKeys`) and ships
three APKs: armeabi-v7a (1001), arm64-v8a (2001), x86_64 (4001).

What the recipe does, and why:

- `flutter@3.50.1` srclib and JDK 21 from apt (`sudo`), as the build needs.
- `flutter pub get --enforce-lockfile` into `.pub-cache` in the source tree,
  so the scanner sees every Dart package.
- maplibre_gl's Play Services code is deleted in `prebuild` (the
  `com.google.android.gms` lines of its `android/build.gradle` and its
  `android/src/gms`), as other fdroiddata Flutter recipes with maplibre_gl
  do. `maplibre_gl.playServicesLocation=false` already keeps it out of the
  build, but the scanner reads the files, not Gradle's conditions, and
  would fail on them.
- `scanignore: assets/map/basemap.bin`: the bundled offline map is binary
  data (Natural Earth, public domain, made by `tool/basemap/`), which the
  scanner would otherwise flag as an unknown binary.
- `scandelete: .pub-cache`: lets the scanner remove the binaries it flags in
  downloaded packages (gradle wrapper jars, test fixtures, devtools assets)
  instead of failing, the usual fdroiddata Flutter setting.
- `GRAIN_UNSIGNED=1` and `flutter build apk --release --split-per-abi
  --target-platform=android-<abi>`, one build per ABI. Update checks use
  tags `v*` and read `version:` from `pubspec.yaml`; `VercodeOperation`
  maps the build number to the three versionCodes.

### Local test

The scripts in `docs/fdroid/local-test/` follow fdroiddata's `.gitlab-ci.yml`
jobs (`fdroid build`, `check apk`, `fdroid lint`, `rewritemeta`,
`checkupdates`). They pin fdroidserver and fdroid-bootstrap-buildserver to
the commits that `.gitlab-ci.yml` pinned on 2026-11-26; take the current ones
from it when re-running. Run from the Grain repository root:

```
W=/tmp/grain-fdroid          # any scratch directory
mkdir -p $W/out
git clone --depth 1 https://gitlab.com/fdroid/fdroiddata.git $W/fdroiddata
cp docs/fdroid/io.github.wladikrin.grain.yml $W/fdroiddata/metadata/
sed -i '/^#/d' $W/fdroiddata/metadata/io.github.wladikrin.grain.yml

# fdroid lint, rewritemeta (must leave the file unchanged), checkupdates
docker run --rm --name grain-fdroid-static \
  -v $W/fdroiddata:/src:ro -v $PWD/docs/fdroid/local-test:/scripts:ro -v $W/out:/out \
  debian:trixie-slim bash /scripts/static.sh

# fdroid build for each versionCode, then fdroid scanner and APK checks
docker run -d --name grain-fdroid-build \
  -v $W/fdroiddata:/src:ro -v $PWD/docs/fdroid/local-test:/scripts:ro -v $W/out:/out \
  registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie sleep infinity
docker exec grain-fdroid-build bash /scripts/setup.sh
docker exec grain-fdroid-build bash /scripts/build.sh \
  io.github.wladikrin.grain:1001 io.github.wladikrin.grain:2001 io.github.wladikrin.grain:4001
docker exec grain-fdroid-build bash /scripts/checkapk.sh
docker cp grain-fdroid-build:/builds/fdroiddata/tmp $W/apks   # the unsigned APKs
docker rm -f grain-fdroid-build
```

Each build prints `BUILD OK <appid>:<versionCode>`; `checkapk.sh` prints
`scanner exit: 0`, the permissions and `gms classes in dex: 0` per APK. The
APKs are unsigned, so `apksigner` reports "DOES NOT VERIFY"; that is
expected. The buildserver image is about 2.4 GB; the build container grew
to about 11 GB, and each ABI took 3 to 5 minutes after the first-time setup
(Flutter SDK clone and Android SDK packages).

Result on 2026-11-26 (commit `ea8f76cd`, tag `v1.0.0`): all three builds and
the scanner passed; lint, rewritemeta and checkupdates had no findings. The
only scanner warnings are the devtools Roboto fonts inside the `drift` and
`shared_preferences` packages in `.pub-cache` (not part of the app). Each APK
asks for `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`,
`INTERNET` and AndroidX's `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, and has
no `com/google/android/gms` classes.

### Merge request

1. Fork https://gitlab.com/fdroid/fdroiddata on GitLab; keep the fork public
   and the branch unprotected.
2. On a new branch, add `metadata/io.github.wladikrin.grain.yml` (the recipe
   without its comment header), and nothing else. Commit as
   "New app: Grain".
3. Push the branch and open a merge request against `fdroid/fdroiddata`
   `master`, titled "New app: Grain", with the "Default" template; paste
   `docs/fdroid/merge-request.md` below its comment as the description.
4. Wait for the pipeline; fix or explain anything it or the Reports tab
   shows, then tick the Pipeline boxes. Answer reviewers in the MR.

For a new release: tag `vX.Y.Z` with a higher `version: X.Y.Z+N` in
`pubspec.yaml`; once the app is in, F-Droid's checkupdates picks up the tag
on its own and adds the three builds. F-Droid's `fdroid update` takes the "What's new"
text from `changelogs/<versionCode>.txt` for a built versionCode (1001, 2001,
4001; `CurrentVersionCode` is 4001) or from `changelogs/default.txt`, so
`changelogs/1.txt` is not shown there; from the next release on, add the
three per-ABI files (see "Release command").
