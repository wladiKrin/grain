# Grain 3 — Rolls & logging: follow-ups

Recorded when plan 3 finished (2026-11-21). Branch feat/rolls on top of feat/gear. No device was connected: every on-device check in docs/testing/device-test-script.md is still open.

## Decisions made during the build
- - R1 Task 3: Ruling: Drift tables use @DataClassName('RollRow'/'FrameRow'/'SavedReadingRow') to avoid clashing with model classes — cost if wrong: none.
- - R2 Task 6/7: Ruling: main() builds one LocationChannel and passes it to RollController and SettingsScreen; GrainApp takes an injectable LocationSource for tests — cost if wrong: none.
- - R3 Task 5/7: Ruling: GrainApp's default RollController gets takeSnapshot: widget.source.snapshot — cost if wrong: none.
- - R4 Task 12: Ruling: import comparison normalises roll status (active vs finished) — an active roll restored as finished counts as identical/skipped — cost if wrong: duplicate roll after re-import.
- - R5 Task 6/12: Ruling: SettingsScreen gains explicit params (gear, rolls, platform, now: DateTime Function()) — export filename test uses injected now — cost if wrong: none.
- - R6 Task 13: Ruling: run the generated-files `git diff --exit-code` check limited to generated paths (lib/db/*.g.dart, drift_schemas, test/drift) or after committing — cost if wrong: none.
- - R7 Task 7: Ruling: the Yashica assertion switches gear away and back (setGear with equal gear is a no-op) — cost if wrong: none.
- - R8 Task 8: Ruling: "box 3200 push +3" means +3 stops (9 third-stop detents) → 25600 out of range → refused — cost if wrong: none.
- - R9 Task 2: Ruling: files that use formatStops/MeterMode after the move need explicit imports, not just export — cost if wrong: none.
- - R10 Task 2/9/10: Ruling: minors from scan apply: insertBlankAt on empty list takes rollId; FakeLocation has permission fields; Task 10 shows frame counts for finished rolls and uses unambiguous finders; new-roll push resets to 0 even when copying — cost if wrong: none.
- - R11 Task 9: Ruling: metered EV, manual offset and metering area stay read-only in the frame editor (they are measurements, editing them would falsify the log; spec "edit any field" read as user-entered fields) — cost if wrong: three more editable fields.
- - R12 Task 13: Ruling: APK target remains "under ~20 MB"; record the actual size; above 20 MB accepted within "~" and carried to plan 4 — cost if wrong: size.
- Task 2: Ruling: the brief's re-exports of mode.dart/stops.dart from meter_controller/offset_scale are omitted; later tasks import package:grain/exposure/mode.dart and stops.dart directly (carried in dispatches) — cost if wrong: a compile error fixed with one import.
- Task 3: Ruling: reviewer Minor 3 (textEnum columns fail whole select on an unknown value) is taken now, overriding the brief's textEnum — v2 has not shipped, so plain text + repository mapping costs nothing later and protects the roll history from one bad row — cost if wrong: none.
- Task 7: Ruling: at 360×800 Manual+viewfinder with no roll the viewfinder shrinks to ~87 px (floor relaxed to 80 for that case only) — small screens, the viewfinder can be hidden, and removing controls would break the one-gesture goal; 392×872 (Pixel-class) keeps 150 — cost if wrong: cramped viewfinder on small phones.
- Task 7: Ruling: header line 3 (film/push) hidden while meter-only — the roll is not being logged then, so its film line would mislead — cost if wrong: one line of text.
- Task 11: Ruling: exported files stay in <temp>/exports until the next export (receiving app must be able to read them after the share sheet returns) — cost if wrong: a few MB of cache.
- Task 12: Ruling: gear profiles imported before a failed record write stay (additive only; re-import skips them) — cost if wrong: extra profiles after a failed import.
- Task 12: Ruling: imported rolls keep their roll numbers even if duplicated locally (planning ruling; numbers are labels, ids are identity) — cost if wrong: two "Roll 4"s.
- Task 12: Ruling: a record whose snapshot was deleted locally but exists in the backup counts as identical (local deletion respected, snapshot not resurrected) — cost if wrong: a deleted thumbnail can't be recovered from an old backup.
- Final: Ruling: final fix wave = must-fix (updatedAt in merge keys) + reading late-attach dropped during import (can null a snapshot on later edit) + run SnapshotStore.open()/rolls.load() in parallel with other startup work + export CSV/JSON snapshot column uses the zip entry name when a zip is produced (so files match). Auto-backup carrying calibration/location-on via shared_prefs stays as is (same-phone reinstall is the common case; location still needs runtime permission) — cost if wrong: re-set calibration on a new phone.
- Final: parked — export with zip: frame whose snapshot file is missing keeps its uuid name in CSV/JSON — Ruling: deferred; blank it in plan 4 polish — cost: a name that matches no zip entry.
- Final: parked — roll started during an import transaction can coexist with an imported active roll — Ruling: real, narrow (import takes seconds, user must start a roll mid-import); plan 4 re-checks the invariant after the write — cost: two active rolls until one is finished.

## Deferred small issues and notes
- Task 1: minor (deferred): enterBackground doesn't await in-flight start release (pre-existing)
- Task 2: minor (deferred): insertBlankAt on empty list numbers 1 not startFrame (callers use nextNumber)
- Task 3: minor (deferred): FK cascade under foreign_keys ON untested (deleteRoll explicit)
- Task 4: minor (deferred): failed writes not rolled back in memory; unawaited(logFrame()) would surface uncaught error
- Task 5: minor (deferred): snapshot logged in landscape stored sideways (portrait-locked; checklist)
- Task 5: minor (deferred): createBitmap may be 1 px off computed size
- Task 5: minor (deferred): engine detach mid-encode orphans a JPEG in filesDir/snapshots (orphan sweep candidate)
- Task 6: minor (deferred): permanently-denied location only shows SnackBar, no pointer to system settings
- Task 6: note: Task 7 must pass widget.location (same LocationChannel) to RollController (R2)
- Task 6: minor (deferred): after detach, done(null) starts the next provider attempt (bounded by budget) — add a detached flag
- Task 7: note: Review Focus 3 "restart with another body selected" is owned by Task 8 (body-change dialog) — carry into Task 8 dispatch.
- Task 7: minor (deferred): GrainApp has no didUpdateWidget for rolls (existing pattern); screens <800 dp / large text scale untested
- Task 8: minor (deferred): rolls-checklist lacks a row for autocomplete overlay vs on-screen keyboard
- Task 8: minor (deferred): "Finish and start" reopens then closes camera (second lend right after first)
- Task 8: minor (deferred): dialog re-asks when switching between two non-roll bodies (per brief)
- Task 9: minor (deferred): rolls-checklist lacks rows for 40-thumbnail scroll smoothness and real date/time pickers
- Task 9: minor (deferred): picking date/time drops stored seconds
- Task 9: minor (deferred): frame editor display doesn't refresh on late attach (data safe)
- Task 10: minor (deferred): _lastSaved set before write completes (failed note write not retried); rolls_screen framesOf().then lacks catchError
- Task 11: minor (deferred): CSV date_time with null offset is bare UTC, unmarked
- Task 12: minor (deferred): record edited in memory during import briefly shows stored version
- Task 13: note: arm64 release APK 22.3 MB (R12: accepted, carried to plan 4)
- Task 13: minor (deferred): restoring a newer-schema auto-backup onto an older app hits a Drift downgrade
- Task 13: minor (deferred): full-backup copy mid-write could tear the DB in theory (rollback journal included; low risk)
