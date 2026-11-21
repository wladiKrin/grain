// Temporary bring-up screen for the Camera2 bridge; removed in Task 8.
// Grant the camera permission first: adb shell pm grant io.github.wladikrin.grain android.permission.CAMERA
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'meter_channel.dart';
import 'reading.dart';

class DebugMeterScreen extends StatefulWidget {
  const DebugMeterScreen({super.key, this.source});

  final MeterSource? source;

  @override
  State<DebugMeterScreen> createState() => _DebugMeterScreenState();
}

class _DebugMeterScreenState extends State<DebugMeterScreen> {
  late final MeterSource _source = widget.source ?? MeterChannel();
  StreamSubscription<MeterStats>? _sub;
  PreviewInfo? _info;
  MeterStats? _stats;
  String? _error;
  int _events = 0;
  double _rate = 0;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  void initState() {
    super.initState();
    _sub = _source.stats.listen((s) {
      _events++;
      final secs = _clock.elapsedMilliseconds / 1000;
      if (secs >= 1) {
        _rate = _events / secs;
        _events = 0;
        _clock.reset();
      }
      setState(() => _stats = s);
    }, onError: (Object e) => setState(() => _error = '$e'));
    _source.start().then(
      (i) {
        if (mounted) setState(() => _info = i);
      },
      onError: (Object e) {
        if (mounted) {
          setState(
            () => _error = e is PlatformException
                ? '${e.code}: ${e.message}'
                : '$e',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _source.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    final s = _stats;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (info != null)
              AspectRatio(
                // Buffer is in sensor orientation; the portrait view swaps the sides.
                aspectRatio: info.sensorOrientation % 180 == 0
                    ? info.size.width / info.size.height
                    : info.size.height / info.size.width,
                child: Texture(textureId: info.textureId),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Text(
                  [
                    if (_error != null) 'error: $_error',
                    if (info != null)
                      'texture ${info.textureId} ${info.size} orient ${info.sensorOrientation} eq ${info.phoneEqFocal.toStringAsFixed(1)} mm',
                    if (s != null) ...[
                      'EV100 ${readingFrom(s, area: MeterArea.average).ev100.toStringAsFixed(2)}',
                      'events/s ${_rate.toStringAsFixed(1)}',
                      'exposureNs ${s.exposureNs}  sensitivity ${s.sensitivity}  boost ${s.boost}  f/${s.aperture}',
                      'exposure ${s.minExposureNs}..${s.maxExposureNs}  iso ${s.minIso}..${s.maxIso}',
                      'frame ${s.frameLuma.toStringAsFixed(4)}  crop ${s.cropLuma.toStringAsFixed(4)}  spot ${s.spotLuma.toStringAsFixed(4)}',
                      'histogram ${s.histogram.join(' ')}',
                    ],
                  ].join('\n'),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
