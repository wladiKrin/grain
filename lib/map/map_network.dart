import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'map_styles.dart';

/// One request MapLibre made, as the app's HTTP client saw it.
class MapRequest {
  const MapRequest(this.url, {required this.ok, this.blocked = false});

  final Uri url;

  /// It got an answer that is not an error: a tile, or none there (404).
  final bool ok;

  /// Asked for with the Offline style on: refused before going online.
  final bool blocked;
}

/// The map's HTTP client (`MapNetPlugin.kt`): it names Grain to every
/// server, can refuse everything (the Offline style), and says how each
/// request went.
abstract interface class MapNetwork {
  /// Every request, as it ends.
  Stream<MapRequest> get requests;

  /// Sets the User-Agent sent, and whether anything may go online.
  Future<void> configure({required String userAgent, required bool offline});
}

/// The app's [MapNetwork], over the `grain/map_net` channel.
class PlatformMapNetwork implements MapNetwork {
  PlatformMapNetwork._() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'request') return;
      final args = (call.arguments as Map).cast<String, Object?>();
      final r = MapRequest(
        Uri.parse(args['url']! as String),
        ok: args['ok'] == true,
        blocked: args['blocked'] == true,
      );
      if (r.blocked) debugPrint('Offline map style asked for ${r.url}');
      _requests.add(r);
    });
  }

  static final instance = PlatformMapNetwork._();

  static const _channel = MethodChannel('grain/map_net');
  final _requests = StreamController<MapRequest>.broadcast();

  @override
  Stream<MapRequest> get requests => _requests.stream;

  @override
  Future<void> configure({
    required String userAgent,
    required bool offline,
  }) async {
    try {
      await _channel.invokeMethod<void>('configure', {
        'userAgent': userAgent,
        'offline': offline,
      });
    } on MissingPluginException {
      // Not on Android (tests): there is no map client to set.
    }
  }
}

/// Whether the online map is failing: [failuresBeforeNote] requests to its
/// servers failed with none answered in between (no network, or the
/// network permission off), or its style could not be read. Requests to
/// other servers (a style left a moment ago) do not count.
class MapFailures extends ChangeNotifier {
  static const failuresBeforeNote = 3;

  MapStyleDoc? _style;
  int _failures = 0;
  bool _styleFailed = false;
  bool _dismissed = false;

  int get failures => _failures;
  bool get styleFailed => _styleFailed;

  /// The note is up.
  bool get showing =>
      (_styleFailed || _failures >= failuresBeforeNote) && !_dismissed;

  /// Something failed since the last answer.
  bool get failing => _styleFailed || _failures > 0;

  /// Counts for [style] from now on; a new style starts afresh. Tells no
  /// listener (called as the map is built).
  void watch(MapStyleDoc style) {
    if (style == _style) return;
    _style = style;
    _failures = 0;
    _styleFailed = false;
    _dismissed = false;
  }

  void request(MapRequest r) {
    final style = _style;
    if (r.blocked || style == null || !style.hosts.contains(r.url.host)) {
      return;
    }
    if (r.ok) {
      if (!failing && !_dismissed) return;
      _failures = 0;
      _styleFailed = false;
      _dismissed = false;
      notifyListeners();
      return;
    }
    final was = showing;
    _failures++;
    if (r.url.toString() == style.url) _styleFailed = true;
    if (showing != was) notifyListeners();
  }

  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }
}
