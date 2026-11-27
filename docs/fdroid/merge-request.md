<!--
Description for the fdroiddata merge request "New app: Grain".
Filled in from fdroiddata's .gitlab/merge_request_templates/Default.md
(the "New App" template; the "Closes rfp#" line is left out, there is no
RFP issue). Paste everything below the line into the MR.
-->

---

## Abstract for new app inclusion

### Please introduce the functions and usage of your app in summary, and also attach some screenshots.

Grain is a light meter and roll log for film photographers. It meters through
the phone camera (average, centre-weighted, or spot by tapping the preview) and
gives aperture, shutter speed and ISO in aperture priority, shutter priority,
manual and free modes. Each dial moves one value per swipe detent, in the steps
the user's camera uses (full, half or third stops). A bundled library of camera
bodies and lenses (CC0) limits the dials to what the user's own gear can set.
Rolls are logged frame by frame with settings, notes, a small reference
snapshot and optionally the location; rolls export as CSV/JSON (plus a zip of
the snapshots), and all data can be backed up and restored. Logged frames can
be shown on a map drawn by MapLibre Native: a built-in offline map by default,
or an online style if the user picks one.

Screenshots (demo data):

| | | |
|---|---|---|
| ![Meter, dark](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/1-meter_dark.png) | ![Meter, light](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/2-meter_light.png) | ![Roll](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/3-roll.png) |
| ![Map](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/4-map.png) | ![Map styles](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/5-styles.png) | ![Gear library](https://raw.githubusercontent.com/wladiKrin/grain/v1.0.0/docs/screenshots/6-library.png) |

### Please elaborate why you wrote this app. Please highlight the unique functions it provides over other similar apps in F-Droid.

I shoot film and wanted one app that both meters and logs the roll, without an
account, ads, a paywall or Google Play Services. Compared with other light
meters on F-Droid, Grain:

- runs its own exposure loop on the camera instead of trusting the phone's
  auto-exposure, so dim scenes read true;
- knows the user's actual cameras and lenses (bundled CC0 library plus own
  profiles, shareable as QR code or file) and offers only the values they can set;
- keeps a per-frame roll log (a camera per frame, skip/insert/edit frames,
  snapshots, location) with CSV/JSON export and full backup/restore;
- shows a viewfinder crop for the film format and a histogram with the film's latitude.

## Checklist

### Policy

* [x] The app complies with the [inclusion policy](https://f-droid.org/docs/Inclusion_Policy). _Pay special attention to Quality point 6._
  GPL-3.0-only, no ads, no tracking, no Google Play Services. SQLite is built
  from the vendored amalgamation (`third_party/sqlite`, public domain) through
  the `sqlite3` package's build hook, not downloaded. MapLibre Native for
  Android (BSD-2) and OkHttp (Apache-2.0) come as FLOSS artifacts from Maven
  Central. `maplibre_gl.playServicesLocation=false` keeps
  `com.google.android.gms` out of the build; the recipe also deletes the
  plugin's Play Services source and dependency lines in `prebuild` (as other
  maplibre_gl apps here do), because the scanner reads them regardless.
  The built APKs have no `com/google/android/gms` classes.
