# Grain on-device test script

One ordered session for the first run on a real phone.

- Device: Pixel 10.
- Build: the release APK, built with the release command below.
- Record each result in the last column as `✓` or `✗` plus a note, and tick the
  box. Numbers to fill in are marked `____`.
- Rows with `—` as the expected result are notes to read, not checks.

## Setup

1. On the phone: Settings > About phone, tap Build number seven times, then
   Settings > System > Developer options > turn on USB debugging.
2. Connect the phone by USB and accept the "Allow USB debugging" prompt.
3. On the computer (with `~/.grain-env.sh` or your own environment sourced):

```
adb devices            # the phone is listed as "device", not "unauthorized"
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Logs. Native camera code logs under the tag `GrainCamera`; Dart logs via
`debugPrint`, which shows under the tag `flutter`:

```
adb logcat -c
adb logcat -s flutter GrainCamera
```

Package name: `io.github.wladikrin.grain`.

## Build facts (recorded on the build host, 2026-11-21)

| Fact | Value |
|---|---|
| Release APK sizes (final, `--split-per-abi`) | arm64-v8a 21,262,803 bytes (21.3 MB), armeabi-v7a 19,175,397 bytes (19.2 MB), x86_64 22,592,796 bytes (22.6 MB) |
| arm64 size history | plan 2: 20,475,232 bytes (20.5 MB; 21,524,542 bytes without `--split-debug-info --obfuscate` and cupertino_icons dropped; 19.1 MB before share_plus / file_selector / qr_flutter); plan 3: 22,262,896 bytes (22.3 MB); plan 4 before Task 8: 22,345,232; after Task 8: 21,265,732 |
| Size limit | Plan target "< 20 MB" (~20): the total stays above it, accepted: what remains is `libflutter.so` (11.3 MB) and `libapp.so` (7.0 MB) |
| Task 8 size levers | `libsqlite3.so` 1,749,952 → 1,153,752 bytes (vendored 3.54.1, `-Os`, gc-sections); 4 × `InterTight-*.ttf` 1,231,268 → 294,756 bytes stored (subsets) |
| Permissions (`aapt2 dump permissions`) | `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, plus the app's own non-network `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no `INTERNET` |
| Play Services / Firebase | 0 `com/google/android/gms` or `com/google/firebase` matches in the dex files |
| Reproducibility | two clean builds: every APK entry byte-identical, incl. `libapp.so` and `libsqlite3.so`; see `docs/release.md` |
| Offline source build | SQLite built from source with no network (verified on the host in a network namespace) |
| Host verification | `flutter test` 584 passed, `flutter analyze` clean, `./gradlew :app:testDebugUnitTest` passed, Drift codegen produced no diff |

## 1. Install and first launch

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 1.1 | Install over an existing Task 8 build if one is on the phone (`adb install -r`), then open the app | The app opens existing rolls and gear with no database error after the SQLite switch | |
| 1.2 | Open the app for the first time (or after "Clear storage") | An "Allow camera" prompt appears and works; after allowing, the preview starts | |
| 1.3 | Deny the camera prompt twice | The prompt then leads to the settings ("Open settings") | |
| 1.4 | Check the release (R8 minified) build | The minified release APK starts the camera and the permission flow works (no R8-stripped classes) | |
| 1.5 | Rotate the phone | The meter stays in portrait | |
| 1.6 | Switch the system to dark mode and launch | No black launch flash; dark status bar icons on the paper ground | |
| 1.7 | Look at the viewfinder | The preview is upright (not rotated) | |
| 1.8 | Check which lens is chosen | The ~26 mm main camera | |
| 1.9 | Cold start, five times: `adb shell am force-stop io.github.wladikrin.grain && adb logcat -c && adb shell am start -W io.github.wladikrin.grain/.MainActivity`; read `TotalTime`, then `adb logcat -d -v time \| grep -E "ActivityTaskManager.*(START\|Displayed)\|GRAIN first EV"`. Time to first EV = `GRAIN first EV` timestamp minus the `START` timestamp. Record the median | Cold start to first EV value <= 1.5 s; the meter is up in 1.5 s or less with the library and database loaded. Runs (TotalTime / first EV, ms): 1 ____ / ____, 2 ____ / ____, 3 ____ / ____, 4 ____ / ____, 5 ____ / ____, median ____ / ____ | |
| 1.10 | Same cold start with an active roll of 72 frames (see 7.x to build one); read `TotalTime` and `adb logcat -d \| grep Displayed` (startup loads settings, gear library, snapshot dir, gear and rolls in parallel) | The meter is up in 1.5 s or less; TotalTime ____ ms | |

