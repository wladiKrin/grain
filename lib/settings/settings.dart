import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which palette the app wears: the system's, or one fixed.
enum ThemeChoice { system, light, dark }

/// Persisted preferences: calibration offset, haptics and the viewfinder and
/// histogram defaults (the app opens the way they were left).
class Settings extends ChangeNotifier {
  Settings._(
    this._prefs, {
    required int thirds,
    required this._haptics,
    required bool vf,
    required this._snapshots,
    required this._location,
    required this._histogram,
    required this._frameLandscape,
    required this._shakeWarning,
    required this._clickSound,
    required this._theme,
  }) : _calibrationThirds = thirds,
       _viewfinderOn = vf;

  /// Non-persistent settings for tests.
  Settings.inMemory() : _prefs = null;

  static const _kCalibration = 'calibrationThirds';
  static const _kHaptics = 'haptics';
  static const _kViewfinder = 'viewfinderOn';
  static const _kSnapshots = 'snapshots';
  static const _kLocation = 'location';
  static const _kHistogram = 'histogram';
  static const _kFrameLandscape = 'frameLandscape';
  static const _kShake = 'shakeWarning';
  static const _kClick = 'clickSound';
  static const _kTheme = 'themeChoice';

  /// Calibration range in thirds of a stop (±3 EV).
  static const maxThirds = 9;

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    return Settings._(
      p,
      thirds: (p.getInt(_kCalibration) ?? 0).clamp(-maxThirds, maxThirds),
      haptics: p.getBool(_kHaptics) ?? true,
      vf: p.getBool(_kViewfinder) ?? true,
      snapshots: p.getBool(_kSnapshots) ?? true,
      location: p.getBool(_kLocation) ?? false,
      histogram: p.getBool(_kHistogram) ?? false,
      frameLandscape: p.getBool(_kFrameLandscape) ?? true,
      shakeWarning: p.getBool(_kShake) ?? false,
      clickSound: p.getBool(_kClick) ?? false,
      theme:
          ThemeChoice.values.asNameMap()[p.getString(_kTheme)] ??
          ThemeChoice.system,
    );
  }

  final SharedPreferences? _prefs;

  int _calibrationThirds = 0;
  bool _haptics = true;
  bool _viewfinderOn = true;
  bool _snapshots = true;
  bool _location = false;
  bool _histogram = false;
  bool _frameLandscape = true;
  bool _shakeWarning = false;
  bool _clickSound = false;
  ThemeChoice _theme = ThemeChoice.system;

  /// -9..9.
  int get calibrationThirds => _calibrationThirds;
  double get calibrationEv => _calibrationThirds / 3;
  bool get haptics => _haptics;
  bool get viewfinderOn => _viewfinderOn;

  /// Take a snapshot with every logged frame or saved reading.
  bool get snapshots => _snapshots;

  /// Attach the location to every logged frame or saved reading.
  bool get location => _location;

  /// Show the histogram over the viewfinder.
  bool get histogram => _histogram;

  /// Draw the lens frame sideways (landscape) in the viewfinder.
  bool get frameLandscape => _frameLandscape;

  /// Mark shutter speeds slower than 1/focal length (35 mm equivalent).
  bool get shakeWarning => _shakeWarning;

  /// Play a soft click with every dial detent.
  bool get clickSound => _clickSound;

  /// Light, dark, or follow the system.
  ThemeChoice get theme => _theme;

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

  Future<void> setSnapshots(bool v) async {
    if (v == _snapshots) return;
    _snapshots = v;
    notifyListeners();
    await _prefs?.setBool(_kSnapshots, v);
  }

  Future<void> setLocation(bool v) async {
    if (v == _location) return;
    _location = v;
    notifyListeners();
    await _prefs?.setBool(_kLocation, v);
  }

  Future<void> setHistogram(bool v) async {
    if (v == _histogram) return;
    _histogram = v;
    notifyListeners();
    await _prefs?.setBool(_kHistogram, v);
  }

  Future<void> setFrameLandscape(bool v) async {
    if (v == _frameLandscape) return;
    _frameLandscape = v;
    notifyListeners();
    await _prefs?.setBool(_kFrameLandscape, v);
  }

  Future<void> setShakeWarning(bool v) async {
    if (v == _shakeWarning) return;
    _shakeWarning = v;
    notifyListeners();
    await _prefs?.setBool(_kShake, v);
  }

  Future<void> setClickSound(bool v) async {
    if (v == _clickSound) return;
    _clickSound = v;
    notifyListeners();
    await _prefs?.setBool(_kClick, v);
  }

  Future<void> setTheme(ThemeChoice v) async {
    if (v == _theme) return;
    _theme = v;
    notifyListeners();
    await _prefs?.setString(_kTheme, v.name);
  }

  /// The settings a backup carries. Calibration belongs to this phone's
  /// sensor and location to its owner's choice: neither travels.
  Map<String, Object?> backupMap() => {
    _kHaptics: _haptics,
    _kViewfinder: _viewfinderOn,
    _kSnapshots: _snapshots,
    _kHistogram: _histogram,
    _kFrameLandscape: _frameLandscape,
    _kShake: _shakeWarning,
    _kClick: _clickSound,
  };

  /// Applies [m] from a backup: only the keys of [backupMap]; a value of the
  /// wrong type is ignored.
  Future<void> applyBackupMap(Map<String, Object?> m) async {
    if (m[_kHaptics] case final bool v) await setHaptics(v);
    if (m[_kViewfinder] case final bool v) await setViewfinderOn(v);
    if (m[_kSnapshots] case final bool v) await setSnapshots(v);
    if (m[_kHistogram] case final bool v) await setHistogram(v);
    if (m[_kFrameLandscape] case final bool v) await setFrameLandscape(v);
    if (m[_kShake] case final bool v) await setShakeWarning(v);
    if (m[_kClick] case final bool v) await setClickSound(v);
  }
}