* [x] The original app author has been notified (and does not oppose the inclusion). I am the author.
* [x] The upstream app source code repo contains the app metadata in a [Fastlane](https://gitlab.com/snippets/1895688) or [Triple-T](https://gitlab.com/snippets/1901490) folder structure. The summary and description must be included and images, icon, and changelog should also be provided for better user experience. The `en-US` locale must be included.
  `fastlane/metadata/android/en-US/`: title, short and full description,
  icon and changelog `1.txt`. Screenshots are not in the Fastlane folder at
  `v1.0.0`; they are in `docs/screenshots/` (linked above).

### Docs

* [x] Please read [the guide](https://gitlab.com/fdroid/fdroiddata/-/blob/master/CONTRIBUTING.md) first if this is your first contribution.
* [x] Please make sure your metadata follows the best practice in [our templates](https://gitlab.com/fdroid/fdroiddata/tree/master/templates).
* [x] Please read the [Build Metadata Reference](https://f-droid.org/docs/Build_Metadata_Reference/) and make sure your metadata is valid.
* [x] Please read the [Quick Start Guide](https://f-droid.org/en/docs/Submitting_to_F-Droid_Quick_Start_Guide/).

### Merge Request Setup

* [x] The title of this merge request should follow "New app: app name" format.
* [x] Please make sure your fdroiddata fork is public and your branch is not protected. See <https://docs.gitlab.com/user/project/repository/branches/protected/>.
* [x] Please read [our Git guide](https://gitlab.com/fdroid/wiki/-/wikis/Tips-for-fdroiddata-contributors/Git-Usage) if you don't know how to rebase your branch. Don't rebase your branch if there is no conflict.
* [x] All related [fdroiddata](https://gitlab.com/fdroid/fdroiddata/issues) and [RFP issues](https://gitlab.com/fdroid/rfp/issues) have been referenced in this merge request. There are none.
* [x] Please only submit one app in one MR.

### Metadata

* [x] Metadata must be put in `metadata/<applicationId>.yml`.
* [x] Metadata must be a valid YAML file.
* [x] Metadata must use LF as line ending.
* [x] Don't add summary/description/changelog/images or anything that should be provided in upstream repo. Please check the Changes tab to make sure there is no other unrelated files added in the MR.
* [x] Releases are tagged and auto update is enabled unless there is a special reason.
  Tags `v*`; `UpdateCheckData` reads `version:` from `pubspec.yaml`.
* [x] There is an issue tracker and contact info of the author so that we can report bugs and contact the author.
* [x] An AuthorName must be added. It doesn't need to be the real name.
* [x] External repos are added as git submodules instead of srclibs. You can update git submodules without opening an MR in this repo and the submodule is covered by our scanner.
  No external repos apart from the Flutter SDK, which uses the standard
  `flutter` srclib pinned to the version the app is built with (3.50.1).
* [x] Enable [Reproducible Builds](https://f-droid.org/docs/Reproducible_Builds). We'll use your signature for improved security/reliability, also allowing users to switch between different channels. Do note that if you don't enable reproducible build then the apk will be signed with our key so you can't enable it later. If you can't enable this, please add the reasons here.
  Enabled: each build has `binary:` (the GitHub release asset
  `grain-%v-<abi>.apk`) and the app has `AllowedAPKSigningKeys`. The
  release APKs are no longer obfuscated, and are built in
  `registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie` with the
  recipe's own commands at F-Droid's paths (`tool/release/build_release.sh`
  in the repo), then signed. Checked locally on 2026-11-27: `fdroid build`
  with a throwaway-signed `binary` reported all three builds as matching
  the reference binary (its signature copied onto F-Droid's build verifies),
  and the unsigned APKs are byte-identical (`cmp`). The first release built
  this way is 1.0.1 (versionCodes 5001, 5002, 5004); the build entries will
  move to it once it is tagged and its APKs are on GitHub.
* [x] Setup abi split if the APK is large and the splitted ones can be much smaller.
  Three builds with `--split-per-abi`, versionCode = build number * 1000 +
  ABI (armeabi-v7a 1, arm64-v8a 2, x86_64 4), set in
  `android/app/build.gradle.kts`, mapped by `VercodeOperation`
  (`%c * 1000 + 1`, `+ 2`, `+ 4`).
* [x] Only the latest versions should be kept in the metadata before it's merged. If you update the metadata, please replace the old versions with the new ones.
* [x] Don't add any disabled versions in the metadata.
* [x] The `commit` field should be the full hash. Please don't use tag or branch in commit.
  Full hashes. They still point at `v1.0.0` until 1.0.1 is tagged (see
  above).

### Pipeline

* [ ] All pipelines should pass.
  (Tick once the MR pipeline is green.) Locally, in
  `registry.gitlab.com/fdroid/fdroidserver:buildserver-trixie` following this
  repo's `fdroid build` CI job: on 2026-11-26 `fdroid build` passed for
  v1.0.0 (then 1001, 2001 and 4001), `fdroid scanner` passed on the three
  APKs, and `fdroid lint`, `fdroid rewritemeta` (no changes) and
  `fdroid checkupdates --allow-dirty` (up to date) had no findings; on
  2026-11-27 `fdroid build` of the current source with `binary` and
  `AllowedAPKSigningKeys` passed the reproducibility check for 1001, 1002
  and 1004, and `fdroid lint` and `rewritemeta` passed on this recipe.
  `scanignore: assets/map/basemap.bin` is the bundled offline map, binary
  data made from public-domain Natural Earth by `tool/basemap/` in the repo.
  The remaining scanner warnings are devtools Roboto fonts inside the
  `drift` and `shared_preferences` packages in `.pub-cache`, not in the app.
* [ ] All warnings and errors in the Reports tab should be fixed or explained.
* [x] F-Droid CI runners are under GitLab's FOSS program, so there's no need for you to pay for any CI time. If Gitlab starts asking for phone numbers or credit cards don't submit anything, just leave a note in the MR so we know we need to trigger the CI.

### Anti-features

None expected. The app has no ads, no tracking, no non-free dependencies and
no non-free network services. `INTERNET` is used only for the optional online
map styles, which are off by default (the default map style is a bundled
offline map). When the user picks one, tiles come from free services:
OpenFreeMap (tiles.openfreemap.org), OpenStreetMap (tile.openstreetmap.org)
and OpenTopoMap (opentopomap.org). Permissions: `CAMERA` (metering),
`ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` (optional location per
frame), `INTERNET` (optional online map), plus AndroidX's own
`DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. MapLibre's
`ACCESS_NETWORK_STATE` and `ACCESS_WIFI_STATE` are removed in the manifest.

---------------------

/label ~"New App"
