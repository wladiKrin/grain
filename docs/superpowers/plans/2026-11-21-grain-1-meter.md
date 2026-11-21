# Grain 1 — Meter: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A working, installable Grain lightmeter on the Pixel 10: live camera metering (average over the lens crop + tap-to-spot), aperture-priority / shutter-priority / manual modes, swipe dials with haptic detents, toggleable viewfinder cropped to the chosen focal length, ISO stepper and a settings screen — all in free mode ("No camera"), with no gear library or logging yet.

**Architecture:** Flutter app with plain `ChangeNotifier` state (no state-management package). Pure-Dart exposure math (`lib/exposure`) is the heart and is fully unit-tested. A small Kotlin Camera2 bridge inside the app module streams the preview as a Flutter `Texture` and sends per-frame AE metadata plus linear-luma statistics over an `EventChannel`; Dart turns those into a scene EV. UI follows mockup "B + viewfinder, swipe dials".

**Tech Stack:** Flutter (stable, Dart 3), Kotlin + Camera2, `shared_preferences`, `permission_handler`. Fonts bundled (Inter Tight, OFL) — no network font loading.

**Spec:** `docs/superpowers/specs/2026-11-21-lightmeter-design.md`
**Mockup:** https://claude.ai/artifact/TjjoktNV7so13osdFTFJsK (board "B + viewfinder, swipe dials")

**Later plans (not this one):** 2 Gear library (bodies, lenses, favorites, community JSON, QR/file sharing, ultra-wide switch) · 3 Rolls & logging (saved readings, rolls, frames, snapshots, push/pull, export, backup/import) · 4 Histogram & polish (histogram overlay, shake warning, click sound, F-Droid release).

## Global Constraints

- App name **Grain**; Android `applicationId` / namespace **`io.github.wladikrin.grain`**; Kotlin package `io.github.wladikrin.grain`.
- Licence **GPLv3** (`LICENSE` at repo root).
- `minSdk` **29** (Android 10); target/compile SDK = latest stable the installed Flutter supports.
- No proprietary dependencies: no Google Play Services, Firebase, analytics, ads, network access. Do **not** add the `INTERNET` permission to the release manifest.
- Reference device: **Google Pixel 10**.
- Colours: ground `#F4F2EE`, ink `#141414`, secondary text `#5E5B55`, dividers `#D9D5CD`, control borders `#C9C4BA`, faded neighbour values `#8C877E`, accent (metered value) `#B8321A`. Font Inter Tight (weights 300/400/500/600). Touch targets ≥ 44 logical px. No shadows, no gradients in UI chrome.
- Dial: one value per detent, detent = **40 logical px** of horizontal drag, no fling/momentum; haptic tick on every detent, **stronger tick on full stops**; tapping a faded neighbour moves one step.
- Free mode: apertures **f/1 – f/64**, shutter **1/8000 s – 30 s**, ISO **6 – 12800**, all **in thirds**, format 35 mm, focal-length dial **12 – 600 mm**.
- Calibration offset: **±3 EV in 1/3 steps**.
- Performance: cold start to live reading **≤ 1.5 s** on the Pixel 10; dial drags without dropped frames.
- Installed APK **< 20 MB per ABI** (`flutter build apk --split-per-abi`).

## Review Focus

1. **Camera permission denied or revoked** → the meter screen shows a calm explanation and a "Allow camera" button; dials still work; no crash. Test in Task 8.
2. **Scene beyond the phone's AE range** (very dark: AE at max exposure time and max ISO with near-black luma; very bright: AE at min with near-white luma) → reading is flagged under/over range instead of showing a confident wrong number; zero luma never yields `-infinity`/`NaN`. Test in Task 4.
3. **Solved value outside the scale** (e.g. needs 1/16000 s) → shows the end value with an over/under flag. Test in Task 3.
4. **App backgrounded / screen off** → camera is released on pause and reopened on resume; nothing leaks or freezes. Test in Task 7.
5. **Dragging past either end of a scale, or dragging very fast** → value stays at the end, no haptic fires at the clamp, never skips more than one value per 40 px. Test in Task 5.

---

### Task 1: Toolchain, project scaffold, repo

**Files:**
- Create: Flutter project in repo root (`pubspec.yaml`, `lib/main.dart`, `android/…`, `test/…`)
- Create: `LICENSE` (GPLv3 full text), `README.md`, `.gitignore` (Flutter default), `.github/workflows/test.yml`
- Create: `assets/fonts/InterTight-{Light,Regular,Medium,SemiBold}.ttf`, `assets/fonts/OFL.txt`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: a buildable app named Grain with package `io.github.wladikrin.grain`; font family `InterTight` declared in `pubspec.yaml`.

- [ ] **Step 1: Install toolchain (owner may need to run `sudo` commands)**

