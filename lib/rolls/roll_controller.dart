import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backup/merge.dart';
import '../gear/model.dart';
import '../settings/settings.dart';
import 'ids.dart' as ids;
import 'location.dart';
import 'model.dart';
import 'numbering.dart' as numbering;
import 'roll_repository.dart';
import 'snapshot_store.dart';

typedef TakeSnapshot = Future<String?> Function(String id);

/// Rolls, their frames and saved readings. Changes are applied to memory
/// first (so the UI never waits) and written through one serial chain.
class RollController extends ChangeNotifier {
  RollController({
    required RollRepository repository,
    required this._snapshots,
    required this._settings,
    this._takeSnapshot,
    this._location,
    DateTime Function()? now,
    String Function()? newId,
  }) : _repo = repository,
       _clock = now ?? DateTime.now,
       _newId = newId ?? ids.newId;

  factory RollController.inMemory({
    required Settings settings,
    required SnapshotStore snapshots,
    TakeSnapshot? takeSnapshot,
    LocationSource? location,
    DateTime Function()? now,
  }) => RollController(
    repository: MemoryRollRepository(),
    snapshots: snapshots,
    settings: settings,
    takeSnapshot: takeSnapshot,
    location: location,
    now: now,
  );

  final RollRepository _repo;
  final SnapshotStore _snapshots;
  final Settings _settings;
  final TakeSnapshot? _takeSnapshot;
  final LocationSource? _location;
  final DateTime Function() _clock;
  final String Function() _newId;

  List<Roll> _rolls = [];
  List<SavedReading> _readings = [];
  final Map<String, List<Frame>> _frames = {};

  Future<void> _chain = Future.value();

  /// Record ids with a snapshot being taken, and those whose arriving file
  /// must be deleted instead of attached.
  final Set<String> _pendingSnapshots = {};
  final Set<String> _discardSnapshot = {};

  /// Same for locations: fixes in flight, and those to drop on arrival.
  final Set<String> _pendingFixes = {};
  final Set<String> _discardFix = {};

  SnapshotStore get snapshots => _snapshots;

  DateTime _now() => ids.atSecond(_clock());

