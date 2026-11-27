# Releasing Grain

## Release command

```
flutter build apk --release --split-per-abi
```

The APKs land in `build/app/outputs/flutter-apk/`. The release is not
obfuscated (no `--obfuscate`, no `--split-debug-info`): Grain is FLOSS, so
obfuscation gains nothing, and F-Droid's reproducible build compares with a
plain build. This command is for your own phone; the APKs you publish come
from `tool/release/build_release.sh` (see "Release flow").

### versionCode

Each split APK gets `versionCode = N * 1000 + abi`, where `N` is the number
after the `+` in `pubspec.yaml` and `abi` is 1 (armeabi-v7a), 2 (arm64-v8a)
or 4 (x86_64): the ABI comes last, as F-Droid asks. `1.0.0+1` gives `1001`,
`1002` and `1004`; `1.0.1+5` gives `5001`, `5002` and `5004`. A build without
`--split-per-abi` (one universal APK) gets `N * 1000`. This replaces Flutter's
own split scheme (`1000 * abi + N`, which gave v1.0.0 its `1001`, `2001`
and `4001`): `android/app/build.gradle.kts` sets each output's versionCode in
an `androidComponents.onVariants` callback, which runs after Flutter's and
wins. `test/release/version_code_test.dart` checks that the Gradle file and
the F-Droid recipe (versionCodes, `VercodeOperation`) agree.

To check the APKs themselves:

```
for a in armeabi-v7a arm64-v8a x86_64; do
  $ANDROID_HOME/build-tools/<version>/aapt2 dump badging build/app/outputs/flutter-apk/app-$a-release.apk | head -1
done
```

For `1.0.0+1` this prints `versionCode='1001'`, `'1002'` and `'1004'`
(checked 2026-11-27; with `--build-number=5`: `5001`, `5002`, `5004`, and
`5000` for the universal APK).

`N` must only grow. v1.0.0's APKs had up to `4001`, so the next release,
1.0.1, uses `N = 5` (`version: 1.0.1+5`: `5001`, `5002`, `5004`, all above
`4001`), and later releases count on from there.

Bump `version:` in `pubspec.yaml` (and `appVersion` in `lib/version.dart`)
for each release, and add the release's "What's new" text as
`fastlane/metadata/android/en-US/changelogs/<code>.txt` for each of the three
APK version codes, `N * 1000 + 1`, `+ 2` and `+ 4` (for `1.0.1+5`:
`5001.txt`, `5002.txt` and `5004.txt`, the same text; at most 500
characters). F-Droid shows the file for the versionCode it built.
`changelogs/1.txt` is the 1.0.0 text from before this rule; F-Droid shows no
changelog for 1.0.0.

Phone screenshots for F-Droid are in
`fastlane/metadata/android/en-US/images/phoneScreenshots/` (1080 px wide,
status and navigation bars cropped, demo data only; see
`tool/demo/demo_backup_test.dart`). F-Droid reads the store metadata from the
tagged source, so changes show from the next release.

## Release flow

The published APKs are built in F-Droid's buildserver image, the same way
F-Droid builds them, so that F-Droid can verify its own build against them
and ship them with your signature (see "Reproducible builds").

1. Set `version: X.Y.Z+N` in `pubspec.yaml` and `appVersion` in
   `lib/version.dart`, and add the three changelog files. Commit, then tag:
   `git tag vX.Y.Z`. The script takes the build commands from
   `docs/fdroid/io.github.wladikrin.grain.yml` at the tag, so that file's
   `srclibs`, `prebuild`, `build` and `output` must be the ones in
   fdroiddata (its versionCodes and commit are not used).
