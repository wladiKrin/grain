import 'dart:async';

import 'package:flutter/foundation.dart';

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

  Future<List<Frame>> framesOf(String rollId) async {
    final cached = _frames[rollId];
    if (cached != null) return List.unmodifiable(cached);
    final loaded = await _enqueue(() => _repo.frames(rollId));
    if (!_rolls.any((r) => r.id == rollId)) return loaded;
    final list = _frames.putIfAbsent(rollId, () => loaded);
    notifyListeners();
    return List.unmodifiable(list);
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
      unawaited(() async {
        try {
          final path = await take(_newId());
          if (path == null) return;
          final name = path.substring(path.lastIndexOf('/') + 1);
          if (!exists() || !attachSnapshot(name)) {
            await _snapshots.delete(name);
          }
        } catch (e) {
          debugPrint('Snapshot failed: $e');
        }
      }());
    }
    final loc = _location;
    if (_settings.location && loc != null) {
      unawaited(() async {
        try {
          final fix = await loc.current();
          if (fix != null) attachFix(fix);
        } catch (e) {
          debugPrint('Location failed: $e');
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

  Future<void> updateFrame(Frame f) {
    final u = f.copyWith(updatedAt: _now());
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

  Future<void> insertBlank(String rollId, int position) async {
    final frames = await framesOf(rollId);
    await _apply(
      rollId,
      numbering.insertBlankAt(
        frames,
        position,
        id: _newId(),
        rollId: rollId,
        now: _now(),
      ),
    );
  }

  Future<void> deleteFrame(String rollId, String frameId) async {
    final frames = await framesOf(rollId);
    final i = frames.indexWhere((f) => f.id == frameId);
    if (i < 0) return;
    final name = frames[i].snapshot;
    await _apply(
      rollId,
      numbering.deleteAt(frames, i, now: _now()),
      deleted: [frameId],
    );
    if (name != null) await _snapshots.delete(name);
  }

  Future<void> renumberFrom(String rollId, int position, int number) async {
    final frames = await framesOf(rollId);
    if (position < 0 || position >= frames.length) return;
    await _apply(
      rollId,
      numbering.renumberFrom(frames, position, number, now: _now()),
    );
  }

  Future<void> deleteFrameSnapshot(String rollId, String frameId) async {
    final f = _findFrame(frameId);
    final name = f?.snapshot;
    if (f == null || name == null) return;
    await updateFrame(f.copyWith(snapshot: () => null));
    await _snapshots.delete(name);
  }

  // ---- readings ----------------------------------------------------------

  Future<void> updateReading(SavedReading r) {
    final u = r.copyWith(updatedAt: _now());
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

  Future<void> deleteReadingSnapshot(String id) async {
    final r = _readings.where((x) => x.id == id).firstOrNull;
    final name = r?.snapshot;
    if (r == null || name == null) return;
    await updateReading(r.copyWith(snapshot: () => null));
    await _snapshots.delete(name);
  }
}
