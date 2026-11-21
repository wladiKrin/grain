import 'package:flutter/services.dart';

import 'reading.dart';

/// What the native side reports when the camera preview starts.
class PreviewInfo {
  const PreviewInfo({
    required this.textureId,
    required this.size,
    required this.sensorOrientation,
    required this.phoneEqFocal,
  });

  factory PreviewInfo.fromMap(Map<Object?, Object?> m) => PreviewInfo(
    textureId: (m['textureId'] as num).toInt(),
    size: Size(
      (m['previewWidth'] as num).toDouble(),
      (m['previewHeight'] as num).toDouble(),
    ),
    sensorOrientation: (m['sensorOrientation'] as num).toInt(),
    phoneEqFocal: (m['phoneEqFocal'] as num).toDouble(),
  );

  final int textureId;

  /// Preview buffer size in sensor orientation (landscape on most phones).
  final Size size;
  final int sensorOrientation;

  /// Main back camera's 35 mm-equivalent focal length, mm.
  final double phoneEqFocal;
}

/// Source of live metering data; [MeterChannel] is the real one, tests pass fakes.
abstract class MeterSource {
  /// Opens the camera. Throws [PlatformException] with code `denied` when the
  /// camera permission is missing, `camera_error` for other failures.
  Future<PreviewInfo> start();

  Future<void> stop();

  /// [crop] and [spot] are normalized 0..1 in display (portrait) coordinates;
  /// [radius] is relative to the crop width.
  Future<void> setRegions(Rect crop, Offset spot, double radius);

  Stream<MeterStats> get stats;
}

class MeterChannel implements MeterSource {
  MeterChannel();

  static const _method = MethodChannel('grain/meter');
  static const _events = EventChannel('grain/meter/stats');

  @override
  Future<PreviewInfo> start() async {
    final m = await _method.invokeMapMethod<Object?, Object?>('start');
    if (m == null) {
      throw PlatformException(
        code: 'camera_error',
        message: 'start returned no preview info',
      );
    }
    return PreviewInfo.fromMap(m);
  }

  @override
  Future<void> stop() => _method.invokeMethod<void>('stop');

  @override
  Future<void> setRegions(Rect crop, Offset spot, double radius) =>
      _method.invokeMethod<void>('setRegions', {
        'crop': [crop.left, crop.top, crop.right, crop.bottom],
        'spot': [spot.dx, spot.dy, radius],
      });

  @override
  Stream<MeterStats> get stats => _events.receiveBroadcastStream().map(
    (e) => MeterStats.fromMap(e as Map<Object?, Object?>),
  );
}