2. Build and sign (needs docker and `android/key.properties`):

   ```
   source ~/.grain-env.sh          # or any ANDROID_HOME with build-tools
   tool/release/build_release.sh vX.Y.Z
   ```

   It builds every build entry of the recipe as it is at the tag, in
   `registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie`
   (`tool/release/container_build.sh`): a clean checkout of the tag at
   `/home/vagrant/build/io.github.wladikrin.grain`, Flutter cloned at its
   tag to `/home/vagrant/build/srclib/flutter`, the recipe's own `prebuild`
   and `build` commands as user `vagrant` with fdroid's environment
   (`SOURCE_DATE_EPOCH` from the commit, `PUB_CACHE` in the source tree,
   `GRADLE_USER_HOME=/home/vagrant/.gradle`, `LC_ALL=C.UTF-8`, ...). Then, on
   the host, it checks that each unsigned APK is already zipaligned and signs
   it with `apksigner` and the key from `android/key.properties` (the script
   reads the file itself; passwords go to `apksigner` through environment
   variables, not the command line). It prints each APK's certificate
   SHA-256 and warns if it is not the recipe's `AllowedAPKSigningKeys`.
   About 15 to 25 minutes; the container is removed afterwards.

   Output in `build/release/vX.Y.Z/`: `grain-X.Y.Z-armeabi-v7a.apk`,
   `grain-X.Y.Z-arm64-v8a.apk` and `grain-X.Y.Z-x86_64.apk` (signed), and
   the unsigned ones in `unsigned/`. Options: a second argument onwards
   limits the ABIs (`tool/release/build_release.sh vX.Y.Z arm64-v8a`);
   `GRAIN_KEY_PROPERTIES=<file>` uses another properties file,
   `GRAIN_NO_SIGN=1` only builds, `GRAIN_FDROID_IMAGE` picks another image.
3. Push the tag and create the GitHub release `vX.Y.Z` with the three signed
   APKs as assets, under exactly those names: the recipe's `binary` field is
   `https://github.com/wladiKrin/grain/releases/download/v%v/grain-%v-<abi>.apk`.
4. F-Droid's checkupdates adds the new builds on its own once the app is in;
   until then, update the merge request's recipe (versionName, versionCode,
   the tag's full commit hash, `CurrentVersion`, `CurrentVersionCode`).
   F-Droid builds each APK, downloads the `binary`, copies its signature onto
   its own build and verifies it (`fdroid build` fails if anything differs);
   it then publishes your signed APK. Never re-sign or replace an uploaded
   asset afterwards.

