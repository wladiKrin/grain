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
| Release APK size (final, after the final-review fixes; `--split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate`) | arm64-v8a 21,338,033 bytes (21.3 MB). Before those fixes, with all three ABIs: arm64-v8a 21,262,803, armeabi-v7a 19,175,397 (19.2 MB), x86_64 22,592,796 (22.6 MB); the fixes add about 75 KB (licence texts, the Licences page, fraction spans) |
| arm64 size history | plan 2: 20,475,232 bytes (20.5 MB; 21,524,542 bytes without `--split-debug-info --obfuscate` and cupertino_icons dropped; 19.1 MB before share_plus / file_selector / qr_flutter); plan 3: 22,262,896 bytes (22.3 MB); plan 4 before Task 8: 22,345,232; after Task 8: 21,265,732; after Task 10: 21,262,803; final: 21,338,033 |
| Size limit | Plan target "< 20 MB" (~20): the total stays above it, accepted: what remains is `libflutter.so` (11.3 MB) and `libapp.so` (7.0 MB) |
| Task 8 size levers | `libsqlite3.so` 1,749,952 → 1,153,752 bytes (vendored 3.54.1, `-Os`, gc-sections); 4 × `InterTight-*.ttf` 1,231,268 → 294,756 bytes stored (subsets) |
| Permissions (`aapt2 dump permissions`) | `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, plus the app's own non-network `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no `INTERNET` |
| Play Services / Firebase | 0 `com/google/android/gms` or `com/google/firebase` matches in the dex files |
| Reproducibility | two clean builds: every APK entry byte-identical, incl. `libapp.so` and `libsqlite3.so`; see `docs/release.md` |
| Offline source build | SQLite built from source with no network (verified on the host in a network namespace) |
| Host verification (final tree) | `flutter test` 596 passed, `flutter analyze` clean, `./gradlew :app:testDebugUnitTest` 36 passed; Drift codegen produced no diff (Task 10) |

## 1. Install and first launch

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 1.1 | Upgrade from plan 3 (the only check of the v2→v3 database migration and the switch to vendored SQLite on real data). Build and install the plan-3 app as described below the table, make a roll with a few frames, a saved reading and an own lens, then build and `adb install -r` this build and open it | The roll, its frames, the saved reading and the own lens are all there; no database error | |
| 1.2 | Open the app for the first time (`adb shell pm clear io.github.wladikrin.grain` after 1.1), allow the camera | An "Allow camera" prompt appears and works; after allowing, the preview starts. This is the R8-minified release build, so a working camera and permission flow also shows R8 stripped nothing needed (denying twice is checked in 9.1) | |
| 1.3 | Rotate the phone | The meter stays in portrait | |
| 1.4 | Switch the system to dark mode and launch | No black launch flash; dark status bar icons on the paper ground | |
| 1.5 | Look at the viewfinder | The preview is upright (not rotated) | |
| 1.6 | Check which lens is chosen | The ~26 mm main camera | |
| 1.7 | Cold start, five times: `adb shell am force-stop io.github.wladikrin.grain && adb logcat -c && adb shell am start -W io.github.wladikrin.grain/.MainActivity`; read `TotalTime`, then `adb logcat -d -v time \| grep -E "ActivityTaskManager.*(START\|Displayed)\|GRAIN first EV"`. Time to first EV = `GRAIN first EV` timestamp minus the `START` timestamp. Record the median | Cold start to first EV value <= 1.5 s; the meter is up in 1.5 s or less with the library and database loaded. Runs (TotalTime / first EV, ms): 1 ____ / ____, 2 ____ / ____, 3 ____ / ____, 4 ____ / ____, 5 ____ / ____, median ____ / ____ | |

The plan-3 build for 1.1 (plan 3 is branch `feat/rolls`, commit `6600de4`).
Plan 3 signs its release build with the debug key. Without
`android/key.properties` this build does too, so `adb install -r` upgrades in
place; with a `key.properties`, move it aside for 1.1. If the Setup above
already installed this build, `adb uninstall io.github.wladikrin.grain` first
(an older build cannot install over a newer one). Start from a clean working
tree:

```
adb uninstall io.github.wladikrin.grain   # only if a Grain build is installed
git checkout feat/rolls
flutter clean
flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols-plan3 --obfuscate
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
# on the phone: make the roll, frames, saved reading and own lens
git checkout feat/polish
flutter clean
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

The plan-3 build fetches its prebuilt SQLite, so it needs the network once.
The cold start with a 72-frame roll is row 7.25, after step 7 has built that
roll.

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
| 2.7 | Count stats events over 10 s in the DevTools timeline (`flutter run --profile`), once in bright light and once in a dim room (the camera picks its own frame rate, usually 30 fps in dim light and up to 60 in bright light; note which it was if DevTools shows it) | <= 15 events/s in both, no stalls. Bright ____ /s, dim ____ /s | |
| 2.8 | Optional (needs a second phone, or an uninstall, because an older build cannot open this build's database): meter the same scene on this build and on the plan-2 build (branch `feat/gear`, built as in 1.1). The METER reader is now at preview size with sparser luma sampling | Stats still ~15/s; EV unchanged within ±⅙ EV | |
| 2.9 | Tap a spot in Manual mode with the viewfinder on | The spot lands where tapped; the ring and ticks are clearly visible, not a dot | |
| 2.10 | Tap in the dimmed area outside the crop | The spot lands on the crop edge | |
| 2.11 | On a phone that reports no aperture (if available), read the EV line | It reads "EV ≈..." (f/1.8 assumed) | |

If spot readings look compressed (a bright or dark spot reads closer to the
average than the reference meter says), the preview tone curve may not be the
sRGB curve the luma linearization assumes. Try forcing it in the capture
request: `TONEMAP_MODE_GAMMA_VALUE` with gamma 2.2, or
`TONEMAP_MODE_PRESET_CURVE` with `TONEMAP_PRESET_CURVE_SRGB`.

## 3. Dials, haptics, click sound

Click sound is off by default. Rows 3.3 to 3.6 turn it on in Settings >
Click sound; 3.7 turns it off again.

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 3.1 | Turn the dials | Haptic ticks are strong on full stops | |
| 3.2 | Look at the value row with the viewfinder hidden | 92 px numerals do not overflow on the Pixel's width | |
| 3.3 | Settings > Click sound on. Back on the meter, turn the aperture dial | A soft click per detent, louder on full stops | |
| 3.4 | Click sound on: swipe the dials fast. Then Settings > Click sound off and swipe them fast again | The haptics feel the same in both runs: crisp, no lag with the click on | |
| 3.5 | Click sound off; turn it on in Settings, go back and turn a dial at once | A click from the second detent on at the latest. The first detent right after turning it on may be silent (the sound loads asynchronously); that passes. No click after several detents fails | |
| 3.6 | Click sound on. Set the ringer to silent and turn a dial; then ringer on and turn it again | Silent ringer: no click (the click uses the system-sound rules, like touch sounds). Ringer on: clicks. Result: silent ____, ringer on ____ | |
| 3.7 | Settings > Click sound off, then `adb shell dumpsys media.audio_flinger \| grep -i soundpool` | No Grain track (the sound pool is released) | |
| 3.8 | Drag the dials with Settings > Developer options > Profile GPU rendering > "On screen as bars" on (or `flutter run --profile` and DevTools Performance) | Bars stay under the 16 ms line; no jank frames while dragging the dials. Result: ______ | |
| 3.9 | Look at thirds and halves on the calibration dial (Settings), the push dial and the two latitude dials (Start roll), and the manual-mode OFFSET readout | ⅓, ⅔ and ½ are all drawn as small Inter Tight fractions of the same weight and size (digits around a fraction slash, e.g. 2⁄3); the whole stop beside them (the 1 in −1⅓) is a normal-size digit; −, ≈, ▲ ▼, → render | |
| 3.10 | Compare the fonts | Fonts look unchanged (Light/Regular/Medium/SemiBold); ½ stops render | |
| 3.11 | Optional, needs a 360 dp-wide phone or `adb shell wm size 1080x2400 && adb shell wm density 480` (undo with `wm size reset` / `wm density reset`): viewfinder off, shutter priority, dial the shutter to 1/1000 | The faded neighbours beside the big shutter value (1/500, 1/2000) are readable, not cut off; note it if they are clipped | |
| 3.12 | Swipe a dial fast and let go; then fling it and touch it mid-spin | It keeps spinning, slows down and stops exactly on a value, ticking per value; a touch stops it at once. A slow drag still moves one value per detent | |

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
| 4.2 | Turn the focal dial down until the frame no longer fits the main camera's picture (sideways frame: about 1.4 × the main eq. focal, ~34 mm on a 25 mm camera; upright: about the main eq. focal) | The ultra-wide engages; the preview visibly widens | |
| 4.3 | Turn back up past that point | The main camera returns | |
| 4.4 | Cross the threshold back and forth on the focal dial | No visible stall or black frame (separate-camera path: a short reopen is acceptable, no hang) | |
| 4.5 | Separate-camera path only (no hysteresis yet): dial the focal back and forth across the main camera's eq. focal (e.g. 24 ↔ 28 mm on a 25 mm main camera) about ten times | Each crossing reopens the camera; the black gap and delay are tolerable and nothing hangs or ends on the wrong camera. Gap length ____ ms; if annoying, hysteresis goes into a later plan | |
| 4.6 | Set a wide focal, press Home, return | The ultra-wide is in use again | |
| 4.7 | Leave the meter screen or background the app right while the ultra-wide is switching (separate-camera path) | The camera indicator goes off and stays off | |
| 4.8 | Sunny exterior, same spot or average mode, main then ultra-wide within a minute: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.9 | Bright interior, same method: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.10 | Dim interior, same method: Main EV ____, Ultra-wide EV ____ | Difference <= 1/3 stop (diff ____) | |
| 4.11 | Histogram on (the histogram button in the viewfinder), pan from a window to a dark room | The bars move ~15×/s, no dial jank | |
| 4.12 | Start a slide roll first (Rolls > Start roll, type Slide, any film; see 7.1). Histogram on, mid-grey subject | The band is narrow, about a third of the panel | |
| 4.13 | Same slide roll, histogram on, tap Hold, pan away | The histogram freezes with the held reading | |
| 4.14 | `adb shell top -H -p $(adb shell pidof io.github.wladikrin.grain)` with the histogram on, then off | GrainCamera thread CPU is the same | |
| 4.15 | Optional, with the plan-2 build as in 2.8: same `top -H` while metering, this build vs the plan-2 build | GrainCamera CPU about the same (preview-size YUV reader + `samplingStep`) | |
| 4.16 | Open the app fresh | The lens frame is sideways (wider than tall); the dimmed bars are above and below it | |
| 4.17 | Tap the frame button (top left of the viewfinder), then again; kill and reopen the app | The frame turns upright and back; the choice survives the restart. Near the threshold (e.g. 28–35 mm on 35 mm film) turning it may switch between main and ultra-wide | |
| 4.18 | Sideways frame, log a frame on a roll | The snapshot is landscape and matches the frame | |

## 5. Shake warning

The camera-shake warning is off by default: turn on Settings > Camera-shake
warning first. It marks shutter speeds slower than 1/(35 mm-equivalent
focal length).

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 5.1 | A 35 mm body with a 50 mm lens (or Free mode at 50 mm), shutter priority, shutter 1/30 | A quiet hand mark (secondary grey, not accent) beside SHUTTER | |
| 5.2 | Same at 1/60 | The mark is gone | |
| 5.3 | Library: pick the Pentax 67 (6×7) and its 105 mm lens (about 51 mm equivalent). Shutter 1/30, then 1/60 | The mark shows at 1/30 and is gone at 1/60 (1/60 is faster than 1/51) | |

## 6. Gear library, favorites, editors, QR and file share, import

Make a second phone show QR codes (a body, a kit with "Share with lenses", the
largest kit) for the scan rows.

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 6.1 | Tap the lens chip repeatedly | It cycles favorite lenses and feels instant | |
| 6.2 | At 360 px width (display size set small), look at the header and chips with the longest bundled names (e.g. "Zoom-Nikkor 35-105/3.5-4.5 AI-S") | They fit without overflow | |
| 6.3 | 360 x 800 phone, Manual mode, viewfinder on, no roll | Nothing overflows; the numerals step down to their smallest and the viewfinder is small but usable (about 90 px) | |
| 6.3a | Repeat 6.3 with the histogram on | Record whether the histogram panel (bottom right of the viewfinder) overlaps the EV pill or Hold (top right): overlap yes / no ____. An overlap that hides the EV value fails | |
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

For rows that need a roll of 72 frames (7.25) or 40+ frames with snapshots
(7.19, 7.20), log them rapidly once here.

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
| 7.23 | In a roll with frames 1 to 5: open frame 3, change its shutter speed and note, Save | Frame 3 shows the new values; the other frames are unchanged | |
| 7.23a | Same roll: insert a frame before frame 3 | The new frame is 3; the old frames 3 to 5 are now 4 to 6 | |
| 7.23b | Same roll: delete frame 2 | The frames after it move up by one; numbers have no gap | |
| 7.23c | Same roll: Edit roll, change the body to another camera, Save | The roll header shows the new body; the frames keep their settings | |
| 7.24 | Make a backup with an active roll (Settings > Export everything, 8.5), then on the phone with an active roll start its import (Settings > Import everything, 8.6) and, in the seconds the import runs, start a roll from the meter | Exactly one active roll afterwards (see 8.8) | |
| 7.25 | Cold start as in 1.7 with an active roll of 72 frames; read `TotalTime` and `adb logcat -d \| grep Displayed` (startup loads settings, gear library, snapshot dir, gear and rolls in parallel) | The meter is up in 1.5 s or less; TotalTime ____ ms | |
| 7.26 | At 360 px width (display size set small), Start roll: look at the two side-by-side Under / Over latitude dials (32 px values) on colour negative (−2 / +3) and after a few detents to −2½ / +3½ | Values and their neighbours fit; nothing overflows or overlaps; a swipe on one dial never moves the other | |
| 7.27 | Start roll on colour negative, move only the Under dial, then switch the type to Slide | Under keeps the value you set; Over follows the type (+½) | |

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
| 8.10 | Import with "Use the settings from the file" ticked | Haptics, viewfinder default, snapshots, histogram, camera-shake warning and click sound follow the file; calibration and location stay as they were | |
| 8.11 | Pick the backup from a cloud provider (Drive) instead of local storage | Import works (the file is copied, streamed, before reading) | |
| 8.12 | Create a roll, log and edit a frame, export the roll (CSV and backup zip) on the current build | All work | |
| 8.13 | The auto-backup restore uninstalls the app, so it is step 13, at the end | — | |

## 9. Settings and permissions (blocked flows)

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 9.1 | Deny the camera twice, then tap "Open settings"; grant the camera there and come back | The preview starts with no restart | |
| 9.2 | Block the location permission, then in Settings turn Save location on | The snackbar offers "Open settings"; grant there, return, and the Save location switch can be turned on | |
| 9.3 | Settings > Licences | A licence page headed Grain, 1.0.0, GPLv3; the list has ZXing core, Inter Tight, SQLite and Grain gear library besides the Flutter packages; ZXing core opens the full Apache License 2.0 text | |
| 9.4 | Settings > Appearance: Dark, then Light, then System; with System, switch the phone's dark theme in quick settings | The whole app follows at once: near-black ground with off-white text in dark, paper in light; status and navigation bar icons stay readable; the viewfinder box stays black in both | |
| 9.5 | Dark: open every screen (meter, rolls, a roll, frame editor, gear pickers and editors, share sheet, scan, export sheet, Settings, Licences) and every dialog and snackbar | No light-mode leftovers, nothing unreadable (e.g. dark text on dark) | |
| 9.6 | Phone in dark theme, cold-start the app | No white flash before the meter appears | |

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
| 12.4 | `ls -l build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` | About 21,338,033 bytes as in Build facts (accepted above the plan's ~20 MB) | |
| 12.5 | `$ANDROID_HOME/build-tools/*/aapt2 dump permissions` on the APK | CAMERA, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION and DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION only; no INTERNET | |
| 12.6 | `unzip -p <apk> 'classes*.dex' \| grep -a -c -e 'com/google/android/gms' -e 'com/google/firebase'` | `0` | |
| 12.7 | Unsigned F-Droid build. On a fresh clone run `flutter build apk --release` once first (it writes `android/gradlew`, which is not in the repository). Then `cd android && GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease`; sign `build/app/outputs/apk/release/app-release-unsigned.apk` with your own key (`apksigner sign --ks ~/grain-release.jks <apk>`) and install it (uninstall first if the installed app has another key) | It builds and runs like the release APK. It is one universal, unobfuscated APK, so its size and bytes are not comparable with the split release APKs (see `docs/release.md`) | |

## 13. Auto-backup restore (uninstalls the app; do it last)

- [ ] Done: all rows of this step.

| # | Action | Expected | Result |
|---|---|---|---|
| 13.1 | `adb shell bmgr backupnow io.github.wladikrin.grain`, uninstall, reinstall the same APK (same signing key; a build with another key cannot restore into it), `adb shell bmgr restore io.github.wladikrin.grain` | Rolls, readings, profiles and settings are back; thumbnails show placeholders | |
| 13.2 | `adb shell run-as io.github.wladikrin.grain ls files/snapshots` after the restore | Empty (snapshots are not backed up) | |