## 2. Metering accuracy and calibration against a reference meter

Reference: a camera's meter or a known handheld meter, same ISO, same
aperture, read as EV at ISO 100. Take both readings at the same spot, within a
minute. Set the calibration offset once (on the first scene) so the average
reading matches the reference, then keep it for all scenes.

Acceptable: difference <= 2/3 stop after the single calibration offset.

Calibration offset used: ______ EV

- [ ] Done: calibration offset set once and recorded.

| # | Action | Expected | Result |
|---|---|---|---|
| 2.1 | Sunny exterior: Reference EV ____, Grain average EV ____, Grain spot EV ____ | Average and spot differ from the reference by <= 2/3 stop (avg diff ____, spot diff ____) | |
| 2.2 | Open shade: Reference EV ____, Grain average EV ____, Grain spot EV ____ | Same, <= 2/3 stop (avg diff ____, spot diff ____) | |
| 2.3 | Bright interior: Reference EV ____, Grain average EV ____, Grain spot EV ____ | Same, <= 2/3 stop (avg diff ____, spot diff ____) | |
| 2.4 | Dim interior: Reference EV ____, Grain average EV ____, Grain spot EV ____ | Same, <= 2/3 stop (avg diff ____, spot diff ____) | |
| 2.5 | Backlit subject: Reference EV ____, Grain average EV ____, Grain spot EV ____ | Same, <= 2/3 stop (avg diff ____, spot diff ____) | |
| 2.6 | Change the scene brightness (cover the lens, point at a window) | EV values react when the scene brightness changes | |
| 2.7 | Count stats events over 10 s (`debugPrint` count or the DevTools timeline), at 30 and 60 fps | <= 15 events/s, no stalls | |
| 2.8 | Meter the same scene on this build and on the plan-2 build (METER reader now at preview size, sparser luma sampling) | Stats still ~15/s; EV unchanged within ±⅙ EV | |
| 2.9 | Tap a spot in Manual mode with the viewfinder on | The spot lands where tapped; the ring and ticks are clearly visible, not a dot | |
| 2.10 | Tap in the dimmed area outside the crop | The spot lands on the crop edge | |
| 2.11 | On a phone that reports no aperture (if available), read the EV line | It reads "EV ≈..." (f/1.8 assumed) | |

If spot readings look compressed (a bright or dark spot reads closer to the
average than the reference meter says), the preview tone curve may not be the
sRGB curve the luma linearization assumes. Try forcing it in the capture
request: `TONEMAP_MODE_GAMMA_VALUE` with gamma 2.2, or
`TONEMAP_MODE_PRESET_CURVE` with `TONEMAP_PRESET_CURVE_SRGB`.

## 3. Dials, haptics, click sound

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 3.1 | Turn the dials | Haptic ticks are strong on full stops | |
| 3.2 | Look at the value row with the viewfinder hidden | 92 px numerals do not overflow on the Pixel's width | |
| 3.3 | Enable Click sound in Settings, turn the aperture dial | A soft click per detent, louder on full stops | |
| 3.4 | Click sound on, swipe the dials fast (compare with click off) | Haptics stay crisp, no lag | |
| 3.5 | Enable Click sound, turn a dial at once | Note only: the first detent right after enabling may be silent (the sound loads asynchronously) | |
| 3.6 | Ringer on silent, click sound on | Note whether the click follows (expected: system-sound volume rules) | |
| 3.7 | Click sound off, `adb shell dumpsys media.audio_flinger \| grep -i soundpool` | No Grain track | |
| 3.8 | Drag the dials with Settings > Developer options > Profile GPU rendering > "On screen as bars" on (or `flutter run --profile` and DevTools Performance) | Bars stay under the 16 ms line; no jank frames while dragging the dials. Result: ______ | |
| 3.9 | Check fractions on the dials and value row | Fractions ⅓/⅔ look consistent; −, ≈, ▲ ▼, → render | |
| 3.10 | Compare the fonts | Fonts look unchanged (Light/Regular/Medium/SemiBold); ½ stops render | |