Arch Linux: JDK 17 (`jdk17-openjdk`), Flutter stable (AUR `flutter-bin`, or `git clone -b stable https://github.com/flutter/flutter ~/flutter` and add `~/flutter/bin` to PATH), Android SDK command-line tools + platform-tools + a current platform and build-tools, then `flutter doctor --android-licenses`. Enable USB debugging on the Pixel 10.

Run: `flutter doctor`
Expected: ✓ for Flutter and Android toolchain; Pixel listed under `flutter devices` when plugged in.

- [ ] **Step 2: Create project and repo**

Run in `/home/wladi/Projects/lightmeter`: `git init`, then `flutter create --org io.github.wladikrin --project-name grain --platforms android,ios .` (keeps existing `docs/`). Set `minSdk = 29` in `android/app/build.gradle(.kts)`. Set Android label to `Grain`. Add `LICENSE` (GPLv3), fonts + `OFL.txt` and declare them in `pubspec.yaml`. Replace the counter demo with an empty `MaterialApp(title: 'Grain')`.

- [ ] **Step 3: Write smoke test**

```dart
testWidgets('app boots', (tester) async {
  await tester.pumpWidget(const GrainApp());
  expect(find.byType(MaterialApp), findsOneWidget);
});
```

- [ ] **Step 4: Run** `flutter test` → PASS; `flutter run` on the Pixel → blank app titled Grain.

- [ ] **Step 5: CI + README**

`.github/workflows/test.yml`: on push/PR, `subosito/flutter-action` (stable), `flutter analyze`, `flutter test`. `README.md`: one-paragraph pitch, how to install the toolchain, `flutter run`, `flutter test`, licence.

- [ ] **Step 6: Commit** `git add -A && git commit -m "chore: scaffold Grain Flutter app"`

---

### Task 2: Exposure scales

**Files:**
- Create: `lib/exposure/scales.dart`
- Test: `test/exposure/scales_test.dart`

**Interfaces:**
- Produces:
  - `class ScaleValue { final String label; final double value; final bool isFullStop; }` — `value` is exact (aperture: f-number √2^stops; shutter: seconds 2^(stops); ISO: 100·2^(stops)), `label` is the nominal marking.
  - `enum StepSize { full, half, third }`
  - `List<ScaleValue> apertureScale({required StepSize step, double min = 1, double max = 64})`
  - `List<ScaleValue> shutterScale({required StepSize step, double fastest = 1/8000, double slowest = 30})` — ordered fastest → slowest.
  - `List<ScaleValue> isoScale({StepSize step = StepSize.third, int min = 6, int max = 12800})`
  - `int nearestIndex(List<ScaleValue> scale, double value)` — nearest by `|log2(a/b)|`.

Nominal labels (copy exactly):
- Aperture thirds: 1, 1.1, 1.2, 1.4, 1.6, 1.8, 2, 2.2, 2.5, 2.8, 3.2, 3.5, 4, 4.5, 5, 5.6, 6.3, 7.1, 8, 9, 10, 11, 13, 14, 16, 18, 20, 22, 25, 29, 32, 36, 40, 45, 51, 57, 64
- Aperture halves: 1, 1.2, 1.4, 1.7, 2, 2.4, 2.8, 3.3, 4, 4.8, 5.6, 6.7, 8, 9.5, 11, 13, 16, 19, 22, 27, 32, 38, 45, 54, 64
- Shutter thirds (fast→slow): 1/8000, 1/6400, 1/5000, 1/4000, 1/3200, 1/2500, 1/2000, 1/1600, 1/1250, 1/1000, 1/800, 1/640, 1/500, 1/400, 1/320, 1/250, 1/200, 1/160, 1/125, 1/100, 1/80, 1/60, 1/50, 1/40, 1/30, 1/25, 1/20, 1/15, 1/13, 1/10, 1/8, 1/6, 1/5, 1/4, 0.3", 0.4", 1/2, 0.6", 0.8", 1", 1.3", 1.6", 2", 2.5", 3.2", 4", 5", 6", 8", 10", 13", 15", 20", 25", 30"
- Shutter halves: 1/8000, 1/6000, 1/4000, 1/3000, 1/2000, 1/1500, 1/1000, 1/750, 1/500, 1/350, 1/250, 1/180, 1/125, 1/90, 1/60, 1/45, 1/30, 1/20, 1/15, 1/10, 1/8, 1/6, 1/4, 0.3", 1/2, 0.7", 1", 1.5", 2", 3", 4", 6", 8", 12", 15", 20", 30"
- ISO thirds: 6, 8, 10, 12, 16, 20, 25, 32, 40, 50, 64, 80, 100, 125, 160, 200, 250, 320, 400, 500, 640, 800, 1000, 1250, 1600, 2000, 2500, 3200, 4000, 5000, 6400, 8000, 10000, 12800
- `isFullStop` = every 3rd value (thirds) or every 2nd (halves) counted from the grid origin (aperture f/1, shutter 1/8000, ISO 100). Full stops therefore are: aperture 1, 1.4, 2 … 64; shutter 1/8000, 1/4000 … 1/2, 1", 2", 4", 8", 15", 30"; ISO 6, 12, 25, 50, 100 … 12800.

