import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location.dart';
import 'model.dart';

/// [LocationSource] over the native `grain/location` channel (the platform
/// LocationManager, no Play Services).
class LocationChannel implements LocationSource {
  LocationChannel({MethodChannel? channel, Future<bool> Function()? request})
    : _channel = channel ?? const MethodChannel('grain/location'),
      _request = request ?? _requestWhenInUse;

  final MethodChannel _channel;
  final Future<bool> Function() _request;

  static Future<bool> _requestWhenInUse() async {
    final status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  @override
  Future<GeoFix?> current() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('current', {
        'timeoutMs': 10000,
      });
      if (m == null) return null;
      return GeoFix(
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<bool> requestPermission() => _request();
}