## 4. Viewfinder, crops, ultra-wide, spot, hold, histogram

Look for the path the ultra-wide detection took:

```
adb logcat -c
adb logcat -s GrainCamera
```

Look for `ultra-wide: zoom ratio ...` (main logical camera zooms out with
`CONTROL_ZOOM_RATIO`), `ultra-wide: separate camera ...` (the session reopens
on another camera id) or `ultra-wide: none`.

Path that ran: ______  Main eq. focal: ______ mm  Ultra-wide eq. focal: ______ mm

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 4.1 | Set the focal dial to 50 mm and compare the crop to the real view | The crop matches a 50 mm framing | |
| 4.2 | Turn the focal dial below the main camera's eq. focal | The ultra-wide engages; the preview visibly widens | |
| 4.3 | Turn back above the main camera's eq. focal | The main camera returns | |
| 4.4 | Cross the threshold back and forth on the focal dial | No visible stall or black frame (separate-camera path: a short reopen is acceptable, no hang) | |
| 4.5 | Separate-camera path only (no hysteresis yet): dial the focal back and forth across the main camera's eq. focal (e.g. 24 ↔ 28 mm on a 25 mm main camera) about ten times | Each crossing reopens the camera; the black gap and delay are tolerable and nothing hangs or ends on the wrong camera. Gap length ____ ms; if annoying, hysteresis goes into a later plan | |
| 4.6 | Set a wide focal, press Home, return | The ultra-wide is in use again | |
| 4.7 | Leave the meter screen or background the app right while the ultra-wide is switching (separate-camera path) | The camera indicator goes off and stays off | |
| 4.8 | Sunny exterior, same spot or average mode, main then ultra-wide within a minute: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.9 | Bright interior, same method: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.10 | Dim interior, same method: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.11 | Histogram on, pan from a window to a dark room | The bars move ~15×/s, no dial jank | |
| 4.12 | Histogram on with an active slide roll, mid-grey subject | The band is narrow, about a third of the panel | |
| 4.13 | Histogram on, tap Hold, pan away | The histogram freezes with the held reading | |
| 4.14 | `adb shell top -H -p $(adb shell pidof io.github.wladikrin.grain)` with the histogram on, then off | GrainCamera thread CPU is the same | |
| 4.15 | Same `top -H` while metering, this build vs the plan-2 build | GrainCamera CPU about the same (preview-size YUV reader + `samplingStep`) | |

## 5. Shake warning

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 5.1 | Shake warning on, 50 mm, shutter priority 1/30 | A quiet hand mark (secondary grey, not accent) beside SHUTTER | |
| 5.2 | Same at 1/60 | The mark is gone | |
| 5.3 | 6x7 body with a 90 mm lens | The mark appears at 1/60 | |

## 6. Gear library, favorites, editors, QR and file share, import

Make a second phone show QR codes (a body, a kit with "Share with lenses", the
largest kit) for the scan rows.

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 6.1 | Tap the lens chip repeatedly | It cycles favorite lenses and feels instant | |
| 6.2 | At 360 px width (display size set small), look at the header and chips with the longest bundled names (e.g. "Zoom-Nikkor 35-105/3.5-4.5 AI-S") | They fit without overflow | |
| 6.3 | 360 x 800 phone, Manual mode, viewfinder on, no roll | Nothing overflows; the numerals step down to their smallest and the viewfinder is small but usable (about 90 px) | |
| 6.4 | Open the library, a lens picker, an editor or settings | The camera indicator goes off; back on the meter the preview returns within about a second | |
| 6.5 | Library > Import > Scan QR code while the library is open | It still scans, and the meter preview comes back only after leaving the library | |
| 6.6 | Library > Share on a body | The system share sheet opens with `<id>.json`; a messaging app receives a readable JSON file | |
| 6.7 | Save the shared file to Files / Downloads | It works and the content is the pretty-printed profile | |
| 6.8 | Import > From file, pick that file; then import it again | "Import <body>?" dialog, snackbar "Imported ...", the body is listed and starred; importing again adds no duplicate | |
| 6.9 | Import > Scan QR code on a body QR shown on another phone | The code is read in <= 2 s; the confirmation appears and the preview closes | |
| 6.10 | Scan a "Share with lenses" kit QR | "Import <body> and N lenses?" | |
| 6.11 | Scan the largest kit QR the app will show (error correction L, ~2953 bytes) | The code is read | |
| 6.12 | Scan a single-body QR in a dim interior | It still reads | |
| 6.13 | Scan a URL QR (non-Grain) | "Not a Grain profile" for about 2 s and scanning continues; nothing is imported | |
| 6.14 | Leave the scan screen with back | Returns to the meter and the viewfinder preview comes back, no stuck camera indicator | |
| 6.15 | Home (or lock) while the scan screen is open, then return | The camera indicator goes off; coming back reopens the scan preview and a code still scans | |
| 6.16 | Leave the scan screen (or background) while a code is in view | The camera indicator goes off without a noticeable delay from a running decode | |

