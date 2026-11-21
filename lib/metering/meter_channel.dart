import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'reading.dart';

/// What the native side reports when the camera preview starts.
class PreviewInfo {
  const PreviewInfo({
    required this.textureId,
    required this.size,
    required this.sensorOrientation,
    required this.phoneEqFocal,
    this._mainEqFocal,
    this.wideEqFocal,
    this.wide = false,
  });

  factory PreviewInfo.fromMap(Map<Object?, Object?> m) => PreviewInfo(
    textureId: (m['textureId'] as num).toInt(),
    size: Size(
      (m['previewWidth'] as num).toDouble(),
      (m['previewHeight'] as num).toDouble(),
    ),
    sensorOrientation: (m['sensorOrientation'] as num).toInt(),
    phoneEqFocal: (m['phoneEqFocal'] as num).toDouble(),
    mainEqFocal: (m['mainEqFocal'] as num?)?.toDouble(),
    wideEqFocal: (m['wideEqFocal'] as num?)?.toDouble(),
    wide: m['wide'] as bool? ?? false,
  );

  final int textureId;

  /// Preview buffer size in sensor orientation (landscape on most phones).
  final Size size;
  final int sensorOrientation;

  /// The active camera's 35 mm-equivalent focal length, mm (the ultra-wide's
  /// while [wide] is on).
  final double phoneEqFocal;

  final double? _mainEqFocal;

  /// Main back camera's 35 mm-equivalent focal length, mm.
  double get mainEqFocal => _mainEqFocal ?? phoneEqFocal;

  /// Ultra-wide's 35 mm-equivalent focal length, mm; null when the phone has none.
  final double? wideEqFocal;

  /// Whether the ultra-wide is in use.
  final bool wide;
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

  /// Switches between the main camera and the ultra-wide. Without an
  /// ultra-wide, `setWide(true)` answers the unchanged preview.
  Future<PreviewInfo> setWide(bool wide);

  /// Opens the camera for QR scanning: no [stats], decoded texts on [qrCodes].
  /// Same exceptions as [start]; [stop] ends it.
  Future<PreviewInfo> startScan();

  /// One event per decoded QR text while scanning; consecutive duplicates are
  /// suppressed natively.
  Stream<String> get qrCodes;

  /// JPEG of the running meter preview's lens crop, saved app-privately as
  /// `snapshots/<id>.jpg`; answers its path, or null when no meter preview is
  /// running or the snapshot failed. Never throws for camera failures.
  Future<String?> snapshot(String id);
}

class MeterChannel implements MeterSource {
  MeterChannel();

  static const _method = MethodChannel('grain/meter');
  static const _events = EventChannel('grain/meter/stats');
  static const _qr = EventChannel('grain/meter/qr');

  Future<PreviewInfo> _preview(String method, [Object? arguments]) async {
    final m = await _method.invokeMapMethod<Object?, Object?>(
      method,
      arguments,
    );
    if (m == null) {
      throw PlatformException(
        code: 'camera_error',
        message: '$method returned no preview info',
      );
    }
    return PreviewInfo.fromMap(m);
  }

  @override
  Future<PreviewInfo> start() => _preview('start');

  @override
  Future<PreviewInfo> startScan() => _preview('startScan');

  @override
  Future<PreviewInfo> setWide(bool wide) => _preview('setWide', {'wide': wide});

  @override
  Future<void> stop() => _method.invokeMethod<void>('stop');

  @override
  Future<void> setRegions(Rect crop, Offset spot, double radius) =>
      _method.invokeMethod<void>('setRegions', {
        'crop': [crop.left, crop.top, crop.right, crop.bottom],
        'spot': [spot.dx, spot.dy, radius],
      });

  @override
  Future<String?> snapshot(String id) async {
    try {
      return await _method.invokeMethod<String>('snapshot', {'id': id});
    } on PlatformException catch (e) {
      debugPrint('snapshot failed: ${e.code} ${e.message}');
      return null;
    }
  }

  /// One cached broadcast stream; subscribers share the same event channel
  /// listener.
  @override
  late final Stream<MeterStats> stats = _events.receiveBroadcastStream().map(
    (e) => MeterStats.fromMap(e as Map<Object?, Object?>),
  );

  /// One cached broadcast stream, like [stats].
  @override
  late final Stream<String> qrCodes = _qr.receiveBroadcastStream().map(
    (e) => e as String,
  );
}
