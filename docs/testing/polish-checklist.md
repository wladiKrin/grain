# Grain polish: on-device checklist

Device: Pixel 10, release build

| check | expected | result |
|---|---|---|
| Histogram on, pan from a window to a dark room | the bars move ~15×/s, no dial jank | |
| Histogram with an active slide roll, mid-grey subject | the band is narrow, about a third of the panel | |
| Histogram on, tap Hold, pan away | the histogram freezes with the held reading | |
| `adb shell top -H`: GrainCamera CPU with histogram on vs off | the same | |
| Stats rate (`debugPrint` count over 10 s or the DevTools timeline), 30 and 60 fps | ≤ 15/s | |
| Shake warning on, 50 mm, shutter priority 1/30 | a quiet hand mark (secondary grey, not accent) beside SHUTTER | |
| Same at 1/60 | the mark is gone | |
| 6x7 body with a 90 mm lens | the mark appears at 1/60 | |
| Click sound on, turn the aperture dial | a soft click per detent, louder on full stops | |
| Click sound on, swipe fast | haptics stay crisp, no lag (compare with click off) | |
| Enable click sound, turn a dial at once | the first detent right after enabling may be silent (the sound loads asynchronously) | |
| Ringer on silent, click sound on | note whether the click follows (expected: system-sound volume rules) | |
| Click sound off, `adb shell dumpsys media.audio_flinger \| grep -i soundpool` | no Grain track | |

## Plan 4 Task 6: parked fixes
- [ ] Manual mode with the viewfinder on, tap a spot: the ring and ticks are clearly visible, not a dot.
- [ ] Tap in the dimmed area: the spot lands on the crop edge.
- [ ] Import a backup containing an active roll and start a roll in the seconds the import runs: one active roll afterwards.
- [ ] On a phone that reports no aperture, the EV line reads "EV ≈..." (f/1.8 assumed).

## Plan 4 Task 7: blocked permissions
- [ ] Deny the camera twice: the prompt offers "Open settings"; grant the camera there, come back to Grain: the preview starts with no restart.
- [ ] Same for location from Settings: after blocking, the snackbar offers "Open settings"; grant there, return, and the Save location switch can be turned on.

## Plan 4 Task 8: APK size

Command: `flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate`, `app-arm64-v8a-release.apk`. Plan-3 figure: 22,262,896 bytes (22.26 MB).

| | before (HEAD b55e68d) | after (Task 8) |
|---|---|---|
| APK total | 22,345,232 | 21,265,732 (−1,079,500) |
| `lib/arm64-v8a/libsqlite3.so` | 1,749,952 (prebuilt download) | 1,153,752 (vendored 3.54.1, `-Os`, gc-sections) |
| 4 × `InterTight-*.ttf`, stored / compressed | 1,231,268 / 626,784 | 294,756 / 143,484 (subsets) |
| `lib/arm64-v8a/libflutter.so` | 11,346,352 | 11,346,352 |
| `lib/arm64-v8a/libapp.so` | 7,013,336 | 7,013,336 |
| `classes.dex` | 966,860 | 966,860 |
| `lib/arm64-v8a/libdartjni.so` | 131,792 | 131,792 |
| `assets/flutter_assets/NOTICES.Z` | 117,854 | 117,854 |

Largest Dart packages (`--analyze-size`, unchanged by Task 8): `package:flutter` 2 MB, `package:material_ui` 1 MB, `package:archive` 694 KB, `package:grain` 683 KB, `package:drift` 155 KB.

The total stays above 20,000,000 bytes: within "~" as in the plan-2 and plan-3 rulings (R12). What remains is the Flutter engine (`libflutter.so`, 11.3 MB) and the AOT snapshot (`libapp.so`, 7.0 MB: Flutter, Material, archive, Grain, drift), all in use; no further lever without removing a feature or a used dependency.

Offline source build verified on the host: with `.dart_tool/hooks_runner/shared/sqlite3` deleted, the release build succeeded inside a network namespace with no network (`unshare -rn` + loopback only; `curl https://sqlite.org` failed inside), and the hook's build directory has no `download-*` entry. The hook's compile command ends with `-O3 … -Os -ffunction-sections -fdata-sections -Wl,--gc-sections` (last `-O` is `-Os`).

- [ ] Install the Task 8 release build over an existing install: the app opens existing rolls and gear with no database error after the SQLite switch.
- [ ] Create a roll, log and edit a frame, export the roll (CSV and backup zip): all work.
- [ ] Fonts look unchanged (Light/Regular/Medium/SemiBold); ⅓ and ½ stops, −, ≈, ▲ ▼, → render; ⅔ was never in Inter Tight and uses the system font, as before.

## Task 9: release readiness

- [ ] Launcher icon on the Pixel home screen: Paper ground, ink aperture disc, red dot in the middle.
- [ ] Themed icons switched on (Settings, Wallpaper & style): the icon becomes the monochrome aperture, tinted by the wallpaper.
- [ ] App info shows version 1.0.0.
