// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:grain/gear/gear_repository.dart';
import 'package:grain/gear/gear_scales.dart';
import 'package:grain/gear/ids.dart';
import 'package:grain/gear/library.dart';
import 'package:grain/gear/model.dart';

class ImportResult {
  const ImportResult({required this.bodies, required this.lenses});
  final List<Body> bodies;
  final List<Lens> lenses;

  String get summary => [
    for (final b in bodies) b.displayName,
    for (final l in lenses) l.displayName,
  ].join(', ');
}

int _byBody(Body a, Body b) {
  final c = a.make.compareTo(b.make);
  return c != 0 ? c : a.model.compareTo(b.model);
}

int _byLens(Lens a, Lens b) {
  final c = a.focalMin.compareTo(b.focalMin);
  return c != 0 ? c : a.name.compareTo(b.name);
}

/// Selected body / lens / focal length plus the library, user profiles and
/// favorites. Every mutation persists and notifies once.
class GearController extends ChangeNotifier {
  GearController({
    required GearLibrary library,
    required GearRepository repository,
  }) : _library = library,
       _repo = repository;

  factory GearController.inMemory({GearLibrary? library}) => GearController(
    library: library ?? const GearLibrary.empty(),
    repository: MemoryGearRepository(),
  );

  static const _focalPersistDelay = Duration(milliseconds: 500);

  final GearLibrary _library;
  final GearRepository _repo;

  List<Body> _userBodies = [];
  List<Lens> _userLenses = [];
  final Set<String> _favBodies = {};
  final Set<String> _favLenses = {};
  GearSetup _setup = const GearSetup();
  Timer? _focalTimer;

  Future<void> load() async {
    _userBodies = await _repo.userBodies();
    _userLenses = await _repo.userLenses();
    _favBodies
      ..clear()
      ..addAll(await _repo.favorites(ProfileKind.body));
    _favLenses
      ..clear()
      ..addAll(await _repo.favorites(ProfileKind.lens));
    final s = await _repo.selection();
    final body = s.bodyId == null ? null : _bodyById(s.bodyId!);
    Lens? lens = s.lensId == null ? null : _lensById(s.lensId!);
    if (body == null) {
      lens = null;
    } else if (lens == null || lens.mount != body.mount) {
      lens = _ruleLens(body, null);
    }
    _setup = GearSetup(
      body: body,
      lens: lens,
      focal: _fitFocal(lens, s.focal ?? 50),
    );
    notifyListeners();
  }

  // Lookup -----------------------------------------------------------------

  Body? _bodyById(String id) {
    for (final b in [..._userBodies, ..._library.bodies]) {
      if (b.id == id) return b;
    }
    return null;
  }

  Lens? _lensById(String id) {
    for (final l in [..._userLenses, ..._library.lenses]) {
      if (l.id == id) return l;
    }
    return null;
  }

  Set<String> _takenIds(ProfileKind kind) => {
    for (final p
        in kind == ProfileKind.body
            ? [..._library.bodies, ..._userBodies]
            : [..._library.lenses, ..._userLenses])
      p.id,
  };

  List<GearProfile> _all(ProfileKind kind) => kind == ProfileKind.body
      ? [..._library.bodies, ..._userBodies]
      : [..._library.lenses, ..._userLenses];

  // Queries ----------------------------------------------------------------

  List<Body> get bodies => [..._library.bodies, ..._userBodies]..sort(_byBody);

  List<Lens> lensesFor(String mount) => [
    for (final l in [..._library.lenses, ..._userLenses])
      if (l.mount == mount) l,
  ]..sort(_byLens);

  List<Body> get favoriteBodies => [
    for (final b in bodies)
      if (_favBodies.contains(b.id)) b,
  ];

  List<Lens> favoriteLensesFor(String mount) => [
    for (final l in lensesFor(mount))
      if (_favLenses.contains(l.id)) l,
  ];

  List<String> get mounts => {
    for (final b in [..._library.bodies, ..._userBodies]) b.mount,
    for (final l in [..._library.lenses, ..._userLenses]) l.mount,
  }.toList()..sort();

