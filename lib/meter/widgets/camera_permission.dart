import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../ui/theme.dart';

/// Asks for the camera; resolves to whether it is now granted.
typedef CameraPermissionRequest = Future<bool> Function();

/// Requests the camera permission, or opens the app's system settings when
/// Android will no longer show the request dialog.
Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) await openAppSettings();
  return false;
}

/// Calm explanation with an "Allow camera" button, shown instead of the
/// viewfinder while the camera permission is missing.
class CameraPermissionPrompt extends StatelessWidget {
  const CameraPermissionPrompt({
    super.key,
    required this.onGranted,
    this.request = requestCameraPermission,
  });

  final VoidCallback onGranted;
  final CameraPermissionRequest request;

  Future<void> _allow() async {
    if (await request()) onGranted();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        const Text(
          'Grain needs the camera to measure light.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: GrainColors.ink),
        ),
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _allow,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: GrainColors.ink,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Text(
                'Allow camera',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: GrainColors.ground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
