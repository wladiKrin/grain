# Metering and release checklist

Release APK: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
Device: Pixel 10. Fill the empty result columns on the device.

## Install

```
flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 1. Accuracy against a reference meter

Reference: a camera's meter or a known handheld meter, same ISO, same
aperture, read as EV at ISO 100. Take both readings at the same spot, within a
minute. Set the calibration offset once (on the first scene) so the average
reading matches the reference, then keep it for all scenes.

Acceptable: difference <= 2/3 stop after the single calibration offset.

Calibration offset used: ______ EV

| Scene | Reference EV | Grain average EV | Grain spot EV | Avg diff (stops) | Spot diff (stops) | Pass |
|---|---|---|---|---|---|---|
| Sunny exterior | | | | | | |
| Open shade | | | | | | |
| Bright interior | | | | | | |
| Dim interior | | | | | | |
| Backlit subject | | | | | | |

## 2. Cold-start timing

Target: cold start to first EV value <= 1.5 s.

Method (repeat 5 times, take the median):

```
adb shell am force-stop io.github.wladikrin.grain
adb logcat -c
adb shell am start -W io.github.wladikrin.grain/.MainActivity
```

Read `TotalTime` (ms) from the `am start -W` output. Then read the time to the
first EV value: the app logs `GRAIN first EV` via `debugPrint` when the first
camera statistics arrive.

```
adb logcat -d -v time | grep -E "ActivityTaskManager.*(START|Displayed)|GRAIN first EV"
```

Time to first EV = timestamp of `GRAIN first EV` minus the timestamp of the
`START` line of the launch.

| Run | TotalTime (ms) | Time to first EV (ms) |
|---|---|---|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| Median | | |

## 3. Frame performance

Either enable Settings > Developer options > Profile GPU rendering > "On
screen as bars" and drag the dials: bars stay under the 16 ms line. Or:

```
flutter run --profile -d <device>
```

and use DevTools (Performance): no jank frames while dragging the dials.

Result: ______

## 4. On-device behaviour checks

| Check | Expected | Result |
|---|---|---|
| Preview orientation | Preview is upright (not rotated) in the viewfinder | |
| Lens choice | The ~26 mm main camera is chosen | |
| AE reaction | EV values react when the scene brightness changes | |
| Event rate | <= 15 events/s, no stalls | |
| Lifecycle | Camera stops on background and starts on foreground | |
| Spot position | The spot lands where tapped | |
| Lens crop | The crop matches a 50 mm framing | |
| Haptics | Haptic ticks are strong on full stops | |
| Value row, viewfinder hidden | 92 px numerals do not overflow on the Pixel's width | |
| Permission flow | "Allow camera" prompt works; deny twice leads to settings | |
| R8 release build runs on device | The minified release APK starts the camera and the permission flow works (no R8-stripped classes) | |
| Portrait lock | Rotating the phone keeps the meter in portrait | |
| Dark mode | With system dark mode on: no black launch flash, dark status bar icons on the paper ground | |

If spot readings look compressed (a bright or dark spot reads closer to the
average than the reference meter says), the preview tone curve may not be the
sRGB curve the luma linearization assumes. Try forcing it in the capture
request: `TONEMAP_MODE_GAMMA_VALUE` with gamma 2.2, or
`TONEMAP_MODE_PRESET_CURVE` with `TONEMAP_PRESET_CURVE_SRGB`.

## 5. Release verification (already done on the build host)

- APK size < 20 MB per ABI.
- `aapt2 dump permissions`: only `CAMERA` plus the AndroidX
  `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; no `INTERNET`.
- No `com.google.android.gms` or Firebase classes in the dex.