  bool isFavorite(GearProfile p) => switch (p) {
    Body() => _favBodies.contains(p.id),
    Lens() => _favLenses.contains(p.id),
  };

  bool isUser(GearProfile p) => switch (p) {
    Body() => _userBodies.any((b) => b.id == p.id),
    Lens() => _userLenses.any((l) => l.id == p.id),
  };

  Body? get body => _setup.body;
  Lens? get lens => _setup.lens;
  double get focal => _setup.focal;
  GearSetup get setup => _setup;

  // Selection --------------------------------------------------------------

  /// The current lens if it fits; else the first favorite for the mount; else
  /// the mount's only lens (fixed-lens cameras); else none.
  Lens? _ruleLens(Body body, Lens? current) {
    if (current != null && current.mount == body.mount) return current;
    final favs = favoriteLensesFor(body.mount);
    if (favs.isNotEmpty) return favs.first;
    final all = lensesFor(body.mount);
    return all.length == 1 ? all.first : null;
  }

  double _fitFocal(Lens? lens, double focal) {
    if (lens == null) return focal;
    if (!lens.isZoom) return lens.focalMin;
    return focal.clamp(lens.focalMin, lens.focalMax).toDouble();
  }

  Future<void> _setSetup(GearSetup next) async {
    _focalTimer?.cancel();
    _focalTimer = null;
    final changed = next != _setup;
    _setup = next;
    await _saveSelection();
    if (changed) notifyListeners();
  }

  Future<void> _saveSelection() => _repo.saveSelection(
    StoredSelection(
      bodyId: _setup.body?.id,
      lensId: _setup.lens?.id,
      focal: _setup.focal,
    ),
  );

  Future<void> selectBody(Body? body) {
    if (body == null) {
      return _setSetup(GearSetup(focal: _setup.focal));
    }
    final lens = _ruleLens(body, _setup.lens);
    return _setSetup(
      GearSetup(body: body, lens: lens, focal: _fitFocal(lens, _setup.focal)),
    );
  }

  Future<void> selectLens(Lens? lens) {
    final body = _setup.body;
    if (lens != null && (body == null || body.mount != lens.mount)) {
      throw ArgumentError.value(
        lens.id,
        'lens',
        'does not fit the selected body mount',
      );
    }
    return _setSetup(
      GearSetup(body: body, lens: lens, focal: _fitFocal(lens, _setup.focal)),
    );
  }

  Future<bool> cycleLens() async {
    final body = _setup.body;
    if (body == null) return false;
    final favs = favoriteLensesFor(body.mount);
    if (favs.isEmpty) return false;
    final i = favs.indexWhere((l) => l.id == _setup.lens?.id);
    await selectLens(favs[(i + 1) % favs.length]);
    return true;
  }

  /// Clamped for zooms; ignored for primes (their focal is fixed). The
  /// repository write is debounced so a detent scroll is not a write storm.
  Future<void> setFocal(double focal) async {
    final lens = _setup.lens;
    if (lens != null && !lens.isZoom) return;
    final f = _fitFocal(lens, focal);
    if (f == _setup.focal) return;
    _setup = GearSetup(body: _setup.body, lens: lens, focal: f);
    _focalTimer?.cancel();
    _focalTimer = Timer(_focalPersistDelay, () {
      _focalTimer = null;
      unawaited(_saveSelection());
    });
    notifyListeners();
  }

  // Favorites and user profiles --------------------------------------------

  Future<void> toggleFavorite(GearProfile p) async {
    final set = p is Body ? _favBodies : _favLenses;
    final on = !set.contains(p.id);
    if (on) {
      set.add(p.id);
    } else {
      set.remove(p.id);
    }
    await _repo.setFavorite(p.kind, p.id, on);
    notifyListeners();
  }

  /// Stores [p] as a user profile (upsert). A new id gets a free one.
  Future<T> saveUser<T extends GearProfile>(T p) async {
    final stored = await _store(p);
    // Keep the selection pointing at the edited instance.
    final sel = _setup;
    if (stored is Body && sel.body?.id == stored.id) {
      final lens = _ruleLens(stored, sel.lens);
      _setup = GearSetup(
        body: stored,
        lens: lens,
        focal: _fitFocal(lens, sel.focal),
      );
      await _saveSelection();
    } else if (stored is Lens && sel.lens?.id == stored.id) {
      _setup = GearSetup(
        body: sel.body,
        lens: stored,
        focal: _fitFocal(stored, sel.focal),
      );
      await _saveSelection();
    }
    notifyListeners();
    return stored;
  }