The recipe's `AllowedAPKSigningKeys` is the SHA-256 of the release
certificate (`apksigner verify --print-certs <apk>`, "Signer #1 certificate
SHA-256 digest"): `352354f74e0d21a00e3c89721545c3f021f41d573e2a9a5394b2840ddc4410b0`.

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

F-Droid publishes the APKs you sign, after checking that its own build of the
same commit is byte-identical apart from the signature (`binary` and
`AllowedAPKSigningKeys` in the recipe;
https://f-droid.org/docs/Reproducible_Builds/). What makes that work:

- `tool/release/build_release.sh` builds in F-Droid's buildserver image, at
  F-Droid's source path (`/home/vagrant/build/io.github.wladikrin.grain`),
  with Flutter at F-Droid's srclib path
  (`/home/vagrant/build/srclib/flutter`), the same `PUB_CACHE`
  (`.pub-cache` in the source tree) and the same commands and
  environment. The source path ends up in the APK: the Dart snapshot
  (`lib/<abi>/libapp.so`) contains
  `file:///home/vagrant/build/io.github.wladikrin.grain/.dart_tool/flutter_build/dart_plugin_registrant.dart`,
  so a build in any other directory differs. (The SQLite library compiled
  through the `sqlite3` build hook and the other native libraries contain no
  build paths.)
- Flutter is pinned (the recipe's `flutter@3.50.1` srclib; the script
  clones the same tag); the Flutter engine, the NDK (`ndkVersion` comes from
  Flutter, installed by the Android Gradle plugin), the Gradle wrapper and
  every Gradle and pub dependency are pinned by version (`pubspec.lock`,
  `--enforce-lockfile`).
- SQLite is vendored (`third_party/`) and compiled from source.
- No `--obfuscate` and no `--split-debug-info`.
- Each ABI is its own build from a clean checkout, as F-Droid builds it.
- F-Droid copies the signature onto its own unsigned build, so the signed
  APK must be exactly the unsigned one plus an APK Signing Block. The
  unsigned APKs are already zipaligned (the script checks that zipalign
  leaves them unchanged), and the script signs with
  `apksigner sign --alignment-preserved true --v1-signing-enabled false
  --v2-signing-enabled true --v3-signing-enabled true` and then checks
  that only the signing block was added. `apksigner`'s defaults do not work
  here: it re-aligns the stored entries (`--alignment-preserved false`) and
  adds v1 files under `META-INF/`, and F-Droid's copy of that signature then
  fails to verify (seen on 2026-11-27). minSdk 29 needs no v1 signature.

To check a build yourself, compare the unsigned APKs, for example
`cmp build/release/vX.Y.Z/unsigned/grain-X.Y.Z-arm64-v8a.apk <F-Droid's unsigned APK>`
or `diffoscope` for the differences. "Submitting to F-Droid", "Local test",
shows how to run F-Droid's own check.

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

## Submitting to F-Droid

The recipe is `docs/fdroid/io.github.wladikrin.grain.yml`; the merge-request
text is `docs/fdroid/merge-request.md`. F-Droid builds from the tag's full
commit hash, checks its build against the developer-signed APK at `binary`
and ships that APK, signed with your key (`AllowedAPKSigningKeys`). Three
APKs: armeabi-v7a (`N * 1000 + 1`), arm64-v8a (`+ 2`), x86_64 (`+ 4`).

The recipe's build entries still name v1.0.0 (commit `ea8f76cd`), with the
new versionCodes 1001, 1002 and 1004. v1.0.0 predates the versionCode scheme
(its APKs are 1001, 2001 and 4001) and its GitHub APKs are obfuscated, so
these entries do not build or verify as they stand. The first reproducible
release is 1.0.1 with build number 5: once `v1.0.1` is tagged and its APKs
are on GitHub (see "Release flow"), set the three entries to
`versionName: 1.0.1`, versionCodes 5001, 5002 and 5004, and the tag's full
commit hash, and `CurrentVersion: 1.0.1`, `CurrentVersionCode: 5004`.

What the recipe does, and why:

- `flutter@3.50.1` srclib. No `sudo`: the buildserver image already has
  JDK 21, which the build needs.
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
  (`%c * 1000 + 1`, `+ 2`, `+ 4`) maps the build number to the three
  versionCodes.
- `binary`: the signed GitHub release asset of that ABI,
  `https://github.com/wladiKrin/grain/releases/download/v%v/grain-%v-<abi>.apk`
  (`%v` is the versionName). `AllowedAPKSigningKeys`: the SHA-256 of the
  release certificate. `fdroid rewritemeta` wraps the armeabi-v7a `binary`
  line, which is too long for one line; keep it that way.

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
  io.github.wladikrin.grain:<code> ...          # the recipe's three versionCodes
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

### Reproducibility check (before tagging)

`fdroid build` with `binary` does what F-Droid's server will do: it builds,
downloads the reference APK, copies its signature onto its own build and
verifies it, and fails with a diffoscope report if anything differs. To run
it on a commit before tagging, use a test recipe for the local repository,
the APKs from `tool/release/build_release.sh` signed with a throwaway key,
and a local HTTPS server (fdroid downloads `binary` over https only;
`serve.sh`). From the Grain repository root, after committing:

```
W=/tmp/grain-fdroid; K=$W/key; mkdir -p $W/out $K
keytool -genkeypair -keystore $K/test.jks -storetype PKCS12 -storepass testpass \
  -keypass testpass -alias test -keyalg RSA -keysize 2048 -validity 1000 -dname CN=test
printf 'storeFile=%s\nstorePassword=testpass\nkeyAlias=test\nkeyPassword=testpass\n' \
  $K/test.jks > $K/test.properties
GRAIN_KEY_PROPERTIES=$K/test.properties GRAIN_RELEASE_OUT=$W/release \
  tool/release/build_release.sh                 # (a) prints the test certificate's SHA-256
TESTCERT=<that SHA-256>

git clone --depth 1 https://gitlab.com/fdroid/fdroiddata.git $W/fdroiddata
sed -e '/^#/d' -e 's|^Repo: .*|Repo: /grain-repo|' -e "s|commit: .*|commit: $(git rev-parse HEAD)|" \
  -e 's|https://github.com/wladiKrin/grain/releases/download/v%v/|https://localhost:8443/|' \
  -e "s|^AllowedAPKSigningKeys: .*|AllowedAPKSigningKeys: $TESTCERT|" \
  docs/fdroid/io.github.wladikrin.grain.yml > $W/fdroiddata/metadata/io.github.wladikrin.grain.yml
# set the three versionCodes to the ones for pubspec.yaml's build number, if they differ

docker run -d --name grain-fdroid-build -v $W/fdroiddata:/src:ro \
  -v $PWD/docs/fdroid/local-test:/scripts:ro -v $W/out:/out \
  -v $PWD:/grain-repo:ro -v $W/release:/serve/apks:ro \
  registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie sleep infinity
docker exec grain-fdroid-build bash /scripts/setup.sh
docker exec -d grain-fdroid-build bash /scripts/serve.sh
docker exec -e REQUESTS_CA_BUNDLE=/tmp/serve/cert.pem grain-fdroid-build bash /scripts/build.sh \
  io.github.wladikrin.grain:1001 io.github.wladikrin.grain:1002 io.github.wladikrin.grain:1004   # (b)
docker cp grain-fdroid-build:/builds/fdroiddata/tmp $W/fdroid-apks
for a in 1001:armeabi-v7a 1002:arm64-v8a 1004:x86_64; do                                       # (c)
  cmp $W/fdroid-apks/io.github.wladikrin.grain_${a%:*}.apk $W/release/unsigned/grain-*-${a#*:}.apk \
    && echo "${a#*:} identical"
done
docker rm -f grain-fdroid-build
```

Each build must log "compared built binary to supplied reference binary
successfully" and "supplied reference binary has allowed signer", then
`BUILD OK`.

Result on 2026-11-27, commit `4e19f2a` (version 1.0.0+1 in `pubspec.yaml`,
so versionCodes 1001, 1002 and 1004), image
`registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie` (digest
`sha256:1ea8bef1...0dac`), fdroidserver `fa7b54e` (CI pins `a35fdfdd`
and pulls forward):

- (a) `build_release.sh` built the three APKs twice, in two fresh
  containers, with identical results (unsigned SHA-256: armeabi-v7a
  `018f7d66...e1a8`, arm64-v8a `a5e410b1...5fb4`, x86_64 `361dd975...9ae8`).
- (b) `fdroid build` of 1001, 1002 and 1004 with the throwaway-signed
  `binary`: each logged "compared built binary to supplied reference binary
  successfully" and "supplied reference binary has allowed signer", then
  `BUILD OK`. F-Droid's unsigned APKs had the same SHA-256 as in (a).
- (c) `cmp`: F-Droid's unsigned APKs and the script's are byte-identical,
  all three ABIs. `aapt2 dump badging` on F-Droid's APKs shows
  versionCode 1001, 1002 and 1004.

The first attempt failed only at the signature copy: the unsigned APKs were
already identical, but `apksigner`'s defaults had re-aligned the signed APK
and added v1 files (see "Reproducible builds"). Nothing in Grain's build had
to change for byte-identical output: building at F-Droid's paths with the
recipe's own commands was enough; no `-ffile-prefix-map`, timestamp or build
ID changes were needed.

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

For a new release, follow "Release flow": tag `vX.Y.Z` with a higher
`version: X.Y.Z+N` in `pubspec.yaml`, build and sign with
`tool/release/build_release.sh`, and upload the three APKs to the GitHub
release before F-Droid builds it; once the app is in, F-Droid's
checkupdates picks up the tag on its own and adds the three builds. F-Droid's
`fdroid update` takes the "What's new" text from
`changelogs/<versionCode>.txt` for a built versionCode (`N * 1000 + 1`,
`+ 2`, `+ 4`) or from `changelogs/default.txt`, so `changelogs/1.txt` is
not shown there; from the next release on, add the three per-ABI files (see
"versionCode").
