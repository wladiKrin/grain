# Gear checklist

On-device checks for plan 2 (gear profiles, ultra-wide, QR). Same release APK
and install steps as `metering-checklist.md`.
Device: Pixel 10. Fill the empty result columns on the device. Later tasks
append rows.

## 1. Ultra-wide camera

The native side logs which ultra-wide path it found when the camera opens:

```
adb logcat -c
adb logcat -s GrainCamera
```

Look for `ultra-wide: zoom ratio ...` (main logical camera zooms out with
`CONTROL_ZOOM_RATIO`), `ultra-wide: separate camera ...` (the session reopens
on another camera id) or `ultra-wide: none`.

Path that ran: ______  Main eq. focal: ______ mm  Ultra-wide eq. focal: ______ mm

| Check | Expected | Result |
|---|---|---|
| Ultra-wide engages | Turning the focal dial below the main camera's eq. focal switches to the ultra-wide; the preview visibly widens | |
| Ultra-wide releases | Turning back above the main camera's eq. focal returns to the main camera | |
| No stall at the threshold | Crossing the threshold back and forth on the focal dial: no visible stall or black frame (separate-camera path: a short reopen is acceptable, no hang) | |
| Threshold reopen is tolerable | Separate-camera path only (no hysteresis yet): dial the focal back and forth across the main camera's eq. focal (e.g. 24 ↔ 28 mm on a 25 mm main camera) about ten times. Each crossing reopens the camera; check the black gap and the delay are tolerable and nothing hangs or ends on the wrong camera. Note the gap length; if it is annoying, hysteresis goes into a later plan | |
| Resume | Background and foreground with a wide focal set: the ultra-wide is in use again | |
| Stop while switching | Leave the meter screen or background the app right while the ultra-wide is switching (separate-camera path): the camera indicator goes off and stays off | |

EV agreement on the same scene (main vs. ultra-wide, same spot or average
mode, read within a minute). Acceptable: difference <= 1/3 stop.

| Scene | Main EV | Ultra-wide EV | Diff (stops) | Pass |
|---|---|---|---|---|
| Sunny exterior | | | | |
| Bright interior | | | | |
| Dim interior | | | | |

## 2. QR scan

| Check | Expected | Result |
|---|---|---|
| Single body | A single-body QR shown on a second phone is read in <= 2 s | |
| Largest kit QR | The largest kit QR the app will show (error correction L, ~2953 bytes) is read | |
| Dim light | Scanning in a dim interior still reads a single-body QR | |
| Leaving scan is instant | Leaving the scan screen (or backgrounding) while a code is in view: the camera indicator goes off without a noticeable delay from a running decode | |

## 3. Meter screen with gear

| Check | Expected | Result |
|---|---|---|
| Cold start | Cold start to first meter frame <= 1.5 s with the library and database loaded (same method as the metering checklist) | |
| Lens chip cycle | Tapping the lens chip cycles favorite lenses and feels instant | |
| Narrow width | At 360 px width the header and chips fit with the longest bundled names (e.g. "Zoom-Nikkor 35-105/3.5-4.5 AI-S") without overflow | |

## 4. Sharing and import

| Check | Expected | Result |
|---|---|---|
| Share a body to a messaging app | Library > Share on a body opens the system share sheet with `<id>.json`; the receiver gets a readable JSON file | |
| Share a body to Files | Saving the shared file to Files / Downloads works and the content is the pretty-printed profile | |
| Import from Downloads | Import > From file, pick that file: "Import <body>?" dialog, snackbar "Imported ...", the body is listed and starred; importing it again adds no duplicate | |
| Scan a body QR | Import > Scan QR code on a QR shown on another phone (body): the confirmation appears, the preview closes | |
| Scan a kit QR | Same with "Share with lenses" QR: "Import <body> and N lenses?" | |
| Scan a non-Grain QR | A URL QR shows "Not a Grain profile" for about 2 s and scanning continues; nothing is imported | |
| Back out of scanning | Leaving the scan screen with back returns to the meter and the viewfinder preview comes back, no stuck camera indicator | |
| Background mid-scan | Home (or lock) while the scan screen is open: the camera indicator goes off; coming back reopens the scan preview and a code still scans | |
| Meter camera off behind the library | Open the library, a lens picker, an editor or settings: the camera indicator goes off; back on the meter the preview returns within about a second. Library > Import > Scan QR code still scans, and the meter preview comes back only after leaving the library | |

## 5. Release size and permissions (arm64 release APK)

Built with
`flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate`.

| Check | Expected | Result |
|---|---|---|
| Size | `app-arm64-v8a-release.apk` < 20 MB | 20.5 MB (20,475,232 bytes; 19.5 MiB) with `--split-debug-info=build/symbols --obfuscate` and without cupertino_icons (libapp.so 6.2 → 5.2 MB); was 21.5 MB (21,524,542 bytes) without them, 19.1 MB before share_plus / file_selector / qr_flutter. Still 0.5 MB over the limit: accepted per the final ruling (no font subsetting, no `useLegacyPackaging`), revisit in plan 4 |
| Permissions | `aapt2 dump permissions`: CAMERA only (plus AndroidX's non-network DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION); no INTERNET | CAMERA only, no INTERNET |
| Play Services | No `com.google.android.gms` classes in the dex files | none found |