## 7. Rolls: start, log, snapshots, location, edit, body change

For rows that need a roll of 72 frames (1.10) or 40+ frames with snapshots,
log them rapidly once here.

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 7.1 | Start a roll; log a frame | The new frame number shows with no visible delay (at most one frame); the snapshot and location arrive later without blocking | |
| 7.2 | Log a frame at 35 mm, then at 50 mm (portrait) | A snapshot appears within ~1 s, upright, matching the viewfinder crop of that lens | |
| 7.3 | Hide the viewfinder and log a frame | A snapshot is still saved | |
| 7.4 | `adb shell run-as io.github.wladikrin.grain ls -l files/snapshots` | Each file 60–120 KB, long edge ≤ 1000 px | |
| 7.5 | Log 10 frames rapidly | 10 snapshot files; the dial stays smooth | |
| 7.6 | Swipe the dials while a snapshot encodes | No new jank | |
| 7.7 | `adb shell top -H -p $(adb shell pidof io.github.wladikrin.grain)` after a log | GrainSnapshot is busy only briefly after a log | |
| 7.8 | Open the phone's gallery app | No Grain snapshots appear there | |
| 7.9 | Log a frame, press Home at once, return | The snapshot still attaches to that frame on return | |
| 7.10 | Note: the activity is portrait-locked; snapshots are rotated by sensor orientation only, so a frame logged with the phone held landscape is stored sideways (by design for now; device orientation/EXIF is later work) | — | |
| 7.11 | At 360 px width, with a roll at frame 37/36 +1 and a Delta 3200 · 3200 → 12800 film | "Roll 12 · frame 37/36 +1" and "Delta 3200 · 3200 → 12800" fit the header without overflow; the Log button, rolls button and Start roll link fit | |
| 7.12 | Tap Log frame twice quickly | The Undo snack bar floats above the button and never covers it; both frames log | |
| 7.13 | Settings: turn Save location on | System dialog offers precise / approximate; refuse → switch stays off with "Location permission was not granted." | |
| 7.14 | Location on: log a frame | A fix is attached within 10 s (indoors: the last known fix) | |
| 7.15 | Airplane mode + GPS off, location on: log a frame | The frame logs with no location and no delay | |
| 7.16 | Revoke the location permission in system settings, log a frame | Logging still works, no location | |
| 7.17 | Roll editor: type in the film stock field with the keyboard up | The autocomplete suggestion overlay is not hidden by the keyboard and stays tappable | |
| 7.18 | Frame editor: open the date and the time pickers | The real system pickers open, accept a choice, and the frame shows the chosen wall-clock date and time | |
| 7.19 | Roll with 40 frames, each with a snapshot: scroll the roll view quickly | Thumbnails appear without stutter; no visible jank | |
| 7.20 | Rolls screen with several rolls and 40+ saved readings with snapshots: scroll both tabs | Smooth scrolling; Active tag and frame counts (e.g. 12/36) are right | |
| 7.21 | Meter: tap the Rolls button | The Rolls screen opens; no camera indicator while it is open; the meter preview returns on going back | |
| 7.22 | Saved reading: edit the note, press back, reopen; then "Remove location" and "Delete snapshot" | The note is kept; both work and the thumbnail disappears from the list | |
| 7.23 | Edit, insert, delete and renumber frames in a roll; change the body on a roll | Frames renumber correctly and the roll shows the new body | |
| 7.24 | Start the import of a backup containing an active roll and start a roll in the seconds it runs (see 8.5) | One active roll afterwards | |

