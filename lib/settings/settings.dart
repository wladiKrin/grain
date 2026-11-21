import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted preferences: calibration offset, haptics and the viewfinder
/// default (the app opens the way the viewfinder was left).
class Settings extends ChangeNotifier {
  Settings._(
    this._prefs, {
    required int thirds,
    required this._haptics,
    required bool vf,
  }) : _calibrationThirds = thirds,
       _viewfinderOn = vf;

  /// Non-persistent settings for tests.
  Settings.inMemory() : _prefs = null;

  static const _kCalibration = 'calibrationThirds';
  static const _kHaptics = 'haptics';
  static const _kViewfinder = 'viewfinderOn';

  /// Calibration range in thirds of a stop (±3 EV).
  static const maxThirds = 9;

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return Settings._(
      p,
      thirds: (p.getInt(_kCalibration) ?? 0).clamp(-maxThirds, maxThirds),
      haptics: p.getBool(_kHaptics) ?? true,
      vf: p.getBool(_kViewfinder) ?? true,
    );
  }

  final SharedPreferences? _prefs;

  int _calibrationThirds = 0;
  bool _haptics = true;
  bool _viewfinderOn = true;

  /// -9..9.
  int get calibrationThirds => _calibrationThirds;
  double get calibrationEv => _calibrationThirds / 3;
  bool get haptics => _haptics;
  bool get viewfinderOn => _viewfinderOn;

  Future<void> setCalibrationThirds(int v) async {
    v = v.clamp(-maxThirds, maxThirds);
    if (v == _calibrationThirds) return;
    _calibrationThirds = v;
    notifyListeners();
    await _prefs?.setInt(_kCalibration, v);
  }

  Future<void> setHaptics(bool v) async {
    if (v == _haptics) return;
    _haptics = v;
    notifyListeners();
    await _prefs?.setBool(_kHaptics, v);
  }

  Future<void> setViewfinderOn(bool v) async {
    if (v == _viewfinderOn) return;
    _viewfinderOn = v;
    notifyListeners();
    await _prefs?.setBool(_kViewfinder, v);
  }
}
