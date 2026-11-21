# Grain 3 — Rolls & logging: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grain keeps a frame-by-frame record: rolls (film, type, box speed, push/pull, body, size, start frame), one-tap "Log frame N" with every exposure value, a reference snapshot from the running camera stream and optional location, standalone "Save reading" when no roll is loaded, a roll view with thumbnails and full editing (insert, delete, renumber), per-roll CSV/JSON/snapshot-zip export, Export/Import everything, and Android auto-backup of the database and settings.

**Architecture:** A pure-Dart rolls layer (`lib/rolls/`) holds the model, numbering, push/pull math, film suggestions and the export codec. `RollController` (plain `ChangeNotifier`) owns the active roll, its frames and the saved readings over a `RollRepository` (Drift tables added to the existing `GrainDatabase`, schemaVersion 2 with a generated, tested v1→v2 migration; in-memory in tests). Logging updates memory and inserts the frame at once; the snapshot (Kotlin: latest YUV frame → upright, lens-cropped JPEG on a background thread, written to `filesDir/snapshots/`) and the location (Kotlin `LocationManager` bridge) are attached when they arrive. `GrainApp` connects `GearController`, `MeterController` and `RollController`: the roll's exposed-at ISO drives the meter, and a body change during a roll asks to finish it or meter only.

**Tech Stack:** Flutter 3.50.1 (Dart 3.14), Kotlin + Camera2 + `android.location.LocationManager`, Drift 2.35 (`make-migrations`, schema verifier), `uuid`, `archive`, existing `share_plus`, `file_selector`, `path_provider`, `permission_handler`, `shared_preferences`.

**Spec:** `docs/superpowers/specs/2026-11-21-lightmeter-design.md` (binding; §5.1 header items 1, 6, 7; §5.4 all; §5.5 backup/snapshots/location; §6 logging instant; §7 roll numbering tests; §9.1 EXIF-ready JSON). Plan 2: `docs/superpowers/plans/2026-11-21-grain-2-gear.md`; rulings and parked items: `docs/superpowers/plans/2026-11-21-grain-2-gear-followups.md`, `docs/superpowers/plans/2026-11-21-grain-1-meter-followups.md`.

**Later plans (not this one):** 4 Histogram & polish (histogram with the roll's film-type latitude, shake warning, click sound, F-Droid release incl. SQLite from source).

## Global Constraints

Carried from plans 1–2 (unchanged):
- App name **Grain**; package **`io.github.wladikrin.grain`**; **GPLv3**; `minSdk` **29**.
- No proprietary dependencies: no Google Play Services, Firebase, ML Kit, analytics, ads. No `INTERNET` permission in the release manifest. Works fully offline.
- Colours via `GrainColors` (ground `#F4F2EE`, ink `#141414`, secondary `#5E5B55`, divider `#D9D5CD`, faded `#8C877E`, accent `#B8321A`). Font Inter Tight. Touch targets ≥ 44 logical px. No shadows/gradients.
- Dial: one value per detent, haptic tick per detent, stronger on full stops (`SwipeDial`, `Haptics`).
- Performance: cold start to live reading **≤ 1.5 s** on the Pixel 10 (now incl. loading the active roll); **logging a frame feels instant** (spec §6) — no `await` on snapshot or location before the UI updates; installed APK **< ~20 MB per ABI** (currently 20.5 MB arm64 with `--split-debug-info=build/symbols --obfuscate`, accepted within "~" in plan 2).

Process (binding for every task):
- Every flutter/dart/gradle command is prefixed `source ~/.grain-env.sh &&`.
- UI code imports `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.
- State is plain `ChangeNotifier`; no state-management package.
- No device is connected: on-device checks go into **`docs/testing/rolls-checklist.md`** (created in Task 1) and never block a task.
- Drift-generated files (`*.g.dart`, `lib/db/database.steps.dart`, `drift_schemas/`, `test/drift/`) are committed; CI's `build_runner` + `git diff --exit-code` must stay clean.
- Every `implements MeterSource` fake is `test/support/fake_source.dart`'s `FakeMeterSource`; it must implement the member Task 5 adds. `FakeGearPlatform` (`test/support/fake_platform.dart`) likewise for Task 11.

New in this plan:
- Dependencies, exact (checked on pub.dev 2026-11-21: both pure Dart, no Android/native code, so no gms): `uuid: ^4.6.0` (latest; already in the lock as a transitive), `archive: ^4.7.1` (latest; drift's `archive: ^4.0.2` is compatible). No `geolocator`, `location`, `image`, `intl`, `csv` or any other package.
- Stable ids: UUID v4 strings from `const Uuid().v4()` for rolls, frames, saved readings and snapshot files.
- Database: `GrainDatabase.schemaVersion` **2**; v1 user profiles, favorites and selection survive the upgrade (generated migration test).
- Snapshot: JPEG, upright, cropped to the lens crop rect, long edge **≤ 1000 px** (never upscaled), quality stepped **85 → 75 → 65 → 55** until **≤ 120 000 bytes** (target ~100 KB); `filesDir/snapshots/<uuid>.jpg`; no EXIF at all (so no GPS); never the gallery/MediaStore. DB stores only the file name.
- Location: **off by default**; off → nothing stored anywhere. Permissions `ACCESS_COARSE_LOCATION` and `ACCESS_FINE_LOCATION` (Ruling L1), requested only when the user turns the setting on.
- Push/pull: **−3…+3 in thirds** (`pushThirds` −9…9); exposed-at ISO = box × 2^(pushThirds/3), snapped to the nearest third-stop ISO label within **6–12800**; out of range → refused in the roll editor.
- Frame numbers: `StartFrame` 00 / 0 / 1 → stored numbers **−1 / 0 / 1**; label of −1 is `"00"`. Nominal frames are 1…size; a number above size shows **`+k`** (k = number − size).

## Review Focus

1. **Late snapshot or location for a frame that changed meanwhile** — the user logs, then at once deletes, renumbers or edits the frame (or backgrounds the app) before the JPEG/fix arrives → it attaches to that frame by id without undoing the edit; for a deleted frame the orphan file is removed. Tests in Task 4.
2. **Snapshot files missing** — after Android auto-restore (snapshots excluded) or a deleted file, frames still name a snapshot → placeholder thumbnail, no exception; export zips and backups skip missing files. Tests in Task 9 and Task 11.
3. **Body differs from the active roll's** — the user picks another body or "No camera", deletes the roll's user body, or restarts with another body selected → the button reads "Save reading", nothing is logged to the roll; choosing the roll's body again resumes logging. Tests in Task 7 and Task 8.
4. **Importing a backup twice, or one with an edited copy of a roll** — second import adds nothing and reports "skipped"; an edited roll with the same id is kept as a copy with new ids; an imported active roll while one is active here becomes finished. Tests in Task 12.
5. **Exposed-at ISO outside the body's ISO dial** (HP5 pushed to 1600 in a Yashica Mat-124G, ISO 25–400) → the meter uses 1600, the ISO stepper reaches it, the first frame logs ISO 1600 with no "differs" marker. Test in Task 7.

## Rulings made while planning (do not re-open)

- **Plan-2 parked items** (controller ruling) are Task 1: in-flight start respects `_lends`; editor `_saving` resets when `saveUser` throws; a lend ending while backgrounded does not reopen the camera.
- **Meter-only is derived, not stored:** the roll logs iff `gear.body?.id == activeRoll.bodyId` (both null for a "No camera" roll). The body-change dialog only asks; "Meter only" changes nothing; picking the roll's body again resumes logging. Startup never shows the dialog.
- **Body-change dialog timing:** asked when the full-screen library route returns (the body id before push ≠ after, and the new body is not the roll's), never over the picker (its pop would close the dialog). "Finish roll N and start a new one" opens the roll editor for the new body; the old roll is finished only when the new one is saved (cancel keeps everything).
- **One active roll:** `startRoll` finishes the current active roll in the same transaction. Finished rolls are not reopened in v1 (their fields and frames stay editable).
- **Roll numbers** = max existing number + 1 (1 for the first); imported rolls keep their number.
- **New-roll defaults:** film stock, type, box ISO and start frame copied from the most recent roll; **push always 0** (a silently inherited push would misexpose a whole roll); size = body's `frames` (36 without a body).
- **Exposed-at ISO beyond the body's ISO range** extends the meter's ISO scale to include it (Review Focus 5); bodies' ISO dials limit their own meters, not the film.
- **Header:** line 1 body; line 2 during a logging roll `Roll 4 · frame 12/36` (`+1` appended past size), meter-only `Meter only · roll 4 is in the Canon A-1`, else the format label as today; line 3 only when push ≠ 0: `HP5 · 400 → 800` (short film name).
- **Navigation:** a `RoundButton` (`Icons.view_list_outlined`, "Rolls and saved readings") sits right of the Log/Save button; the "Start roll" link sits under it when no roll logs. The header text keeps opening the library.
- **Log feedback:** strong haptic tick + SnackBar `Frame 12 logged` / `Reading saved` with **Undo** (deletes it, renumbering following frames).
- **Delete frame shifts following frames down by one; insert blank shifts them up by one;** "Renumber from here" sets one number and numbers the rest consecutively. Positions are a separate sort key, so renumbering never reorders.
- **Frame editing:** every value the photographer set is editable (aperture, shutter, ISO, lens, focal, mode, date/time, note, location removal, snapshot deletion); metered EV, offset and area are read-only records of what the meter said.
- **Logged values:** priority modes log the solved (snapped) value; Bulb logs shutter `B` with `exposureTime` = the solved seconds rounded to 0.1 s; no reading → the solved field and `meteredEv` are null (nothing blocks logging). EXIF values are nominal (`1/1000` → 0.001 s, `f/5.6` → 5.6), not the exact scale values.
- **Time:** stored UTC truncated to whole seconds plus `utcOffsetMinutes` at log time; exports write local time with offset (`2026-11-21T14:03:22+01:00`) so EXIF `DateTimeOriginal` + `OffsetTimeOriginal` can be written later.
- **Snapshot source (controller ruling + refinement):** the METER-mode YUV reader becomes the preview-class size (`choosePreviewSize`, largest 4:3 ≤ 1440 px — a guaranteed PRIV+YUV preview combination); `LumaStats` samples every `max(2, width / 160)`th pixel so stats cost stays as today. A 50 mm crop on a 25 mm-equivalent phone therefore yields ~720 px long edge (never upscaled); 35 mm and wider reach 1000 px.
- **L1 Location permissions:** COARSE and FINE are declared and requested together (`Permission.locationWhenInUse`; Android 12+ lets the user choose approximate). Reason: on Android 10–11 phones without Google's network provider (typical F-Droid users), only GPS exists and it needs FINE. One fresh fix with a **10 s** timeout, else the last known fix if ≤ 30 min old, else none.
- **CSV:** UTF-8 **with BOM** (Excel otherwise garbles umlauts in notes), RFC 4180 quoting, `\r\n` line ends, one header row, roll columns repeated on every row.
- **Backup settings:** the backup carries `haptics`, `viewfinderOn`, `snapshots`; calibration (per phone) and location (needs this phone's permission) are never exported. Import applies settings only when the user ticks "Use the settings from the file" (off by default).
- **Backup profiles:** merged by (kind, id): identical → skipped; different → kept as `<id>-2`… with references in the imported rolls/frames/readings remapped; favorites are unioned.
- **Android backup:** `fullBackupContent` + `dataExtractionRules` include `app_flutter/grain.sqlite` (+ `-wal`, `-journal`) in domain `root` and `FlutterSharedPreferences.xml` in `sharedpref`; exclude `snapshots/` in domain `file`, in cloud backup and device transfer alike.
- **Moves (no behaviour change):** `enum MeterMode` → `lib/exposure/mode.dart` (re-exported by `meter_controller.dart`); `formatStops` → `lib/exposure/stops.dart` (re-exported by `offset_scale.dart`); `scales.dart`'s private `_nominal` becomes public `nominalValue`.

---

### Task 1: Plan-2 parked lifecycle fixes

**Files:**
- Modify: `lib/meter/meter_controller.dart` (`resume` loop, foreground flag), `lib/main.dart` (lifecycle listener), `lib/gear/ui/body_editor.dart`, `lib/gear/ui/lens_editor.dart` (`_save`)
- Create: `docs/testing/rolls-checklist.md`
- Test: `test/meter/meter_controller_gear_test.dart`, `test/app_lend_test.dart`, `test/gear/ui/editors_test.dart`

**Interfaces:**
- Consumes: existing `MeterController.resume/pause/lendCamera`, `_lends`, `FakeMeterSource.startGate`.
- Produces:
  - `Future<void> MeterController.enterBackground()` — sets `_foreground = false`, then `pause()`.
  - `Future<void> MeterController.enterForeground()` — sets `_foreground = true`, then `resume()`.
  - `resume()` records `_wantRunning = true` and returns without starting while `!_foreground` or `_lends > 0` (as today for lends).
  - The start loop keeps the camera only when `_wantRunning && !_disposed && _lends == 0 && _foreground`; the release branch's "start over" condition gets the same guards.
  - `GrainApp` lifecycle: `onResume: enterForeground`; `onInactive`/`onHide`/`onPause: enterBackground`.
  - Editors: `_save` wraps `saveUser` in `try`/`finally` resetting `_saving`; on error shows `'Could not save: $e'` in the existing error line.

- [ ] **Step 1: Write the failing tests**

```dart
// meter_controller_gear_test.dart
test('a start in flight when a lend begins does not keep the camera', () async {
  src.startGate = Completer<void>();
  final started = c.resume();                    // start in flight
  final lend = c.lendCamera(() async {
    unawaited(c.resume());                       // e.g. lifecycle onResume during the lend
    src.startGate!.complete();
    await started;
    expect(src.hasListener, isFalse);
    expect(src.calls, ['start', 'stop']);
  });
  await lend;
  expect(src.calls, ['start', 'stop', 'start']);
  expect(src.hasListener, isTrue);
});
test('a lend ending in the background does not reopen the camera', () async {
  await c.resume();
  await c.lendCamera(() => c.enterBackground());
  expect(src.calls, ['start', 'stop']);
  await c.enterForeground();
  expect(src.calls, ['start', 'stop', 'start']);
});
// app_lend_test.dart
testWidgets('returning from the library while backgrounded keeps the camera closed', (t) async {
  await pumpApp(t);                               // calls == ['start']
  await t.tap(find.byIcon(Icons.photo_camera_outlined)); await settle(t);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused); await settle(t);
  await back(t);
  expect(src.calls, ['start', 'stop']);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed); await settle(t);
  expect(src.calls, ['start', 'stop', 'start']);
});
// editors_test.dart — repository whose saveProfile throws StateError('disk full')
testWidgets('a failed save re-enables Save and says why', ...); // body and lens editor: tap Save → text 'Could not save: Bad state: disk full'; Save TextButton.onPressed != null; route still open
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/meter test/app_lend_test.dart test/gear/ui/editors_test.dart` → the four new tests FAIL.
- [ ] **Step 3: Implement** the Interfaces above.
- [ ] **Step 4: Create** `docs/testing/rolls-checklist.md` (title, "Device: Pixel 10, release build", table `| check | expected | result |`) with rows: open the library, press Home, wait 5 s, return → no camera indicator while away, preview returns; same while a QR scan is open.
- [ ] **Step 5: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, "No issues found!".
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "fix(meter): lends and background keep the camera closed; editors recover from a failed save"`

