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
