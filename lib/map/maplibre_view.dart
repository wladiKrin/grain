import 'dart:async';

import 'package:maplibre_gl/maplibre_gl.dart'
    show
        AnnotationType,
        CameraPosition,
        CameraUpdate,
        CircleLayerProperties,
        LatLng,
        MapLibreMap,
        MapLibreMapController,
        MinMaxZoomPreference;
import 'package:material_ui/material_ui.dart';

import 'geo.dart';
import 'map_view.dart';

/// The markers' source and layers, added to every style once it loads.
const markerSource = 'grain-markers';
const markerHaloLayer = 'grain-marker-halo', markerLayer = 'grain-markers';

/// The map, drawn by MapLibre Native: [options]' style with the markers on
/// top as circle layers. North stays up and the map is not tilted; no
/// logo, compass or attribution button (the screen shows the attribution).
class MapLibreView extends StatefulWidget {
  const MapLibreView(this.options, {super.key});

  final MapViewOptions options;

  @override
  State<MapLibreView> createState() => _MapLibreViewState();
}

/// [MapLibreView] for a [MapViewBuilder].
Widget mapLibreView(MapViewOptions options) => MapLibreView(options);

class _MapLibreViewState extends State<MapLibreView>
    implements MapViewController {
  MapLibreMapController? _map;

  /// The markers are on the style that showed last.
  bool _markersAdded = false;

  /// The markers the map has, to send only a change.
  Map<String, Object?>? _sent;

  /// Style loads so far: a load that a newer one overtook stops.
  int _loads = 0;

  @override
  Future<CameraView?> camera() async {
    final p = await _map?.queryCameraPosition();
    if (p == null) return null;
    return CameraView(GeoPoint(p.target.latitude, p.target.longitude), p.zoom);
  }

  @override
  Future<void> moveTo(CameraView view) async {
    await _map?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(view.center.latitude, view.center.longitude),
        view.zoom,
      ),
      duration: const Duration(milliseconds: 450),
    );
  }

  @override
  Future<void> reload() async {
    final map = _map;
    if (map == null) return;
    _markersAdded = false;
    await map.setStyle(widget.options.style.style);
  }

  @override
  void didUpdateWidget(MapLibreView old) {
    super.didUpdateWidget(old);
    if (old.options.style != widget.options.style) _markersAdded = false;
    if (!identical(old.options.markers, widget.options.markers)) {
      unawaited(_sendMarkers());
    }
  }

  @override
  void dispose() {
    _map?.onFeatureTapped.remove(_featureTapped);
    super.dispose();
  }

  void _created(MapLibreMapController map) {
    _map = map;
    map.onFeatureTapped.add(_featureTapped);
    widget.options.onCreated(this);
  }

  void _featureTapped(
    Object point,
    Object coordinates,
    String id,
    String layerId,
    Object? annotation,
  ) {
    if (layerId == markerLayer) widget.options.onMarkerTap(id);
  }

  /// A style loaded (the first, or a new one, as for dark mode): the
  /// markers go on it. A load overtaken by a newer one stops; a step whose
  /// source or layer is there already (from a load before) is skipped.
  Future<void> _styleLoaded() async {
    final map = _map;
    if (map == null || !mounted) return;
    final load = ++_loads;
    _markersAdded = false;
    final markers = widget.options.markers;
    Future<bool> step(String what, Future<void> Function() add) async {
      try {
        await add();
      } on Exception catch (e) {
        debugPrint('Map $what not added: $e');
      }
      return mounted && load == _loads;
    }

    if (!await step(
          'marker source',
          () => map.addGeoJsonSource(markerSource, markers),
        ) ||
        !await step(
          'marker halo',
          () => map.addCircleLayer(
            markerSource,
            markerHaloLayer,
            const CircleLayerProperties(
              circleRadius: ['get', 'halo'],
              circleColor: _ink,
              circleSortKey: ['get', 'order'],
            ),
            filter: [
              '==',
              ['get', 'selected'],
              true,
            ],
            enableInteraction: false,
          ),
        ) ||
        !await step(
          'markers',
          () => map.addCircleLayer(
            markerSource,
            markerLayer,
            const CircleLayerProperties(
              circleRadius: ['get', 'radius'],
              circleColor: ['get', 'fill'],
              circleStrokeColor: ['get', 'ring'],
              circleStrokeWidth: ['get', 'stroke'],
              circleSortKey: ['get', 'order'],
            ),
          ),
        )) {
      return;
    }
    _markersAdded = true;
    // Sent again, in case the source was there already with older data or
    // the markers changed while they were added.
    _sent = null;
    await _sendMarkers();
  }

  /// The halo's colour, the palette's ink, from each feature.
  static const _ink = ['get', 'haloColor'];

  Future<void> _sendMarkers() async {
    final map = _map, markers = widget.options.markers;
    if (map == null || !_markersAdded || identical(markers, _sent)) return;
    _sent = markers;
    try {
      await map.setGeoJsonSource(markerSource, markers);
    } on Exception catch (e) {
      debugPrint('Map markers not updated: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final c = o.initialCamera;
    return MapLibreMap(
      styleString: o.style.style,
      initialCameraPosition: CameraPosition(
        target: LatLng(c.center.latitude, c.center.longitude),
        zoom: c.zoom,
      ),
      onMapCreated: _created,
      onStyleLoadedCallback: () => unawaited(_styleLoaded()),
      onMapClick: (_, _) => widget.options.onMapTap(),
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      logoEnabled: false,
      attributionEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(0, 19),
      // No annotations: the markers are a layer of their own.
      annotationOrder: const [],
      annotationConsumeTapEvents: const [AnnotationType.circle],
      foregroundLoadColor: o.background,
    );
  }
}