- [ ] **Step 1: Write failing tests**

```dart
test('aperture thirds f/1–f/64 has 37 values, full stops flagged', () {
  final s = apertureScale(step: StepSize.third);
  expect(s.length, 37);
  expect(s.first.label, '1'); expect(s.last.label, '64');
  expect(s.where((v) => v.isFullStop).map((v) => v.label),
      ['1','1.4','2','2.8','4','5.6','8','11','16','22','32','45','64']);
  expect(s[3].value, closeTo(math.sqrt2, 1e-9)); // exact, not 1.4
});
test('shutter thirds 1/8000–30s, fast to slow', () {
  final s = shutterScale(step: StepSize.third);
  expect(s.first.label, '1/8000'); expect(s.last.label, '30"');
  expect(s.firstWhere((v) => v.label == '1/125').value, closeTo(1 / 128, 1e-9));
});
test('aperture scale respects min/max (lens limits)', () {
  final s = apertureScale(step: StepSize.half, min: 1.8, max: 22);
  expect(s.first.label, '1.8'); expect(s.first.value, 1.8);
  expect(s[1].label, '2'); expect(s.last.label, '22');
});
test('nearestIndex snaps by log distance', () {
  final s = apertureScale(step: StepSize.full);
  expect(s[nearestIndex(s, 3.0)].label, '2.8');
  expect(s[nearestIndex(s, 3.5)].label, '4');
});
test('iso thirds 6–12800', () {
  final s = isoScale();
  expect(s.first.label, '6'); expect(s.last.label, '12800');
  expect(s.where((v) => v.label == '400').single.isFullStop, isTrue);
});
```

Rule for the min/max test: a limit that is not on the chosen grid (a lens's f/1.8 on a half-stop grid) becomes an extra end value with its own label and exact value, followed by the next grid value. It is not a full stop.

- [ ] **Step 2: Run** `flutter test test/exposure/scales_test.dart` → FAIL (undefined).
- [ ] **Step 3: Implement** in `lib/exposure/scales.dart`: label tables as `const` lists; exact value computed from the index within the full thirds/halves grid (e.g. aperture third index k → `pow(2, k / 6)`, shutter third index k from 1/8000 → `pow(2, k/3) / 8192`, ISO from 100 at k=0 → `100 * pow(2, k/3)`). `isFullStop` = index divisible by 3 (thirds) or 2 (halves).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(exposure): aperture, shutter and ISO scales`

---

### Task 3: Exposure solver

**Files:**
- Create: `lib/exposure/solver.dart`
- Test: `test/exposure/solver_test.dart`

**Interfaces:**
- Consumes: `ScaleValue`, `nearestIndex` (Task 2).
- Produces:
  - `double evAtIso(double ev100, double iso)` = `ev100 + log2(iso / 100)`
  - `enum RangeFlag { ok, over, under }` — `over` = scene too bright for the scale (would need a faster shutter / smaller aperture than available).
  - `class Solved { final int index; final RangeFlag flag; }`
  - `Solved solveShutter({required double ev100, required double iso, required double aperture, required List<ScaleValue> shutters})` — exact `t = N² / 2^EV_S`, snapped.
  - `Solved solveAperture({required double ev100, required double iso, required double shutter, required List<ScaleValue> apertures})` — exact `N = sqrt(t · 2^EV_S)`, snapped.
  - `double manualOffset({required double ev100, required double iso, required double aperture, required double shutter, double step = 1/3})` = `round((log2(t / N²) + EV_S) / step) * step`; positive = overexposed.
  - Flag rule: if the exact target lies beyond the scale's end by more than half the local step → `over`/`under`, index = that end.

- [ ] **Step 1: Write failing tests**

```dart
final shutters = shutterScale(step: StepSize.third);
final apertures = apertureScale(step: StepSize.third);
test('sunny 16: EV15 ISO100 f/16 → 1/125', () {
  final r = solveShutter(ev100: 15, iso: 100, aperture: 16, shutters: shutters);
  expect(shutters[r.index].label, '1/125'); expect(r.flag, RangeFlag.ok);
});
test('ISO 400 shifts two stops: EV12 ISO400 f/4 → 1/250', () {
  final r = solveShutter(ev100: 12, iso: 400, aperture: 4, shutters: shutters);
  expect(shutters[r.index].label, '1/250');
});
test('shutter priority: EV15 ISO100 1/125 → f/16', () {
  final r = solveAperture(ev100: 15, iso: 100, shutter: 1 / 128, apertures: apertures);
  expect(apertures[r.index].label, '16');
});
test('too bright for the fastest shutter → over, clamped', () {
  final r = solveShutter(ev100: 20, iso: 3200, aperture: 1, shutters: shutters);
  expect(r.index, 0); expect(r.flag, RangeFlag.over);
});
test('too dark for 30 s → under, clamped', () {
  final r = solveShutter(ev100: -8, iso: 25, aperture: 64, shutters: shutters);
  expect(r.index, shutters.length - 1); expect(r.flag, RangeFlag.under);
});
test('manual offset: one stop too slow reads +1', () {
  expect(manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 64), closeTo(1, 1e-9));
  expect(manualOffset(ev100: 15, iso: 100, aperture: 16, shutter: 1 / 128), closeTo(0, 1e-9));
});
```

- [ ] **Step 2: Run** `flutter test test/exposure/solver_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/exposure/solver.dart`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(exposure): solve shutter/aperture and manual offset`