  /// Runs [action] after every earlier write; a failure does not block later
  /// writes but is still reported to the caller.
  Future<T> _enqueue<T>(Future<T> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> load() async {
    final rolls = await _enqueue(_repo.rolls);
    final readings = await _enqueue(_repo.readings);
    _rolls = rolls;
    _readings = readings;
    _frames.clear();
    final a = active;
    if (a != null) _frames[a.id] = await _enqueue(() => _repo.frames(a.id));
    notifyListeners();
  }

  // ---- rolls -------------------------------------------------------------

  Roll? get active {
    for (final r in _rolls) {
      if (r.isActive) return r;
    }
    return null;
  }

  List<Frame> get activeFrames {
    final a = active;
    return a == null ? const [] : List.unmodifiable(_frames[a.id] ?? const []);
  }

  /// Active first, then `startedAt` descending.
  List<Roll> get rolls {
    final l = [..._rolls];
    l.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      final c = b.startedAt.compareTo(a.startedAt);
      return c != 0 ? c : b.number.compareTo(a.number);
    });
    return l;
  }

  List<SavedReading> get readings => List.unmodifiable(_readings);

  /// Most recently started roll, for editor defaults.
  Roll? get latest {
    Roll? best;
    for (final r in _rolls) {
      if (best == null ||
          r.startedAt.isAfter(best.startedAt) ||
          (r.startedAt == best.startedAt && r.number > best.number)) {
        best = r;
      }
    }
    return best;
  }

  int? get nextFrameNumber {
    final a = active;
    return a == null ? null : numbering.nextNumber(a, activeFrames);
  }

  String? get nextLabel {
    final n = nextFrameNumber;
    return n == null ? null : numbering.frameLabel(n);
  }

  int get nextOverrun {
    final a = active;
    final n = nextFrameNumber;
    return a == null || n == null ? 0 : numbering.overrun(a, n);
  }

  bool logsFor(Body? body) => active != null && active!.bodyId == body?.id;

  Future<Roll> startRoll({
    required String filmStock,
    required FilmType filmType,
    required int boxIso,
    required int pushThirds,
    required Body? body,
    required int size,
    required StartFrame startFrame,
    String notes = '',
  }) {
    final now = _now();
    final previous = active;
    final finished = previous?.copyWith(
      status: RollStatus.finished,
      finishedAt: () => now,
      updatedAt: now,
    );
    var number = 0;
    for (final r in _rolls) {
      if (r.number > number) number = r.number;
    }
    final roll = Roll(
      id: _newId(),
      number: number + 1,
      filmStock: filmStock,
      filmType: filmType,
      boxIso: boxIso,
      pushThirds: pushThirds,
      bodyId: body?.id,
      bodyMake: body?.make ?? '',
      bodyModel: body?.model ?? '',
      format: body?.format ?? FilmFormat.f135,
      size: size,
      startFrame: startFrame,
      notes: notes,
      status: RollStatus.active,
      startedAt: now,
      updatedAt: now,
    );
    _rolls = [
      for (final r in _rolls)
        if (finished != null && r.id == finished.id) finished else r,
      roll,
    ];
    _frames[roll.id] = [];
    notifyListeners();
    return _enqueue(() async {
      await _repo.transaction(() async {
        if (finished != null) await _repo.saveRoll(finished);
        await _repo.saveRoll(roll);
      });
      return roll;
    });
  }

  Future<void> updateRoll(Roll r) {
    final u = r.copyWith(updatedAt: _now());
    _rolls = [
      for (final x in _rolls)
        if (x.id == u.id) u else x,
    ];
    notifyListeners();
    return _enqueue(() => _repo.saveRoll(u));
  }

  Future<void> finishRoll(String id) {
    final now = _now();
    Roll? done;
    _rolls = [
      for (final x in _rolls)
        if (x.id == id)
          done = x.copyWith(
            status: RollStatus.finished,
            finishedAt: () => now,
            updatedAt: now,
          )
        else
          x,
    ];
    if (done == null) return Future.value();
    final saved = done;
    notifyListeners();
    return _enqueue(() => _repo.saveRoll(saved));
  }

  Future<void> deleteRoll(String id) async {
    final frames = await framesOf(id);
    final names = [
      for (final f in frames)
        if (f.snapshot != null) f.snapshot!,
    ];
    _rolls = [
      for (final x in _rolls)
        if (x.id != id) x,
    ];
    _frames.remove(id);
    notifyListeners();
    await _enqueue(() => _repo.deleteRoll(id));
    for (final n in names) {
      await _snapshots.delete(n);
    }
  }

  /// Frames logged in a roll, once its frames are loaded (see [framesOf]).
  int? frameCount(String rollId) => _frames[rollId]?.length;

  Future<List<Frame>> framesOf(String rollId) async {
    final cached = _frames[rollId];
    if (cached != null) return List.unmodifiable(cached);
    final loaded = await _enqueue(() => _repo.frames(rollId));
    if (!_rolls.any((r) => r.id == rollId)) return loaded;
    final list = _frames.putIfAbsent(rollId, () => loaded);
    notifyListeners();
    return List.unmodifiable(list);
  }

  /// Every roll with its frames (cached ones as they are in memory).
  Future<List<(Roll, List<Frame>)>> allFrames() async => [
    for (final r in [..._rolls])
      (r, List<Frame>.unmodifiable(_frames[r.id] ?? await _loadFrames(r.id))),
  ];

  Future<List<Frame>> _loadFrames(String rollId) =>
      _enqueue(() => _repo.frames(rollId));

  /// Stores the records of an import in one transaction, then reloads the
  /// roll and reading lists (loaded frames stay cached, so a late snapshot or
  /// location for a frame logged just before still lands). The plan only
  /// holds new records. An imported active roll is stored finished if a roll
  /// became active here since the plan was made; returns how many were.
  Future<int> importRecords(MergePlan plan) async {
    var activeId = active?.id;
    var finished = 0;
    final rolls = <(Roll, List<Frame>)>[];
    for (final (r, frames) in plan.rolls) {
      if (r.isActive && activeId != null && activeId != r.id) {
        finished++;
        rolls.add((
          r.copyWith(
            status: RollStatus.finished,
            finishedAt: () => finishTimeFor(r, frames),
          ),
          frames,
        ));
      } else {
        if (r.isActive) activeId = r.id;
        rolls.add((r, frames));
      }
    }
    await _enqueue(
      () => _repo.transaction(() async {
        for (final (r, frames) in rolls) {
          await _repo.saveRoll(r);
          if (frames.isNotEmpty) await _repo.saveFrames(frames);
        }
        for (final s in plan.readings) {
          await _repo.saveReading(s);
        }
      }),
    );
    final (all, readings) = await (
      _enqueue(_repo.rolls),
      _enqueue(_repo.readings),
    ).wait;
    _rolls = all;
    _readings = readings;
    final a = active;
    if (a != null && !_frames.containsKey(a.id)) {
      _frames[a.id] = await _loadFrames(a.id);
    }
    notifyListeners();
    return finished;
  }

  // ---- logging -----------------------------------------------------------

  Future<Frame> logFrame(Exposure e, {String? note}) async {
    final roll = active;
    if (roll == null) throw StateError('No active roll');
    final list = _frames.putIfAbsent(roll.id, () => []);
    final now = _clock();
    final frame = Frame(
      id: _newId(),
      rollId: roll.id,
      position: list.length,
      number: numbering.nextNumber(roll, list),
      exposure: e,
      takenAt: ids.atSecond(now),
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
      note: note,
      updatedAt: ids.atSecond(now),
    );
    list.add(frame);
    notifyListeners();
    final persisted = _enqueue(() => _repo.saveFrames([frame]));
    _attachLater(
      id: frame.id,
      attachSnapshot: (name) => _setFrameField(frame.id, snapshot: name),
      attachFix: (fix) => _setFrameField(frame.id, location: fix),
      exists: () => _findFrame(frame.id) != null,
    );
    await persisted;
    return frame;
  }

  Future<SavedReading> saveReading(
    Exposure e, {
    required Body? body,
    required FilmFormat format,
    String? note,
  }) async {
    final now = _clock();
    final r = SavedReading(
      id: _newId(),
      bodyId: body?.id,
      bodyMake: body?.make ?? '',
      bodyModel: body?.model ?? '',
      format: format,
      exposure: e,
      takenAt: ids.atSecond(now),
      utcOffsetMinutes: now.timeZoneOffset.inMinutes,
      note: note,
      updatedAt: ids.atSecond(now),
    );
    _readings = [r, ..._readings];
    notifyListeners();
    final persisted = _enqueue(() => _repo.saveReading(r));
    _attachLater(
      id: r.id,
      attachSnapshot: (name) => _setReadingField(r.id, snapshot: name),
      attachFix: (fix) => _setReadingField(r.id, location: fix),
      exists: () => _readings.any((x) => x.id == r.id),
    );
    await persisted;
    return r;
  }

  /// Starts the snapshot and location requests without waiting for them.
  void _attachLater({
    required String id,
    required bool Function(String name) attachSnapshot,
    required bool Function(GeoFix fix) attachFix,
    required bool Function() exists,
  }) {
    final take = _takeSnapshot;
    if (_settings.snapshots && take != null) {
      _pendingSnapshots.add(id);
      unawaited(() async {
        try {
          final path = await take(_newId());
          if (path == null) return;
          final name = path.substring(path.lastIndexOf('/') + 1);
          final discard = _discardSnapshot.contains(id);
          if (discard || !exists() || !attachSnapshot(name)) {
            await _snapshots.delete(name);
          }
        } catch (e) {
          debugPrint('Snapshot failed: $e');
        } finally {
          _pendingSnapshots.remove(id);
          _discardSnapshot.remove(id);
        }
      }());
    }
    final loc = _location;
    if (_settings.location && loc != null) {
      _pendingFixes.add(id);
      unawaited(() async {
        try {
          final fix = await loc.current();
          if (fix != null && _settings.location && !_discardFix.contains(id)) {
            attachFix(fix);
          }
        } catch (e) {
          debugPrint('Location failed: $e');
        } finally {
          _pendingFixes.remove(id);
          _discardFix.remove(id);
        }
      }());
    }
  }

  /// Applies a late value to the current in-memory frame and saves it.
  bool _setFrameField(String id, {String? snapshot, GeoFix? location}) {
    final f = _findFrame(id);
    if (f == null) return false;
    final u = f.copyWith(
      snapshot: snapshot == null ? null : () => snapshot,
      location: location == null ? null : () => location,
      updatedAt: _now(),
    );
    _replaceFrame(u);
    notifyListeners();
    unawaited(_enqueue(() => _repo.saveFrames([u])));
    return true;
  }

  bool _setReadingField(String id, {String? snapshot, GeoFix? location}) {
    final i = _readings.indexWhere((x) => x.id == id);
    if (i < 0) return false;
    final u = _readings[i].copyWith(
      snapshot: snapshot == null ? null : () => snapshot,
      location: location == null ? null : () => location,
      updatedAt: _now(),
    );
    _readings = [..._readings]..[i] = u;
    notifyListeners();
    unawaited(_enqueue(() => _repo.saveReading(u)));
    return true;
  }

  Frame? _findFrame(String id) {
    for (final list in _frames.values) {
      for (final f in list) {
        if (f.id == id) return f;
      }
    }
    return null;
  }

  void _replaceFrame(Frame u) {
    final list = _frames[u.rollId];
    if (list == null) return;
    final i = list.indexWhere((f) => f.id == u.id);
    if (i >= 0) list[i] = u;
  }

  // ---- frame editing -----------------------------------------------------

  /// Saves an edit. The snapshot and location are not part of an edit: they
  /// stay as they are now (a late attach may have landed since the editor
  /// opened); clear a snapshot with [deleteFrameSnapshot].
  Future<void> updateFrame(Frame f) {
    final cur = _findFrame(f.id);
    if (cur == null) return Future.value();
    final u = f.copyWith(
      snapshot: () => cur.snapshot,
      location: () => cur.location,
      updatedAt: _now(),
    );
    return _writeFrame(u);
  }

  Future<void> _writeFrame(Frame u) {
    _replaceFrame(u);
    notifyListeners();
    return _enqueue(() => _repo.saveFrames([u]));
  }

  /// Swaps in [next] for [rollId] and saves what changed (plus deletions).
  Future<void> _apply(
    String rollId,
    List<Frame> next, {
    List<String> deleted = const [],
  }) {
    final old = {for (final f in _frames[rollId] ?? <Frame>[]) f.id: f};
    final changed = [
      for (final f in next)
        if (old[f.id] != f) f,
    ];
    _frames[rollId] = [...next];
    notifyListeners();
    return _enqueue(
      () => _repo.transaction(() async {
        if (deleted.isNotEmpty) await _repo.deleteFrames(deleted);
        if (changed.isNotEmpty) await _repo.saveFrames(changed);
      }),
    );
  }

  /// Runs [op] on the cached frames of [rollId], loading them first on a
  /// cache miss; the cache is read synchronously so nothing lands in between.
  Future<void> _withFrames(String rollId, Future<void> Function() op) {
    if (_frames[rollId] != null) return op();
    return framesOf(rollId).then((_) => op());
  }

  Future<void> insertBlank(String rollId, int position) =>
      _withFrames(rollId, () {
        final frames = _frames[rollId]!;
        if (position < 0 || position > frames.length) return Future.value();
        return _apply(
          rollId,
          numbering.insertBlankAt(
            frames,
            position,
            id: _newId(),
            rollId: rollId,
            now: _now(),
          ),
        );
      });

  Future<void> deleteFrame(String rollId, String frameId) =>
      _withFrames(rollId, () async {
        final frames = _frames[rollId]!;
        final i = frames.indexWhere((f) => f.id == frameId);
        if (i < 0) return;
        final name = frames[i].snapshot;
        final done = _apply(
          rollId,
          numbering.deleteAt(frames, i, now: _now()),
          deleted: [frameId],
        );
        await done;
        if (name != null) await _snapshots.delete(name);
      });

  Future<void> renumberFrom(String rollId, int position, int number) =>
      _withFrames(rollId, () {
        final frames = _frames[rollId]!;
        if (position < 0 || position >= frames.length) return Future.value();
        return _apply(
          rollId,
          numbering.renumberFrom(frames, position, number, now: _now()),
        );
      });

  Future<void> deleteFrameSnapshot(String rollId, String frameId) async {
    final f = _findFrame(frameId);
    if (f == null) return;
    final name = f.snapshot;
    if (name == null) {
      // Still being taken: the file is deleted when it arrives.
      if (_pendingSnapshots.contains(frameId)) _discardSnapshot.add(frameId);
      return;
    }
    await _writeFrame(f.copyWith(snapshot: () => null, updatedAt: _now()));
    await _snapshots.delete(name);
  }

  Future<void> deleteFrameLocation(String rollId, String frameId) async {
    final f = _findFrame(frameId);
    if (f == null) return;
    if (_pendingFixes.contains(frameId)) _discardFix.add(frameId);
    if (f.location == null) return;
    await _writeFrame(f.copyWith(location: () => null, updatedAt: _now()));
  }

  // ---- readings ----------------------------------------------------------

  /// As [updateFrame]: snapshot and location are kept as they are now.
  Future<void> updateReading(SavedReading r) {
    final cur = _readings.where((x) => x.id == r.id).firstOrNull;
    if (cur == null) return Future.value();
    return _writeReading(
      r.copyWith(
        snapshot: () => cur.snapshot,
        location: () => cur.location,
        updatedAt: _now(),
      ),
    );
  }

  Future<void> _writeReading(SavedReading u) {
    _readings = [
      for (final x in _readings)
        if (x.id == u.id) u else x,
    ];
    notifyListeners();
    return _enqueue(() => _repo.saveReading(u));
  }

  Future<void> deleteReading(String id) async {
    final name = _readings.where((x) => x.id == id).firstOrNull?.snapshot;
    _readings = [
      for (final x in _readings)
        if (x.id != id) x,
    ];
    notifyListeners();
    await _enqueue(() => _repo.deleteReading(id));
    if (name != null) await _snapshots.delete(name);
  }

  Future<void> deleteReadingLocation(String id) async {
    final r = _readings.where((x) => x.id == id).firstOrNull;
    if (r == null) return;
    if (_pendingFixes.contains(id)) _discardFix.add(id);
    if (r.location == null) return;
    await _writeReading(r.copyWith(location: () => null, updatedAt: _now()));
  }

  Future<void> deleteReadingSnapshot(String id) async {
    final r = _readings.where((x) => x.id == id).firstOrNull;
    if (r == null) return;
    final name = r.snapshot;
    if (name == null) {
      if (_pendingSnapshots.contains(id)) _discardSnapshot.add(id);
      return;
    }
    await _writeReading(r.copyWith(snapshot: () => null, updatedAt: _now()));
    await _snapshots.delete(name);
  }
}
