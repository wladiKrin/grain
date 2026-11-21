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

## 5. Release size and permissions (arm64 release APK)

| Check | Expected | Result |
|---|---|---|
| Size | `app-arm64-v8a-release.apk` < 20 MB | 21.5 MB (21,524,542 bytes) after share_plus / file_selector / qr_flutter; was 19.1 MB. OVER the limit, reported as a concern |
| Permissions | `aapt2 dump permissions`: CAMERA only (plus AndroidX's non-network DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION); no INTERNET | CAMERA only, no INTERNET |
| Play Services | No `com.google.android.gms` classes in the dex files | none found |
