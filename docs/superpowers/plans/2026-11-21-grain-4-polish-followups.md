# Grain 4 — Histogram & polish: follow-ups

Recorded when plan 4 finished (2026-11-21). Branch feat/polish on top of feat/rolls. No device was connected: everything in docs/testing/device-test-script.md is still to be run on the Pixel 10.

## Decisions made during the build
- - R1 Task 4: Ruling: the MeterController getter is named `shakeRiskNow` (top-level shakeRisk() keeps its name) — avoids shadowing — cost if wrong: none.
- - R2 Task 3/4/5: Ruling: each task that adds a Settings key to backupMap also updates test/backup/backup_test.dart's exact-map assertion — cost if wrong: none.
- - R3 Task 2: Ruling: test/rolls/support.dart roll() helper gains filmType, latitudeUnderHalves, latitudeOverHalves params; file added to Task 2 — cost if wrong: none.
- - R4 Task 4/5: Ruling: settings order: Haptic feedback, Click sound, Camera-shake warning — cost if wrong: order only.
- - R5 Task 1: Ruling: run test/meter/offset_scale_test.dart too in Task 1 verification — cost if wrong: none.
- - R6 Task 8: Ruling: Task 8's size baseline is HEAD at task start; also record the plan-3 figure (22.26 MB) for comparison — cost if wrong: none.
- Task 8: Ruling: ⅔ glyph mismatch (system-font ⅔ beside Inter ⅓) is visible on the main meter — include in plan-4 final fix wave: UI-only rendering of thirds as 1⁄3 / 2⁄3 with U+2044 + FontFeature.fractions, add U+2044 to the subset; export strings unchanged — cost if wrong: small UI change.
- Task 8: Ruling: final wave also adds per-file SHA3-256 to third_party/sqlite/README.md and says the recorded hash is the zip's — cost: none.
- Task 10: Ruling: the 9 device-script minors (ordering/prereqs, settings toggles to turn on, optional comparisons, garbled 12.7, 8.13 uninstall last, duplicated path in plan-2 followups) go into the final fix wave — the script is what the owner will actually use — cost: none.
- Final: Ruling: fresh-clone gradlew — document "run `flutter build apk --release` once first" (keep Flutter's default ignore of the wrapper) and note the plain gradle build isn't comparable to the published split APKs — cost if wrong: F-Droid recipe may need the wrapper committed later.
- Final: Ruling: latitude editor follows the plan ruling (an untouched dial follows the film type; drop the ??= pinning) — supersedes the Task 2 reviewer's acceptance — cost if wrong: small UI behaviour.
- Final: Ruling: final fix wave = reviewer must-fix 1–6 + queued items (thirds rendering with fraction span only, SQLite per-file hashes, README third-party notices, key.properties requireNotNull, device-script fixes incl. reviewer additions).
- Final: parked — main meter dials at 92 px numerals on a 360 px screen clip the neighbours of 1/1000 (pre-existing) — Ruling: device check first (row to add), fix if visible — cost: clipped faded neighbour text on small phones.
- Final: parked — dial labels softWrap:false clip rather than wrap if too wide — Ruling: accepted; widths fit at 360 px by estimate — cost: clipped label on unusual widths.

## Deferred small issues and notes
- Task 2: minor (deferred): pinned latitude survives a later film-type change (only "Use film default" reverts) — undocumented in UI
- Task 2: minor (deferred): polish-checklist needs a row for the side-by-side 32 px latitude dials (Task 10 device script)
- Task 3: minor (deferred): HistogramView has no ==, equal views still notify; recompute per dial detent when histogram on
- Task 5: minor (deferred): ClickPlugin onLoadComplete doesn't check pool is current
- Task 6: minor (deferred): aperture list with only non-positive values → f/1.8 used but apertureAssumed false
- Task 7: minor (deferred): a spurious permanentlyDenied on a first (dismissed) request shows "Open settings" with no way back to a real request
- Task 8: note: arm64 APK 21.27 MB after SQLite -Os + font subset (was 22.35); >20 MB accepted within '~' (R12/R7)
- Task 8: note: Inter Tight has no ⅔ glyph — falls back to system font (pre-existing); device check
- Task 8: minor (deferred): native_build_test can't tell vendored vs prebuilt at same version (sqlite_source_id optional); subset.sh comment stripping naive
- Task 9: note: Task 10 must update README's pointer to docs/testing/*-checklist.md → device-test-script.md
- Task 10: note: two clean builds give byte-identical APK contents but different APK sha256 (zip metadata/signature; uninvestigated) — recorded in docs/release.md
