import 'dart:async';

import 'package:grain/map/geo.dart';
import 'package:grain/map/map_network.dart';
import 'package:grain/map/map_view.dart';
import 'package:material_ui/material_ui.dart';

/// Stands in for MapLibre, which needs the platform: shows each marker as
/// a button labelled as the real one is, and keeps what the screen asked
/// for.
class FakeMap implements MapViewController {
  /// The options of every build, the last last.
  final builds = <MapViewOptions>[];
  final moves = <CameraView>[];
  int reloads = 0;
  CameraView? _camera;

  MapViewOptions get last => builds.last;

  /// The styles shown, in order, each once.
  List<String> get styles {
    final out = <String>[];
    for (final b in builds) {
      if (out.isEmpty || out.last != b.style.style) out.add(b.style.style);
    }
    return out;
  }

  List<Map<String, Object?>> get features =>
      (last.markers['features']! as List).cast<Map<String, Object?>>();

  Map<String, Object?> props(Map<String, Object?> f) =>
      (f['properties']! as Map).cast<String, Object?>();

  @override
  Future<CameraView?> camera() async => _camera;

  @override
  Future<void> moveTo(CameraView view) async {
    moves.add(view);
    _camera = view;
  }

  @override
  Future<void> reload() async => reloads++;

  Widget build(MapViewOptions o) => _FakeMapWidget(this, o);
}

class _FakeMapWidget extends StatefulWidget {
  const _FakeMapWidget(this.map, this.options);

  final FakeMap map;
  final MapViewOptions options;

  @override
  State<_FakeMapWidget> createState() => _FakeMapWidgetState();
}

class _FakeMapWidgetState extends State<_FakeMapWidget> {
  @override
  void initState() {
    super.initState();
    widget.map._camera ??= widget.options.initialCamera;
    scheduleMicrotask(() => widget.options.onCreated(widget.map));
  }

  @override
  Widget build(BuildContext context) {
    final map = widget.map..builds.add(widget.options);
    final o = widget.options;
    return GestureDetector(
      key: const ValueKey('fake-map'),
      behavior: HitTestBehavior.opaque,
      onTap: o.onMapTap,
      child: ColoredBox(
        color: o.background,
        child: Wrap(
          children: [
            for (final f in map.features)
              Semantics(
                container: true,
                button: true,
                label: map.props(f)['label']! as String,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => o.onMarkerTap(f['id']! as String),
                  child: const SizedBox(width: 44, height: 44),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The map's HTTP client, faked: keeps what it is told, and lets a test
/// say how requests went.
class FakeNetwork implements MapNetwork {
  final configured = <({String userAgent, bool offline})>[];
  final _requests = StreamController<MapRequest>.broadcast();

  /// Holds [configure] until completed, when set.
  Completer<void>? hold;

  @override
  Stream<MapRequest> get requests => _requests.stream;

  @override
  Future<void> configure({
    required String userAgent,
    required bool offline,
  }) async {
    configured.add((userAgent: userAgent, offline: offline));
    await hold?.future;
  }

  void request(String url, {bool ok = true}) =>
      _requests.add(MapRequest(Uri.parse(url), ok: ok));
}