  Future<T> _store<T extends GearProfile>(T p, {bool forceNew = false}) async {
    final existing = !forceNew && isUser(p);
    GearProfile out = p;
    if (!existing) {
      final id = uniqueId(p.id, _takenIds(p.kind));
      if (id != p.id) {
        out = switch (p) {
          Body() => p.copyWith(id: id),
          Lens() => p.copyWith(id: id),
        };
      }
    }
    await _repo.saveProfile(out);
    switch (out) {
      case Body():
        _userBodies = _upsert(_userBodies, out);
      case Lens():
        _userLenses = _upsert(_userLenses, out);
    }
    return out as T;
  }

  List<T> _upsert<T extends GearProfile>(List<T> list, T p) {
    final i = list.indexWhere((e) => e.id == p.id);
    if (i < 0) return [...list, p];
    final copy = [...list];
    copy[i] = p;
    return copy;
  }

  Future<void> deleteUser(GearProfile p) async {
    if (!isUser(p)) return;
    final selected = p is Body
        ? _setup.body?.id == p.id
        : _setup.lens?.id == p.id;
    if (selected) {
      _focalTimer?.cancel();
      _focalTimer = null;
    }
    await _repo.deleteProfile(p.kind, p.id);
    switch (p) {
      case Body():
        _userBodies = [
          for (final b in _userBodies)
            if (b.id != p.id) b,
        ];
        _favBodies.remove(p.id);
        if (_setup.body?.id == p.id) _setup = GearSetup(focal: _setup.focal);
      case Lens():
        _userLenses = [
          for (final l in _userLenses)
            if (l.id != p.id) l,
        ];
        _favLenses.remove(p.id);
        if (_setup.lens?.id == p.id) {
          _setup = GearSetup(body: _setup.body, focal: _setup.focal);
        }
    }
    notifyListeners();
  }

  Body duplicateBody(Body b) => b.copyWith(
    id: uniqueId(
      slugify('${b.make} ${b.model} copy'),
      _takenIds(ProfileKind.body),
    ),
    model: '${b.model} (copy)',
  );

  Lens duplicateLens(Lens l) => l.copyWith(
    id: uniqueId(
      slugify('${l.make} ${l.name} copy'),
      _takenIds(ProfileKind.lens),
    ),
    name: '${l.name} (copy)',
  );

  // Import -----------------------------------------------------------------

  Future<ImportResult> importDoc(GearDoc doc) async {
    final bodies = <Body>[];
    final lenses = <Lens>[];
    switch (doc) {
      case Body():
        bodies.add(await _importOne(doc));
      case Lens():
        lenses.add(await _importOne(doc));
      case Kit():
        bodies.add(await _importOne(doc.body));
        for (final l in doc.lenses) {
          lenses.add(await _importOne(l));
        }
    }
    notifyListeners();
    return ImportResult(bodies: bodies, lenses: lenses);
  }

  Future<T> _importOne<T extends GearProfile>(T p) async {
    GearProfile? match;
    for (final e in _all(p.kind)) {
      final same = switch ((p, e)) {
        (Body a, Body b) => a.copyWith(id: b.id) == b,
        (Lens a, Lens b) => a.copyWith(id: b.id) == b,
        _ => false,
      };
      if (same) {
        match = e;
        break;
      }
    }
    final GearProfile result = match ?? await _store(p, forceNew: true);
    final set = p is Body ? _favBodies : _favLenses;
    if (set.add(result.id)) {
      await _repo.setFavorite(result.kind, result.id, true);
    }
    return result as T;
  }

  @override
  void dispose() {
    if (_focalTimer != null) {
      _focalTimer!.cancel();
      _focalTimer = null;
      unawaited(_saveSelection());
    }
    super.dispose();
  }
}
