# Grain 4 — Histogram & polish: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grain is ready for a first release. It gets the optional histogram overlay with the film's latitude band (per roll), the camera-shake warning, the optional click sound, the parked user-visible fixes, SQLite built from vendored source (F-Droid), release signing, metadata, an original app icon, a smaller APK, a full README and one ordered on-device test script for the owner's first session with the Pixel 10.

**Architecture:** The histogram uses the 64-bin gamma-Y histogram of the lens crop that `LumaStats` already computes on every emitted frame, so the native side does no extra work per frame. Pure Dart (`lib/metering/histogram.dart`) maps the bins, the metered luma and the film latitude (`lib/rolls/latitude.dart`) to a `HistogramView`. `MeterController` publishes it on its own `ValueNotifier`, and a `CustomPainter` repaints from that notifier alone, so nothing else rebuilds. The shake warning is a pure predicate shown as a mark in the shutter row's label. The click is a short WAV that Kotlin synthesises at runtime and plays through `SoundPool`; a `Haptics` decorator plays it after the haptic tick. Release work is build config, resources and docs, each pinned by a `dart:io` file test.

**Tech Stack:** Flutter 3.50.1 (Dart 3.14), Kotlin + Camera2 + `android.media.SoundPool`, Drift 2.35 (schema v3), `package:sqlite3` 3.9.1 build hook in `source` mode with a vendored SQLite amalgamation, fontTools (`pyftsubset`, dev-machine tool only, not a build dependency), `rsvg-convert` (dev-machine tool, for the 512 px store icon).

**Spec:** `docs/superpowers/specs/2026-11-21-lightmeter-design.md` (binding; §3 constraints: F-Droid, no proprietary deps, < ~20 MB per ABI, README; §5.1 histogram overlay, swipe-dial click sound, camera-shake warning; §5.4 film type → latitude; §5.5 settings; §6 performance). Plan 3: `docs/superpowers/plans/2026-11-21-grain-3-rolls.md`. Rulings and parked items: `docs/superpowers/plans/2026-11-21-grain-{1-meter,2-gear,3-rolls}-followups.md`.

This is the last plan of v1.

## Global Constraints

Carried over from plans 1–3, unchanged:
- App name **Grain**; package **`io.github.wladikrin.grain`**; **GPLv3** code, **CC0** library; `minSdk` **29**.
- No proprietary dependencies: no Google Play Services, Firebase, ML Kit, analytics or ads. No `INTERNET` permission in the release manifest. Works fully offline.
- Colours via `GrainColors` (ground `#F4F2EE`, ink `#141414`, secondary `#5E5B55`, divider `#D9D5CD`, faded `#8C877E`, accent `#B8321A`). Font Inter Tight. Touch targets ≥ 44 logical px. No shadows or gradients.
- Dial: one value per detent, a haptic tick per detent, stronger on full stops (`SwipeDial`, `Haptics`).
- Performance: cold start to live reading **≤ 1.5 s** on the Pixel 10; dial drag at display refresh with no dropped frames; haptic within one frame of a detent; logging feels instant.
- Snapshot, location, backup and numbering rules from plan 3 stay as they are.

Process (binding for every task):
- Every flutter/dart/gradle command is prefixed `source ~/.grain-env.sh &&`.
- UI code imports `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
- State is plain `ChangeNotifier` (plus `ValueNotifier` for the histogram); no state-management package.
- No device is connected. On-device checks go into **`docs/testing/polish-checklist.md`** (created in Task 1) and never block a task. Task 10 merges every checklist into `docs/testing/device-test-script.md`.
- Drift-generated files (`*.g.dart`, `lib/db/database.steps.dart`, `drift_schemas/`, `test/drift/`) are committed; `build_runner` + `git diff --exit-code` must stay clean.
- Every `implements MeterSource` fake is `test/support/fake_source.dart`'s `FakeMeterSource`; every `LocationSource` fake is `test/support/fake_location.dart`'s `FakeLocation`.

New in this plan:
- **No new pub or Gradle dependency.** SoundPool is part of the Android platform. Any package added anyway needs a pub.dev check (latest version, no Android code that pulls in `com.google.android.gms`) written into this plan's follow-ups.
- Settings defaults: **histogram off**, **camera-shake warning off**, **click sound off**. All three are remembered and carried in the backup, like `haptics`.
- Film latitude, in stops relative to the metered value: **colour and B&W negative −2 … +3**, **slide −½ … +½**. Per-roll override in **half stops**: under **−5 … 0** (stored −10…0 halves), over **0 … +6** (stored 0…12 halves); null means "follow the film type". With no logging roll (none, or meter-only), the band is the negative default.
- Histogram: the existing 64 bins over the lens crop; at most **15 stats events/s** (`MIN_EVENT_INTERVAL_MS = 60`); no extra per-frame native work; drawn only when the viewfinder is on.
- Shake threshold: warn when the shutter time in use, in seconds, is **> 1 / equivalentFocal(focal, format)** (`lib/metering/fov.dart`; the 135 equivalent).
- Click: a 12 ms mono 16-bit 44.1 kHz WAV synthesised in Kotlin at runtime (no committed audio, no third-party sound), played through `SoundPool` with `USAGE_ASSISTANCE_SONIFICATION`. The haptic tick is always issued first, and the click never awaits anything on the UI thread.
- Database **`schemaVersion` 3** (two nullable roll columns), with a generated, tested v2→v3 migration.
- SQLite: built from `third_party/sqlite/sqlite3.c` (the newest 3.54.x amalgamation from sqlite.org, version in `third_party/sqlite/VERSION`) through the sqlite3 hook's `source: source` mode. A build with an empty hook cache downloads nothing.
- Release: `versionName` **1.0.0**, `versionCode` **1** (`pubspec.yaml` `version: 1.0.0+1`). `android/key.properties` and `*.jks` are never committed.
- APK: target **under ~20 MB per ABI**. Baseline: plan-3 arm64 release **22,262,896 bytes** (`--split-per-abi --split-debug-info=build/symbols --obfuscate`). That is the documented release command.
- No third-party artwork: the Flutter-logo launcher PNGs are removed.

## Review Focus

1. **Held reading with the histogram on.** The user holds a reading, then points the phone elsewhere. The histogram, marker and band stay frozen with the held numbers until release. Test in Task 3.
2. **Viewfinder hidden, then shown again, with the histogram on.** Nothing is drawn or computed while the viewfinder is hidden. When it is shown again the histogram returns at once with the remembered setting, without waiting for a toggle. Test in Task 3.
3. **An older backup or roll JSON with no latitude keys.** Import succeeds, the rolls follow their film type's default, and a second import of the same file is still "skipped" (identical). Test in Task 2.
4. **Shake warning with Bulb or with no reading.** Aperture priority solving to B shows the warning. No reading yet (solved shutter null) shows nothing and does not throw. Test in Task 4.
5. **Click sound on, native side missing or still loading** (tests, a first tap right after enabling). The haptic still ticks at once, no exception surfaces, and there is no click until the sound is loaded. Test in Task 5.

## Rulings made while planning (do not re-open)

- **The histogram x-axis is the camera's own gamma-Y axis** (64 bins, as sent), the way camera histograms look. The marker and band edges are placed by encoding linear luma: `x(L) = (255 · srgbEncode(clamp(L, 0, 1)) + 0.5) / 256`. Edges past white or black clamp to the ends. Bar height is `sqrt(count / maxCount)`, so small clusters stay visible.
- **The marker is the metered luma** (`spotLuma` in spot, `cropLuma` in average) of the same stats the reading uses: frozen ones while held.
- **Band anchor:** `[metered · 2^(under − o), metered · 2^(over − o)]`, where `o` is the Manual offset in stops (`MeterController.offset`, + = more exposure; 0 in the priority modes). Calibration is not applied, because it corrects the phone's absolute EV and not the relative tones in the frame.
- **The latitude comes from the logging roll only.** `rolls.logsFor(gear.body)` → `roll.latitude`; otherwise `FilmLatitude.negative` (meter-only means this roll is not in the camera being metered).
- **Histogram placement:** a 128 × 52 lp panel, inset 10 lp from the viewfinder's bottom-right corner. The toggle is a `RoundButton` (`Icons.bar_chart`, "Show histogram" / "Hide histogram") at the viewfinder's top-left. Top-right keeps the EV pill and hold, and bottom-left keeps "Wider than this camera". No settings row: the overlay is toggled where it is seen, and the choice is remembered in `Settings.histogram`.
- **Shake mark:** a 14 lp `Icons.back_hand_outlined` in `GrainColors.secondary`, right after the SHUTTER label, with semantics "Camera shake risk". It goes in the label row so that the dial and numeral layout never shift.
- **The click sound plays on every `Haptics.tick`** (dials, ISO stepper, focal chip, lens cycle, and Log's strong tick), through one `ClickingHaptics` decorator. Volume is 1.0 strong and 0.55 light. Native `SoundPool` exists only while the setting is on.
- **Latitude override storage:** two nullable integer half-stop columns on `rolls`, two `film` keys in roll JSON (`latitudeUnderHalves`, `latitudeOverHalves`, null allowed, absent = null). The JSON `schema` stays 1, because the change is additive and optional.
- **Roll editor latitude:** two `SwipeDial`s ("Under", "Over") show the effective values. A dial the user never touches stays null, so it follows a film-type change. "Use film default" resets both to null.
- **No-aperture phones:** Kotlin falls back to **f/1.8** when `LENS_INFO_AVAILABLE_APERTURES` is missing or empty and the capture result has no `LENS_APERTURE`, and sends `apertureAssumed: true`. The EV line then reads `EV ≈12.3 · AVG`.
- **Spot reticle:** when the true spot radius is under 8 px, a faint ring (ground, alpha 0.5, 1 px) is drawn at 8 px and the ticks start at `max(r, 8) + 4`.
- **Spot taps are clamped to the lens crop** (plan-1 parked "tap in dimmed area meters outside lens crop").
- **Permissions:** a refusal that leaves a permission permanently denied no longer jumps to system settings by itself (plan-1 parked). The camera prompt switches to "Open settings", and the location refusal SnackBar gets an "Open settings" action.
- **Import invariant (plan-3 parked):** after the import transaction and reload, if more than one roll is active, the roll that was active here wins. Imported active rolls are stored finished with `finishTimeFor`, and the count adds to the returned number.
- **Zip export (plan-3 parked):** when a zip is produced, a frame without a zip entry (its file is missing) gets a blank snapshot in CSV and JSON. Without a zip, names stay as stored.
- **SQLite size flags only, no feature omits:** `-Os -ffunction-sections -fdata-sections -Wl,--gc-sections`, and the package's default compile options stay. Dropping FTS5, session or the other defaults could leave `package:sqlite3` bindings pointing at missing symbols on paths no test reaches.
- **Fonts:** Inter Tight's OFL header declares **no Reserved Font Name** (checked: `assets/fonts/OFL.txt` lines 1–6). Subsetting is therefore allowed under OFL 1.1 without a rename, and the subset stays under OFL with the copyright line. The originals move to `tool/fonts/source/` (not bundled); `tool/fonts/subset.sh` regenerates `assets/fonts/`.
- **Signing:** with `android/key.properties`, the release uses that keystore. With env `GRAIN_UNSIGNED=1`, the release is unsigned (for F-Droid and reproducibility checks, via `./gradlew :app:assembleRelease`). Otherwise it is debug-signed, so `flutter build apk` still installs.
- **Icons:** an adaptive icon only (minSdk 29 ≥ 26), from vector XML: background `#F4F2EE`, an ink disc with a hexagonal aperture opening and an accent dot, and a monochrome layer. The PNG mipmaps are deleted.
- **One device script:** `docs/testing/device-test-script.md` replaces `metering-`, `gear-`, `rolls-` and `polish-checklist.md`, which are deleted after merging.
- **The plan-4 follow-ups file is written by the controller** (the session running this plan), not by a task implementer. Task 10 only leaves it a size and verification record.

