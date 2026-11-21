# Grain rolls & logging: on-device checklist

Device: Pixel 10, release build

| check | expected | result |
| --- | --- | --- |
| Open the library, press Home, wait 5 s, return | No camera indicator while away; the meter preview returns after leaving the library | |
| Open a QR scan (library → Import → Scan QR code), press Home, wait 5 s, return | No camera indicator while away; the scan preview returns; the meter preview returns after closing the scan and the library | |
| Log a frame at 35 mm, then at 50 mm (portrait) | A snapshot appears within ~1 s, upright, matching the viewfinder crop of that lens | |
| Log a frame with the viewfinder hidden | A snapshot is still saved | |
| `adb shell run-as io.github.wladikrin.grain ls -l files/snapshots` | Each file 60–120 KB, long edge ≤ 1000 px | |
| Log 10 frames rapidly | 10 snapshot files; the dial stays smooth | |
| Meter the same scene on this build and on the plan-2 build (METER reader now at preview size, sparser luma sampling) | Stats still ~15/s; EV unchanged within ±⅙ EV | |
| CPU check: `adb shell top -H -p $(adb shell pidof io.github.wladikrin.grain)` while metering, this build vs plan-2 build | GrainCamera thread CPU about the same (preview-size YUV reader + `samplingStep`); GrainSnapshot busy only briefly after a log | |
| Swipe dials while a snapshot encodes | No new jank | |
| Open the phone's gallery app | No Grain snapshots appear there | |
| Log a frame, press Home at once | The snapshot still attaches to that frame on return | |
| Note: the activity is portrait-locked; snapshots are rotated by sensor orientation only, so a frame logged with the phone held landscape is stored sideways (by design for now; device orientation/EXIF is later work) | — | |
| Settings: turn Save location on | System dialog offers precise / approximate; refuse → switch stays off with "Location permission was not granted." | |
| Location on: log a frame | A fix is attached within 10 s (indoors: the last known fix) | |
| Airplane mode + GPS off, location on: log a frame | Frame logs with no location and no delay | |
| Revoke the location permission in system settings, log a frame | Logging still works, no location | |

## Meter: log frame, save reading (Task 7)

| check | expected | result |
| --- | --- | --- |
| Log frame feels instant | The new frame number shows with no visible delay (at most one frame); the snapshot and location arrive later without blocking | |
| Narrow header and bottom row at 360 px | "Roll 12 · frame 37/36 +1" and "Delta 3200 · 3200 → 12800" fit the header without overflow; the Log button, rolls button and Start roll link fit | |
| 360 x 800 phone, Manual mode, viewfinder on, no roll | Nothing overflows; the numerals step down to their smallest and the viewfinder is small but usable (about 90 px) | |
| Tap Log frame twice quickly | The Undo snack bar floats above the button and never covers it; both frames log | |
| Cold start with an active roll of 72 frames | The meter is up in 1.5 s or less | |
