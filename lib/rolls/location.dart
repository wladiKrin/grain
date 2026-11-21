import 'model.dart';

/// Where the photographer is, when they allow it. The platform
/// implementation lives elsewhere; the controller only needs this.
abstract class LocationSource {
  /// A fix, or null when unavailable or not permitted.
  Future<GeoFix?> current();

  /// Asks for the permission; true when granted.
  Future<bool> requestPermission();
}