## 8. Export roll, export/import everything, auto-backup restore

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 8.1 | Export a roll with snapshots, share to Files and to a messaging app | Both receive roll-N-<film>.csv, .json and -snapshots.zip; the sheet closes after sharing | |
| 8.2 | Open the CSV in LibreOffice and in Excel | Umlauts intact; a note with commas, quotes or line breaks stays in one cell; date_time shows the time the frame was logged | |
| 8.3 | Open the snapshots zip | One JPEG per frame that has a snapshot, named frame-<number>.jpg | |
| 8.4 | Export a roll of 200+ frames with snapshots | The sheet stays responsive while the zip is built | |
| 8.5 | Settings > Export everything with >= 100 snapshots on the phone | The share sheet offers grain-backup-<date>.zip; time taken ____ s; no jank while it is built; memory stays stable (Android Studio profiler) | |
| 8.6 | Import that zip on a second phone (or after "Clear storage") | Same rolls, frames, saved readings, own gear and favorites; every thumbnail shows | |
| 8.7 | Import the same zip again | "Added 0 rolls, 0 saved readings, 0 profiles. Skipped N already on this phone." and nothing is duplicated | |
| 8.8 | Import with a roll active on this phone | The imported active roll is listed as finished; the roll here stays active | |
| 8.9 | Pick a file that is not a zip (e.g. a photo or a text file) | "Can't import" with "Not a Grain backup"; nothing changes | |
| 8.10 | Import with "Use the settings from the file" ticked | Haptics, viewfinder default and snapshots follow the file; calibration and location stay as they were | |
| 8.11 | Pick the backup from a cloud provider (Drive) instead of local storage | Import works (the file is copied, streamed, before reading) | |
| 8.12 | Create a roll, log and edit a frame, export the roll (CSV and backup zip) on the current build | All work | |
| 8.13 | `adb shell bmgr backupnow io.github.wladikrin.grain`, uninstall, reinstall from the same signing key, `adb shell bmgr restore` | Rolls, readings, profiles and settings are back; thumbnails show placeholders | |
| 8.14 | `adb shell run-as io.github.wladikrin.grain ls files/snapshots` after the restore | Empty (snapshots are not backed up) | |

## 9. Settings and permissions (blocked flows)

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 9.1 | Deny the camera twice, then tap "Open settings"; grant the camera there and come back | The preview starts with no restart | |
| 9.2 | Block the location permission, then in Settings turn Save location on | The snackbar offers "Open settings"; grant there, return, and the Save location switch can be turned on | |

## 10. Lifecycle and the camera indicator

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 10.1 | Background the meter, then foreground it | The camera stops on background and starts on foreground | |
| 10.2 | Open the library, press Home, wait 5 s, return | No camera indicator while away; the meter preview returns after leaving the library | |
| 10.3 | Open a QR scan (library > Import > Scan QR code), press Home, wait 5 s, return | No camera indicator while away; the scan preview returns; the meter preview returns after closing the scan and the library | |

## 11. Performance

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 11.1 | Drag the dials with the histogram on | No jank (see 3.8, 4.11) | |
| 11.2 | Compare GrainCamera CPU with the histogram on and off | The same (see 4.14) | |
| 11.3 | Log frames while watching the dials | Logging feels instant (see 7.1, 7.5) | |

## 12. Icon, themed icon, version, size, release / F-Droid build

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 12.1 | Look at the launcher icon on the Pixel home screen | Paper ground, ink aperture disc, red dot in the middle | |
| 12.2 | Switch themed icons on (Settings, Wallpaper & style) | The icon becomes the monochrome aperture, tinted by the wallpaper | |
| 12.3 | App info | Shows version 1.0.0 | |
| 12.4 | `ls -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | 21,262,803 bytes as in Build facts (accepted above the plan's ~20 MB) | |
| 12.5 | `$ANDROID_HOME/build-tools/*/aapt2 dump permissions` on the APK | CAMERA, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION and DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION only; no INTERNET | |
| 12.6 | `unzip -p <apk> 'classes*.dex' \| grep -a -c -e 'com/google/android/gms' -e 'com/google/firebase'` | `0` | |
| 12.7 | Unsigned F-Droid build: `cd android && GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease`, install the signed result of your own key | Builds and runs like the release APK (see `docs/release.md`) | |