---

### Task 4: Reading from camera statistics

**Files:**
- Create: `lib/metering/reading.dart`
- Test: `test/metering/reading_test.dart`

**Interfaces:**
- Produces:
  - `class MeterStats` (one per camera frame, built from the EventChannel map, see Task 6): `int exposureNs; int sensitivity; int boost /* percent, 100 = none */; double aperture; int minExposureNs, maxExposureNs, minIso, maxIso; double frameLuma, cropLuma, spotLuma /* mean LINEAR luma 0..1 */; List<int> histogram /* 64 bins of crop */;` with `factory MeterStats.fromMap(Map<Object?, Object?> m)`.
  - `enum MeterArea { average, spot }`
  - `class Reading { final double ev100; final RangeFlag flag; }`
  - `Reading readingFrom(MeterStats s, {required MeterArea area, double calibration = 0})`

Algorithm (exact):
```
phoneIso = sensitivity * boost / 100
evAE     = log2(aperture² / (exposureNs / 1e9)) - log2(phoneIso / 100)
L_region = area == spot ? spotLuma : cropLuma
L_floor  = 1e-4                                  // avoids log2(0)
ev100    = evAE + log2(max(L_region, L_floor) / max(frameLuma, L_floor)) + calibration
under if exposureNs >= 0.95*maxExposureNs && sensitivity >= 0.95*maxIso && L_region < 0.01
over  if exposureNs <= 1.05*minExposureNs && sensitivity <= 1.05*minIso && L_region > 0.9
```

- [ ] **Step 1: Write failing tests**

```dart
MeterStats stats({int exp = 1000000, int iso = 100, double frame = .18, double crop = .18, double spot = .18}) =>
    MeterStats.fromMap({'exposureNs': exp, 'sensitivity': iso, 'boost': 100, 'aperture': 1.68,
      'minExposureNs': 10000, 'maxExposureNs': 500000000, 'minIso': 50, 'maxIso': 6400,
      'frameLuma': frame, 'cropLuma': crop, 'spotLuma': spot, 'histogram': List.filled(64, 0)});
test('AE result to EV100', () {
  // f/1.68, 1/1000 s, ISO 100 → log2(2.8224*1000) ≈ 11.46
  expect(readingFrom(stats(), area: MeterArea.average).ev100, closeTo(11.46, 0.01));
});
test('spot twice as bright as frame reads +1 EV', () {
  final r = readingFrom(stats(spot: .36), area: MeterArea.spot);
  expect(r.ev100, closeTo(12.46, 0.01));
});
test('calibration is added', () {
  expect(readingFrom(stats(), area: MeterArea.average, calibration: -2/3).ev100, closeTo(10.79, 0.01));
});
test('black region at AE limits is under-range, never -inf/NaN', () {
  final r = readingFrom(stats(exp: 500000000, iso: 6400, crop: 0), area: MeterArea.average);
  expect(r.flag, RangeFlag.under); expect(r.ev100.isFinite, isTrue);
});
test('blown region at AE minimum is over-range', () {
  final r = readingFrom(stats(exp: 10000, iso: 50, crop: .95), area: MeterArea.average);
  expect(r.flag, RangeFlag.over);
});
```

- [ ] **Step 2: Run** `flutter test test/metering/reading_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/metering/reading.dart`.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(metering): scene EV from AE metadata and linear luma`

---

### Task 5: Swipe dial widget and haptics

**Files:**
- Create: `lib/ui/haptics.dart`, `lib/ui/dial/swipe_dial.dart`
- Test: `test/ui/swipe_dial_test.dart`

**Interfaces:**
- Consumes: `ScaleValue` (Task 2).
- Produces:
  - `abstract class Haptics { void tick({required bool strong}); }`; `class SystemHaptics implements Haptics` — `strong` → `HapticFeedback.mediumImpact()`, else `HapticFeedback.selectionClick()`; respects an `enabled` flag (`SystemHaptics({bool enabled = true})`).
  - `SwipeDial({required List<ScaleValue> values, required int index, required ValueChanged<int> onChanged, required Haptics haptics, double valueFontSize = 64, double detent = 40, Key? key})`
  - Layout (from mockup): row = faded previous label (tappable, `#8C877E`, 24 px) · current label (`valueFontSize`, weight 300) · faded next label; below, a 22 px tick ruler (major tick per value, two minor ticks between, accent centre marker 3 px wide) that translates 1:1 with the finger between detents and snaps back on release.
  - Semantics: the dial exposes `Semantics(value: label, increasedValue:, decreasedValue:, onIncrease:, onDecrease:)` so it works with TalkBack.