---

### Task 2: Rolls model, numbering, push/pull and film suggestions

**Files:**
- Create: `lib/exposure/mode.dart`, `lib/exposure/stops.dart`, `lib/rolls/model.dart`, `lib/rolls/numbering.dart`, `lib/rolls/push.dart`, `lib/rolls/film_stocks.dart`, `lib/rolls/ids.dart`
- Modify: `lib/meter/meter_controller.dart` (remove `MeterMode`, `export '../exposure/mode.dart';`), `lib/meter/widgets/offset_scale.dart` (remove `formatStops`, `export '../../exposure/stops.dart';`), `lib/exposure/scales.dart` (`_nominal` → public `nominalValue`), `pubspec.yaml` (`uuid: ^4.6.0`)
- Test: `test/rolls/model_test.dart`, `test/rolls/numbering_test.dart`, `test/rolls/push_test.dart`, `test/rolls/film_stocks_test.dart`

**Interfaces:**
- Consumes: `FilmFormat`, `Body` (gear model), `MeterArea` (`lib/metering/reading.dart`), `isoScale`, `nearestIndex`.
- Produces (`lib/rolls/ids.dart`): `String newId()` → `const Uuid().v4()`; `DateTime atSecond(DateTime t)` → UTC, milliseconds/microseconds dropped.
- Produces (`lib/rolls/model.dart`) — all classes immutable with value `==`/`hashCode` over every field; nullable fields in `copyWith` take `T? Function()?` so `() => null` clears:
  - `enum FilmType { colorNeg('color-neg', 'Colour negative'), bwNeg('bw-neg', 'B&W negative'), slide('slide', 'Slide'); final String id, label; static FilmType? byId(String id); }`
  - `enum StartFrame { doubleZero('00', -1), zero('0', 0), one('1', 1); final String label; final int number; static StartFrame? byLabel(String s); }`
  - `enum RollStatus { active, finished }`
  - `class GeoFix { const GeoFix({required double latitude, required double longitude, double? accuracy}); }`
  - `class Exposure { const Exposure({MeterMode? mode, double? aperture, String? shutter, double? exposureTime, int? iso, String? lensId, String? lensMake, String? lensName, double? focal, double? meteredEv, double? offset, MeterArea? area}); static const blank = Exposure(); bool get isBlank; Exposure copyWith(...); }` — `aperture`/`exposureTime` nominal; `shutter` the dial label (`'1/125'`, `'2"'`, `'B'`); `meteredEv` = EV100 incl. calibration.
  - `class Roll { const Roll({required String id, required int number, required String filmStock, required FilmType filmType, required int boxIso, required int pushThirds, String? bodyId, String bodyMake = '', String bodyModel = '', required FilmFormat format, required int size, required StartFrame startFrame, String notes = '', required RollStatus status, required DateTime startedAt, DateTime? finishedAt, required DateTime updatedAt}); String get bodyName /* '$bodyMake $bodyModel' or 'No camera' when bodyId == null */; int get exposedIso /* exposedIsoFor(boxIso, pushThirds) ?? boxIso */; double get pushStops /* pushThirds / 3 */; bool get isActive; Roll copyWith(...); }`
  - `class Frame { const Frame({required String id, required String rollId, required int position, required int number, Exposure exposure = Exposure.blank, DateTime? takenAt, int? utcOffsetMinutes, String? note, GeoFix? location, String? snapshot, required DateTime updatedAt}); String get label => frameLabel(number); Frame copyWith(...); }` — `snapshot` is a file name (`<uuid>.jpg`), never a path.
  - `class SavedReading { const SavedReading({required String id, String? bodyId, String bodyMake = '', String bodyModel = '', required FilmFormat format, required Exposure exposure, required DateTime takenAt, required int utcOffsetMinutes, String? note, GeoFix? location, String? snapshot, required DateTime updatedAt}); String get bodyName; SavedReading copyWith(...); }`
- Produces (`lib/rolls/numbering.dart`) — inputs and outputs in position order, positions 0…n−1 contiguous, other fields untouched except `updatedAt` of changed frames (= the `now` argument):
  - `String frameLabel(int number)` (−1 → `'00'`); `int? parseFrameLabel(String s)` (`'00'` → −1, `'0'`…`'999'` → int, else null)
  - `int nextNumber(Roll roll, List<Frame> frames)` → `frames.isEmpty ? roll.startFrame.number : frames.last.number + 1`
  - `int overrun(Roll roll, int number)` → `max(0, number - roll.size)`
  - `List<Frame> insertBlankAt(List<Frame> frames, int position, {required String id, required String rollId, required DateTime now})` — the blank takes the number of the frame now at `position` (or `nextNumber` at the end); that frame and all after move +1 in position and number.
  - `List<Frame> deleteAt(List<Frame> frames, int position, {required DateTime now})` — following frames −1 in position and number.
  - `List<Frame> renumberFrom(List<Frame> frames, int position, int number, {required DateTime now})` — `frames[position]` gets `number`, each later frame previous + 1.
- Produces (`lib/rolls/push.dart`):
  - `int? exposedIsoFor(int box, int pushThirds)` — 0 → `box`; else `box·2^(p/3)` snapped to the nearest `isoScale()` label; null when outside `[6·2^(−1/6), 12800·2^(1/6)]`.
  - `String pushLabel(int pushThirds)` — `'Box speed'`, `'Push ${formatStops(p/3)}'`, `'Pull ${formatStops(p/3)}'`.
  - `String filmLine(Roll r)` — `'${shortFilmName(r.filmStock)} · ${r.boxIso}'` plus `' → ${r.exposedIso}'` when `pushThirds != 0`.
  - `String rollStatus(Roll r, int next)` — `'Roll ${r.number} · frame ${frameLabel(next)}/${r.size}'` plus `' +${overrun}'` when > 0.
- Produces (`lib/rolls/film_stocks.dart`): `class FilmStock { const FilmStock(this.name, this.short, this.iso, this.type); }`; `const List<FilmStock> filmStocks`; `String shortFilmName(String stock)` (exact name match → `short`, else `stock`). List (name / short / ISO / type): Ilford HP5 Plus / HP5 / 400 / bw · Ilford FP4 Plus / FP4 / 125 / bw · Ilford Delta 100 / Delta 100 / 100 / bw · Ilford Delta 400 / Delta 400 / 400 / bw · Ilford Delta 3200 / Delta 3200 / 3200 / bw · Ilford Pan F Plus / Pan F / 50 / bw · Ilford XP2 Super / XP2 / 400 / bw · Kentmere Pan 400 / Kentmere 400 / 400 / bw · Kodak Tri-X 400 / Tri-X / 400 / bw · Kodak T-Max 100 / TMX / 100 / bw · Kodak T-Max 400 / TMY / 400 / bw · Fomapan 100 / Foma 100 / 100 / bw · Fomapan 400 / Foma 400 / 400 / bw · Kodak Portra 160 / Portra 160 / 160 / colour · Kodak Portra 400 / Portra 400 / 400 / colour · Kodak Portra 800 / Portra 800 / 800 / colour · Kodak Ektar 100 / Ektar / 100 / colour · Kodak Gold 200 / Gold / 200 / colour · Kodak UltraMax 400 / UltraMax / 400 / colour · Fujifilm 200 / Fuji 200 / 200 / colour · CineStill 800T / 800T / 800 / colour · CineStill 400D / 400D / 400 / colour · Lomography Color Negative 400 / Lomo 400 / 400 / colour · Kodak Ektachrome E100 / E100 / 100 / slide · Fujifilm Velvia 50 / Velvia 50 / 50 / slide · Fujifilm Provia 100F / Provia / 100 / slide.

