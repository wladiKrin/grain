import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/metering/meter_channel.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/ui/haptics.dart';
import 'package:material_ui/material_ui.dart';

class _Source implements MeterSource {
  final calls = <String>[];

  @override
  Future<PreviewInfo> start() async {
    calls.add('start');
    return const PreviewInfo(
      textureId: 1,
      size: Size(1440, 1080),
      sensorOrientation: 90,
      phoneEqFocal: 25,
    );
  }

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Future<void> setRegions(Rect crop, Offset spot, double radius) async {}

  @override
  Stream<MeterStats> get stats => _stats.stream;
  final _stats = StreamController<MeterStats>.broadcast();
}

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

void main() {
  testWidgets('app boots on the meter screen and follows the lifecycle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    // A launched app starts in the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final src = _Source();
    await tester.pumpWidget(GrainApp(source: src, haptics: _Haptics()));
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(MeterScreen), findsOneWidget);
    expect(src.calls, ['start']);
    expect(find.byType(Texture), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // Subscription cancel completes on the real event loop.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(src.calls, ['start', 'stop']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(src.calls, ['start', 'stop', 'start']);
  });
}