Drag rule (exact): on drag start remember `startIndex` and `startX`. On update, `idx = clamp(startIndex + round(-(dx) / detent), 0, len-1)`. Dragging left increases the index. If `idx != index` → call `onChanged(idx)` and `haptics.tick(strong: values[idx].isFullStop)`. A single update can move at most one value per 40 px; at a clamp, no tick.

- [ ] **Step 1: Write failing tests** (with `class FakeHaptics implements Haptics { final ticks = <bool>[]; … }` and a stateful test host holding `index`)

```dart
testWidgets('drag left 40px steps +1 with one tick', ...);       // index 3 → 4, ticks == [values[4].isFullStop]
testWidgets('drag left 120px steps +3, three ticks, strong on full stops', ...);
testWidgets('drag past the end clamps and stops ticking', ...);  // start at len-2, drag -400px → len-1, ticks.length == 1
testWidgets('tap next label steps +1; tap previous steps -1', ...);
testWidgets('drag of 19px does not change value', ...);
```

- [ ] **Step 2: Run** `flutter test test/ui/swipe_dial_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/ui/haptics.dart` and `lib/ui/dial/swipe_dial.dart` (`GestureDetector` with `onHorizontalDragStart/Update/End`, ruler via `CustomPainter` with an `offset` field; the ruler repaints only the painter, not the whole row).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(ui): swipe dial with haptic detents`

---

### Task 6: Native Camera2 metering bridge

**Files:**
- Create: `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/MeterPlugin.kt` (channels, lifecycle)
- Create: `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/CameraSession.kt` (Camera2 open/configure/close)
- Create: `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/LumaStats.kt` (pure, no Android types)
- Modify: `android/app/src/main/kotlin/io/github/wladikrin/grain/MainActivity.kt` (register plugin)
- Modify: `android/app/src/main/AndroidManifest.xml` (`android.permission.CAMERA`, `<uses-feature android:name="android.hardware.camera" android:required="true"/>`)
- Modify: `android/app/build.gradle(.kts)` (JUnit test dependency)
- Create: `lib/metering/meter_channel.dart`
- Test: `android/app/src/test/kotlin/io/github/wladikrin/grain/meter/LumaStatsTest.kt`

**Interfaces:**
- Channel contract (exact names):
  - `MethodChannel('grain/meter')`:
    - `start` → `{textureId: int, previewWidth: int, previewHeight: int, sensorOrientation: int, phoneEqFocal: double}` (`phoneEqFocal` = main back camera focal length × 43.27 / sensor physical diagonal, mm).
    - `stop` → `null` (closes camera, releases texture).
    - `setRegions({crop: [l, t, r, b], spot: [cx, cy, radius]})` — normalized 0..1 in **display (portrait) coordinates**; radius relative to crop width.
  - `EventChannel('grain/meter/stats')`: maps with exactly the `MeterStats` keys of Task 4, at most **15 per second**.
- Dart: `class MeterChannel { Future<PreviewInfo> start(); Future<void> stop(); Future<void> setRegions(Rect crop, Offset spot, double radius); Stream<MeterStats> get stats; }`, `class PreviewInfo { final int textureId; final Size size; final int sensorOrientation; final double phoneEqFocal; }`. Make `MeterChannel` an interface-like class so tests can pass a fake (`abstract class MeterSource` + `MeterChannel implements MeterSource`).
- Kotlin `LumaStats`:
  - `object LumaStats { fun srgbToLinear(y: Int): Double; fun displayToSensor(x: Double, y: Double, orientation: Int): Pair<Double, Double>; fun compute(plane: ByteArray, width: Int, height: Int, rowStride: Int, crop: RectD, spotCx: Double, spotCy: Double, spotR: Double): Stats }` with `data class RectD(l,t,r,b)` and `data class Stats(frame: Double, crop: Double, spot: Double, histogram: IntArray)` — means of linear luma; histogram = 64 bins of gamma Y over the crop. Sample every 2nd pixel in each direction.

Camera2 setup: back camera with largest `LENS_FACING_BACK` main sensor (not ultra-wide; pick the camera whose focal-equivalent is closest to 24–28 mm). Two outputs: the Flutter `SurfaceTexture` from `TextureRegistry` (preview size ≈ 1280×960 or nearest 4:3) and a `YUV_420_888` `ImageReader` at ~320×240. Repeating request `CONTROL_MODE_AUTO`, `CONTROL_AE_MODE_ON`, AF continuous-picture. From each `TotalCaptureResult` read `SENSOR_EXPOSURE_TIME`, `SENSOR_SENSITIVITY`, `CONTROL_POST_RAW_SENSITIVITY_BOOST` (default 100), `LENS_APERTURE`; pair with the latest `LumaStats.compute` of the Y plane; ranges from `SENSOR_INFO_EXPOSURE_TIME_RANGE`/`SENSOR_INFO_SENSITIVITY_RANGE`. All camera work on a dedicated `HandlerThread`; events posted to the main thread.

- [ ] **Step 1: Write failing Kotlin tests**

```kotlin
@Test fun linearizesSrgb() { assertEquals(0.0, LumaStats.srgbToLinear(0), 1e-9); assertEquals(1.0, LumaStats.srgbToLinear(255), 1e-9); assertEquals(0.216, LumaStats.srgbToLinear(128), 0.002) }
@Test fun mapsDisplayToSensorAt90() { val (u, v) = LumaStats.displayToSensor(0.25, 0.1, 90); assertEquals(0.1, u, 1e-9); assertEquals(0.75, v, 1e-9) }
@Test fun cropAndSpotMeansOnSyntheticImage() { /* 40×40 plane: left half Y=0, right half Y=255; crop = right half (in sensor coords) → crop≈1.0, frame≈0.5, spot at (0.75,0.5) → ≈1.0; histogram bin 63 holds all crop samples */ }
```

- [ ] **Step 2: Run** `cd android && ./gradlew :app:testDebugUnitTest` → FAIL.
- [ ] **Step 3: Implement** `LumaStats.kt` (precomputed 256-entry linear LUT). Run tests → PASS.
- [ ] **Step 4: Implement** `CameraSession.kt`, `MeterPlugin.kt`, `MainActivity.kt` registration, manifest changes, and `lib/metering/meter_channel.dart`.
- [ ] **Step 5: Manual check on Pixel 10** — temporary debug screen (removed in Task 8) showing the `Texture` and raw `MeterStats` text. Expected: live preview; exposureNs/sensitivity change when covering the lens; cropLuma > frameLuma when the crop is pointed at a lamp; ≤ 15 events/s.
- [ ] **Step 6: Commit** `feat(metering): Camera2 bridge with AE metadata and luma stats`

---

### Task 7: Meter controller and field of view

**Files:**
- Create: `lib/metering/fov.dart`, `lib/meter/meter_controller.dart`
- Test: `test/metering/fov_test.dart`, `test/meter/meter_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 2–6 (`MeterSource`, `MeterStats`, `readingFrom`, solver, scales).
- Produces:
  - `Rect lensCrop({required Size preview, required double lensFocal, required double phoneEqFocal, double aspect = 2 / 3})` — normalized centred rect with portrait 2:3 aspect whose diagonal is `phoneEqFocal / lensFocal` of the preview diagonal; if that fraction ≥ 1, the largest 2:3 rect that fits. `bool widerThanPhone(double lensFocal, double phoneEqFocal)`.
  - `const focalStops = [12, 14, 16, 18, 20, 21, 24, 28, 35, 40, 45, 50, 55, 58, 60, 70, 85, 90, 100, 105, 120, 135, 150, 180, 200, 250, 300, 400, 500, 600];`
  - `enum MeterMode { aperturePriority, shutterPriority, manual }`
  - `class MeterController extends ChangeNotifier` with constructor `MeterController({required MeterSource source, double calibrationEv = 0, bool viewfinderOn = true})` and members:
    `MeterMode mode; int apertureIndex; int shutterIndex; int isoIndex; int focalIndex; bool viewfinderOn; Offset spot /* normalized display */; MeterArea area; Reading? reading; PreviewInfo? preview; bool cameraDenied; bool held; double calibrationEv /* setter re-derives reading */;`
    `List<ScaleValue> get apertures, shutters, isos;` (free mode, thirds)
    `Solved? get solvedShutter; Solved? get solvedAperture; double? get offset;` (by mode)
    `Future<void> resume(); Future<void> pause();` (start/stop source)
    `void setMode(MeterMode); void setAperture(int); void setShutter(int); void setIso(int); void setFocal(int); void toggleViewfinder(); void tapSpot(Offset normalized); void clearSpot(); void toggleHold();`
  - `toggleHold()`: while `held`, incoming stats do not change `reading` (the user can recompose and still dial values against the frozen reading).
  - Defaults: mode aperturePriority, aperture f/5.6, shutter 1/125, ISO 400, focal 50, viewfinder from settings, area average.
  - `tapSpot` sets `area = spot` and calls `source.setRegions`; changing focal recomputes the crop and calls `setRegions`.
  - Throttle `notifyListeners` from stats to the stream rate; ignore stats while paused.