- [ ] **Step 1: Write the failing tests**

```dart
// push_test.dart
test('exposed-at ISO in thirds', () {
  for (final (box, p, iso) in [(400, 3, 800), (400, 1, 500), (400, 2, 640), (400, -1, 320), (400, -2, 250),
      (400, 9, 3200), (400, -9, 50), (125, 3, 250), (100, 4, 250), (160, 2, 250), (320, 0, 320), (3200, 6, 12800), (50, -3, 25)]) {
    expect(exposedIsoFor(box, p), iso, reason: '$box $p');
  }
  expect(exposedIsoFor(3200, 9), isNull); expect(exposedIsoFor(6, -1), isNull);
});
test('push labels and header lines', () {
  expect(pushLabel(0), 'Box speed'); expect(pushLabel(3), 'Push +1'); expect(pushLabel(4), 'Push +1⅓'); expect(pushLabel(-2), 'Pull −⅔');
  final hp5 = roll(filmStock: 'Ilford HP5 Plus', boxIso: 400, pushThirds: 3, number: 4, size: 36);
  expect(filmLine(hp5), 'HP5 · 400 → 800'); expect(filmLine(hp5.copyWith(pushThirds: 0)), 'HP5 · 400');
  expect(filmLine(hp5.copyWith(filmStock: 'Rollei RPX 400')), 'Rollei RPX 400 · 400 → 800');
  expect(rollStatus(hp5, 12), 'Roll 4 · frame 12/36'); expect(rollStatus(hp5, 37), 'Roll 4 · frame 37/36 +1');
  expect(rollStatus(hp5, -1), 'Roll 4 · frame 00/36');
});
// numbering_test.dart  (frames(numbers) builds frames with positions 0.., ids 'f0'..)
test('first number per start frame', () {
  expect(frameLabel(nextNumber(roll(startFrame: StartFrame.doubleZero), [])), '00');
  expect(frameLabel(nextNumber(roll(startFrame: StartFrame.zero), [])), '0');
  expect(frameLabel(nextNumber(roll(startFrame: StartFrame.one), [])), '1');
});
test('00 start on a 36 roll overruns to 37 and 38', () {
  final r = roll(startFrame: StartFrame.doubleZero, size: 36);
  final fs = frames([for (var n = -1; n <= 36; n++) n]);       // 38 frames: 00, 0, 1…36
  expect(fs.first.label, '00'); expect(fs.last.label, '36');
  expect(nextNumber(r, fs), 37); expect(overrun(r, 37), 1); expect(overrun(r, 38), 2);
  expect(overrun(r, 36), 0); expect(overrun(r, -1), 0);
});
test('insert blank shifts the rest up', () {
  final out = insertBlankAt(frames([1, 2, 3, 4]), 2, id: 'b', rollId: 'r', now: t0);
  expect(out.map((f) => f.number), [1, 2, 3, 4, 5]); expect(out.map((f) => f.position), [0, 1, 2, 3, 4]);
  expect(out[2].id, 'b'); expect(out[2].exposure.isBlank, isTrue); expect(out[3].id, 'f2');
  expect(insertBlankAt(frames([1, 2]), 2, id: 'b', rollId: 'r', now: t0).last.number, 3);
});
test('delete shifts the rest down', () {
  final out = deleteAt(frames([1, 2, 3, 4]), 1, now: t0);
  expect(out.map((f) => f.id), ['f0', 'f2', 'f3']); expect(out.map((f) => f.number), [1, 2, 3]); expect(out.map((f) => f.position), [0, 1, 2]);
});
test('renumber from a frame keeps order', () {
  final out = renumberFrom(frames([-1, 0, 1, 2, 3]), 2, 5, now: t0);
  expect(out.map((f) => f.label), ['00', '0', '5', '6', '7']);
  expect(renumberFrom(frames([5, 6, 7]), 0, -1, now: t0).map((f) => f.label), ['00', '0', '1']);
  expect(out.map((f) => f.id), ['f0', 'f1', 'f2', 'f3', 'f4']);
});
test('parseFrameLabel', () {
  expect(parseFrameLabel('00'), -1); expect(parseFrameLabel('0'), 0); expect(parseFrameLabel('37'), 37);
  for (final s in ['', '-1', '000', 'a', '1.5']) { expect(parseFrameLabel(s), isNull); }
});
// model_test.dart
test('roll derived values', () { /* bodyName 'Canon A-1'; bodyId null → 'No camera'; exposedIso 800; pushStops 1.0 */ });
test('copyWith clears nullable fields', () { /* frame.copyWith(snapshot: () => null).snapshot isNull; other fields equal */ });
test('nominalValue', () { expect(nominalValue('1/125'), .008); expect(nominalValue('2"'), 2); expect(nominalValue('5.6'), 5.6); });
// film_stocks_test.dart
test('suggestions are unique, on the ISO scale, and HP5 is B&W 400', ...); // names unique; every iso is an isoScale() label; shortFilmName('Ilford HP5 Plus') == 'HP5'
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter pub add uuid:^4.6.0 && flutter test test/rolls` → FAIL (undefined).
- [ ] **Step 3: Implement** the files above and the three moves (update imports; `flutter analyze` must show no unused-import issues).
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Commit** `git add lib test pubspec.yaml pubspec.lock && git commit -m "feat(rolls): roll and frame model, numbering, push/pull and film suggestions"`

---

### Task 3: Database v2 — rolls, frames, saved readings, migration

**Files:**
- Modify: `lib/db/database.dart` (tables, `schemaVersion => 2`, `migration`), `lib/db/database.g.dart` (generated)
- Create: `lib/db/database.steps.dart`, `drift_schemas/grain/drift_schema_v2.json`, `test/drift/grain/migration_test.dart`, `test/drift/grain/generated/*` (all from `make-migrations`); `lib/rolls/roll_repository.dart`
- Test: `test/drift/grain/migration_test.dart` (generated, data test filled in), `test/db/roll_repository_test.dart`

**Interfaces:**
- Consumes: Task 2 model; existing tables.
- Produces:
  - `mixin ExposureColumns on Table` — `mode` (`textEnum<MeterMode>().nullable()`), `aperture` real?, `shutter` text?, `exposureTime` real?, `iso` int?, `lensId`/`lensMake`/`lensName` text?, `focal` real?, `meteredEv` real?, `offsetStops` real?, `area` (`textEnum<MeterArea>().nullable()`), `takenAt` dateTime?, `utcOffsetMinutes` int?, `note` text?, `latitude`/`longitude`/`locationAccuracy` real?, `snapshot` text?, `updatedAt` dateTime.
  - `class Rolls extends Table` — `id` text PK, `number` int, `filmStock` text, `filmType` text (`FilmType.id`), `boxIso` int, `pushThirds` int, `bodyId` text?, `bodyMake` text, `bodyModel` text, `format` text (`FilmFormat.id`), `size` int, `startFrame` text (`StartFrame.label`), `notes` text default `''`, `status` `textEnum<RollStatus>()`, `startedAt`, `finishedAt?`, `updatedAt`.
  - `class Frames extends Table with ExposureColumns` — `id` text PK, `rollId` text `references(Rolls, #id, onDelete: KeyAction.cascade)`, `position` int, `number` int; index `frames_roll_position` on (rollId, position), **not unique** (shifting updates would collide).
  - `class SavedReadings extends Table with ExposureColumns` — `id` text PK, `bodyId` text?, `bodyMake`, `bodyModel`, `format` text; `takenAt` is required in the model, nullable in the shared column.
  - `GrainDatabase.migration`: `onCreate: createAll`; `onUpgrade: stepByStep(from1To2: (m, schema) async { createTable rolls, frames, savedReadings; createIndex framesRollPosition })`; `beforeOpen: customStatement('PRAGMA foreign_keys = ON')`. Replace the old "Plan 3 adds…" doc comment with how to add a step.
  - `abstract class RollRepository { Future<List<Roll>> rolls(); Future<void> saveRoll(Roll r); Future<void> deleteRoll(String id) /* its frames too */; Future<List<Frame>> frames(String rollId) /* position order */; Future<void> saveFrames(List<Frame> frames) /* upsert, one transaction */; Future<void> deleteFrames(List<String> ids); Future<List<SavedReading>> readings() /* newest first */; Future<void> saveReading(SavedReading r); Future<void> deleteReading(String id); Future<T> transaction<T>(Future<T> Function() action); }`
  - `class DriftRollRepository implements RollRepository { DriftRollRepository(this.db); }`; `class MemoryRollRepository implements RollRepository` (same semantics; `transaction` just runs).

- [ ] **Step 1: Change the tables and bump the version**, then generate:
Run: `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && dart run drift_dev make-migrations`
Expected: `drift_schemas/grain/drift_schema_v2.json`, `lib/db/database.steps.dart`, `test/drift/grain/migration_test.dart` and `test/drift/grain/generated/schema_v1.dart`/`schema_v2.dart`/`schema.dart` exist. Then wire `onUpgrade: stepByStep(from1To2: …)` from `database.steps.dart` and re-run `dart run build_runner build --delete-conflicting-outputs`.
- [ ] **Step 2: Fill the generated v1→v2 data test** (replace its TODO): v1 rows `UserProfiles(id 'canon-a1-mine', kind 'body', mount 'canon-fd', json '{"x":1}', updatedAt 2026-11-21T10:00Z)`, `Favorites(kind 'body', profileId 'canon-a1')`, `GearSelections(id 0, bodyId 'canon-a1', lensId 'canon-fd-50-1.8', focal 50.0)` → after migrating to v2 the same three rows read back identically, and `rolls`, `frames`, `saved_readings` exist and are empty. Write `test/db/roll_repository_test.dart` (run against both `DriftRollRepository(GrainDatabase(NativeDatabase.memory()))` and `MemoryRollRepository`):

```dart
test('roll round-trips every field', ...);          // incl. bodyId null, finishedAt null, pushThirds -2, startFrame doubleZero
test('frames come back in position order with every exposure field', ...); // incl. location, snapshot, area spot, mode manual, offset -0.67
test('blank frame round-trips as Exposure.blank', ...);
test('deleteRoll removes its frames', ...);
test('saveFrames upserts several frames at once', ...); // shift positions of 3 frames, re-read order
test('readings newest first', ...);
```
- [ ] **Step 3: Run** `source ~/.grain-env.sh && flutter test test/drift test/db` → repository tests FAIL (`RollRepository` undefined); the migration test PASSes.
- [ ] **Step 4: Implement** `lib/rolls/roll_repository.dart` (row ↔ model mapping; unknown enum ids in a row → row skipped with `debugPrint`, never thrown).
- [ ] **Step 5: Run** `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && git status --short && flutter test && flutter analyze` → all PASS, no issues; no unexpected untracked generated files.
- [ ] **Step 6: Commit** `git add lib/db lib/rolls drift_schemas test && git commit -m "feat(db): schema 2 with rolls, frames and saved readings, tested v1 migration"`

