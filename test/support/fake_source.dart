import 'dart:async';

import 'package:flutter/services.dart';
import 'package:grain/metering/meter_channel.dart';
import 'package:grain/metering/reading.dart';

/// Shared [MeterSource] fake: records calls, lets the test gate or fail
/// [start]/[stop], and emit stats and QR texts.
class FakeMeterSource implements MeterSource {
  FakeMeterSource({
    this.textureId = 1,
    this.size = const Size(1440, 1080),
    this.sensorOrientation = 90,
    this.mainEqFocal = 25,
    this.wideEqFocal,
    this.logRegions = true,
  });

  final int textureId;
  final Size size;
  final int sensorOrientation;
  final double mainEqFocal;

  /// The phone's ultra-wide; null means it has none.
  final double? wideEqFocal;

  /// Whether [setRegions] is recorded in [calls] (it always is in [regions]).
  final bool logRegions;

  /// `'start'`, `'startScan'`, `'stop'`, `'setRegions'`, `'setWide(true)'`, ...
  final calls = <String>[];
  final regions = <(Rect, Offset, double)>[];

  /// Thrown by [start] and [startScan] when set.
  Object? startError;

  /// Thrown by [setWide] when set.
  Object? setWideError;

  /// When set, [start]/[startScan] and [stop] wait for these.
  Completer<void>? startGate;
  Completer<void>? stopGate;

  bool _wide = false;
  final _stats = StreamController<MeterStats>.broadcast();
  final _qr = StreamController<String>.broadcast();

  PreviewInfo get _preview => PreviewInfo(
    textureId: textureId,
    size: size,
    sensorOrientation: sensorOrientation,
    phoneEqFocal: _wide ? wideEqFocal! : mainEqFocal,
    mainEqFocal: mainEqFocal,
    wideEqFocal: wideEqFocal,
    wide: _wide,
  );

  Future<PreviewInfo> _open(String call) async {
    calls.add(call);
    await startGate?.future;
    if (startError != null) throw startError!;
    _wide = false;
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

  @override
  Future<PreviewInfo> setWide(bool wide) async {
    calls.add('setWide($wide)');
    if (setWideError != null) throw setWideError!;
    _wide = wide && wideEqFocal != null;
    return _preview;
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
}
