import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../exposure/scales.dart';
import '../exposure/solver.dart';
import '../gear/gear_scales.dart';
import '../gear/model.dart';
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
    GearSetup gear = const GearSetup(),
  }) : _gear = gear {
    _scales = _scalesAt(gear);
    // Nearest, never -1: the gear may lack the defaults (e.g. ISO 400).
    apertureIndex = nearestIndex(apertures, 5.6);
    shutterIndex = nearestIndex(shutters, 1 / 125);
    isoIndex = nearestIndex(isos, 400);
  }

  final MeterSource _source;

  GearSetup _gear;
  late GearScales _scales;

  /// The selected body, lens and focal length; [setFocal] keeps its focal
  /// in step with the dial.
  GearSetup get gear => _gear;

  /// Scales of the current gear (free-mode thirds over the full ranges when
  /// no body or lens is selected).
  List<ScaleValue> get apertures => _scales.apertures;
  List<ScaleValue> get shutters => _scales.shutters;
  List<ScaleValue> get isos => _scales.isos;
  List<ScaleValue> get focalValues => _scales.focals;

  /// Selected focal length of the lens, mm on its own film format.
  double get focal => focalValues[focalIndex].value;
  bool get hasBulb => _scales.hasBulb;
  FilmFormat get format => _scales.format;

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

  /// Scales for [g] at its focal length snapped to a focal detent, which
  /// also sets [focalIndex].
  GearScales _scalesAt(GearSetup g) {
    final s = scalesFor(g);
    focalIndex = nearestIndex(s.focals, g.focal);
    final f = s.focals[focalIndex].value;
    return f == g.focal
        ? s
        : scalesFor(GearSetup(body: g.body, lens: g.lens, focal: f));
  }

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

  /// Exact time, seconds, when aperture priority needs longer than the
  /// slowest timed speed and the body has B (or T); null otherwise.
  double? get bulbSeconds {
    final solved = solvedShutter;
    if (solved == null || solved.flag != RangeFlag.under || !hasBulb) {
      return null;
    }
    final n = apertures[apertureIndex].value;
    return n * n / math.pow(2, evAtIso(_ev100, _iso));
  }

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
    if (_lent || _running || _starting) return;
    _starting = true;
    cameraDenied = false;
    cameraError = null;
    try {
      while (true) {
        final info = await _source.start();
        if (_wantRunning && !_disposed) {
          preview = info;
          _running = true;
          _session++;
          _wideFailed = false;
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
    if (_disposed) return;
    notifyListeners();
    await _syncWide();
  }

  bool _lent = false;

  /// Runs [use] (e.g. a QR scan) with the camera released: pauses the meter,
  /// keeps [resume] from reopening it meanwhile, and resumes afterwards.
  Future<T> lendCamera<T>(Future<T> Function() use) async {
    _lent = true;
    try {
      await pause();
      return await use();
    } finally {
      _lent = false;
      await resume();
    }
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
      lensFocal: equivalentFocal(focal, format),
      phoneEqFocal: p.phoneEqFocal,
      aspect: format.portraitAspect,
    );
  }

  /// Whether the lens sees more than the camera in use (the crop cannot
  /// show all of its field).
  bool get lensWiderThanCamera {
    final p = preview;
    return p != null &&
        widerThanPhone(equivalentFocal(focal, format), p.phoneEqFocal);
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
    focalIndex = i.clamp(0, focalValues.length - 1);
    _gear = GearSetup(body: _gear.body, lens: _gear.lens, focal: focal);
    final lens = _gear.lens;
    if (lens != null && lens.maxAperture.length > 1) {
      // A varying-aperture zoom: the widest aperture follows the focal.
      final value = apertures[apertureIndex].value;
      _scales = scalesFor(_gear);
      apertureIndex = nearestIndex(apertures, value);
    }
    _sendRegions();
    unawaited(_syncWide());
    notifyListeners();
  }

  /// Switches to [g]: the dials keep their values where the new scales have
  /// them, else snap to the nearest. No-op when [g] equals [gear].
  void setGear(GearSetup g) {
    if (g == _gear) return;
    final aperture = apertures[apertureIndex].value;
    final shutter = shutters[shutterIndex].value;
    final iso = isos[isoIndex].value;
    _gear = g;
    _scales = _scalesAt(g);
    apertureIndex = nearestIndex(apertures, aperture);
    shutterIndex = nearestIndex(shutters, shutter);
    isoIndex = nearestIndex(isos, iso);
    _sendRegions();
    unawaited(_syncWide());
    notifyListeners();
  }

  /// Bumped on every successful start; a switch answer from an earlier
  /// camera session is dropped.
  int _session = 0;
  bool _wideBusy = false;

  /// A switch failed in this camera session: stay on the main camera until
  /// the next start.
  bool _wideFailed = false;

  /// Moves to the ultra-wide when the lens is wider than the main camera
  /// and back when it is not. One call in flight; the wanted state is
  /// re-checked when it answers, so the last focal change wins.
  Future<void> _syncWide() async {
    if (_wideBusy) return;
    _wideBusy = true;
    try {
      while (true) {
        final p = preview;
        if (!_running || _disposed || _wideFailed || p == null) return;
        final wideEq = p.wideEqFocal;
        final want =
            wideEq != null && equivalentFocal(focal, format) < p.mainEqFocal;
        if (want == p.wide) return;
        final session = _session;
        final PreviewInfo next;
        try {
          next = await _source.setWide(want);
        } on PlatformException catch (e) {
          if (session == _session) _wideFailed = true;
          debugPrint('GRAIN setWide($want) failed: ${e.code} ${e.message}');
          continue; // Re-check: a new session may want a switch.
        }
        // Paused, stopped or restarted meanwhile: the answer is stale.
        if (session != _session || !_running || _disposed) continue;
        preview = next;
        // The camera could not switch (it answered its unchanged preview):
        // asking again would loop.
        if (next.wide != want) _wideFailed = true;
        _sendRegions();
        notifyListeners();
      }
    } finally {
      _wideBusy = false;
    }
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