---

### Task 4: RollController — rolls, instant logging, late attachments

**Files:**
- Create: `lib/rolls/roll_controller.dart`, `lib/rolls/snapshot_store.dart`, `lib/rolls/location.dart` (interface only), `test/support/fake_location.dart`
- Modify: `lib/settings/settings.dart` (`snapshots`, `location`)
- Test: `test/rolls/roll_controller_test.dart`, `test/settings/settings_test.dart`

**Interfaces:**
- Consumes: Task 2 model/numbering/push, Task 3 `RollRepository`/`MemoryRollRepository`, `Settings`, `Body`.
- Produces:
  - `abstract class LocationSource { Future<GeoFix?> current(); Future<bool> requestPermission(); }`
  - `typedef TakeSnapshot = Future<String?> Function(String id);` — returns the absolute path of the written JPEG or null.
  - `class SnapshotStore { SnapshotStore(this.dir); static Future<SnapshotStore> open() /* getApplicationSupportDirectory()/snapshots, created */; final Directory dir; File file(String name); Future<bool> exists(String name); Future<void> delete(String name) /* missing file is fine */; }`
  - `Settings` gains `bool get snapshots` (default true), `bool get location` (default false), `Future<void> setSnapshots(bool)`, `Future<void> setLocation(bool)`; persisted under keys `snapshots`, `location` like the existing ones (UI in Task 6).
  - `class RollController extends ChangeNotifier`:
    - `RollController({required RollRepository repository, required SnapshotStore snapshots, required Settings settings, TakeSnapshot? takeSnapshot, LocationSource? location, DateTime Function()? now, String Function()? newId})`; `factory RollController.inMemory({required Settings settings, required SnapshotStore snapshots, TakeSnapshot? takeSnapshot, LocationSource? location, DateTime Function()? now})`
    - `Future<void> load()` — rolls, readings, the active roll's frames.
    - `Roll? get active`; `List<Frame> get activeFrames`; `List<Roll> get rolls` (active first, then `startedAt` descending); `List<SavedReading> get readings`; `Roll? get latest` (most recent `startedAt`, for editor defaults); `SnapshotStore get snapshots`.
    - `int? get nextFrameNumber`, `String? get nextLabel`, `int get nextOverrun` (null/0 without an active roll; named so it does not shadow `numbering.dart`'s `nextNumber`).
    - `bool logsFor(Body? body)` → `active != null && active!.bodyId == body?.id`.
    - `Future<Roll> startRoll({required String filmStock, required FilmType filmType, required int boxIso, required int pushThirds, required Body? body, required int size, required StartFrame startFrame, String notes = ''})` — finishes the active roll (status finished, `finishedAt = now`) in the same `transaction`; new `number` = max + 1; body make/model/format copied (no body → `FilmFormat.f135`).
    - `Future<void> updateRoll(Roll r)`, `Future<void> finishRoll(String id)`, `Future<void> deleteRoll(String id)` (deletes its snapshot files).
    - `Future<List<Frame>> framesOf(String rollId)` — cached per roll; changes notify.
    - `Future<Frame> logFrame(Exposure e, {String? note})` — **synchronously** (before its first `await`) appends the frame to memory with `nextFrameNumber`, the next position, `takenAt = atSecond(now())`, `utcOffsetMinutes = now().timeZoneOffset.inMinutes`, and notifies; then persists and returns; then, unawaited: `takeSnapshot(newId())` when `settings.snapshots`, `location.current()` when `settings.location`.
    - `Future<SavedReading> saveReading(Exposure e, {required Body? body, required FilmFormat format, String? note})` — same instant pattern and attachments.
    - `Future<void> updateFrame(Frame f)`, `insertBlank(String rollId, int position)`, `deleteFrame(String rollId, String frameId)`, `renumberFrom(String rollId, int position, int number)` — via Task 2 functions; changed frames saved in one `saveFrames`; a deleted frame's snapshot file is deleted.
    - `Future<void> deleteFrameSnapshot(String rollId, String frameId)`, `updateReading(SavedReading r)`, `deleteReading(String id)`, `deleteReadingSnapshot(String id)`.
    - Attach rule: a snapshot/fix arriving later is applied with `copyWith(snapshot:)`/`copyWith(location:)` to the **current** in-memory record with that id (other fields as they are now); record gone → snapshot file deleted, fix dropped. All repository writes run through one serial `Future` chain so an attach never lands before its insert.

- [ ] **Step 1: Write the failing tests** (`FakeLocation` returns a preset `GeoFix?` and counts calls; snapshots: a `Completer<String?>` per call; store over `Directory.systemTemp.createTempSync()`; fixed clock `2026-11-21T13:03:22.456Z`)

```dart
test('starting a roll numbers it and finishes the active one', ...); // 1st number 1 active; 2nd number 2 active; 1st finished, finishedAt set; rolls.map(number) == [2, 1]
test('logging is instant: memory updates before the first await', () async {
  final f = rolls.logFrame(e);
  expect(rolls.activeFrames.single.label, '1'); expect(rolls.nextLabel, '2');
  final frame = await f; expect(frame.snapshot, isNull);                 // snapshot still pending
  expect(frame.takenAt, DateTime.utc(2026, 11, 21, 13, 3, 22));
  snap.complete('${store.dir.path}/abc.jpg'); await pumpEventQueue();
  expect(rolls.activeFrames.single.snapshot, 'abc.jpg');
  expect((await repo.frames(roll.id)).single.snapshot, 'abc.jpg');
});
test('two quick logs get consecutive numbers', ...);                   // unawaited ×2 → labels ['1', '2'], repo the same after settle
test('a snapshot for a deleted frame removes the file', ...);          // file abc.jpg created; deleteFrame before complete → file gone, no frames
test('a late snapshot keeps an edit made meanwhile', ...);             // updateFrame(note 'tree') before complete → note 'tree' and snapshot 'abc.jpg'
test('snapshots off takes none; location off asks for none', ...);     // takeSnapshot never called; location.calls == 0; frame.location isNull
test('location on stores the fix', ...);                                // GeoFix(52.52, 13.405, 1500) on the frame and in the repo
test('00 start, 36 frames: counter runs on past the size', ...);       // log 38 → labels '00'…'36', nextLabel '37', nextOverrun 1; one more → nextOverrun 2
test('insert, delete and renumber persist', ...);                       // 4 logged; insertBlank(pos 1) → repo numbers [1,2,3,4,5]; deleteFrame(2nd) → [1,2,3,4]; renumberFrom(0, 5) → [5,6,7,8]
test('logsFor follows the roll body', ...);                             // A-1 roll: A-1 true, AE-1 false, null false; no-body roll: null true
test('save reading stores body, exposure and snapshot', ...);
test('deleting a roll deletes its snapshot files', ...);
test('undo of a log is deleteFrame of the last frame', ...);           // nextLabel back to '1'
// settings_test.dart
test('snapshots default on, location default off, both persist', ...); // SharedPreferences.setMockInitialValues({}); load → true/false; set → reload → values
```

- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls/roll_controller_test.dart test/settings/settings_test.dart` → FAIL (undefined).
- [ ] **Step 3: Implement** the Interfaces above.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Commit** `git add lib test && git commit -m "feat(rolls): roll controller with instant logging and late snapshot/location"`

---

### Task 5: Native snapshot from the running stream

**Files:**
- Create: `android/app/src/main/kotlin/io/github/wladikrin/grain/meter/SnapshotEncoder.kt`, `android/app/src/test/kotlin/io/github/wladikrin/grain/meter/SnapshotEncoderTest.kt`
- Modify: `CameraSession.kt` (METER reader size, `requestSnapshot`), `LumaStats.kt` (`step` parameter), `MeterPlugin.kt` (`snapshot` method), `CameraSessionTest.kt`, `LumaStatsTest.kt`; `lib/metering/meter_channel.dart`; `test/support/fake_source.dart`
- Test: `test/metering/meter_channel_test.dart`

**Interfaces:**
- Consumes: `CameraSession.toSensor` (crop in normalized sensor coordinates), `sensorOrientation`, the camera `handler` thread.
- Produces (Dart):
  - `Future<String?> MeterSource.snapshot(String id)`; `MeterChannel.snapshot` invokes `'snapshot'` with `{'id': id}`, returns the path; `PlatformException` → null (logged with `debugPrint`).
  - `FakeMeterSource`: records `'snapshot($id)'` in `calls`; returns `snapshotPath?.call(id)` (field `String? Function(String id)? snapshotPath`); optional `Completer<void>? snapshotGate`.
- Produces (Kotlin):
  - `LumaStats.compute(..., step: Int = 2)`; `LumaStats.samplingStep(width: Int): Int = max(2, width / 160)`; METER mode uses `samplingStep(img.width)`.
  - METER YUV reader size = `choosePreviewSize(yuvSizes)`; `chooseAnalysisSize` and its tests are removed.
  - `data class PixelRect(val l: Int, val t: Int, val r: Int, val b: Int)`
  - `object SnapshotEncoder { const val MAX_EDGE = 1000; const val MAX_BYTES = 120_000; val QUALITIES = intArrayOf(85, 75, 65, 55); fun cropPixels(crop: RectD, width: Int, height: Int): PixelRect /* floor each edge to even, clamp, at least 2×2 */; fun outputSize(cropW: Int, cropH: Int, orientation: Int): Pair<Int, Int> /* upright (90/270 swap), long edge ≤ MAX_EDGE, rounded, never upscaled */; fun yuvToNv21(width: Int, height: Int, y: ByteArray, yRowStride: Int, u: ByteArray, v: ByteArray, uvRowStride: Int, uvPixelStride: Int): ByteArray; fun encode(nv21: ByteArray, width: Int, height: Int, crop: PixelRect, orientation: Int, out: File) /* YuvImage.compressToJpeg(crop, 95) → BitmapFactory with inSampleSize → Matrix rotate+scale → JPEG at QUALITIES until ≤ MAX_BYTES; write out.tmp then rename */ }`
  - `CameraSession.requestSnapshot(out: File, onDone: (String?) -> Unit)` — METER mode only (else `onDone(null)`); the next `onImage` copies Y/U/V into an NV21 array (plus crop and orientation at that moment) and hands it to a single-thread executor that runs `encode`; `onDone` on the main thread; no frame within **1500 ms** → `onDone(null)`; a session closed meanwhile → `onDone(null)`. Never blocks the camera thread beyond the plane copy.
  - `MeterPlugin` `"snapshot"`: no running METER session → `success(null)`; else `File(context.filesDir, "snapshots/$id.jpg")` (dir created), `success(path)` or `success(null)`; an `id` not matching `^[0-9a-f-]{36}$` → `error("bad_args", …)`.

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun cropPixelsAlignsToEvenPixels() {
    assertEquals(PixelRect(360, 270, 1080, 810), SnapshotEncoder.cropPixels(RectD(.25, .25, .75, .75), 1440, 1080))
    assertEquals(PixelRect(332, 248, 666, 500), SnapshotEncoder.cropPixels(RectD(.333, .333, .667, .667), 1000, 750))
    assertEquals(PixelRect(0, 0, 1440, 1080), SnapshotEncoder.cropPixels(RectD(-.1, -.1, 1.1, 1.1), 1440, 1080))
}
@Test fun outputSizeIsUprightAndNeverUpscaled() {
    assertEquals(667 to 1000, SnapshotEncoder.outputSize(1080, 720, 90))
    assertEquals(1000 to 667, SnapshotEncoder.outputSize(1440, 960, 0))
    assertEquals(400 to 600, SnapshotEncoder.outputSize(600, 400, 270))
}
@Test fun yuvToNv21InterleavesVu() {
    val y = ByteArray(8) { it.toByte() }
    val expected = byteArrayOf(0, 1, 2, 3, 4, 5, 6, 7, 20, 10, 21, 11)
    assertArrayEquals(expected, SnapshotEncoder.yuvToNv21(4, 2, y, 4, byteArrayOf(10, 0, 11), byteArrayOf(20, 0, 21), 4, 2))
    assertArrayEquals(expected, SnapshotEncoder.yuvToNv21(4, 2, y, 4, byteArrayOf(10, 11), byteArrayOf(20, 21), 2, 1))
}
// LumaStatsTest
@Test fun samplingStepKeepsCost() { assertEquals(2, LumaStats.samplingStep(320)); assertEquals(9, LumaStats.samplingStep(1440)) }
@Test fun uniformPlaneSameMeansAtAnyStep() { /* 1440×1080 plane of 128: compute(step 2) and compute(step 9) give equal frame/crop/spot */ }
```
```dart
// meter_channel_test.dart (mock 'grain/meter' handler)
test('snapshot passes the id and returns the path', ...);   // args {'id': 'f47ac10b-58cc-4372-a567-0e02b2c3d479'} → '/data/user/0/io.github.wladikrin.grain/files/snapshots/f47ac10b-58cc-4372-a567-0e02b2c3d479.jpg'
test('a failed snapshot answers null', ...);                 // handler throws PlatformException('camera_error') → null
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/metering && (cd android && ./gradlew :app:testDebugUnitTest)` → FAIL (undefined).
- [ ] **Step 3: Implement** Kotlin and Dart per the Interfaces.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest) && flutter build apk --debug` → all PASS, build succeeds.
- [ ] **Step 5: Append** to `docs/testing/rolls-checklist.md`: snapshot appears within ~1 s and matches the viewfinder crop (35 mm and 50 mm lens; portrait upright); snapshot also with viewfinder hidden; file size 60–120 KB (`adb shell run-as io.github.wladikrin.grain ls -l files/snapshots`); 10 rapid logs → 10 files, dial stays smooth; stats still ~15/s and EV unchanged vs plan-2 build at the same scene (±⅙ EV); no new jank when swiping dials while a snapshot encodes; nothing in the gallery.
- [ ] **Step 6: Commit** `git add android lib test docs/testing && git commit -m "feat(metering): lens-cropped JPEG snapshot from the running stream"`

---

### Task 6: Native location bridge and the snapshot/location settings

**Files:**
- Create: `android/app/src/main/kotlin/io/github/wladikrin/grain/location/LocationPlugin.kt`, `.../location/LocationPick.kt`, `android/app/src/test/kotlin/io/github/wladikrin/grain/location/LocationPickTest.kt`, `lib/rolls/location_channel.dart`
- Modify: `MainActivity.kt` (register `LocationPlugin`), `AndroidManifest.xml` (`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`), `lib/settings/settings_screen.dart`, `lib/main.dart`
- Test: `test/settings/settings_screen_test.dart`, `test/rolls/location_channel_test.dart`

**Interfaces:**
- Consumes: `LocationSource`, `GeoFix` (Task 4/2), `Settings.snapshots/location` (Task 4).
- Produces:
  - Channel `grain/location`, method `current` `{timeoutMs: 10000}` → `{latitude, longitude, accuracy?, timeMs}` or null; `error("denied")` without a location permission.
  - Kotlin `object LocationPick { data class Fix(val lat: Double, val lon: Double, val accuracy: Float?, val timeMs: Long); fun freshest(fixes: List<Fix>, nowMs: Long, maxAgeMs: Long): Fix? /* newest within age; equal time → smaller accuracy */ }`. Plugin: last known over providers `fused` (API 31+), `network`, `gps`, `passive` (each `SecurityException`/disabled skipped); one ≤ 2 min old → answer; else `getCurrentLocation` (API 30+) / `requestSingleUpdate` (API 29) on the first enabled of fused/network/gps with the timeout; timeout → `freshest(lastKnown, now, 30 min)` or null.
  - `class LocationChannel implements LocationSource` — `current()` (denied/errors → null); `requestPermission()` → `Permission.locationWhenInUse.request()` granted (or limited).
  - `SettingsScreen({required Settings settings, required Haptics haptics, LocationSource? location})` — new switch rows after "Open with viewfinder on": **"Reference snapshots"** (subtitle "A small picture of the scene with each frame, kept on this phone.") and **"Save location"** (subtitle "Off: no location is stored anywhere."). Turning location on calls `requestPermission()`; granted → `setLocation(true)`; refused → stays off, SnackBar "Location permission was not granted."

- [ ] **Step 1: Write the failing tests**

```kotlin
@Test fun freshestPicksNewestWithinAge() { /* fixes at now-60s (acc 50) and now-10s (acc 2000) → the -10s one; both older than maxAge → null; equal times → accuracy 50 */ }
```
```dart
testWidgets('turning location on asks for permission first', ...);    // fake grants → switch on, settings.location true, calls == 1
testWidgets('refused permission keeps location off', ...);            // → settings.location false, text 'Location permission was not granted.'
testWidgets('snapshots switch toggles the setting', ...);
test('location channel maps a fix and treats denied as none', ...);    // map → GeoFix(52.52, 13.405, 1500); PlatformException('denied') → null
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/settings test/rolls/location_channel_test.dart && (cd android && ./gradlew :app:testDebugUnitTest)` → FAIL.
- [ ] **Step 3: Implement**; wire `SettingsScreen(location: …)` in `lib/main.dart` (`GrainApp({LocationSource? location})`, default `LocationChannel()`).
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS, no issues.
- [ ] **Step 5: Append** to `docs/testing/rolls-checklist.md`: enable location → system dialog offers precise/approximate; refuse → switch off with message; with location on, a logged frame gets a fix within 10 s (indoors: last known); airplane mode + GPS off → frame logs, no location, no delay; revoke permission in system settings → logging still works, no location.
- [ ] **Step 6: Commit** `git add android lib test docs/testing && git commit -m "feat(settings): snapshot and opt-in location settings with a native location bridge"`

---

### Task 7: Meter screen — Log frame / Save reading, roll ISO, header status

**Files:**
- Create: `lib/meter/widgets/log_button.dart`
- Modify: `lib/meter/meter_controller.dart` (`captureExposure`, `setRollIso`), `lib/meter/meter_screen.dart`, `lib/meter/widgets/header.dart` (third line), `lib/meter/widgets/iso_stepper.dart` (marker), `lib/main.dart` (`GrainApp({RollController? rolls})`, roll → meter ISO sync, `main()` builds `DriftRollRepository`, `SnapshotStore.open()`, `takeSnapshot: source.snapshot`)
- Test: `test/meter/meter_controller_roll_test.dart`, `test/meter/meter_screen_roll_test.dart`, `test/meter/meter_screen_layout_test.dart`, `test/smoke_test.dart`

**Interfaces:**
- Consumes: `RollController` (Task 4), `filmLine`, `rollStatus`, `frameLabel` (Task 2), `MeterSource.snapshot` (Task 5), `nominalValue`.
- Produces:
  - `Exposure MeterController.captureExposure()` — mode; aperture and shutter per Rulings (input dials' labels, solved values in priority modes, `B` + rounded Bulb seconds, null when unsolved); `iso` = `int.parse(isos[isoIndex].label)`; lens id/make/name from `gear.lens`; `focal`; `meteredEv` = `reading?.ev100`; `offset` (manual only); `area`.
  - `void MeterController.setRollIso(int? iso)` — no-op when equal to the current roll ISO; else stores it, rebuilds `isos` so it contains `iso` (`isoScale(min: min(gearMin, iso), max: max(gearMax, iso))` when outside the gear's range; `setGear` keeps the extension) and sets `isoIndex = nearestIndex(isos, iso)`; null restores the gear's scale keeping the nearest value.
  - `bool get MeterController.isoDiffersFromRoll` — roll ISO set and the current ISO label ≠ it.
  - `MeterHeader({…, String? detail})` — optional third line, same style as `subtitle`.
  - `IsoStepper({…, bool marked = false})` — when marked, a 6 px accent dot after the value; semantics label `'ISO 1600, differs from the roll'`.
  - `LogButton({required String label, required VoidCallback onPressed, VoidCallback? onStartRoll, required VoidCallback onOpenRolls})` — filled ink button (height 52, label 17 px w500), the rolls `RoundButton` to its right, "Start roll" text link (13 px, secondary, 44 px target) beneath when `onStartRoll` is set.
  - `MeterScreen({…, required RollController rolls, VoidCallback? onStartRoll, VoidCallback? onOpenRolls})` — label `'Log frame ${rolls.nextLabel}'` when `rolls.logsFor(gear.body)`, else `'Save reading'` (with `onStartRoll`). Tap → `logFrame(captureExposure())` or `saveReading(captureExposure(), body: gear.body, format: controller.format)`, strong haptic, SnackBar `'Frame 12 logged'` / `'Reading saved'` with action `Undo`. Header lines per Rulings (`rollStatus(active, nextFrameNumber!)`, meter-only line, `filmLine` when pushed).
  - `GrainApp` keeps `controller.setRollIso(rolls.logsFor(gear.body) ? rolls.active!.exposedIso : null)` in step on roll and gear changes.

- [ ] **Step 1: Write the failing tests**

```dart
// meter_controller_roll_test.dart
test('roll ISO sets the meter and marks a change', ...);        // A-1, setRollIso(800) → iso label '800', isoDiffersFromRoll false; setIso(+1) → '1000', true
test('exposed ISO beyond the body dial extends the scale', () { // Yashica Mat-124G (25–400), setRollIso(1600)
  expect(c.isos.last.label, '1600'); expect(c.isos[c.isoIndex].label, '1600');
  expect(c.captureExposure().iso, 1600); expect(c.isoDiffersFromRoll, isFalse);
  c.setGear(c.gear); expect(c.isos.last.label, '1600');
});
test('capture in aperture priority logs the solved shutter, nominal', ...); // EV 12, ISO 100, f/4 → shutter '1/250', exposureTime .004, aperture 4.0, mode aperturePriority, meteredEv 12
test('capture without a reading leaves solved values empty', ...);     // shutter isNull, meteredEv isNull, aperture 5.6
test('capture in Bulb', ...);                                           // free mode, ISO 100, f/4, EV -2 → shutter 'B', exposureTime 64.0
test('capture in manual records the offset', ...);
// meter_screen_roll_test.dart  (GrainApp with fakes; RollController.inMemory)
testWidgets('no roll: Save reading with Start roll', ...);             // texts 'Save reading', 'Start roll'; tap → readings.length 1, SnackBar 'Reading saved'
testWidgets('active roll: Log frame N counts up and the header shows the roll', ...); // A-1 roll 4, 36, push +1 HP5 → 'Log frame 1', 'Roll 4 · frame 1/36', 'HP5 · 400 → 800'; tap → 'Log frame 2', 'Roll 4 · frame 2/36', src.calls contains 'snapshot(' once
testWidgets('the button updates before the snapshot arrives', ...);    // snapshotGate pending → 'Log frame 2' after one pump
testWidgets('undo removes the frame', ...);                             // tap Undo → 'Log frame 1', activeFrames empty
testWidgets('another body selected: meter only, Save reading', ...);   // roll in A-1, gear AE-1 → 'Save reading', 'Meter only · roll 4 is in the Canon A-1'; select A-1 → 'Log frame 1'
testWidgets('ISO marker shows when the ISO differs from the roll', ...);
// meter_screen_layout_test.dart — add: Manual + viewfinder + active pushed roll at 392×872: no overflow, viewfinder height ≥ 150
// smoke_test.dart — GrainApp builds with default in-memory RollController
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/meter test/smoke_test.dart` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces (`onStartRoll`/`onOpenRolls` stay no-ops until Tasks 8 and 10); update every existing `MeterScreen(...)` construction in tests; `GrainApp`'s default `rolls` is `RollController.inMemory(settings: settings, snapshots: SnapshotStore(Directory.systemTemp.createTempSync('grain-snapshots')))`.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Append** to `docs/testing/rolls-checklist.md`: Log frame feels instant (no visible delay to the new number, ≤ 1 frame); header and bottom row fit at 360 px with "Roll 12 · frame 37/36 +1" and "Delta 3200 · 3200 → 12800"; cold start ≤ 1.5 s with an active roll of 72 frames.
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "feat(meter): log frames and save readings, roll ISO and status in the header"`