---

### Task 1: Histogram math, film latitude and half-stop labels

**Files:**
- Create: `lib/rolls/latitude.dart`, `lib/metering/histogram.dart`, `test/rolls/latitude_test.dart`, `test/metering/histogram_test.dart`, `docs/testing/polish-checklist.md`
- Modify: `lib/exposure/stops.dart`, `test/exposure/scales_test.dart` (or wherever `formatStops` is tested; add a group)

**Interfaces:**
- Consumes: `FilmType` (`lib/rolls/model.dart`).
- Produces:
  - `class FilmLatitude { const FilmLatitude({required double under, required double over}); final double under, over; static const negative = FilmLatitude(under: -2, over: 3); static const slide = FilmLatitude(under: -0.5, over: 0.5); static FilmLatitude forType(FilmType? type); }` with value `==`/`hashCode`. `forType(slide)` → `slide`; everything else, null included → `negative`.
  - `const latitudeUnderHalvesMin = -10, latitudeOverHalvesMax = 12;`
  - `String formatHalfStops(int halves)`: `0` → `'0'`, `1` → `'+½'`, `-1` → `'−½'` (U+2212), `6` → `'+3'`, `-5` → `'−2½'`, `7` → `'+3½'`.
  - `double srgbEncode(double linear)`: the inverse of `LumaStats.srgbToLinear` (≤ 0.0031308 → ×12.92, else `1.055·L^(1/2.4) − 0.055`).
  - `double histogramX(double linear)`: `(255 * srgbEncode(linear.clamp(0, 1)) + 0.5) / 256`.
  - `class HistogramView { const HistogramView({required List<double> heights, required double marker, required double bandStart, required double bandEnd}); }`. `heights` has 64 entries in 0..1, and the other fields are x in 0..1.
  - `HistogramView? histogramView({required List<int> bins, required double meteredLuma, required FilmLatitude latitude, double offsetStops = 0})`. It returns null when `bins.length != 64`, every bin is 0, or `meteredLuma` is not finite or is ≤ 0.

- [ ] **Step 1: Write the failing tests**

