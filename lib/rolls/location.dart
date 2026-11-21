import '../ui/permissions.dart';
import 'model.dart';

/// Where the photographer is, when they allow it. The platform
/// implementation lives elsewhere; the controller only needs this.
abstract class LocationSource {
  /// A fix, or null when unavailable or not permitted.
  Future<GeoFix?> current();

  /// Asks for the permission and reports how it came out.
  Future<PermissionOutcome> requestPermission();
}