---

### Task 8: Roll editor, Start roll and the body-change dialog

**Files:**
- Create: `lib/rolls/ui/roll_editor.dart`, `lib/rolls/ui/body_change_dialog.dart`
- Modify: `lib/main.dart` (`onStartRoll`, body check after lent routes)
- Test: `test/rolls/ui/roll_editor_test.dart`, `test/app_roll_body_test.dart`

**Interfaces:**
- Consumes: `RollController.startRoll/updateRoll/latest/active` (Task 4), `filmStocks`, `exposedIsoFor`, `pushLabel` (Task 2), `formatStops`, `SwipeDial`, `isoScale`, `GearController.body`.
- Produces:
  - `RollEditorScreen({required RollController rolls, required Haptics haptics, Body? body, Roll? initial})` → pops with the saved `Roll` (null on back). `initial == null`: new roll on `body`, defaults per Rulings. Fields: **Film** (`Autocomplete<FilmStock>` over `filmStocks`, case-insensitive substring; choosing one sets type and box ISO; free text allowed, must be non-empty after trim), **Type** (segmented Colour negative / B&W negative / Slide), **Box speed** (dropdown over `isoScale()` labels), **Push / pull** (`SwipeDial` over −9…9 thirds labelled `formatStops`, 0 = `'0'`) with the result line `'Exposed at ISO 800'` (accent) or `'Out of range (ISO 6–12800)'`, **Body** (read-only text `bodyName`), **Frames** (`ChoiceChip`s 12 / 24 / 36 / 72 / Custom; custom → int field 1–200; default body `frames`, a value not in the chips selects Custom), **First frame** (segmented 00 / 0 / 1), **Notes**. A note `'Saving finishes Roll 4.'` when a different roll is active. Save is refused with the error line for an empty film, out-of-range push or invalid custom size. Editing (`initial` set) calls `updateRoll` and keeps id, number, body, status.
  - `Future<BodyChangeChoice?> showBodyChangeDialog(BuildContext context, {required Roll roll})`; `enum BodyChangeChoice { finishAndStart, meterOnly }` — not barrier-dismissible; title `'Roll ${n} is in the ${roll.bodyName}'`; actions `"Meter only (don't log)"` and `'Finish roll ${n} and start a new one'`.
  - `GrainApp`: "Start roll" pushes `RollEditorScreen(body: gear.body)` via `_pushLent`; `_pushLent` records `gear.body?.id` before the push and, when the route returns, if it changed, a roll is active and `!rolls.logsFor(gear.body)` → dialog; `finishAndStart` → push the editor for the new body.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('new roll: HP5 suggestion fills type and box speed', ...);   // type 'hp5' → tap 'Ilford HP5 Plus' → 'B&W negative' selected, box '400'