- [ ] **Step 1: Write failing tests**

```dart
test('50 mm on a 25 mm-equivalent phone crops to half the diagonal', () {
  final r = lensCrop(preview: const Size(3, 4), lensFocal: 50, phoneEqFocal: 25);
  // pixel diagonal 2.5 (half of 5), aspect 2:3 → w 1.3868, h 2.0801 → normalized 0.4623 × 0.5200
  expect(r.center.dx, closeTo(.5, 1e-9)); expect(r.center.dy, closeTo(.5, 1e-9));
  expect(r.width, closeTo(.4623, 1e-3)); expect(r.height, closeTo(.5200, 1e-3));
});
test('lens wider than phone → full fitting 2:3 rect, widerThanPhone true', ...);
test('aperture priority uses latest reading and ISO', () async {
  // FakeSource emits stats giving ev100 = 15; set ISO 100 & f/16 → solvedShutter label '1/125'
});
test('manual mode exposes offset', ...); // f/16, 1/60, ISO100, EV15 → offset +1 (rounded to 1/3: 1.0)
test('pause stops the source and resume restarts it', () async { /* fake records calls: start, stop, start */ });
test('stats received while paused are ignored', ...);
test('tapSpot switches to spot and sends regions', ...);
test('held reading ignores new stats until released', ...);
test('camera permission denied sets cameraDenied and does not throw', ...); // fake start throws PlatformException(code: 'denied')
```

