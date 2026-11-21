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
