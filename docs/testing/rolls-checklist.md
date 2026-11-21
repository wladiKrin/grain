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
| Cold start with an active roll of 72 frames (force-stop, then launch; measure with `adb shell am start -W -n io.github.wladikrin.grain/.MainActivity` and read `TotalTime`, plus `adb logcat -d \| grep Displayed`; startup loads settings, gear library, snapshot dir, gear and rolls in parallel since the final fix wave) | The meter is up in 1.5 s or less; record TotalTime (ms) here | |

## Roll editor, frame editor, rolls lists (Tasks 8-10)

| check | expected | result |
| --- | --- | --- |
| Roll editor: type in the film stock field with the keyboard up | The autocomplete suggestion overlay is not hidden by the keyboard and stays tappable | |
| Frame editor: open the date and the time pickers | The real system date and time pickers open, accept a choice, and the frame shows the chosen wall-clock date and time | |
| Roll with 40 frames, each with a snapshot: scroll the roll view quickly | Thumbnails appear without stutter; no visible jank | |
| Rolls screen with several rolls and 40+ saved readings with snapshots: scroll both tabs | Smooth scrolling; Active tag and frame counts (e.g. 12/36) are right | |
| Meter: tap the Rolls button | The Rolls screen opens; no camera indicator while it is open; the meter preview returns on going back | |
| Saved reading: edit the note, press back; reopen | The note is kept; "Remove location" and "Delete snapshot" work and the thumbnail disappears from the list | |

## Export (Task 11)

| check | expected | result |
| --- | --- | --- |
| Export a roll with snapshots, share to Files and to a messaging app | Both receive roll-N-<film>.csv, .json and -snapshots.zip; the sheet closes after sharing | |
| Open the CSV in LibreOffice and in Excel | Umlauts intact; a note with commas, quotes or line breaks stays in one cell; date_time shows the time the frame was logged | |
| Open the snapshots zip | One JPEG per frame that has a snapshot, named frame-<number>.jpg | |
| Export a roll of 200+ frames with snapshots | The sheet stays responsive while the zip is built | |

## Backup (Task 12)

| check | expected | result |
| --- | --- | --- |
| Settings → Export everything with ≥ 100 snapshots on the phone | Share sheet offers grain-backup-<date>.zip; note the time taken; no jank while it is built; memory stays stable (Android Studio profiler) | |
| Import that zip on a second phone (or after "Clear storage") | Same rolls, frames, saved readings, own gear and favorites; every thumbnail shows | |
| Import the same zip again | Report says "Added 0 rolls, 0 saved readings, 0 profiles. Skipped N already on this phone." and nothing is duplicated | |
| Import with a roll active on this phone | The imported active roll is listed as finished; the roll here stays active | |
| Pick a file that is not a zip (e.g. a photo or a text file) | "Can't import" with "Not a Grain backup"; nothing changes | |
| Import with "Use the settings from the file" ticked | Haptics, viewfinder default and snapshots follow the file; calibration and location stay as they were | |
| Pick the backup from a cloud provider (Drive) instead of local storage | Import works (the file is copied, streamed, before reading) | |

## Auto-backup and release (Task 13)

| check | expected | result |
| --- | --- | --- |
| `adb shell bmgr backupnow io.github.wladikrin.grain`, uninstall, reinstall from the same signing key (`adb shell bmgr restore`) | Rolls, readings, profiles and settings are back; thumbnails show placeholders | |
| `adb shell run-as io.github.wladikrin.grain ls files/snapshots` after the restore | Empty (snapshots are not backed up) | |

Release build recorded (arm64, `--split-debug-info --obfuscate`): 22,262,896 bytes (22.3 MB, plan-2 baseline 20.5 MB). Permissions: CAMERA, ACCESS_COARSE_LOCATION, ACCESS_FINE_LOCATION (plus the app's own DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION); no INTERNET; 0 com/google/android/gms classes.