- [ ] **Step 2: Run** `flutter test test/metering/fov_test.dart test/meter/meter_controller_test.dart` → FAIL.
- [ ] **Step 3: Implement** `lib/metering/fov.dart`, `lib/meter/meter_controller.dart`. Native `start` must reject with code `'denied'` when the permission is missing (add to Task 6 code if not there).
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(meter): controller with modes, focal crop and lifecycle`

---

### Task 8: Meter screen

**Files:**
- Create: `lib/ui/theme.dart` (`ThemeData grainTheme()` + `abstract final class GrainColors` with the Global Constraints colours)
- Create: `lib/meter/meter_screen.dart`
- Create: `lib/meter/widgets/header.dart`, `mode_tabs.dart`, `viewfinder.dart`, `value_row.dart`, `offset_scale.dart`, `iso_stepper.dart`, `focal_chip.dart`, `camera_permission.dart`
- Modify: `lib/main.dart` (`GrainApp` → `MeterScreen`; app lifecycle → `controller.pause()/resume()` via `AppLifecycleListener`); remove the Task 6 debug screen.
- Test: `test/meter/meter_screen_test.dart`

**Interfaces:**
- Consumes: `MeterController` (Task 7), `SwipeDial` + `Haptics` (Task 5).
- Produces: `MeterScreen({required MeterController controller, required Haptics haptics})`.

Layout top→bottom (matches mockup; values from Global Constraints):
1. Header: "No camera" (600, 15 px) and "Free mode" subline (13 px, secondary); right: viewfinder toggle (eye / eye-off, 44 px circle; filled ink when on) and settings button (gear icon).
2. Focal chip: "50 mm" — tap opens a bottom sheet containing a `SwipeDial` over `focalStops`.
3. Mode tabs: "Aperture priority" | "Shutter priority" | "Manual"; selected = 600 weight with 2 px ink underline.
4. Viewfinder (if on): `Texture` filling a rounded (18 px) box, flex-grow, min 150 px; the lens crop drawn as the visible area (outside dimmed 60 % ink); spot reticle (circle + 4 ticks) at `spot` when `area == spot`, else centre crosshair for average; corner pill "EV 12.3" (one decimal, "EV —" before the first reading) with "SPOT"/"AVG", and next to it a 44 px lock button that calls `toggleHold()` (filled when held; the EV pill shows "HELD"); tap sets spot, long-press returns to average. If `widerThanPhone`, a small note "Wider than this camera".
5. Value rows (divided by 1 px `#D9D5CD`): label row ("APERTURE"/"SHUTTER", 12 px, letter-spacing .14em) — input rows show "← swipe →", the solved row shows "● METERED" in accent. Input row = `SwipeDial`; solved row = large accent label; over/under flag shows "▲ over" / "▼ under" next to it. Value font 64 px with viewfinder on, 92 px off. In Manual both rows are dials and `OffsetScale` appears: −3…+3 ruler with accent marker and a text "+⅔" / "−1⅓" / "0" (thirds as ⅓ ⅔).
6. ISO stepper: "ISO" label; − / value / + (44 px buttons) stepping `isoScale()`; each step ticks haptics.
No log button in this plan.

Camera denied state: in place of the viewfinder, text "Grain needs the camera to measure light." and a button "Allow camera" (requests permission via `permission_handler`, or opens app settings if permanently denied). With viewfinder off and camera denied, the same message shows above the value rows.