testWidgets('push +1 shows exposed ISO 800 and saves pushThirds 3', ...); // drag dial 3 detents → 'Exposed at ISO 800'; Save → roll.pushThirds 3, exposedIso 800, status active, number 1
testWidgets('frames default from the body', ...);                         // Pentax 67 (frames 10) → 'Custom' selected with '10'; A-1 → '36'
testWidgets('first frame 00 is stored', ...);                             // tap '00' → roll.startFrame doubleZero
testWidgets('defaults copy the last roll but not its push', ...);         // latest HP5 push +1 → film 'Ilford HP5 Plus', 'Exposed at ISO 400'
testWidgets('refuses empty film and out-of-range push', ...);             // box 3200 push +3 → 'Out of range (ISO 6–12800)', nothing saved
testWidgets('editing keeps number and body', ...);
// app_roll_body_test.dart (GrainApp, fixture library, roll 1 in A-1 active)
testWidgets('choosing another body asks once the library closes', ...);  // library → tap 'Canon AE-1' → dialog title 'Roll 1 is in the Canon A-1'
testWidgets("meter only keeps the roll and saves readings", ...);       // tap "Meter only (don't log)" → 'Save reading'; roll 1 still active
testWidgets('finish and start: old roll finished only when the new one is saved', ...); // tap 'Finish roll 1 and start a new one' → editor; back → roll 1 still active; again + Save → roll 1 finished, roll 2 active in AE-1, 'Log frame 1'
testWidgets('reselecting the same body asks nothing', ...);
testWidgets('Start roll opens the editor and the meter logs afterwards', ...);
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls/ui test/app_roll_body_test.dart` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Commit** `git add lib test && git commit -m "feat(rolls): roll editor, Start roll and the body-change dialog"`

---

### Task 9: Roll view and frame editing

**Files:**
- Create: `lib/rolls/ui/roll_screen.dart`, `lib/rolls/ui/frame_editor.dart`, `lib/rolls/ui/thumbnail.dart`
- Test: `test/rolls/ui/roll_screen_test.dart`, `test/rolls/ui/frame_editor_test.dart`

**Interfaces:**
- Consumes: `RollController` frame/roll operations (Task 4), `RollEditorScreen` (Task 8), `pushLabel`, `frameLabel`, `parseFrameLabel`, `overrun`, `GearController.lensesFor`, `nominalValue`, `MaterialLocalizations.formatMediumDate/formatTimeOfDay` (no `intl`).
- Produces:
  - `SnapshotThumb({required SnapshotStore store, required String? name, double size = 56})` — `Image.file(store.file(name), cacheWidth: (size * dpr).round(), errorBuilder: placeholder)`; null name or missing file → placeholder `Icons.image_not_supported_outlined` in faded on a divider-coloured square; never throws.
  - `RollScreen({required RollController rolls, required GearController gear, required Haptics haptics, required String rollId, void Function(Roll roll)? onExport})` — header block: film stock (20 px w600), **push line prominent**: `pushLabel` + `' · exposed at ISO 800'` in accent 17 px (box speed: `'Box speed · ISO 400'` in ink), `'Canon A-1 · 36 frames · first frame 1'`, started/finished date, notes. Frame rows: thumb, label 22 px (`+k` small accent tag when `overrun > 0`), `'f/5.6 · 1/125'`, lens short name and focal, time, `'ISO 1600'` with accent dot when ≠ `roll.exposedIso`, note (1 line). Blank frame row: `'Blank'` in faded. Tap row → `FrameEditorScreen`. Row menu: "Insert blank before", "Insert blank after", "Renumber from here…" (dialog with text field, `parseFrameLabel`, error "Use 00, 0 or a number"), "Delete snapshot" (when present), "Delete frame" (confirm "Delete frame 12? Later frames move down by one."). App bar menu: "Edit roll", "Export" (→ `onExport`), "Finish roll" (active only; confirm "Finish roll 4?"), "Delete roll" (confirm "Delete roll 4 and its 36 frames?").
  - `FrameEditorScreen({required RollController rolls, required Roll roll, required Frame frame, required List<Lens> lenses})` → pops after `updateFrame`. Fields: aperture (decimal 0.5–128), shutter (text: `1/N`, `N`, `N"`, `B`; stored label normalised to `'1/N'`/`'N"'`/`'B'`, `exposureTime` = `nominalValue`, B keeps the old time or null), ISO (int 1–25600), lens (dropdown: "No lens", `lenses` for the roll body's mount, plus the frame's current lens name if not among them), focal (mm), mode (segmented A / S / M), date and time (`showDatePicker`/`showTimePicker`, local; stored UTC + offset), note, location (`'52.5200, 13.4050 ± 1500 m'` + "Remove location"), snapshot (large `SnapshotThumb` + "Delete snapshot"). Read-only line: `'Metered EV 12.3 · offset +⅔ · spot'`. Invalid field → error under it, Save disabled.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('push is prominent and frames list in order', ...);       // 'Push +1 · exposed at ISO 800'; rows '1','2','3'