```dart
// latitude_test.dart
test('film types map to their latitude', () {
  expect(FilmLatitude.forType(FilmType.colorNeg), const FilmLatitude(under: -2, over: 3));
  expect(FilmLatitude.forType(FilmType.bwNeg), FilmLatitude.negative);
  expect(FilmLatitude.forType(FilmType.slide), const FilmLatitude(under: -0.5, over: 0.5));
  expect(FilmLatitude.forType(null), FilmLatitude.negative);
});
// stops: formatHalfStops
test('half stops', () {
  expect([0, 1, -1, 6, -5, 7].map(formatHalfStops), ['0', '+½', '−½', '+3', '−2½', '+3½']);
});
// histogram_test.dart
final bins = List<int>.filled(64, 0)..[10] = 100..[20] = 25;
test('mid grey sits at x 0.4615', () => expect(histogramX(.18), closeTo(.4615, 1e-3)));
test('negative film band around 18 % grey', () {
  final v = histogramView(bins: bins, meteredLuma: .18, latitude: FilmLatitude.negative)!;
  expect(v.marker, closeTo(.4615, 1e-3));
  expect(v.bandStart, closeTo(.2358, 1e-3)); // 0.045
  expect(v.bandEnd, closeTo(.9980, 1e-3));   // 1.44 clamps to white
});
test('slide band', () {
  final v = histogramView(bins: bins, meteredLuma: .18, latitude: FilmLatitude.slide)!;
  expect(v.bandStart, closeTo(.3923, 1e-3));
  expect(v.bandEnd, closeTo(.5414, 1e-3));
});
test('a +1 manual offset moves the band one stop down the scene', () {
  final v = histogramView(bins: bins, meteredLuma: .18, latitude: FilmLatitude.negative, offsetStops: 1)!;
  expect(v.bandStart, closeTo(.1634, 1e-3)); // 0.0225
  expect(v.bandEnd, closeTo(.8636, 1e-3));   // 0.72
  expect(v.marker, closeTo(.4615, 1e-3));
});
test('heights are sqrt of the share of the largest bin', () {
  final v = histogramView(bins: bins, meteredLuma: .18, latitude: FilmLatitude.negative)!;
  expect(v.heights.length, 64);
  expect(v.heights[10], 1.0);
  expect(v.heights[20], closeTo(.5, 1e-9));
  expect(v.heights[0], 0.0);
});
test('no view for empty, short or unmetered input', () {
  expect(histogramView(bins: List.filled(64, 0), meteredLuma: .18, latitude: FilmLatitude.negative), isNull);
  expect(histogramView(bins: List.filled(32, 1), meteredLuma: .18, latitude: FilmLatitude.negative), isNull);
  expect(histogramView(bins: bins, meteredLuma: 0, latitude: FilmLatitude.negative), isNull);
  expect(histogramView(bins: bins, meteredLuma: double.nan, latitude: FilmLatitude.negative), isNull);
});
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls/latitude_test.dart test/metering/histogram_test.dart test/exposure` → FAIL (undefined names).
- [ ] **Step 3: Implement** the Interfaces above. `heights` and the view are immutable lists.
- [ ] **Step 4: Create** `docs/testing/polish-checklist.md` with the title "Grain polish: on-device checklist", the line "Device: Pixel 10, release build" and the table header `| check | expected | result |`.
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, "No issues found!".
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "feat(meter): histogram mapping and film latitude"`

---

### Task 2: Per-roll latitude — schema v3, codec and roll editor

**Files:**
- Modify: `lib/db/database.dart` (`Rolls` + `schemaVersion` 3 + `from2To3`), generated `lib/db/database.g.dart`, `lib/db/database.steps.dart`, `drift_schemas/drift_schema_v3.json`, `test/drift/grain/generated/*` (via `make-migrations`), `test/drift/grain/migration_test.dart`, `lib/rolls/model.dart` (`Roll`), `lib/rolls/roll_repository.dart`, `lib/rolls/codec.dart`, `lib/rolls/ui/roll_editor.dart`
- Test: `test/drift/grain/migration_test.dart`, `test/rolls/model_test.dart`, `test/rolls/codec_test.dart`, `test/db/roll_repository_test.dart`, `test/rolls/ui/roll_editor_test.dart`, `test/backup/backup_test.dart`

**Interfaces:**
- Consumes: `FilmLatitude`, `formatHalfStops`, `latitudeUnderHalvesMin`, `latitudeOverHalvesMax` (Task 1).
- Produces:
  - `Rolls`: `IntColumn get latitudeUnderHalves => integer().nullable()();` and `IntColumn get latitudeOverHalves => integer().nullable()();`. Migration `from2To3: (m, schema) async { await m.addColumn(schema.rolls, schema.rolls.latitudeUnderHalves); await m.addColumn(schema.rolls, schema.rolls.latitudeOverHalves); }`.
  - `Roll`: `final int? latitudeUnderHalves, latitudeOverHalves;` (constructor optional, default null; in `_fields`/`==`); `copyWith(..., int? Function()? latitudeUnderHalves, int? Function()? latitudeOverHalves)`; `FilmLatitude get latitude` (each side: override / 2, or the film type's default).
  - Roll JSON `roll.film` gains `latitudeUnderHalves` and `latitudeOverHalves` (int or null). `rollFromJson` treats an absent key as null and rejects values outside −10…0 / 0…12 with the codec's usual `FormatException` path (`_bad('roll.film.latitudeUnderHalves', 'expected -10..0')`, likewise `'expected 0..12'`).
  - Roll editor: section `'Latitude'` after Push / pull, with two `SwipeDial`s labelled `'Under'` (−10…0 halves) and `'Over'` (0…12 halves) using `formatHalfStops` labels, full stops strong. When the type default applies, the caption reads `'Default for Slide: −½ to +½'` (type label and `formatHalfStops` of the defaults); otherwise a `TextButton('Use film default')` sets both back to null.

- [ ] **Step 1: Write the failing tests**

```dart
// model_test.dart
test('latitude follows the film type unless set', () {
  expect(roll(filmType: FilmType.slide).latitude, FilmLatitude.slide);
  expect(roll(filmType: FilmType.slide, latitudeOverHalves: 2).latitude, const FilmLatitude(under: -0.5, over: 1));
  expect(roll(filmType: FilmType.bwNeg, latitudeUnderHalves: -3).latitude, const FilmLatitude(under: -1.5, over: 3));
});
// codec_test.dart
test('latitude overrides round-trip and absent keys mean the default', () {
  final r = roll(latitudeUnderHalves: -4, latitudeOverHalves: 5);
  expect(rollFromJson(rollToJson(r, const [])).$1, r);
  final old = rollToJson(roll(), const []);
  ((old['roll'] as Map)['film'] as Map)..remove('latitudeUnderHalves')..remove('latitudeOverHalves');
  expect(rollFromJson(old).$1.latitudeUnderHalves, isNull);
});
test('latitude out of range is rejected', () {
  final j = rollToJson(roll(latitudeOverHalves: 5), const []);
  ((j['roll'] as Map)['film'] as Map)['latitudeOverHalves'] = 13;
  expect(() => rollFromJson(j), throwsFormatException);
});
// roll_repository_test.dart
test('latitude overrides persist', ...); // saveRoll(roll(latitudeUnderHalves: -2)) → rolls().single.latitudeUnderHalves == -2, latitudeOverHalves == null
// migration_test.dart — the generated "to 3" simple test plus:
test('migration from v2 to v3 keeps rolls and leaves latitude null', ...); // one v2.RollsData row in → v3.RollsData with identical fields and latitudeUnderHalves/OverHalves null
// backup_test.dart (Review Focus 3)
test('a backup without latitude keys imports and re-imports as identical', ...); // strip both keys from every roll in the backup JSON → import adds the rolls with null overrides; importing the same file again reports them skipped
// roll_editor_test.dart
testWidgets('latitude follows the film type until a dial is moved', (t) async {
  // new roll, pick Slide → dial texts '−½' and '+½', caption 'Default for Slide: −½ to +½'
  // pick Colour negative → '−2' and '+3'
  // drag Over one detent right → '+3½', 'Use film default' visible
  // Save → saved roll latitudeOverHalves == 7, latitudeUnderHalves == null
});
testWidgets('Use film default clears both overrides', ...); // edit a roll with (-4, 5) → tap 'Use film default' → Save → both null
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls test/db test/backup` → FAIL.
- [ ] **Step 3: Implement** the table columns, bump `schemaVersion` to 3, then run `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && dart run drift_dev make-migrations` and add `from2To3` to `stepByStep`.
- [ ] **Step 4: Implement** the `Roll` fields, the repository mapping (both directions), the codec keys and the editor section. Existing callers of `Roll(...)` compile unchanged (optional parameters).
- [ ] **Step 5: Run** `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && flutter test && flutter analyze` → all PASS (including the generated `from 1 to 3` and `from 2 to 3` migration tests), "No issues found!".
- [ ] **Step 6: Commit** `git add lib test drift_schemas && git commit -m "feat(rolls): per-roll film latitude, database v3"`

---

### Task 3: Histogram overlay in the viewfinder

**Files:**
- Create: `lib/meter/widgets/histogram_overlay.dart`, `test/meter/histogram_overlay_test.dart`
- Modify: `lib/meter/meter_controller.dart`, `lib/meter/widgets/viewfinder.dart`, `lib/meter/meter_screen.dart` (`_viewfinder` select + params), `lib/settings/settings.dart`, `lib/main.dart` (`_onSettings`, `_onController`, `_syncRollIso`), `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/CameraSession.kt` (`MIN_EVENT_INTERVAL_MS = 60L`), `docs/testing/polish-checklist.md`
- Test: `test/meter/meter_controller_test.dart` (add `List<int>? histogram` to the `stats()` helper), `test/settings/settings_test.dart`, `test/meter/meter_screen_test.dart`, `test/app_roll_body_test.dart` (or `test/meter/meter_screen_roll_test.dart`, wherever GrainApp + an active roll is already set up)

**Interfaces:**
- Consumes: `histogramView`, `HistogramView`, `FilmLatitude` (Task 1); `Roll.latitude` (Task 2); `RollController.logsFor`, `active`.
- Produces:
  - `MeterController({..., bool histogramOn = false})`; `bool histogramOn`; `void toggleHistogram()` (notifies); `final ValueNotifier<HistogramView?> histogram` (disposed in `dispose`); `FilmLatitude latitude` (initially `FilmLatitude.negative`); `void setLatitude(FilmLatitude l)` (no-op when equal).
  - Private `_updateHistogram()` sets `histogram.value` to `histogramView(bins: s.histogram, meteredLuma: area == spot ? s.spotLuma : s.cropLuma, latitude: latitude, offsetStops: mode == manual ? (offset ?? 0) : 0)` from `held ? _frozenStats : _latest`. When `!histogramOn || !viewfinderOn` or there are no stats, it sets null. It is called from `_onStats` (not held), `toggleHold`, `tapSpot`, `clearSpot`, `setLatitude`, `toggleHistogram`, `toggleViewfinder`, `setMode`, `setAperture`, `setShutter`, `setIso` and `calibrationEv`'s setter.
  - `Settings`: key `'histogram'`, `bool get histogram` (default false), `Future<void> setHistogram(bool v)`, included in `backupMap`/`applyBackupMap`.
  - `class HistogramOverlay extends StatelessWidget { const HistogramOverlay({super.key, required ValueListenable<HistogramView?> view}); }`: a `RepaintBoundary` → `SizedBox(128 × 52)` → `CustomPaint(painter: _HistogramPainter(view))`, where the painter passes `repaint: view` to `super` and reads `view.value` in `paint`. Drawing: rounded rect (radius 8) ink alpha 0.55; band rect ground alpha 0.18; the 64 bars as one `Path` in ground alpha 0.85; marker as a 1.5 px accent line; nothing for a null view.
  - `Viewfinder` gains `bool histogramOn = false`, `VoidCallback? onToggleHistogram` and `ValueListenable<HistogramView?>? histogram`; existing constructions (tests) compile unchanged. The button is shown only when `onToggleHistogram != null`. The top-left `RoundButton(Icons.bar_chart, semanticLabel: histogramOn ? 'Hide histogram' : 'Show histogram', toggled: histogramOn, background: GrainColors.ground)`, and the bottom-right `HistogramOverlay` when `histogramOn && histogram != null`.
  - `GrainApp`: passes `histogramOn: _settings.histogram` into the controller, mirrors the controller to settings in `_onController` and settings to the controller in `_onSettings` (as `viewfinderOn`), and in `_syncRollIso` also calls `_controller.setLatitude(logs ? roll!.latitude : FilmLatitude.negative)`.

- [ ] **Step 1: Write the failing tests**

```dart
// meter_controller_test.dart — c built with histogramOn: true, viewfinderOn: true, resumed
final bins = List<int>.filled(64, 0)..[30] = 10;
test('the histogram marks the metered luma', () async {
  src.emit(stats(region: .18, histogram: bins)); await pump();
  expect(c.histogram.value!.marker, closeTo(.4615, 1e-3));
  c.setLatitude(FilmLatitude.slide);
  expect(c.histogram.value!.bandEnd, closeTo(.5414, 1e-3));
});
test('a held reading freezes the histogram', () async {   // Review Focus 1
  src.emit(stats(region: .18, histogram: bins)); await pump();
  c.toggleHold();
  src.emit(stats(region: .72, histogram: bins)); await pump();
  expect(c.histogram.value!.marker, closeTo(.4615, 1e-3));
  c.toggleHold();
  src.emit(stats(region: .72, histogram: bins)); await pump();
  expect(c.histogram.value!.marker, closeTo(histogramX(.72), 1e-9));
});
test('hidden viewfinder computes nothing, showing it restores the view', () async { // Review Focus 2
  src.emit(stats(region: .18, histogram: bins)); await pump();
  c.toggleViewfinder();
  expect(c.histogram.value, isNull);
  src.emit(stats(region: .18, histogram: bins)); await pump();
  expect(c.histogram.value, isNull);
  c.toggleViewfinder();
  expect(c.histogram.value, isNotNull);
});
test('manual offset shifts the band', () async {
  src.emit(stats(region: .18, histogram: bins)); await pump();
  c.setMode(MeterMode.manual);
  c.setIso(c.isos.indexWhere((v) => v.label == '100'));
  c.setAperture(c.apertures.indexWhere((v) => v.label == '8'));
  c.setShutter(c.shutters.indexWhere((v) => v.label == '1/250'));
  expect(c.offset, 1.0);
  expect(c.histogram.value!.bandStart, closeTo(.1634, 1e-3));
});
test('histogram off publishes null', ...); // histogramOn false → value null after emit; toggleHistogram() → non-null
// settings_test.dart
test('histogram defaults off, persists and travels in the backup', ...); // load() → false; setHistogram(true); reload → true; backupMap()['histogram'] == true; applyBackupMap({'histogram': false}) → false
// meter_screen_test.dart
testWidgets('the histogram toggle shows and hides the overlay', ...); // viewfinder on: tap semantics 'Show histogram' → find.byType(HistogramOverlay) findsOneWidget, label now 'Hide histogram'; viewfinder hidden → findsNothing
// GrainApp test (active slide roll for the selected body)
testWidgets('the logging roll sets the latitude, meter-only falls back to negative', ...); // controller.latitude == FilmLatitude.slide; select another body ("Meter only") → FilmLatitude.negative
testWidgets('the histogram choice is remembered', ...); // tap 'Show histogram' → settings.histogram true
// histogram_overlay_test.dart
testWidgets('repaints from the notifier without rebuilding', ...); // pump HistogramOverlay with a ValueNotifier; count builds of a parent Builder; set value twice → parent build count unchanged, tester.binding has no exception; null value paints nothing (no throw)
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/meter test/settings test/app_roll_body_test.dart` → the new tests FAIL.
- [ ] **Step 3: Implement** the controller, settings, overlay, viewfinder and app wiring. In `meter_screen.dart`'s `_viewfinder` selector, add `c.histogramOn` and pass `histogram: _c.histogram`. The histogram value must not appear in any `_Select` (it repaints through the notifier only).
- [ ] **Step 4: Change** `MIN_EVENT_INTERVAL_MS` to `60L` with the comment `// 15 events/s at 30 and 60 fps (every 2nd / 4th frame); 1000/15+1 gave 10/s at 30 fps.`
- [ ] **Step 5: Append** to `docs/testing/polish-checklist.md`: histogram on, pan from a window to a dark room → the bars move ~15×/s with no dial jank; a slide roll's band is narrow (about a third of the panel at mid grey); hold freezes it; an `adb shell top -H` CPU check of GrainCamera with histogram on vs off → same; a stats rate check (`debugPrint` count over 10 s or Flutter DevTools timeline) → ≤ 15/s.
- [ ] **Step 6: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS, "No issues found!".
- [ ] **Step 7: Commit** `git add lib test android docs/testing && git commit -m "feat(meter): histogram overlay with the film's latitude band"`

---

### Task 4: Camera-shake warning

**Files:**
- Create: `lib/exposure/shake.dart`, `test/exposure/shake_test.dart`
- Modify: `lib/meter/meter_controller.dart`, `lib/meter/widgets/value_row.dart`, `lib/meter/meter_screen.dart` (`_valueRows` selector + `warning:`), `lib/settings/settings.dart`, `lib/settings/settings_screen.dart`, `lib/main.dart`
- Test: `test/meter/meter_controller_test.dart`, `test/meter/meter_screen_test.dart`, `test/settings/settings_test.dart`, `test/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `equivalentFocal(double focal, FilmFormat format)` (`lib/metering/fov.dart`); `MeterController.bulbSeconds`, `solvedShutter`, `shutters`, `shutterIndex`, `focal`, `format`.
- Produces:
  - `bool shakeRisk({required double seconds, required double eqFocal}) => seconds > 1 / eqFocal;`
  - `MeterController.shakeWarning` (bool field, default false, set by the app; its setter notifies when it changes) and `bool get shakeRisk`. That getter is false when the warning is off. Otherwise it takes the seconds in use: aperture priority → `bulbSeconds ?? shutters[solvedShutter.index].value` (false with no solved shutter); shutter priority and manual → `shutters[shutterIndex].value`. The result is `shakeRisk(seconds: …, eqFocal: equivalentFocal(focal, format))`.
  - `ValueRow.input(..., bool warning = false)` and `ValueRow.solved(..., bool warning = false)`. When true, the label row shows `Semantics(label: 'Camera shake risk', child: Icon(Icons.back_hand_outlined, size: 14, color: GrainColors.secondary))` 6 lp after the label text.
  - `Settings`: key `'shakeWarning'`, `bool get shakeWarning` (default false), `setShakeWarning`, in the backup map.
  - Settings screen `_SwitchRow(label: 'Camera-shake warning', subtitle: 'Marks shutter speeds slower than 1/focal length (35 mm equivalent).')` placed after "Haptic feedback".

- [ ] **Step 1: Write the failing tests**

```dart
// shake_test.dart
test('1/focal rule on the 135 equivalent', () {
  expect(shakeRisk(seconds: 1 / 32, eqFocal: 50), isTrue);   // 1/30 dial value 2^-5
  expect(shakeRisk(seconds: 1 / 64, eqFocal: 50), isFalse);  // 1/60
  expect(shakeRisk(seconds: 1 / 64, eqFocal: equivalentFocal(50, FilmFormat.half)), isTrue); // ≈72 mm
  expect(shakeRisk(seconds: 1 / 32, eqFocal: 24), isFalse);
});
// meter_controller_test.dart — free mode (135, focal 50), reading EV 15, shakeWarning = true
test('shutter priority 1/30 at 50 mm warns, 1/60 does not', ...);
test('warning off never warns', ...);
test('Bulb warns, no reading does not', () async { // Review Focus 4
  expect(c.shakeRisk, isFalse);                     // before any stats
  src.emit(stats(exposureNs: 1000000000)); await pump(); // EV100 0
  c.setIso(c.isos.indexWhere((v) => v.label == '100'));
  c.setAperture(c.apertures.indexWhere((v) => v.label == '22'));
  expect(c.bulbSeconds, isNotNull);
  expect(c.shakeRisk, isTrue);
});
// meter_screen_test.dart
testWidgets('the shutter row carries the shake mark', ...); // shakeWarning on, shutter priority 1/30 → find.bySemanticsLabel('Camera shake risk') findsOneWidget; 1/250 → findsNothing
// settings tests: default false, persists, backupMap carries 'shakeWarning'; switch writes through
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/exposure test/meter test/settings` → FAIL.
- [ ] **Step 3: Implement** the Interfaces. Add `c.shakeRisk` to the `_valueRows` selector and pass `warning: _c.shakeRisk` to whichever row shows SHUTTER. `GrainApp` sets `_controller.shakeWarning = _settings.shakeWarning` at construction and in `_onSettings`.
- [ ] **Step 4: Append** to the polish checklist: shake warning on, 50 mm, shutter priority 1/30 → mark visible, quiet (secondary grey, not accent); 1/60 → gone; 6×7 body with 90 mm → mark at 1/60.
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS.
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "feat(meter): optional camera-shake warning on the shutter value"`

---

### Task 5: Optional click sound on detents

**Files:**
- Create: `lib/ui/click_sound.dart`, `test/ui/click_sound_test.dart`, `test/support/fake_click.dart`, `android/app/src/main/kotlin/io/github/wladikrin/grain/sound/ClickWav.kt`, `android/app/src/main/kotlin/io/github/wladikrin/grain/sound/ClickPlugin.kt`, `android/app/src/test/kotlin/io/github/wladikrin/grain/sound/ClickWavTest.kt`
- Modify: `android/app/src/main/kotlin/io/github/wladikrin/grain/MainActivity.kt` (`plugins.add(ClickPlugin())`), `lib/main.dart`, `lib/settings/settings.dart`, `lib/settings/settings_screen.dart`
- Test: `test/settings/settings_test.dart`, `test/settings/settings_screen_test.dart`, `test/smoke_test.dart` (or a new `test/app_click_test.dart`)

**Interfaces:**
- Consumes: `Haptics`, `SystemHaptics` (`lib/ui/haptics.dart`).
- Produces:
  - `abstract class ClickSound { void setEnabled(bool on); void click({required bool strong}); }`
  - `class ClickChannel implements ClickSound` over `MethodChannel('grain/click')`. Methods: `setEnabled` `{'on': bool}`, `play` `{'strong': bool}`. Both are sent with `unawaited(...)`, and `PlatformException`/`MissingPluginException` are caught and ignored. It never returns a Future.
  - `class ClickingHaptics implements Haptics { ClickingHaptics(Haptics inner, ClickSound sound, {bool enabled = false}); bool enabled; }`. The `enabled` setter calls `sound.setEnabled(v)` only when the value changes, and the constructor calls it once when the initial value is true. `tick` calls `inner.tick(strong:)` first, then `sound.click(strong:)` if enabled.
  - `FakeClickSound implements ClickSound` with `final List<String> log` shared optionally with a fake Haptics (entries `'setEnabled true'`, `'click strong'`, `'click light'`).
  - `Settings`: key `'clickSound'`, `bool get clickSound` (default false), `setClickSound`, in the backup map. Settings screen `_SwitchRow(label: 'Click sound', subtitle: 'A soft click at each dial step.')` after "Haptic feedback".
  - `GrainApp({..., ClickSound? clickSound})`: `_haptics = ClickingHaptics(widget.haptics ?? _systemHaptics, widget.clickSound ?? ClickChannel(), enabled: _settings.clickSound)`; `_onSettings` sets `enabled`.
  - Kotlin `object ClickWav { fun bytes(sampleRate: Int = 44100): ByteArray }`: a 44-byte RIFF/WAVE PCM header, mono, 16-bit, `round(0.012 · sampleRate)` samples of `0.5 · 32767 · sin(2π·2400·t) · exp(−t / 0.002)`.
  - Kotlin `ClickPlugin : FlutterPlugin, MethodCallHandler` on `grain/click`. `setEnabled(true)` writes `cacheDir/click.wav` from `ClickWav.bytes()` if it is missing, builds `SoundPool` (max 2 streams, `AudioAttributes` `USAGE_ASSISTANCE_SONIFICATION` / `CONTENT_TYPE_SONIFICATION`) and loads the file; `loaded` turns true in `setOnLoadCompleteListener` on status 0. `play` is a no-op until loaded, then plays at volume 1.0 (strong) or 0.55 (light), priority 1, no loop, rate 1. `setEnabled(false)` and `onDetachedFromEngine` call `release()` and null the pool.

- [ ] **Step 1: Write the failing tests**

```dart
// click_sound_test.dart
test('the haptic ticks before the click', () {
  final log = <String>[];
  final h = ClickingHaptics(LogHaptics(log), FakeClickSound(log), enabled: true);
  h.tick(strong: true); h.tick(strong: false);
  expect(log, ['setEnabled true', 'tick strong', 'click strong', 'tick light', 'click light']);
});
test('disabled: haptics only, no native calls', ...); // enabled false → log == ['tick strong']
test('toggling tells the native side once per change', ...); // enabled = true, true, false → ['setEnabled true', 'setEnabled false']
testWidgets('ClickChannel survives a missing plugin', (t) async { // Review Focus 5
  ClickChannel().click(strong: true);          // no handler registered
  ClickChannel().setEnabled(true);
  await t.pump();
  expect(t.takeException(), isNull);
});
test('ClickChannel sends play with strength', ...); // TestDefaultBinaryMessengerBinding mock handler records ('play', {'strong': true})
// settings: default false, persists, backup carries 'clickSound'; switch writes through
// app: settings.setClickSound(true) → fake log contains 'setEnabled true'; drag the aperture dial one detent → exactly one 'click …'
```

```kotlin
// ClickWavTest.kt
@Test fun headerAndLength() {
    val b = ClickWav.bytes()
    assertEquals("RIFF", String(b, 0, 4)); assertEquals("WAVE", String(b, 8, 4))
    val bb = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN)
    assertEquals(1, bb.getShort(22).toInt())      // mono
    assertEquals(44100, bb.getInt(24))
    assertEquals(16, bb.getShort(34).toInt())
    assertEquals(1058, bb.getInt(40))             // 529 samples
    assertEquals(1102, b.size)
}
@Test fun shortDecayingClick() { // peak in 12000..16384, |last sample| < 200
}
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/ui test/settings && (cd android && ./gradlew :app:testDebugUnitTest)` → FAIL.
- [ ] **Step 3: Implement** the Interfaces. `test/support/fake_click.dart` also holds `LogHaptics implements Haptics` (logs `'tick strong'`/`'tick light'`). Every existing `GrainApp(...)` in tests keeps compiling, because `clickSound` is optional and `ClickChannel` swallows the missing plugin.
- [ ] **Step 4: Append** to the polish checklist: click sound on → a soft click per detent, louder on full stops; fast swipes keep haptics crisp with no lag (compare click off); the first detent right after enabling may be silent; the ringer on silent → note whether the click follows (expected: system-sound volume); the click sound off → `adb shell dumpsys media.audio_flinger | grep -i soundpool` shows no Grain track.
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS.
- [ ] **Step 6: Commit** `git add lib test android docs/testing && git commit -m "feat(ui): optional click sound on dial detents"`

---

### Task 6: Parked fixes — import invariant, zip names, no-aperture phones, spot reticle, crop-clamped taps

**Files:**
- Modify: `lib/rolls/roll_controller.dart` (`importRecords`), `lib/rolls/export.dart`, `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/CameraSession.kt`, `lib/metering/reading.dart` (`MeterStats`), `lib/meter/meter_controller.dart`, `lib/meter/widgets/viewfinder.dart` (`evLine`, painter, tap normalisation), `lib/meter/meter_screen.dart` (pass `estimated`)
- Test: `test/rolls/roll_controller_test.dart`, `test/rolls/export_test.dart`, `test/metering/reading_test.dart`, `test/meter/viewfinder_test.dart`, `android/app/src/test/kotlin/io/github/wladikrin/grain/meter/CameraSessionTest.kt`

**Interfaces:**
- Consumes: `finishTimeFor(Roll, List<Frame>)`, `_mergeStored` (existing); `lensCrop`.
- Produces:
  - `importRecords` (behaviour): after the reload, if `_rolls` has more than one active roll, every active roll whose id is in the imported set is stored finished (`copyWith(status: finished, finishedAt: () => finishTimeFor(r, frames))`, saved through the queue) unless no local roll is active. The returned count includes them.
  - `exportRoll` (behaviour): when `entries.isNotEmpty`, a frame without an `entryOf` entry is listed with `snapshot: () => null`.
  - Kotlin `companion object { const val FALLBACK_APERTURE = 1.8; fun phoneAperture(available: FloatArray?): Double }` → the first positive value, else 1.8. The stats event gains `"apertureAssumed" to (result LENS_APERTURE == null && available list empty or null)`.
  - `MeterStats.apertureAssumed` (bool, `m['apertureAssumed'] == true`, default false); `MeterController.apertureAssumed` → `(held ? _frozenStats : _latest)?.apertureAssumed ?? false`, included in the screen's EV selectors.
  - `evLine({..., bool estimated = false})` → `'EV ≈12.3 · AVG'` when estimated (≈ U+2248 directly before the value; `'EV —'` stays as is).
  - `double? faintRingRadius(double r) => r < 8 ? 8 : null;` and `double spotTickGap(double r) => math.max(r, 8) + 4;` (top level in `viewfinder.dart`; the painter uses both).
  - Viewfinder taps: the normalised point is clamped to `crop` (when non-null) before `onSpot`.

- [ ] **Step 1: Write the failing tests**

```dart
// roll_controller_test.dart (gate the repository's transaction as the existing import tests do)
test('a roll started during an import leaves one active roll', () async {
  // plan holds imported active roll X; importRecords starts; while the transaction is gated, startRoll(local Y)
  // release the gate; await both
  expect(rolls.rolls.where((r) => r.isActive).map((r) => r.id), [y.id]);
  expect(rolls.rolls.firstWhere((r) => r.id == x.id).status, RollStatus.finished);
  expect(await importFuture, 1);
  // a fresh controller over the same repository: still one active roll, y
});
// export_test.dart
test('a frame whose snapshot file is missing has a blank name when a zip is made', () async {
  // f1 snapshot exists, f2 snapshot 'gone.jpg' not on disk, withSnapshots: true
  // csv: f1 row snapshot column 'frame-1.jpg', f2 row ''
  // json: frames[0]['snapshot'] == 'frame-1.jpg', frames[1]['snapshot'] == null
});
// reading_test.dart
test('apertureAssumed is read, absent means false', ...);
// viewfinder_test.dart
test('estimated EV line', () => expect(evLine(ev: 12.34, flag: RangeFlag.ok, area: MeterArea.average, held: false, estimated: true), 'EV ≈12.3 · AVG'));
test('small spots get a faint ring', () {
  expect(faintRingRadius(3), 8); expect(spotTickGap(3), 12);
  expect(faintRingRadius(10), isNull); expect(spotTickGap(10), 14);
});
testWidgets('a tap in the dimmed band meters the nearest crop edge', ...); // as 'tap at the crop centre…' with a 50 mm crop; tap 2 px inside the box's top-left → tapped.dx closeTo(crop.left, 1e-9), tapped.dy closeTo(crop.top, 1e-9)
```

```kotlin
// CameraSessionTest.kt
@Test fun apertureFallback() {
    assertEquals(1.8, CameraSession.phoneAperture(null), 0.0)
    assertEquals(1.8, CameraSession.phoneAperture(floatArrayOf()), 0.0)
    assertEquals(1.65, CameraSession.phoneAperture(floatArrayOf(1.65f)), 1e-6)
}
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls test/metering test/meter && (cd android && ./gradlew :app:testDebugUnitTest)` → FAIL.
- [ ] **Step 3: Implement** the Interfaces.
- [ ] **Step 4: Append** to the polish checklist: Manual mode with the viewfinder on, tap a spot → the ring and ticks are clearly visible, not a dot; tap in the dimmed area → the spot lands on the crop edge; import a backup containing an active roll, start a roll in the seconds the import runs → one active roll afterwards.
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS.
- [ ] **Step 6: Commit** `git add lib test android docs/testing && git commit -m "fix: one active roll after import, blank missing zip names, f/1.8 fallback, visible spot, taps inside the crop"`

---

### Task 7: Permanently denied camera or location → open system settings

**Files:**
- Create: `lib/ui/permissions.dart`, `test/ui/permissions_test.dart`
- Modify: `lib/meter/widgets/camera_permission.dart`, `lib/meter/meter_screen.dart` (types), `lib/rolls/location.dart`, `lib/rolls/location_channel.dart`, `lib/settings/settings_screen.dart`, `lib/main.dart` (pass-through if needed), `test/support/fake_location.dart`
- Test: `test/meter/meter_screen_test.dart`, `test/rolls/location_channel_test.dart`, `test/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `permission_handler` (`PermissionStatus`, `openAppSettings`).
- Produces:
  - `enum PermissionOutcome { granted, denied, blocked }`; `PermissionOutcome outcomeOf(PermissionStatus s)`: granted/limited → granted; permanentlyDenied/restricted → blocked; else denied. `typedef OpenSettings = Future<bool> Function();`
  - `typedef CameraPermissionRequest = Future<PermissionOutcome> Function();` `requestCameraPermission()` returns `outcomeOf(await Permission.camera.request())` and never opens settings itself.
  - `CameraPermissionPrompt` becomes a `StatefulWidget` with `{required VoidCallback onGranted, CameraPermissionRequest request = requestCameraPermission, OpenSettings openSettings = openAppSettings}`. On blocked it shows `'Camera access is off for Grain. Turn it on in the system settings.'` and a button `'Open settings'` that calls `openSettings`; otherwise it shows the current text and `'Allow camera'`. The return to the app already resumes the meter (`enterForeground`).
  - `LocationSource.requestPermission()` → `Future<PermissionOutcome>`. `LocationChannel({..., Future<PermissionOutcome> Function()? request})`. `FakeLocation.outcome` (default granted) replaces `granted`.
  - `SettingsScreen({..., OpenSettings openSettings = openAppSettings})`. On denied the SnackBar stays as it is; on blocked it is `SnackBar(content: Text('Location is off for Grain in the system settings.'), action: SnackBarAction(label: 'Open settings', onPressed: openSettings))`; the switch stays off.

- [ ] **Step 1: Write the failing tests**

```dart
// permissions_test.dart
test('statuses map to outcomes', () {
  expect(outcomeOf(PermissionStatus.granted), PermissionOutcome.granted);
  expect(outcomeOf(PermissionStatus.limited), PermissionOutcome.granted);
  expect(outcomeOf(PermissionStatus.denied), PermissionOutcome.denied);
  expect(outcomeOf(PermissionStatus.permanentlyDenied), PermissionOutcome.blocked);
  expect(outcomeOf(PermissionStatus.restricted), PermissionOutcome.blocked);
});
// meter_screen_test.dart (camera denied state, injected request/openSettings)
testWidgets('a blocked camera offers the system settings', ...); // request → blocked: tap 'Allow camera' → text 'Camera access is off for Grain. Turn it on in the system settings.'; tap 'Open settings' → openSettings called once
testWidgets('a plain refusal keeps asking', ...); // request → denied: 'Allow camera' still shown, openSettings never called
// settings_screen_test.dart
testWidgets('blocked location offers the system settings', ...); // FakeLocation.outcome = blocked → SnackBar text above + action 'Open settings' → tap → openSettings called once; settings.location false
// existing 'refused permission keeps location off' → outcome = denied, text 'Location permission was not granted.'
// location_channel_test.dart: request returning PermissionOutcome.granted / .denied passes through
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/ui test/meter test/settings test/rolls/location_channel_test.dart` → FAIL.
- [ ] **Step 3: Implement** the Interfaces and update every `requestPermission`/`granted` use.
- [ ] **Step 4: Append** to the polish checklist: deny the camera twice → "Open settings" → grant there → back in Grain the preview starts with no restart; the same for location from Settings (the switch can then be turned on).
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS.
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "fix(permissions): a blocked camera or location points to the system settings"`

---

### Task 8: SQLite from vendored source and APK size levers

**Files:**
- Create: `third_party/sqlite/sqlite3.c`, `third_party/sqlite/sqlite3.h`, `third_party/sqlite/sqlite3ext.h`, `third_party/sqlite/VERSION`, `third_party/sqlite/README.md`, `tool/fonts/subset.sh`, `tool/fonts/source/InterTight-{Light,Regular,Medium,SemiBold}.ttf` (moved originals), `assets/fonts/README.md`, `test/release/native_build_test.dart`
- Modify: `pubspec.yaml` (`hooks:`), `assets/fonts/InterTight-*.ttf` (subsets, same names), `docs/testing/polish-checklist.md`

**Interfaces:**
- Consumes: `package:sqlite3` 3.9.1 hook (`lib/src/hook/compile/description.dart`: `source: source`, `path`, `additional_flags`; defaults kept unless `default_options: false`).
- Produces:
  - `pubspec.yaml`, at the top level:

    ```yaml
    hooks:
      user_defines:
        sqlite3:
          # Build SQLite from the vendored amalgamation (F-Droid: no prebuilt
          # binaries, no download). See third_party/sqlite/README.md.
          source: source
          path: third_party/sqlite/sqlite3.c
          additional_flags: [-Os, -ffunction-sections, -fdata-sections, -Wl,--gc-sections]
    ```
  - `third_party/sqlite/VERSION`: one line, e.g. `3.54.0`. Use the newest 3.54.x listed on <https://sqlite.org/download.html> on the day; `package:sqlite3` 3.9.1 bundles 3.54.0 (its CHANGELOG 3.7.1). `README.md` gives the source URL, the SHA3-256 from the download page, the public-domain note (<https://sqlite.org/copyright.html>) and how to update.
  - `tool/fonts/subset.sh`: for each source font, `pyftsubset "$src" --output-file="assets/fonts/$(basename "$src")" --unicodes="U+0020-007E,U+00A0-017F,U+0218-021B,U+2010-2027,U+2030,U+2032-2033,U+2039-203A,U+20AC,U+2122,U+2150-215F,U+2190-2193,U+2212,U+2248,U+25B2,U+25BC,U+25CF" --layout-features='*' --no-hinting --desubroutinize`. Afterwards a Python check (fontTools `TTFont(...).getBestCmap()`) exits non-zero if any of `→←·−…—–×±⅓⅔½≈▲▼●äöüßéñ` is in the source font's cmap but missing from its subset (a glyph Inter Tight never had falls back to the system font and is only reported). Header comment: fontTools version used, and how to install it in a venv (`python3 -m venv ~/.local/share/grain-fonttools && ~/.local/share/grain-fonttools/bin/pip install fonttools`).
  - `assets/fonts/README.md`: subset of Inter Tight (copyright line from `OFL.txt`), still under OFL 1.1, no Reserved Font Name, how to regenerate; glyphs outside the subset (Cyrillic or Greek notes) fall back to the system font.

- [ ] **Step 1: Measure the baseline** at the current HEAD: `source ~/.grain-env.sh && flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate && stat -c %s build/app/outputs/flutter-apk/app-arm64-v8a-release.apk && unzip -lv build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | sort -k1 -n -r | head -12`. Record the size and the top entries in the polish checklist under "APK size" (plan-3 figure: 22,262,896 bytes; `libflutter.so` 11.3 MB, `libapp.so` 6.9 MB, `libsqlite3.so` 1.75 MB, 4 fonts 0.63 MB compressed). Then run `source ~/.grain-env.sh && flutter build apk --release --target-platform android-arm64 --analyze-size` and record the five largest Dart packages.
- [ ] **Step 2: Write the failing test** `test/release/native_build_test.dart`:

```dart
test('SQLite comes from the vendored amalgamation', () {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  expect(pubspec, contains('source: source'));
  expect(pubspec, contains('path: third_party/sqlite/sqlite3.c'));
  final version = File('third_party/sqlite/VERSION').readAsStringSync().trim();
  expect(File('third_party/sqlite/sqlite3.c').readAsStringSync(), contains('#define SQLITE_VERSION        "$version"'));
});
test('the loaded SQLite is the vendored one', () async {
  final db = GrainDatabase(NativeDatabase.memory());
  final v = await db.customSelect('select sqlite_version() as v').getSingle();
  expect(v.read<String>('v'), File('third_party/sqlite/VERSION').readAsStringSync().trim());
  await db.close();
});
test('bundled fonts are subsets under the OFL', () {
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
    expect(File('assets/fonts/InterTight-$w.ttf').lengthSync(), lessThan(120000));
  }
  final head = File('assets/fonts/OFL.txt').readAsLinesSync().take(6).join('\n');
  expect(head, contains('SIL Open Font License'));
  expect(head, isNot(contains('Reserved Font Name')));
});
```

- [ ] **Step 3: Run** `source ~/.grain-env.sh && flutter test test/release` → FAIL.
- [ ] **Step 4: Vendor SQLite:** download the amalgamation zip into the scratch directory, check its SHA3-256 against the download page (`python3 -c "import hashlib,sys;print(hashlib.sha3_256(open(sys.argv[1],'rb').read()).hexdigest())" <zip>`), and copy `sqlite3.c`, `sqlite3.h` and `sqlite3ext.h` into `third_party/sqlite/`. Write `VERSION` and `README.md`, and add the `hooks:` block.
- [ ] **Step 5: Subset the fonts:** `git mv assets/fonts/InterTight-*.ttf tool/fonts/source/`, write `tool/fonts/subset.sh`, run it (it installs nothing; a missing `pyftsubset` prints the venv hint and exits 1), and write `assets/fonts/README.md`.
- [ ] **Step 6: Verify the offline source build:** `rm -rf .dart_tool/hooks_runner/shared/sqlite3 && source ~/.grain-env.sh && HTTPS_PROXY=http://127.0.0.1:9 HTTP_PROXY=http://127.0.0.1:9 flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate`. It succeeds, and `ls .dart_tool/hooks_runner/shared/sqlite3/build 2>/dev/null | grep -c download` prints `0`. Then `unzip -l` on the APK shows `lib/arm64-v8a/libsqlite3.so`. Record its size against 1,749,952 bytes. Also check that `-Os` took effect: if the size did not drop, inspect the hook's compile command in `.dart_tool/hooks_runner/.../sqlite3/` logs; the last `-O` flag must be `-Os`.
- [ ] **Step 7: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS. The host test run compiles the vendored SQLite with the system clang.
- [ ] **Step 8: Record the after-measurement** with the Step 1 command. Write "before → after" for the total and for `libsqlite3.so` plus the four fonts into the polish checklist's "APK size" section. If the total is still > 20,000,000 bytes: note it as within "~", as plan-2 and plan-3 rulings R12 did, and list the remaining contributors from `--analyze-size`. No further lever that removes a feature or a dependency in use.
- [ ] **Step 9: Append** to the polish checklist: the release build on the phone opens existing data (no DB error after the SQLite switch), and creating, editing and exporting a roll all work.
- [ ] **Step 10: Commit** `git add pubspec.yaml third_party tool assets test docs/testing && git commit -m "build: SQLite from vendored source, subset Inter Tight, smaller APK"`

---

### Task 9: Release readiness — signing, version, icon, F-Droid metadata, README

**Files:**
- Create: `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher_round.xml`, `android/app/src/main/res/drawable/ic_launcher_foreground.xml`, `android/app/src/main/res/drawable/ic_launcher_monochrome.xml`, `tool/icon/icon.svg`, `fastlane/metadata/android/en-US/{title.txt,short_description.txt,full_description.txt,changelogs/1.txt,images/icon.png}`, `docs/release.md`, `test/release/release_test.dart`
- Modify: `android/app/build.gradle.kts` (signing), `android/app/src/main/AndroidManifest.xml` (`android:roundIcon="@mipmap/ic_launcher_round"`), `android/app/src/main/res/values/colors.xml` (`ic_launcher_background` `#FFF4F2EE`), `README.md`
- Delete: `android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png` (Flutter logo)

**Interfaces:**
- Consumes: `appVersion` (`lib/version.dart`), `pubspec.yaml` `version`.
- Produces:
  - `build.gradle.kts`: `val keystoreProperties = Properties()`, loaded from `rootProject.file("key.properties")` when it exists. `signingConfigs.create("release")` only when it is loaded (`storeFile = file(keystoreProperties["storeFile"] as String)`, plus `storePassword`, `keyAlias`, `keyPassword`). `release.signingConfig = when { System.getenv("GRAIN_UNSIGNED") == "1" -> null; hasKeystore -> signingConfigs.getByName("release"); else -> signingConfigs.getByName("debug") }`, with the comment: `// No key.properties: debug-signed so `flutter build apk` installs. F-Droid and reproducibility checks build unsigned with GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease. Never commit key.properties or the keystore (both gitignored).`
  - Adaptive icon XML: `<adaptive-icon><background android:drawable="@color/ic_launcher_background"/><foreground android:drawable="@drawable/ic_launcher_foreground"/><monochrome android:drawable="@drawable/ic_launcher_monochrome"/></adaptive-icon>` (round = the same).
  - The foreground vector is 108 × 108 dp, viewport 108. Path 1, ink `#141414`, `fillType="evenOdd"`: disc `M54,26 a28,28 0 1,1 0,56 a28,28 0 1,1 0,-56 Z` plus hexagon `M66,54 L60,64.392 L48,64.392 L42,54 L48,43.608 L60,43.608 Z`. Path 2, accent `#B8321A`: dot `M54,50.5 a3.5,3.5 0 1,1 0,7 a3.5,3.5 0 1,1 0,-7 Z`. The monochrome layer is path 1 only, `#FFFFFFFF`. `tool/icon/icon.svg` is the same geometry on a full `#F4F2EE` square (viewBox 0 0 108 108). `images/icon.png` = `rsvg-convert -w 512 -h 512 tool/icon/icon.svg`.
  - Fastlane copy: title `Grain`. Short description `A film lightmeter: one swipe per stop, your own gear, a log of every frame.` (≤ 80). The full description (≤ 4000) covers: what it does, the metering modes, the gear library, rolls and export, the histogram, and that it is offline with no ads, no tracking and no Play Services. Changelog `1.txt`: `First release.` plus a 3–5 line feature list (≤ 500).
  - `docs/release.md`: the release command; creating a keystore (`keytool -genkeypair -v -keystore ~/grain-release.jks -keyalg RSA -keysize 4096 -validity 10000 -alias grain`) and an `android/key.properties` template (`storeFile=/home/you/grain-release.jks`, `storePassword=…`, `keyAlias=grain`, `keyPassword=…`); a back-up-the-keystore warning; the unsigned build for F-Droid. Reproducible-build notes: pinned Flutter 3.50.1, `ndkVersion` from Flutter, vendored SQLite, `--split-debug-info=build/symbols --obfuscate`, building from a clean checkout path, comparing two clean builds; per-ABI versionCodes (`1000·abi + 1` with `--split-per-abi`). F-Droid notes: no network at build time apart from pub/Gradle dependency resolution, fastlane metadata path, `GRAIN_UNSIGNED=1`.
  - README sections, in order: what Grain is (2–3 sentences from spec §1); Features (bullets: one-swipe dials, average/spot, priority/manual/free mode, viewfinder crop, histogram with film latitude, gear library + QR sharing, rolls and frame log with snapshots, CSV/JSON/zip export, backup, offline/no ads/no tracking); Screenshots ("to be added after the first device session"); Build and run from source (toolchain versions: Flutter 3.50.1, JDK 17, Android SDK + NDK as `flutter doctor` reports, a C compiler for host tests; an "environment script" example equivalent to `~/.grain-env.sh` with `JAVA_HOME`, `ANDROID_HOME`, `PATH`; `flutter pub get`, `flutter run`); Tests (`flutter test`, `flutter analyze`, `cd android && ./gradlew :app:testDebugUnitTest`, the device script path); Release build (pointer to `docs/release.md`); Contributing gear (keep the existing text); Licence (GPLv3 code, CC0 `library/`, OFL font subset, SQLite public domain).

- [ ] **Step 1: Write the failing test** `test/release/release_test.dart`:

```dart
test('version is 1.0.0 build 1 everywhere', () {
  expect(RegExp(r'^version: (.+)$', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1), '$appVersion+1');
  expect(appVersion, '1.0.0');
  expect(File('fastlane/metadata/android/en-US/changelogs/1.txt').existsSync(), isTrue);
});
test('store texts fit F-Droid limits', () {
  String t(String f) => File('fastlane/metadata/android/en-US/$f').readAsStringSync().trim();
  expect(t('title.txt'), 'Grain');
  expect(t('short_description.txt').length, inInclusiveRange(1, 80));
  expect(t('full_description.txt').length, inInclusiveRange(1, 4000));
  expect(t('changelogs/1.txt').length, inInclusiveRange(1, 500));
});
test('store icon is a 512 px PNG', () {
  final b = File('fastlane/metadata/android/en-US/images/icon.png').readAsBytesSync();
  expect(b.sublist(1, 4), 'PNG'.codeUnits);
  final d = ByteData.sublistView(b);
  expect([d.getUint32(16), d.getUint32(20)], [512, 512]);
});
test('adaptive icon with a monochrome layer, no Flutter logo left', () {
  final xml = File('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync();
  expect(xml, allOf(contains('<monochrome'), contains('@drawable/ic_launcher_foreground')));
  final pngs = Directory('android/app/src/main/res').listSync(recursive: true).where((f) => f.path.endsWith('ic_launcher.png'));
  expect(pngs, isEmpty);
  expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:roundIcon="@mipmap/ic_launcher_round"'));
});
test('signing reads key.properties, secrets stay ignored', () {
  final g = File('android/app/build.gradle.kts').readAsStringSync();
  expect(g, allOf(contains('key.properties'), contains('GRAIN_UNSIGNED')));
  final ignore = File('android/.gitignore').readAsStringSync();
  expect(ignore, allOf(contains('key.properties'), contains('*.jks')));
});
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/release/release_test.dart` → FAIL.
- [ ] **Step 3: Implement** the signing, icon resources (delete the PNGs; the `mipmap-*` directories may go if empty), SVG, `rsvg-convert` PNG, fastlane texts, `docs/release.md` and README.
- [ ] **Step 4: Verify the signing paths:** `source ~/.grain-env.sh && flutter build apk --release --split-per-abi --target-platform android-arm64 --split-debug-info=build/symbols --obfuscate && $ANDROID_HOME/build-tools/*/apksigner verify --print-certs build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → `CN=Android Debug`. Then `(cd android && GRAIN_UNSIGNED=1 ./gradlew :app:assembleRelease) && ls build/app/outputs/apk/release/` → `app-release-unsigned.apk`, and `apksigner verify` on it → "DOES NOT VERIFY" / missing signature. With a throwaway keystore in the scratch directory and a temporary `android/key.properties`: `apksigner --print-certs` shows its CN. Delete both afterwards; `git status` shows neither.
- [ ] **Step 5: Verify the icon renders** `source ~/.grain-env.sh && $ANDROID_HOME/build-tools/*/aapt2 dump resources build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -c ic_launcher` → ≥ 1. Append to the polish checklist: launcher icon on the Pixel home screen (ground disc, ink aperture, red dot); themed icons on → monochrome aperture tinted by the wallpaper; app info shows version 1.0.0.
- [ ] **Step 6: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS.
- [ ] **Step 7: Commit** `git add android fastlane tool docs README.md test && git commit -m "build: release signing, adaptive icon, F-Droid metadata, README"`

