import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/gear/ui/scan_screen.dart';
import 'package:grain/main.dart';
import 'package:grain/ui/haptics.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_source.dart';
import 'support/gear_fixtures.dart';

class _NoHaptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

/// Lets real-zone futures (a stream's cancel) complete, then pumps.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pumpAndSettle();
  }
}

Future<void> back(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.arrow_back).last);
  await settle(t);
}

void main() {
  late FakeMeterSource src;
  late GearController gear;

  setUp(() {
    src = FakeMeterSource(logRegions: false);
    gear = GearController.inMemory(library: fixtureLibrary());
  });
  tearDown(() => gear.dispose());

  Future<void> pumpApp(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.runAsync(() => gear.selectBody(libBody('canon-a1')));
    await t.pumpWidget(
      GrainApp(source: src, haptics: _NoHaptics(), gear: gear),
    );
    await settle(t);
    expect(src.calls, ['start']);
  }

  testWidgets('the meter camera stops behind the library', (t) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.photo_camera_outlined));
    await settle(t);
    expect(find.text('Library'), findsOneWidget);
    expect(src.calls, ['start', 'stop']);
    await back(t);
    expect(find.text('Library'), findsNothing);
    expect(src.calls, ['start', 'stop', 'start']);
  });

  testWidgets('a scan from the library runs; the meter resumes once', (
    t,
  ) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.photo_camera_outlined));
    await settle(t);
    await t.tap(find.byTooltip('Import'));
    await settle(t);
    await t.tap(find.text('Scan QR code'));
    await settle(t);
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(src.calls, ['start', 'stop', 'startScan']);

    await back(t); // closes the scan: the library is still up
    expect(find.byType(ScanScreen), findsNothing);
    expect(find.text('Library'), findsOneWidget);
    expect(src.calls, ['start', 'stop', 'startScan', 'stop']);

    await back(t); // closes the library: the meter comes back
    expect(src.calls, ['start', 'stop', 'startScan', 'stop', 'start']);
  });

  testWidgets('the meter camera stops behind settings', (t) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.tune));
    await settle(t);
    expect(src.calls, ['start', 'stop']);
    await t.tap(find.byIcon(Icons.arrow_back).last);
    await settle(t);
    expect(src.calls, ['start', 'stop', 'start']);
  });

  testWidgets('the meter camera stops behind the lens picker', (t) async {
    await pumpApp(t);
    await t.tap(find.text('Choose lens'));
    await settle(t);
    expect(src.calls, ['start', 'stop']);
    await back(t);
    expect(src.calls, ['start', 'stop', 'start']);
  });

  testWidgets('backgrounding mid-scan: scan reopens, meter waits for the pop', (
    t,
  ) async {
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.photo_camera_outlined));
    await settle(t);
    await t.tap(find.byTooltip('Import'));
    await settle(t);
    await t.tap(find.text('Scan QR code'));
    await settle(t);
    expect(src.calls, ['start', 'stop', 'startScan']);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
      await t.pump();
    }
    await settle(t);
    expect(src.calls, ['start', 'stop', 'startScan', 'stop', 'startScan']);
    expect(find.byType(ScanScreen), findsOneWidget);
    await back(t);
    await back(t);
    expect(src.calls, [
      'start',
      'stop',
      'startScan',
      'stop',
      'startScan',
      'stop',
      'start',
    ]);
  });
}