testWidgets('overrun frames carry +k', ...);                          // size 2, frames 1..4 → tags '+1', '+2'
testWidgets('ISO different from the roll is marked', ...);            // frame iso 1600 on 800 roll → semantics 'ISO 1600, differs from the roll'
testWidgets('missing snapshot file shows the placeholder', ...);      // snapshot 'gone.jpg' not on disk → Icons.image_not_supported_outlined, no exception
testWidgets('insert blank before frame 2', ...);                      // labels '1','2','3','4'; row 2 'Blank'
testWidgets('delete frame moves later frames down', ...);
testWidgets('renumber from here to 00', ...);                         // first row → '00','0','1'; 'x' → 'Use 00, 0 or a number'
testWidgets('delete snapshot removes the file and the thumb', ...);
testWidgets('finish roll', ...);                                      // confirm → status finished, menu has no 'Finish roll'
// frame_editor_test.dart
testWidgets('edits aperture, shutter, ISO, lens, note', ...);         // '8', '1/60', '400', FD 28, 'pier' → frame.exposure.aperture 8, shutter '1/60', exposureTime closeTo(1/60, 1e-12), iso 400, lensId 'canon-fd-28-2.8', note 'pier'
testWidgets('shutter "2" is stored as 2"', ...);
testWidgets('refuses a bad shutter', ...);                            // '1/0' → error, Save disabled
testWidgets('remove location', ...);
testWidgets('metered values are read-only', ...);                     // no TextField for EV
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls/ui` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Commit** `git add lib test && git commit -m "feat(rolls): roll view with thumbnails, frame editing, insert, delete and renumber"`

---

### Task 10: Rolls and saved readings screens

**Files:**
- Create: `lib/rolls/ui/rolls_screen.dart`, `lib/rolls/ui/reading_screen.dart`
- Modify: `lib/main.dart` (`onOpenRolls` → `_pushLent(RollsScreen)`)
- Test: `test/rolls/ui/rolls_screen_test.dart`

**Interfaces:**
- Consumes: `RollController.rolls/readings/deleteReading/updateReading/deleteReadingSnapshot`, `RollScreen`, `RollEditorScreen`, `SnapshotThumb`.
- Produces:
  - `RollsScreen({required RollController rolls, required GearController gear, required Haptics haptics, void Function(Roll roll)? onExport})` — title "Rolls"; two tabs **"Rolls"** and **"Saved readings"**. Rolls tab: "+" in the app bar ("New roll" → editor for `gear.body`); rows `'Roll 4 · HP5'`, `'Push +1 · Canon A-1 · 12/36'` (frames logged/size), date; active row tagged "Active" (accent); tap → `RollScreen`. Empty: "No rolls yet. Start one from the meter or with +." Readings tab: rows thumb, `'f/5.6 · 1/125 · ISO 400'`, `'Canon A-1 · FD 50/1.8'`, date + time; tap → `ReadingScreen`. Empty: "No saved readings. With no roll loaded, the meter's button saves one."
  - `ReadingScreen({required RollController rolls, required String readingId})` — snapshot, all values, location, editable note (saved on leave), "Delete snapshot", "Delete reading" (confirm).

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('active roll first, then finished newest first', ...);   // rows 'Roll 3 · …' (Active), 'Roll 2', 'Roll 1'
testWidgets('roll row shows push and frame count', ...);              // 'Push +1 · Canon A-1 · 12/36'
testWidgets('tapping a roll opens the roll view', ...);
testWidgets('saved readings list and delete', ...);                   // 2 readings → tap one → 'Delete reading' → confirm → 1 left
testWidgets('reading note is saved on leave', ...);
testWidgets('empty states', ...);
testWidgets('the meter rolls button opens Rolls and releases the camera', ...); // GrainApp: tap semantics 'Rolls and saved readings' → 'Rolls'; src.calls ends with 'stop'
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/rolls/ui/rolls_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Commit** `git add lib test && git commit -m "feat(rolls): rolls and saved readings screens"`

---

### Task 11: Per-roll export — CSV, JSON, snapshot zip

**Files:**
- Create: `lib/rolls/codec.dart`, `lib/rolls/export.dart`, `lib/rolls/ui/export_sheet.dart`
- Modify: `lib/gear/platform.dart` (`sharePaths`, `pickFilePath`, `exportDirectory`), `test/support/fake_platform.dart`, `lib/main.dart` (`onExport`), `pubspec.yaml` (`archive: ^4.7.1`)
- Test: `test/rolls/codec_test.dart`, `test/rolls/export_test.dart`

**Interfaces:**
- Consumes: Task 2 model, `frameLabel`, `parseFrameLabel`, `slugify` (`lib/gear/ids.dart`), `SnapshotStore`, `nominalValue`.
- Produces (`lib/rolls/codec.dart`):
  - `class RollFormatException implements Exception { RollFormatException(this.message); final String message; }`
  - `String isoWithOffset(DateTime utc, int offsetMinutes)` → `'2026-11-21T14:03:22+01:00'` (`-05:30` style for negatives, `+00:00` for 0).
  - `Map<String, Object?> rollToJson(Roll r, List<Frame> frames)` / `(Roll, List<Frame>) rollFromJson(Object? json)`; `Map<String, Object?> readingToJson(SavedReading r)` / `SavedReading readingFromJson(Object? json)` — round-trip exact; parse errors throw `RollFormatException('<path>: <message>')`.
  - Roll JSON (key order fixed): `{"schema":1,"type":"grain-roll","roll":{"id","number","film":{"stock","type","boxIso","pushThirds","pushStops","exposedIso"},"body":{"id","make","model","format"},"size","startFrame","status","startedAt","finishedAt","notes","updatedAt"},"frames":[{"id","position","number" /* label string */,"takenAt" /* isoWithOffset or null */,"utcOffsetMinutes","aperture","shutter","exposureTime","iso","lens":{"id","make","name"} | null,"focalLength","mode" /* "aperture-priority"|"shutter-priority"|"manual"|null */,"meteredEv","offset","area","note","location":{"latitude","longitude","accuracy"} | null,"snapshot","updatedAt"}]}`. Doc comment maps fields to EXIF: aperture→FNumber, exposureTime→ExposureTime, iso→PhotographicSensitivity, focalLength→FocalLength, lens→LensMake/LensModel, body→Make/Model, takenAt→DateTimeOriginal+OffsetTimeOriginal, location→GPS*.
  - `String rollToCsv(Roll r, List<Frame> frames)` — `'﻿'` + header `roll,film,film_type,box_iso,push_stops,exposed_iso,body,frame,date_time,utc_offset,aperture,shutter,exposure_time_s,iso,lens,focal_mm,mode,metered_ev,offset_stops,latitude,longitude,note,snapshot` + one row per frame, `\r\n` after every row; a field containing `,` `"` `\r` or `\n` is quoted with `"` doubled; `push_stops` `'+1'`, `'+1.33'`, `'-0.67'`, `'0'`; `date_time` = `takenAt` + `utcOffsetMinutes` (the phone's offset at log time, not the exporting machine's) as `yyyy-MM-ddTHH:mm:ss`, `utc_offset` `'+01:00'`; `metered_ev` one decimal; `offset_stops` two decimals; blank values empty.
- Produces (`lib/rolls/export.dart`):
  - `String rollFileBase(Roll r)` → `'roll-${r.number}-${slugify(r.filmStock)}'`.
  - `Future<List<File>> exportRoll(Roll r, List<Frame> frames, {required Directory out, required SnapshotStore store, required bool withSnapshots})` → `[<base>.csv, <base>.json]` plus `<base>-snapshots.zip` when `withSnapshots` and ≥ 1 snapshot file exists; zip entries `frame-<label>.jpg` (repeated label → `frame-5-2.jpg`), missing files skipped; written with `ZipFileEncoder` (streams from disk).
  - `GearPlatform` gains `Future<void> sharePaths(List<String> paths, {required String subject})`, `Future<String?> pickFilePath()` (cancel → null; `XFile.path` when it exists, else bytes copied to a temp file) and `Future<Directory> exportDirectory()` (`<temp>/exports`, emptied first). `FakeGearPlatform` records `sharedPaths` and returns `pickedPath`.
  - `Future<void> showExportSheet(BuildContext context, {required Roll roll, required RollController rolls, required GearPlatform platform})` — title `'Export roll 4'`, switch "Include snapshots (zip)" (on; hidden without snapshots), button "Share" → `exportRoll` then `sharePaths(subject: 'Roll 4 · Ilford HP5 Plus')`.

- [ ] **Step 1: Write the failing tests**

```dart
test('CSV escapes commas, quotes and line breaks', () {
  final csv = rollToCsv(roll, [frame(note: 'Window light, "golden"\nsecond line')]);
  expect(csv.startsWith('﻿roll,film,film_type,box_iso,push_stops,exposed_iso,body,frame,'), isTrue);
  expect(csv, contains(',"Window light, ""golden""\nsecond line",'));
  expect(csv.endsWith('\r\n'), isTrue); expect('\r\n'.allMatches(csv).length, 2);
});
test('CSV row values', () {
  // roll 4 'Ilford HP5 Plus' bw 400 push 4 thirds, A-1; frame 12 at 2026-11-21T13:03:22Z offset +60,
  // f/5.6, '1/125', iso 1000, FD 50/1.8, 50 mm, aperture priority, EV 12.34, location 52.52/13.405
  expect(row(csv, 1), '4,Ilford HP5 Plus,bw-neg,400,+1.33,1000,Canon A-1,12,2026-11-21T14:03:22,+01:00,5.6,1/125,0.008,1000,FD 50mm f/1.8,50,aperture-priority,12.3,,52.52,13.405,,abc.jpg');
});
test('push_stops formatting', ...);                                // -2 → '-0.67', 0 → '0', 3 → '+1'
test('blank frame is an empty row with its number', ...);
test('JSON is EXIF-ready', () {
  final f = (rollToJson(roll, [frame12])['frames'] as List).single as Map;
  expect(f['number'], '12'); expect(f['aperture'], 5.6); expect(f['shutter'], '1/125'); expect(f['exposureTime'], .008);
  expect(f['iso'], 1000); expect(f['focalLength'], 50); expect(f['takenAt'], '2026-11-21T14:03:22+01:00');
  expect(f['lens'], {'id': 'canon-fd-50-1.8', 'make': 'Canon', 'name': 'FD 50mm f/1.8'});
  expect((rollToJson(roll, [])['roll'] as Map)['film'], containsPair('pushStops', closeTo(4 / 3, 1e-12)));
});
test('frame 00 and location null', ...);                           // number '00'; location null when absent
test('roll JSON round-trips exactly, incl. blank frames', ...);
test('reading JSON round-trips', ...);
test('foreign JSON is refused with a path', ...);                  // {'schema':1,'type':'grain-roll','roll':{}} → RollFormatException message starts with 'roll.id:'
test('isoWithOffset', ...);                                         // (+60) '+01:00', (-330) '-05:30', (0) '+00:00'
// export_test.dart (temp dirs)
test('export writes csv, json and a zip of existing snapshots', ...); // names ['roll-4-ilford-hp5-plus.csv', '…json', '…-snapshots.zip']; zip entries ['frame-1.jpg', 'frame-2.jpg'] when frame 3's file is missing
test('repeated labels get a suffix in the zip', ...);
test('no snapshots → no zip even when asked', ...);
testWidgets('export sheet shares the files', ...);                   // FakeGearPlatform.sharedPaths basenames as above; subject 'Roll 4 · Ilford HP5 Plus'
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter pub add archive:^4.7.1 && flutter test test/rolls/codec_test.dart test/rolls/export_test.dart` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces (archive 4.x API: `ZipFileEncoder().create(path)`, `addFile(File, name)`, `close()`); wire `onExport` from `RollScreen`/`RollsScreen` in `lib/main.dart`.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Append** to `docs/testing/rolls-checklist.md`: export a roll to Files and to a messaging app; CSV opens in LibreOffice and Excel with umlauts intact and notes with commas/line breaks in one cell; zip opens with one JPEG per frame.
- [ ] **Step 6: Commit** `git add lib test pubspec.yaml pubspec.lock docs/testing && git commit -m "feat(rolls): export a roll as CSV, JSON and a snapshot zip"`

---

### Task 12: Export everything / Import everything

**Files:**
- Create: `lib/backup/backup.dart` (write/read), `lib/backup/merge.dart` (pure planner), `lib/backup/ui.dart`
- Modify: `lib/gear/gear_controller.dart` (`mergeProfiles`), `lib/rolls/roll_controller.dart` (`importRecords`, `allFrames`), `lib/settings/settings.dart` (`backupMap`, `applyBackupMap`), `lib/settings/settings_screen.dart` (section "Backup"), `lib/main.dart`
- Test: `test/backup/merge_test.dart`, `test/backup/backup_test.dart`, `test/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: Task 11 codec (`rollToJson`/`rollFromJson`, `readingToJson`/`readingFromJson`, `RollFormatException`), `gearToJson`/`parseGear`, `uniqueId`, `GearPlatform.sharePaths/pickFilePath/exportDirectory`, `SnapshotStore`, `newId`.
- Produces:
  - Zip layout: `grain-backup.json` + `snapshots/<name>.jpg`. JSON: `{"schema":1,"type":"grain-backup","exportedAt":isoWithOffset,"app":"1.0.0","profiles":[gearToJson…],"favorites":{"body":[ids],"lens":[ids]},"rolls":[rollToJson…],"readings":[readingToJson…],"settings":{"haptics":bool,"viewfinderOn":bool,"snapshots":bool}}`.
  - `Future<File> writeBackup({required Directory out, required GearController gear, required RollController rolls, required Settings settings, required DateTime now})` → `grain-backup-2026-11-21.zip` (`ZipFileEncoder`; missing snapshot files skipped).
  - `class BackupFormatException implements Exception { final String message; }` — `'Not a Grain backup'` (no/invalid `grain-backup.json`), `'Made by a newer version of Grain (schema 2)'`.
  - `class BackupContents { List<GearProfile> profiles; Map<ProfileKind, Set<String>> favorites; List<(Roll, List<Frame>)> rolls; List<SavedReading> readings; Map<String, Object?> settings; Future<List<int>?> snapshot(String name); }`; `Future<BackupContents> readBackup(String zipPath)` (`ZipDecoder().decodeStream(InputFileStream(path))`, entries read on demand).
  - `MergePlan planMerge({required List<(Roll, List<Frame>)> localRolls, required List<SavedReading> localReadings, required BackupContents incoming, required Map<String, String> profileIds /* 'body:id'/'lens:id' → new id */, required String Function() newId})` (`lib/backup/merge.dart`) — same id + identical JSON (`rollToJson`/`readingToJson` deep-equal after id remapping) → skip; same id + different → copy with new ids for the roll and all its frames (or the reading); new id → add; incoming active roll while a local roll is active → stored finished (`finishedAt` = its last frame's `takenAt` or `startedAt`); snapshot names collected for copying, a name already present with different bytes → new `<uuid>.jpg` and references rewritten. `MergePlan { List<(Roll, List<Frame>)> rolls; List<SavedReading> readings; Map<String, String> snapshots /* source name → target name */; ImportReport report; }`
  - `class ImportReport { const ImportReport({…all fields, default 0}); final int rollsAdded, rollsCopied, rollsSkipped, rollsDeactivated, readingsAdded, readingsCopied, readingsSkipped, profilesAdded, profilesCopied, profilesSkipped, snapshotsAdded; String get summary; }` — counts read `1 roll`/`3 rolls` (same for readings, profiles); summary: `'Added A rolls, B saved readings, C profiles.'` + (N = all copies) `' Kept 1 as a copy because it differs from what is here.'` / `' Kept N as copies because they differ from what is here.'` + `' Skipped M already on this phone.'` + `' 1 imported active roll is now finished.'` / `' K imported active rolls are now finished.'` (each clause only when > 0).
  - `Future<({Map<String, String> renames, int added, int copied, int skipped})> GearController.mergeProfiles(List<GearProfile> profiles, Map<ProfileKind, Set<String>> favorites)` — per (kind, id) against bundled + user: identical → skipped; different → stored as `uniqueId(id, taken)` and listed in `renames` (`'body:id'`/`'lens:id'` → new id); new → stored; favorites unioned (remapped). Imported profiles are not auto-starred here (the file's favorites are).
  - `Future<void> RollController.importRecords(MergePlan plan)` (one transaction; reloads); `Future<List<(Roll, List<Frame>)>> RollController.allFrames()`.
  - `Map<String, Object?> Settings.backupMap()`; `Future<void> Settings.applyBackupMap(Map<String, Object?> m)` (only the three keys; wrong types ignored).
  - Settings screen section "Backup" above the footer: **"Export everything"** → `writeBackup` → `sharePaths(subject: 'Grain backup 21 Nov 2026')`; **"Import everything"** → `pickFilePath` → `readBackup` → confirm dialog `'Import 3 rolls, 12 saved readings and 2 profiles?'` (same plurals) with checkbox "Use the settings from the file" (off) → merge → dialog with `report.summary`. Errors → dialog "Can't import" + message. A busy indicator while working; buttons disabled meanwhile.

- [ ] **Step 1: Write the failing tests**

```dart
// merge_test.dart (pure)
test('identical roll is skipped', ...);                            // report.rollsSkipped 1, plan.rolls empty
test('same id, different content → kept as a copy with new ids', ...); // copy roll id != original; every frame id new; frames' rollId == copy id; rollsCopied 1
test('new roll and reading are added', ...);
test('imported active roll becomes finished when one is active here', ...); // status finished, rollsDeactivated 1
test('profile renames reach roll body and frame lens ids', ...);  // profileIds {'body:my-a1': 'my-a1-2', 'lens:my-50': 'my-50-2'}
test('a snapshot name taken by different bytes is renamed', ...);
test('summary text', () {
  expect(ImportReport(rollsAdded: 3, readingsAdded: 12, profilesAdded: 2, rollsCopied: 1, rollsSkipped: 5, rollsDeactivated: 1).summary,
      'Added 3 rolls, 12 saved readings, 2 profiles. Kept 1 as a copy because it differs from what is here. '
      'Skipped 5 already on this phone. 1 imported active roll is now finished.');
  expect(const ImportReport(rollsAdded: 1).summary, 'Added 1 roll, 0 saved readings, 0 profiles.');
});
// backup_test.dart (temp dirs, in-memory controllers)
test('export → import on an empty phone restores everything', ...); // rolls, frames, readings, user profiles, favorites, snapshot bytes equal
test('importing the same backup twice adds nothing', ...);       // 2nd report: added 0, skipped == all
test('settings are applied only when asked; calibration never travels', ...);
test('not a backup and newer schema are refused', ...);          // random zip → 'Not a Grain backup'; schema 2 → 'Made by a newer version of Grain (schema 2)'
test('missing snapshot files are skipped on export', ...);
test('gear mergeProfiles: identical skipped, different suffixed, favorites unioned', ...);
// settings_screen_test.dart
testWidgets('export everything shares the zip', ...);             // sharedPaths single basename 'grain-backup-2026-11-21.zip'
testWidgets('import everything confirms and reports', ...);        // dialog 'Import 1 roll, 0 saved readings and 0 profiles?' → Import → text contains 'Added 1 roll,'
```
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/backup test/settings` → FAIL.
- [ ] **Step 3: Implement** per the Interfaces.
- [ ] **Step 4: Run** `source ~/.grain-env.sh && flutter test && flutter analyze` → all PASS, no issues.
- [ ] **Step 5: Append** to `docs/testing/rolls-checklist.md`: export everything with ≥ 100 snapshots (time, no jank, memory stable); import it on a second phone (or after "Clear storage") → identical rolls and thumbnails; import twice → "Skipped"; picking a non-zip → "Can't import".
- [ ] **Step 6: Commit** `git add lib test docs/testing && git commit -m "feat(backup): export and import everything, merged by stable ids"`

---

### Task 13: Android auto-backup, release check, follow-ups

**Files:**
- Create: `android/app/src/main/res/xml/backup_rules.xml`, `android/app/src/main/res/xml/data_extraction_rules.xml`, `test/android/backup_rules_test.dart`, `docs/superpowers/plans/2026-11-21-grain-3-rolls-followups.md`
- Modify: `android/app/src/main/AndroidManifest.xml` (`android:allowBackup="true"`, `android:fullBackupContent="@xml/backup_rules"`, `android:dataExtractionRules="@xml/data_extraction_rules"`), `docs/testing/rolls-checklist.md`

**Interfaces:**
- Consumes: DB file `app_flutter/grain.sqlite` (`driftDatabase(name: 'grain')` in `getApplicationDocumentsDirectory()`), prefs `FlutterSharedPreferences.xml` (legacy `SharedPreferences.getInstance()`), snapshots in `files/snapshots/`.
- Produces: `backup_rules.xml` `<full-backup-content>` with `<include domain="root" path="app_flutter/grain.sqlite"/>`, `…-wal`, `…-journal`, `<include domain="sharedpref" path="FlutterSharedPreferences.xml"/>`, `<exclude domain="file" path="snapshots/"/>`; `data_extraction_rules.xml` `<data-extraction-rules>` with the same rules in `<cloud-backup>` and `<device-transfer>`.

- [ ] **Step 1: Write the failing test** `test/android/backup_rules_test.dart` (plain `dart:io` string checks): both XML files contain the four includes and the exclude exactly as above (in both sections of the extraction rules); the manifest references both resources and does not contain `allowBackup="false"`; `lib/db/database.dart` still opens `driftDatabase(name: 'grain')`; `lib/settings/settings.dart` uses `SharedPreferences.getInstance()` (legacy file name holds).
- [ ] **Step 2: Run** `source ~/.grain-env.sh && flutter test test/android` → FAIL (files missing).
- [ ] **Step 3: Create** the XML files and manifest attributes.
- [ ] **Step 4: Run the full verification** `source ~/.grain-env.sh && dart run build_runner build --delete-conflicting-outputs && git diff --exit-code && flutter test && flutter analyze && (cd android && ./gradlew :app:testDebugUnitTest)` → all PASS, no diff, no issues.
- [ ] **Step 5: Build and check the release** `source ~/.grain-env.sh && flutter build apk --release --split-per-abi --split-debug-info=build/symbols --obfuscate && ls -lh build/app/outputs/flutter-apk/ && $ANDROID_HOME/build-tools/*/aapt2 dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` → permissions exactly `CAMERA`, `ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION` plus Flutter's non-network defaults; no `INTERNET`; nothing from Google Play Services. Record the arm64 size (plan-2 baseline 20.5 MB; expected ≤ ~21 MB) in `docs/testing/rolls-checklist.md` and in the follow-ups file.
- [ ] **Step 6: Append** to `docs/testing/rolls-checklist.md`: `adb shell bmgr backupnow io.github.wladikrin.grain`, uninstall, reinstall (`adb shell bmgr restore` / reinstall from the same signing key) → rolls, readings, profiles and settings back, thumbnails show placeholders; `adb shell run-as … ls files/snapshots` empty after restore.
- [ ] **Step 7: Write** `docs/superpowers/plans/2026-11-21-grain-3-rolls-followups.md` (same shape as plan 2's: "Decisions made during the build", "Deferred small issues", APK size line).
- [ ] **Step 8: Commit** `git add android test docs && git commit -m "build(android): auto-backup for database and settings, snapshots excluded"`