---

### Task 10: Final verification and the device test script

**Files:**
- Create: `docs/testing/device-test-script.md`
- Delete (after merging): `docs/testing/metering-checklist.md`, `docs/testing/gear-checklist.md`, `docs/testing/rolls-checklist.md`, `docs/testing/polish-checklist.md`
- Modify: `README.md` (the Tests section points to the script)

**Interfaces:**
- Consumes: every checklist row from plans 1–4.
- Produces: `device-test-script.md`. Its header gives the device (Pixel 10), the build (the Task 9 release command, `adb install -r`) and how to record results (`✓ / ✗ + note`). Then numbered steps in this session order: 1 install and first launch (permission, cold-start timing via `adb logcat | grep 'GRAIN first EV'`); 2 metering accuracy and calibration against a reference meter; 3 dials, haptics, click sound; 4 viewfinder, crops, ultra-wide, spot, hold, histogram; 5 shake warning; 6 gear library, favorites, editors, QR/file share and import; 7 rolls: start, log, snapshots, location, edit/insert/delete/renumber, body change; 8 export roll, export/import everything, auto-backup restore; 9 settings and permissions (blocked → Open settings); 10 lifecycle and camera indicator (Home, library, scan); 11 performance (jank with the histogram on, CPU, logging instant); 12 icon, themed icon, version, size. Each step is one row `| # | action | expected | result |` with the expected result copied from the source checklist (reworded only to make it a single action). Every source row appears exactly once, including the recorded APK numbers.