- [ ] **Step 1: Write failing widget tests** (fake `MeterSource`, `FakeHaptics`)

```dart
testWidgets('aperture priority shows metered shutter in accent', ...);   // EV15 ISO100 f/16 → text '1/125' with color GrainColors.accent
testWidgets('switching to Shutter priority swaps dial and result', ...);
testWidgets('manual shows both dials and offset text', ...);            // '+1' case
testWidgets('viewfinder toggle hides Texture and enlarges numerals', ...); // font 92
testWidgets('camera denied shows Allow camera and dials still work', ...);
testWidgets('over-range shows ▲ over', ...);
```

- [ ] **Step 2: Run** `flutter test test/meter/meter_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement** theme, screen and widgets.
- [ ] **Step 4: Run** `flutter test` → all PASS; `flutter analyze` → no issues.
- [ ] **Step 5: Manual check on Pixel 10:** preview shows the 50 mm crop; tapping a bright window raises the EV; swiping aperture ticks on every third and harder on full stops; screen off/on resumes the preview.
- [ ] **Step 6: Commit** `feat(meter): meter screen`

---

### Task 9: Settings

**Files:**
- Create: `lib/settings/settings.dart`, `lib/settings/settings_screen.dart`
- Modify: `lib/main.dart` (load `Settings` before `runApp`; construct `MeterController(calibrationEv: settings.calibrationEv, viewfinderOn: settings.viewfinderOn)`; listen to `settings` to update `controller.calibrationEv`; persist `toggleViewfinder` via `settings.setViewfinderOn`), `lib/meter/meter_controller.dart` (none beyond Task 7 unless wiring needs a callback), `lib/meter/widgets/header.dart` (gear → `SettingsScreen`)
- Test: `test/settings/settings_test.dart`, `test/settings/settings_screen_test.dart`

**Interfaces:**
- Produces: `class Settings extends ChangeNotifier { static Future<Settings> load(); int calibrationThirds /* -9..9 */; double get calibrationEv; bool haptics; bool viewfinderOn; Future<void> setCalibrationThirds(int); Future<void> setHaptics(bool); Future<void> setViewfinderOn(bool); }` backed by `shared_preferences` keys `calibrationThirds`, `haptics`, `viewfinderOn` (defaults 0, true, true). `Settings.inMemory()` for tests.
- `SettingsScreen({required Settings settings})`: "Calibration" with a `SwipeDial` over −3…+3 in thirds (labels "−1⅓", "0", "+⅔"…) and helper text "Compare with a camera you trust and nudge until they agree."; switches "Haptic feedback" and "Open with viewfinder on"; footer "Grain · GPLv3 · version".

- [ ] **Step 1: Write failing tests**: defaults; persistence round-trip via `SharedPreferences.setMockInitialValues`; clamp −9..9; controller reading shifts by calibration (+1 EV when set to +3 thirds); haptics off → `SystemHaptics(enabled: false)` produces no platform calls (test with `TestDefaultBinaryMessengerBinding` handler counting `HapticFeedback.vibrate` calls).
- [ ] **Step 2: Run** `flutter test test/settings` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test` → PASS.
- [ ] **Step 5: Commit** `feat(settings): calibration, haptics, viewfinder default`

---

### Task 10: Release build, performance and accuracy check

**Files:**
- Create: `docs/testing/metering-checklist.md`
- Modify: `android/app/build.gradle(.kts)` (release config: R8 minify + shrink resources; debug-signed for now), `README.md` (install from APK)
- Modify: `android/app/src/main/AndroidManifest.xml` (confirm no INTERNET permission in release)

- [ ] **Step 1: Write `docs/testing/metering-checklist.md`**: for 5 scenes (sunny exterior, open shade, bright interior, dim interior, backlit subject) record a reference reading (a camera's meter or a known handheld meter) vs Grain average and spot; acceptable difference ≤ ⅔ stop after one calibration offset; cold-start timing method (`adb shell am start -W io.github.wladikrin.grain/.MainActivity`, read `TotalTime`, plus time-to-first `EV` value from a `debugPrint` timestamp).
- [ ] **Step 2: Build** `flutter build apk --release --split-per-abi` → `app-arm64-v8a-release.apk` **< 20 MB** (`ls -lh build/app/outputs/flutter-apk/`).
- [ ] **Step 3: Verify permissions** `aapt2 dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → only `android.permission.CAMERA` (and Flutter defaults that are not INTERNET).
- [ ] **Step 4: On Pixel 10** install the release APK; run the checklist; cold start to first EV ≤ 1.5 s; drag dials with "Profile GPU rendering" bars under the 16 ms line (or `flutter run --profile` + DevTools, no jank frames during drag). Record results in the checklist file.
- [ ] **Step 5: Commit** `chore: release build config and metering checklist`
