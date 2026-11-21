import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../exposure/scales.dart';
import '../exposure/solver.dart';
import '../metering/fov.dart';
import '../metering/meter_channel.dart';
import '../metering/reading.dart';

enum MeterMode { aperturePriority, shutterPriority, manual }

const _centre = Offset(.5, .5);
/// Spot radius relative to the crop width: a 4 % circle (spec §5.2: ~3–5 %).
const _spotRadius = 0.02;

/// State and lifecycle of the meter screen. Owns the camera subscription:
/// [resume] opens it, [pause] releases it.
class MeterController extends ChangeNotifier {
  MeterController({
    required this._source,
    this._calibrationEv = 0,
    this.viewfinderOn = true,
  }) {
    apertureIndex = _indexOf(apertures, '5.6');
    shutterIndex = _indexOf(shutters, '1/125');
    isoIndex = _indexOf(isos, '400');
    focalIndex = focalStops.indexOf(50);
  }

  final MeterSource _source;

  /// Free-mode scales, thirds over the full ranges.
  final List<ScaleValue> apertures = apertureScale(step: StepSize.third);
  final List<ScaleValue> shutters = shutterScale(step: StepSize.third);
  final List<ScaleValue> isos = isoScale();

  MeterMode mode = MeterMode.aperturePriority;
  late int apertureIndex, shutterIndex, isoIndex, focalIndex;
  bool viewfinderOn;

  /// Spot position, normalized display coordinates.
  Offset spot = _centre;
  MeterArea area = MeterArea.average;
  Reading? reading;
  PreviewInfo? preview;
  bool cameraDenied = false;

  /// Message of a non-permission camera failure, if any.
  String? cameraError;
  bool held = false;

  double _calibrationEv;
  double get calibrationEv => _calibrationEv;
  set calibrationEv(double v) {
    if (v == _calibrationEv) return;
    _calibrationEv = v;
    _derive();
    notifyListeners();
  }

  MeterStats? _latest;

  /// The frame captured by [toggleHold]; while [held], the reading derives
  /// from it (spot, area and calibration changes included).
  MeterStats? _frozenStats;
  StreamSubscription<MeterStats>? _sub;
  bool _running = false;
  bool _starting = false;

  /// Set by resume, cleared by pause/dispose; lets an in-flight start notice
  /// that it was cancelled.
  bool _wantRunning = false;
  bool _disposed = false;

  static int _indexOf(List<ScaleValue> s, String label) =>
      s.indexWhere((v) => v.label == label);

  double get _ev100 => reading!.ev100;
  double get _iso => isos[isoIndex].value;

  Solved? get solvedShutter =>
      reading == null || mode != MeterMode.aperturePriority
      ? null
      : solveShutter(
          ev100: _ev100,
          iso: _iso,
          aperture: apertures[apertureIndex].value,
          shutters: shutters,
        );

  Solved? get solvedAperture =>
      reading == null || mode != MeterMode.shutterPriority
      ? null
      : solveAperture(
          ev100: _ev100,
          iso: _iso,
          shutter: shutters[shutterIndex].value,
          apertures: apertures,
        );

  double? get offset => reading == null || mode != MeterMode.manual
      ? null
      : manualOffset(
          ev100: _ev100,
          iso: _iso,
          aperture: apertures[apertureIndex].value,
          shutter: shutters[shutterIndex].value,
        );

  Future<void> resume() async {
    if (_disposed) return;
    // Recorded before the guard so a resume during an in-flight start keeps it.
    _wantRunning = true;
    if (_running || _starting) return;
    _starting = true;
    cameraDenied = false;
    cameraError = null;
    try {
      while (true) {
        final info = await _source.start();
        if (_wantRunning && !_disposed) {
          preview = info;
          _running = true;
          _sub = _source.stats.listen(_onStats, onError: _onStatsError);
          _sendRegions();
          break;
        }
        // Paused or disposed while starting: release the camera again.
        await _source.stop();
        // Resumed again while it was being released: start over.
        if (!_wantRunning || _disposed) break;
      }
    } on PlatformException catch (e) {
      if (e.code == 'denied') {
        cameraDenied = true;
      } else {
        cameraError = e.message ?? e.code;
      }
    } finally {
      _starting = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> pause() async {
    _wantRunning = false;
    final wasRunning = _running;
    _running = false;
    await _sub?.cancel();
    _sub = null;
    if (wasRunning) await _source.stop();
  }

  bool _loggedFirstStats = false;

  void _onStats(MeterStats s) {
    if (!_running) return;
    if (!_loggedFirstStats) {
      _loggedFirstStats = true;
      // Cold-start timing: compare this logcat timestamp with the launch.
      debugPrint('GRAIN first EV');
    }
    // A frame that gives no finite EV (bad AE metadata) is dropped, so
    // [_latest] always derives a reading.
    if (readingFrom(s, area: area) == null) return;
    _latest = s;
    if (held) return;
    _derive();
    notifyListeners();
  }

  /// The native side tears the camera down after reporting an error; a later
  /// [resume] opens it again.
  void _onStatsError(Object error) {
    if (!_running) return;
    _running = false;
    unawaited(_sub?.cancel());
    _sub = null;
    preview = null;
    _latest = null;
    cameraError = error is PlatformException
        ? (error.message ?? error.code)
        : error.toString();
    if (!held) reading = null;
    if (!_disposed) notifyListeners();
  }

  void _derive() {
    final s = held ? _frozenStats : _latest;
    if (s == null) {
      reading = null;
      return;
    }
    reading = readingFrom(s, area: area, calibration: _calibrationEv);
  }

  /// Preview buffer size in portrait display orientation, once started.
  Size? get previewSize {
    final s = preview?.size;
    if (s == null) return null;
    // The preview buffer is landscape; crops are in portrait display space.
    return s.width > s.height ? Size(s.height, s.width) : s;
  }

  /// The current lens's field of view, normalized in [previewSize].
  Rect? get cropRect {
    final p = preview, size = previewSize;
    if (p == null || size == null) return null;
    return lensCrop(
      preview: size,
      lensFocal: focalStops[focalIndex].toDouble(),
      phoneEqFocal: p.phoneEqFocal,
    );
  }

  /// Spot radius relative to the crop width.
  double get spotRadius => _spotRadius;

  void _sendRegions() {
    final crop = cropRect;
    if (crop == null) return;
    unawaited(_source.setRegions(crop, spot, _spotRadius));
  }

  void setMode(MeterMode m) {
    mode = m;
    notifyListeners();
  }

  void setAperture(int i) {
    apertureIndex = i.clamp(0, apertures.length - 1);
    notifyListeners();
  }

  void setShutter(int i) {
    shutterIndex = i.clamp(0, shutters.length - 1);
    notifyListeners();
  }

  void setIso(int i) {
    isoIndex = i.clamp(0, isos.length - 1);
    notifyListeners();
  }

  void setFocal(int i) {
    focalIndex = i.clamp(0, focalStops.length - 1);
    _sendRegions();
    notifyListeners();
  }

  void toggleViewfinder() {
    viewfinderOn = !viewfinderOn;
    notifyListeners();
  }

  void tapSpot(Offset normalized) {
    spot = normalized;
    area = MeterArea.spot;
    _derive();
    _sendRegions();
    notifyListeners();
  }

  void clearSpot() {
    spot = _centre;
    area = MeterArea.average;
    _derive();
    _sendRegions();
    notifyListeners();
  }

  void toggleHold() {
    held = !held;
    _frozenStats = held ? _latest : null;
    _derive();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wantRunning = false;
    _sub?.cancel();
    super.dispose();
  }
}
