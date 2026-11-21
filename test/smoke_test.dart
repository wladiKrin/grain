import 'package:flutter_test/flutter_test.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/settings/settings_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_source.dart';

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
    final src = FakeMeterSource(logRegions: false);
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

  testWidgets('settings open from the meter and share the viewfinder pref', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1700, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = Settings.inMemory();
    await tester.pumpWidget(
      GrainApp(
        source: FakeMeterSource(logRegions: false),
        haptics: _Haptics(),
        settings: settings,
      ),
    );
    await tester.pump();
    expect(find.byType(Texture), findsOneWidget);

    // The eye toggle persists.
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();
    expect(settings.viewfinderOn, isFalse);

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // The settings switch drives the open meter.
    await tester.tap(find.text('Open with viewfinder on'));
    await tester.pumpAndSettle();
    expect(settings.viewfinderOn, isTrue);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.byType(Texture), findsOneWidget);
  });
}
