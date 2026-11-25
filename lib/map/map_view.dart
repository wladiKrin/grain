import 'package:material_ui/material_ui.dart';

import 'geo.dart';
import 'map_styles.dart';

/// What the map screen asks of the map it shows: the style, the markers
/// and the camera, and what it is told back. The real map is MapLibre
/// (`MapLibreView`); tests put in a fake, as MapLibre needs the platform.
class MapViewOptions {
  const MapViewOptions({
    required this.style,
    required this.initialCamera,
    required this.markers,
    required this.background,
    required this.onMarkerTap,
    required this.onMapTap,
    required this.onCreated,
  });

  final MapStyleDoc style;

  /// Read when the map is made only.
  final CameraView initialCamera;

  /// The markers as GeoJSON (`markerGeoJson`): a new map each time they
  /// change.
  final Map<String, Object?> markers;

  /// Shown until the style draws.
  final Color background;

  /// A marker was tapped: its point's id.
  final void Function(String id) onMarkerTap;

  /// The map was tapped away from the markers.
  final VoidCallback onMapTap;

  /// The map is ready to be moved.
  final void Function(MapViewController controller) onCreated;
}

/// Moves a map that is showing.
abstract interface class MapViewController {
  /// Where the map looks now; null before it knows.
  Future<CameraView?> camera();

  /// Moves the map to [view], animated.
  Future<void> moveTo(CameraView view);

  /// Loads the style again, so what failed is asked for afresh.
  Future<void> reload();
}

/// Builds the map for [options].
typedef MapViewBuilder = Widget Function(MapViewOptions options);
