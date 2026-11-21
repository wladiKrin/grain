import 'package:permission_handler/permission_handler.dart';

/// What a permission request came to: usable, refused (may be asked again) or
/// blocked (only the system settings can change it).
enum PermissionOutcome { granted, denied, blocked }

PermissionOutcome outcomeOf(PermissionStatus s) {
  if (s.isGranted || s.isLimited) return PermissionOutcome.granted;
  if (s.isPermanentlyDenied || s.isRestricted) return PermissionOutcome.blocked;
  return PermissionOutcome.denied;
}

/// Opens the app's page in the system settings.
typedef OpenSettings = Future<bool> Function();
