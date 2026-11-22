import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../ui/permissions.dart';
import '../../ui/theme.dart';

/// Asks for the camera; resolves to how the request came out.
typedef CameraPermissionRequest = Future<PermissionOutcome> Function();

/// Requests the camera permission. Never opens the settings itself.
Future<PermissionOutcome> requestCameraPermission() async =>
    outcomeOf(await Permission.camera.request());

/// Calm explanation with an "Allow camera" button, shown instead of the
/// viewfinder while the camera permission is missing. When Android will no
/// longer show the request, the button opens the system settings instead.
class CameraPermissionPrompt extends StatefulWidget {
  const CameraPermissionPrompt({
    super.key,
    required this.onGranted,
    this.request = requestCameraPermission,
    this.openSettings = openAppSettings,
  });

  final VoidCallback onGranted;
  final CameraPermissionRequest request;
  final OpenSettings openSettings;

  @override
  State<CameraPermissionPrompt> createState() => _CameraPermissionPromptState();
}

class _CameraPermissionPromptState extends State<CameraPermissionPrompt> {
  bool _blocked = false;
  bool _busy = false;

  Future<void> _allow() async {
    if (_busy) {
      return;
    }
    _busy = true;
    try {
      final outcome = await widget.request();
      if (outcome == PermissionOutcome.granted) return widget.onGranted();
      if (mounted) {
        setState(() => _blocked = outcome == PermissionOutcome.blocked);
      }
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 12,
      children: [
        Text(
          _blocked
              ? 'Camera access is off for Grain. Turn it on in the system settings.'
              : 'Grain needs the camera to measure light.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: g.ink),
        ),
        Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _blocked ? widget.openSettings : _allow,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: g.ink,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                _blocked ? 'Open settings' : 'Allow camera',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: g.ground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
