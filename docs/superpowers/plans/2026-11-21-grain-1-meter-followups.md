# Grain 1 — Meter: follow-ups

Recorded when plan 1 finished (2026-11-21). The device was never connected during the build, so every on-device check in docs/testing/device-test-script.md is still open.

## Decisions made during the build
- Branch: feat/meter (from main @ 2aafc5f). Ruling: work on a feature branch in the fresh repo instead of a separate worktree — repo was just created, nothing else lives on main — cost if wrong: none (branch is isolated).
- Ruling: controller installs the toolchain (Task 1 Step 1) itself, user-space in ~ (flutter ~/flutter, JDK ~/.local/jdk-17*, SDK ~/Android/Sdk), no sudo — environment, not code — cost if wrong: owner may prefer system packages; easy to switch PATH.
- Ruling: Task 6 implements start() rejecting with PlatformException code 'denied' when CAMERA permission is not granted — plan T7 requires it — cost if wrong: trivial.
- Ruling: Task 8 changes GrainApp to `GrainApp({MeterSource? source, Haptics? haptics})` defaulting to real MeterChannel/SystemHaptics, and updates test/smoke_test.dart to pass fakes — keeps smoke test valid — cost if wrong: trivial.
- Ruling: use package:material_ui/material_ui.dart (Flutter 3.50 deprecates package:flutter/material.dart) in all code — carry to every dispatch — cost if wrong: trivial import swap.
- Task 3: Ruling: plan test 'EV12 ISO400 f/4 → 1/250' was a plan defect (1/250 is the ISO100 answer; ISO400 → 1/1000); implementer's corrected test (ISO100→1/250, ISO400→1/1000) stands — math verified by controller — cost if wrong: none.
- Task 6: Ruling: MeterChannel.stats creates a new EventChannel stream per access (multi-listener breaks sink) — load-bearing for Task 7 (controller resubscribes on resume) — Task 7 implementer caches it as a single broadcast stream in meter_channel.dart — cost if wrong: trivial
- Task 8: Ruling: accept compileSdk 37 (targetSdk 36) required by permission_handler_android 14.x — compile-only, keeps its permanently-denied fix — cost if wrong: pin permission_handler 13.x and revert to 36.
- Task 8: Ruling: Reading.flag (phone AE range, Review Focus 2) is surfaced in Task 8's EV pill — plan gap, no later task owns it; spec anti-goal of confident wrong numbers — cost if wrong: small UI text
- Ruling: include spot radius 0.02 (spec §5.2 says 3–5 % of crop width) in the final fix wave — spec is binding over plan's 0.04 — cost if wrong: one constant.
- Ruling: include status-bar dark-mode fix (visible on any phone in dark mode; spec anti-goal of visual clutter / looks good) — cost if wrong: trivial.
- Ruling: deferred "can wait" minors per final reviewer triage stay deferred.

## Deferred small issues (triaged "can wait" by the final review)
- Task 1: minor (deferred): ios CFBundleName lowercase 'grain'
- Task 1: minor (deferred): template TODOs + debug-key release signing in android/app/build.gradle.kts (Task 10 touches release config)
- Task 1: minor (deferred): unused cupertino_icons dependency
- Task 1: minor (deferred): CI Flutter version unpinned while code needs 3.50 (material_ui)
- Task 2: minor (deferred): _shutterLimit mislabels non-reciprocal sub-second limits (0.7 → '1/1'); label as seconds when 1/v not ~integer (Plan 2 gear limits will exercise this)
- Task 2: minor (deferred): limits within 0.05 stop of grid snap to grid value instead of exact limit
- Task 2: minor (deferred): test gaps — shutter/ISO extra end values, aperture max off-grid, iso half throws, half-step full flags, limit beyond grid
- Task 2: minor (deferred): nearestIndex on empty scale / value<=0 returns 0 silently
- Task 3: minor (deferred): stale _snap doc comment (solver.dart:50-52)
- Task 3: minor (deferred): single-element test doesn't pin 1/6-stop flag boundary
- Task 3: minor (deferred): descending-scale branch of _snap untested (dead generality)
- Task 4: minor (deferred): exposureNs/aperture/sensitivity <= 0 or NaN luma yields non-finite ev100 (validate in fromMap or clamp) — relevant to Review Focus 2, final review should triage
- Task 4: minor (deferred): wrong-typed values throw TypeError not FormatException; histogram length unchecked
- Task 4: minor (deferred): tests missing spot-path under/over, near-limit ok case, double-valued inputs
- Task 5: minor (deferred): ruler offset (1:1 translate, snap to 0) untested
- Task 5: minor (deferred): SystemHaptics enabled=false and strong/light mapping untested (Task 9 adds an enabled=false test)
- Task 5: minor (deferred): parent index change mid-drag is overridden by drag base
- Task 5: minor (deferred): painter allocates Paint per frame, loops all values
- Task 6: minor (deferred): throttle yields ~10 ev/s at 30 fps (67 ms vs ms truncation) — use ~60 ms or advance lastEmitMs by interval
- Task 6: minor (deferred): setRegions vs openOnCameraThread race may leave stale sensor regions
- Task 6: minor (deferred): toSensor / size choosers untested (move toSensor to LumaStats + test)
- Task 6: minor (deferred): preview Surface released before CameraDevice onClosed
- Task 6: minor (deferred): createSurfaceTexture vs SurfaceProducer — confirm preview renders under Impeller on Pixel; switch if not
- Task 7: minor (deferred): held reading re-derived from newer _latest on tapSpot/clearSpot/calibration change (keep _frozenStats)
- Task 7: minor (deferred): unawaited setRegions drops PlatformException as uncaught async error; called while paused; stats.listen no onError
- Task 7: minor (deferred): preview swap uses width>height heuristic, not sensorOrientation; portrait geometry not asserted
- Task 7: minor (deferred): dispose() doesn't stop a running source
- Task 7: minor (deferred): cancel-path stop() failure reported as cameraError
- Task 8: minor (deferred): openAppSettings fires right after a fresh refusal (check prior status first)
- Task 8: minor (deferred): permission request lacks busy guard / error handling (double tap)
- Task 8: minor (deferred): tap in dimmed area meters outside lens crop (clamp to crop)
- Task 8: minor (deferred): settings icon Icons.tune vs brief "gear"
- Task 8: minor (deferred): 150 px viewfinder min not enforced on short screens
- Task 8: minor (deferred): pause() not awaited before controller.dispose in GrainApp
- Task 9: minor (deferred): meter value row overflowed at 360 logical px with Ahem test font when viewfinder hidden (92 px numerals) — verify on device with real font; consider FittedBox scaleDown
- Task 9: minor (deferred): settings setters notify before unawaited prefs write; failed write silently diverges
- Task 9: minor (deferred): hardcoded appVersion '1.0.0' may drift from pubspec (guard test)
- Task 9: minor (deferred): smoke settings test uses 1700 px view to dodge Ahem overflow — may mask narrow-screen overflow
- Task 10: minor (deferred): _loggedFirstStats declared mid-class, no comment on one-shot semantics
- Task 10: minor (deferred): checklist lacks recorded numbers and an "R8 release build runs on device" row
- Task 10: minor (deferred): logcat grep pattern device-dependent
- Final: minor (deferred): Manual-mode spot reticle ~3 px radius reads as a dot — check on device, add faint outer ring if needed
- Final: minor (deferred): taps in ink bands clamp to preview edge (outside crop)
- Final: minor (deferred): viewfinder_test name mismatch
- Final: minor (deferred): defaultAperture fallback 0.0 → phone without aperture info shows "EV —" forever; consider f/1.8 fallback or message