- [ ] **Step 1: Run the full verification** `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && git diff --exit-code -- lib/db drift_schemas test/drift && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS, no diff, "No issues found!".
- [ ] **Step 2: Build the release and check it:** `source ~/.grain-env.sh && flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate && ls -l build/app/outputs/flutter-apk/*.apk && A=build/app/outputs/flutter-apk/app-arm64-v8a-release.apk && $ANDROID_HOME/build-tools/*/aapt2 dump permissions $A && unzip -p $A 'classes*.dex' | grep -a -c -e 'com/google/android/gms' -e 'com/google/firebase'`. Expected: permissions exactly `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` plus Flutter's non-network defaults (e.g. `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`), no `INTERNET`; gms/firebase count `0`. Record the size of all three ABIs.
- [ ] **Step 3: Reproducibility spot check:** copy `$A` aside, run `flutter clean`, rebuild with the same command, and compare `sha256sum` of `lib/arm64-v8a/libapp.so` and `lib/arm64-v8a/libsqlite3.so` extracted from both APKs. Record "identical" or the differing entries in `docs/release.md`'s reproducibility notes (a difference is recorded, not fixed here).
- [ ] **Step 4: Write** `docs/testing/device-test-script.md` as specified, then `git rm` the four checklists and update the README Tests section.
- [ ] **Step 5: Leave the follow-ups record:** put the APK sizes (before plan 4, after Task 8, final per ABI), the gms/permission results, the reproducibility result and any deviation from this plan in the commit message body. **The controller then writes `docs/superpowers/plans/2026-11-21-grain-4-polish-followups.md`** in the plan-3 follow-ups shape ("Decisions made during the build", "Deferred small issues", APK size line); the implementer does not write it.
- [ ] **Step 6: Commit** `git add -A docs README.md && git commit -m "docs: one ordered on-device test script for the first Pixel 10 session"`
