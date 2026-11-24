import 'dart:async';

import 'package:flutter/services.dart';
import 'package:grain/metering/meter_channel.dart';
import 'package:grain/metering/reading.dart';

/// Shared [MeterSource] fake: records calls, lets the test gate or fail
/// [start]/[stop]/[snapshot], and emit stats and QR texts.
class FakeMeterSource implements MeterSource {
  FakeMeterSource({
    this.textureId = 1,
    this.size = const Size(1440, 1080),
    this.sensorOrientation = 90,
    this.mainEqFocal = 25,
    this.wideEqFocal,
    this.maxZoom = 1,
    this.logRegions = true,
  });

  final int textureId;
  final Size size;
  final int sensorOrientation;
  final double mainEqFocal;

  /// The phone's ultra-wide; null means it has none.
  final double? wideEqFocal;

  /// The main camera's largest zoom; 1 means no camera zoom.
  final double maxZoom;

  /// Whether [setRegions] is recorded in [calls] (it always is in [regions]).
  final bool logRegions;

  /// `'start'`, `'startScan'`, `'stop'`, `'setRegions'`, `'setZoom(0.52)'`
  /// (the zoom asked for, two decimals), ...
  final calls = <String>[];
  final regions = <(Rect, Offset, double)>[];

  /// Thrown by [start] and [startScan] when set.
  Object? startError;

  /// Thrown by [setZoom] when set.
  Object? setZoomError;

  /// When set, [start]/[startScan] and [stop] wait for these.
  Completer<void>? startGate;
  Completer<void>? stopGate;

  /// Answers [snapshot] (recorded as `'snapshot(<id>)'`); null when unset.
  String? Function(String id)? snapshotPath;

  /// When set, [snapshot] waits for it before answering.
  Completer<void>? snapshotGate;

  /// When set, [setZoom] waits for it before answering.
  Completer<void>? zoomGate;

  bool _wide = false;
  double _zoom = 1;
  final _stats = StreamController<MeterStats>.broadcast();
  final _qr = StreamController<String>.broadcast();

  PreviewInfo get _preview => PreviewInfo(
    textureId: textureId,
    size: size,
    sensorOrientation: sensorOrientation,
    phoneEqFocal: _wide ? wideEqFocal! : mainEqFocal * _zoom,
    mainEqFocal: mainEqFocal,
    wideEqFocal: wideEqFocal,
    wide: _wide,
    zoom: _wide ? wideEqFocal! / mainEqFocal : _zoom,
    maxZoom: maxZoom,
  );

  Future<PreviewInfo> _open(String call) async {
    calls.add(call);
    await startGate?.future;
    if (startError != null) throw startError!;
    _wide = false;
    _zoom = 1;
    return _preview;
  }

  @override
  Future<PreviewInfo> start() => _open('start');

  @override
  Future<PreviewInfo> startScan() => _open('startScan');

  @override
  Future<void> stop() async {
    calls.add('stop');
    await stopGate?.future;
  }

  @override
  Future<void> setRegions(Rect crop, Offset spot, double radius) async {
    if (logRegions) calls.add('setRegions');
    regions.add((crop, spot, radius));
  }

  /// Like the native side: below 1 the ultra-wide (unchanged without one),
  /// above 1 capped at [maxZoom].
  @override
  Future<PreviewInfo> setZoom(double zoom) async {
    calls.add('setZoom(${zoom.toStringAsFixed(2)})');
    await zoomGate?.future;
    if (setZoomError != null) throw setZoomError!;
    if (zoom < 1) {
      if (wideEqFocal != null) _wide = true;
    } else {
      _wide = false;
      _zoom = zoom.clamp(1, maxZoom).toDouble();
    }
    return _preview;
  }

  @override
  Future<String?> snapshot(String id) async {
    calls.add('snapshot($id)');
    await snapshotGate?.future;
    return snapshotPath?.call(id);
  }

  @override
  Stream<MeterStats> get stats => _stats.stream;

  @override
  Stream<String> get qrCodes => _qr.stream;

  bool get hasListener => _stats.hasListener;
  bool get hasQrListener => _qr.hasListener;
  void emit(MeterStats s) => _stats.add(s);
  void fail(Object error) => _stats.addError(error);
  void emitQr(String text) => _qr.add(text);
  void failQr(Object error) => _qr.addError(error);
}
