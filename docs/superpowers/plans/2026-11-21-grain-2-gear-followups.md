# Grain 2 — Gear library: follow-ups

Recorded when plan 2 finished (2026-11-21). Branch feat/gear on top of feat/meter. No device was connected: every on-device check in docs/testing/device-test-script.md and docs/testing/device-test-script.md is still open.

## Decisions made during the build
- - R1 Task 2/9: Ruling: Lens.shortName uses replaceAllMapped (plan's replaceAll does not expand $1 in Dart) — plan defect — cost if wrong: none.
- - R2 Task 7: Ruling: Task 7 adds fixtureLibrary() to test/support/gear_fixtures.dart and includes that file in its commit — plan omission — cost if wrong: none.
- - R3 Task 6: Ruling: Task 6 creates shared test/support/fake_source.dart (FakeMeterSource implementing all MeterSource members incl. setWide/startScan/qrCodes); existing fakes in smoke/system_ui/meter_controller/meter_screen tests switch to it where practical; Tasks 8/9/11 reuse it — avoids 7 copies — cost if wrong: test-only refactor.
- - R4 Task 8: Ruling: MeterController initial indices use nearestIndex against the gear's scales, never _indexOf returning -1 — startup crash risk — cost if wrong: none.
- - R5 Task 8/9: Ruling: MeterController.setFocal updates its stored GearSetup.focal so GearController→setGear round-trip is a no-op when equal (no extra recompute/setRegions); GearController persists focal to the repository debounced (~500 ms) not per detent — perf anti-goal — cost if wrong: small.
- - R6 Task 10: Ruling: BodyPickerScreen app-bar title is "Library" (Task 9 test expects it) — cost if wrong: copy.
- - R7 Task 10: Ruling: editor assigns id = slugify('$make $model') (lens: '$make $name') for new profiles before validation — cost if wrong: none.
- - R8 Task 11: Ruling: ScanScreen awaits source stop() before popping / before lendCamera resumes; add a test asserting call order stop→start — camera race — cost if wrong: none.
- - R9 Task 9: Ruling: delete focal_chip.dart's private _focalValues and use GearScales.focals — DRY — cost if wrong: none.
- - R10 Plan Goal: Ruling: dials are timed-only; Bulb appears only as solved "B" result (Rulings section wins over Goal wording) — cost if wrong: a B detent later.
- - R11 all tasks: Ruling: tests shown as `...` in the plan must be written with real assertions; Task 10 "editor refuses a body without a timed speed" starts from a duplicated valid body — cost if wrong: none.
- - R12 (planner): Ruling: sqlite3 build-hook prebuilt binaries accepted for now; plan 4 must switch to source build for F-Droid — cost if wrong: F-Droid rejection until plan 4.
- Task 3: Ruling: reviewer's "FD 50/1.4 min f/16" finding rejected — the file matches the plan and the common New FD 50mm f/1.4, which stops down to f/22 (only the older S.S.C. version ends at f/16); file unchanged — cost if wrong: one number in one JSON file.
- Task 8: Ruling: Review Focus 4 "zooming back keeps f/4.5" — on a half-stop lens the 35 mm scale has no 4.5 (3.5, 4, 4.8, 5.6), so value-remap lands on f/4.8, the nearest legal value; the intent (no jump back to wide open) holds; test asserts 4.8 — cost if wrong: a remembered dialled value in the controller.
- Task 9: Ruling: pre-existing 12 px Manual+viewfinder overflow at 392×872 (Ahem) is user-visible in a primary mode on a Pixel-sized screen → include in plan-2 final fix wave (make meter column scale/scroll-safe, add a Manual+viewfinder widget test at 392×872) — cost if wrong: small layout change.
- Task 11: note: arm64 release APK 21.5 MB vs spec "under ~20 MB" target. Ruling: final fix wave tries size levers that keep features (--split-debug-info/--obfuscate in the documented release build, drop unused cupertino_icons, check font/asset tree-shaking), records the result; if still >20 MB accept as within the "~" tolerance and note for plan 4 — cost if wrong: spec target missed by ~1.5 MB.
- Final: Ruling: final fix wave = reviewer must-fix 1–6 + editor _saving guard + newer-schema QR message; APK levers limited to --split-debug-info/--obfuscate (documented release command + checklist) and dropping cupertino_icons; NO font subsetting (touching licensed font files) and NO useLegacyPackaging (spec targets installed size, which it would increase) — cost if wrong: APK stays ~21 MB until plan 4.
- Final: Ruling: library/editor/settings routes lend the camera (meter stops behind them; nesting counter so scan-from-library works) — battery + camera-indicator privacy — cost if wrong: ~0.3 s camera reopen when returning to the meter.
- Final: parked — start-in-flight loop ignores _lends (resume during lend while start in flight leaves meter running while lent) — Ruling: real, narrow; fix first thing in plan 3 (one-line `&& _lends == 0` + test) — cost if wrong: camera briefly on behind library in a rare race.
- Final: parked — editor _saving stuck if saveUser throws — Ruling: real, deferred — cost: Save stays disabled after a DB error until reopen.
- Final: parked — pause() does not track stop of cancelled in-flight start — Ruling: deferred, no observed failure path — cost: theoretical.
- Final: parked — lend ending while app backgrounded reopens meter camera (plan-1 behaviour) — Ruling: deferred to plan 3 lifecycle pass with the item above — cost: camera on while backgrounded in a rare path.

## Deferred small issues
- Task 1: minor (deferred): formatSeconds unguarded for 0/NaN; 0.999 → '1/1'
- Task 1: minor (deferred): bodyShutterScale mark "0.5" labels 0.5" (not 1/2) — library validation could normalise
- Task 2: minor (deferred): _parseTop cast throws TypeError for non-String-key maps (direct callers only)
- Task 2: minor (deferred): schema maxLength on raw string vs Dart trims
- Task 2: minor (deferred): no test for kit body wrong type; duplicate lens ids in kit unchecked
- Task 3: minor (deferred): Minolta X-700 ISO 25–1600 unverified (reviewer unsure)
- Task 3: minor (deferred): half-stop apertureStep on Pentax-M/Zuiko/FD unverified (reviewer unsure)
- Task 3: minor (deferred): library.dart wrong-kind-for-directory branch untested
- Task 4: minor (deferred): Drift orders profiles by updatedAt (edit moves to end) vs memory insertion order
- Task 4: minor (deferred): CI git diff --exit-code ignores untracked generated files
- Task 5: minor (deferred): effectiveMaxAperture candidates.last fallback unreachable; no test for focal clamp / 3+ breakpoints
- Task 6: note: arm64 release APK 19.1 MB (budget <20) — watch in Task 11 / plan 4
- Task 6: minor (deferred): setWide(true) then quick setWide(false) on separate-camera path ends on ultra-wide — Task 8 must serialize setWide calls
- Task 6: minor (deferred): failed zoom-ratio switch answers success with unchanged map (log only)
- Task 6: minor (deferred): plain start joining during wide reopen gets camera_error though fallback reopens main
- Task 7: minor (deferred): dispose() unawaited flush may hit closed repository
- Task 7: minor (deferred): debounce test uses real 650 ms delay (fakeAsync better)
- Task 8: note: stray uncommitted dart-format edits (4 files) stashed as 'stray dart-format edits…' — not part of any task
- Task 8: minor (deferred): M1 separate-camera wide + main fallback both fail → dead preview, no error shown
- Task 8: minor (deferred): M2 no test for stale-session switch answer after pause+resume
- Task 8: minor (deferred): M3 resume() can return before wide applied when previous session switch in flight
- Task 8: minor (deferred): M4 unawaited _syncWide catches only PlatformException
- Task 8: minor (deferred): no hysteresis at main-camera focal (separate-camera phones reopen repeatedly) — add checklist row
- Task 9: minor (deferred): no widget test for 360 px with longest lens name
- Task 10: minor (deferred): lens editor truncates >2-point maxAperture to ends on edit (data loss on duplicate-and-edit of such zooms)
- Task 10: minor (deferred): body editor snaps non-standard ISO min/max to isoScale
- Task 10: minor (deferred): editors' _save lacks re-entrancy guard (double tap → second suffixed profile)
- Task 10: minor (deferred): Save button 44 px target not asserted; lens picker ignores other-mount taps silently
- Task 11: note: arm64 release APK 21.5 MB vs spec "under ~20 MB" target. Ruling: final fix wave tries size levers that keep features (--split-debug-info/--obfuscate in the documented release build, drop unused cupertino_icons, check font/asset tree-shaking), records the result; if still >20 MB accept as within the "~" tolerance and note for plan 4 — cost if wrong: spec target missed by ~1.5 MB.
- Task 11: minor (deferred): lintVital disabled for all plugin modules, could narrow to file_selector_android
- Task 11: minor (deferred → final wave candidate): ScanScreen has no lifecycle handling — scan camera stays open when backgrounded mid-scan
- Final: can-wait (from final review): DB open failure hangs splash; sequential library asset load; pending focal write lost if killed <500 ms; bundled id colliding with user id shows two entries; lens editor drops >2 aperture breakpoints.
