import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/codec.dart';
import 'package:grain/gear/model.dart';
import 'package:grain/gear/ui/scan_screen.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_source.dart';
import '../../support/gear_fixtures.dart';

late FakeMeterSource src;
GearDoc? popped;
bool done = false;

Future<void> openScan(WidgetTester t) async {
  popped = null;
  done = false;
  await t.pumpWidget(
    MaterialApp(
      theme: grainTheme(),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async {
            popped = await Navigator.push<GearDoc>(
              c,
              MaterialPageRoute(builder: (_) => ScanScreen(source: src)),
            );
            done = true;
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
}

Future<void> emit(WidgetTester t, String text) async {
  src.emitQr(text);
  await t.pump(); // deliver the event
  await t.pump(); // build the result
}

/// Lets real-zone futures (a stream's cancel) complete, then pumps.
Future<void> settleReal(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await t.pumpAndSettle();
  }
}

void main() {
  final a1 = libBody('canon-a1');

  setUp(() => src = FakeMeterSource());

  testWidgets('scan shows the preview, frame and hint', (t) async {
    await openScan(t);
    expect(find.byType(Texture), findsOneWidget);
    expect(find.text('Point at a Grain QR code'), findsOneWidget);
    expect(src.calls, ['startScan']);
    expect(src.hasQrListener, isTrue);
  });

  testWidgets('scan ignores foreign codes and returns the first profile', (
    t,
  ) async {
    await openScan(t);
    await emit(t, 'https://example.org');
    expect(find.text('Not a Grain profile'), findsOneWidget);
    expect(done, isFalse);
    await t.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(find.text('Not a Grain profile'), findsNothing);
    expect(find.text('Point at a Grain QR code'), findsOneWidget);

    await emit(t, 'hello');
    await emit(t, '{"schema":1,"type":"tripod"}');
    expect(find.text('Not a Grain profile'), findsOneWidget);
    expect(done, isFalse);
    expect(src.calls, ['startScan']);
    await t.pump(const Duration(seconds: 3));

    await emit(t, encodeCompact(a1));
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect((popped as Body).id, 'canon-a1');
    expect(src.calls, ['startScan', 'stop']);
  });

  testWidgets('the camera is released before the screen pops', (t) async {
    await openScan(t);
    src.stopGate = Completer<void>();
    await emit(t, encodeCompact(a1));
    await t.pump(const Duration(seconds: 1));
    expect(src.calls, ['startScan', 'stop']);
    expect(done, isFalse);
    expect(find.byType(ScanScreen), findsOneWidget);
    src.stopGate!.complete();
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(src.calls, ['startScan', 'stop']);
  });

  testWidgets('back stops the camera once and returns null', (t) async {
    await openScan(t);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(popped, isNull);
    expect(src.calls, ['startScan', 'stop']);
  });

  testWidgets('scan with camera denied explains and can go back', (t) async {
    src.startError = PlatformException(code: 'denied');
    await openScan(t);
    expect(
      find.text('Grain needs the camera to scan a profile.'),
      findsOneWidget,
    );
    expect(find.byType(Texture), findsNothing);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(popped, isNull);
  });

  testWidgets('the scan releases the camera before the meter restarts', (
    t,
  ) async {
    src = FakeMeterSource(logRegions: false);
    final meter = MeterController(source: src);
    addTearDown(meter.dispose);
    await meter.resume();
    late BuildContext ctx;
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    GearDoc? doc;
    final lend = meter.lendCamera(
      () => Navigator.push<GearDoc>(
        ctx,
        MaterialPageRoute(builder: (_) => ScanScreen(source: src)),
      ),
    );
    lend.then((d) => doc = d);
    await settleReal(t);
    expect(src.calls, ['start', 'stop', 'startScan']);

    src.stopGate = Completer<void>();
    await emit(t, encodeCompact(a1));
    await settleReal(t);
    // The scan's stop is pending: the meter must not have restarted.
    expect(src.calls, ['start', 'stop', 'startScan', 'stop']);
    src.stopGate!.complete();
    await settleReal(t);
    expect(src.calls, ['start', 'stop', 'startScan', 'stop', 'start']);
    expect((doc as Body).id, 'canon-a1');
  });

  testWidgets('a profile from a newer Grain shows the upgrade message', (
    t,
  ) async {
    await openScan(t);
    final m = jsonDecode(encodePretty(a1)) as Map<String, Object?>;
    m['schema'] = 2;
    await emit(t, jsonEncode(m));
    expect(
      find.text('schema: made by a newer version of Grain (schema 2)'),
      findsOneWidget,
    );
    expect(find.text('Not a Grain profile'), findsNothing);
    expect(done, isFalse);
    await t.pump(const Duration(seconds: 2, milliseconds: 100));
    expect(find.text('Point at a Grain QR code'), findsOneWidget);
  });

  testWidgets('a camera error while scanning shows a calm notice', (t) async {
    await openScan(t);
    src.failQr(PlatformException(code: 'camera_error', message: 'Gone'));
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Camera unavailable\nGone'), findsOneWidget);
    expect(find.byType(Texture), findsNothing);
    // The native side already tore the scan down: back does not stop again.
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(src.calls, ['startScan']);
  });

  testWidgets('backgrounding releases the scan camera; resume reopens it', (
    t,
  ) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await openScan(t);
    expect(src.calls, ['startScan']);
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
      await t.pump();
    }
    expect(src.calls, ['startScan', 'stop']);
    for (final s in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      t.binding.handleAppLifecycleStateChanged(s);
      await t.pump();
    }
    await t.pump();
    expect(src.calls, ['startScan', 'stop', 'startScan']);
    expect(find.byType(Texture), findsOneWidget);
    // Still scanning: a code is taken and the camera released once.
    await emit(t, encodeCompact(a1));
    await t.pumpAndSettle();
    expect((popped as Body).id, 'canon-a1');
    expect(src.calls, ['startScan', 'stop', 'startScan', 'stop']);
  });

  testWidgets('back while backgrounded does not stop twice', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await openScan(t);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await t.pump();
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(done, isTrue);
    expect(src.calls, ['startScan', 'stop']);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pumpAndSettle();
    expect(src.calls, ['startScan', 'stop']);
  });

  testWidgets('a camera error clears on the next resume', (t) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await openScan(t);
    src.failQr(PlatformException(code: 'camera_error', message: 'Gone'));
    await t.pump();
    await t.pump();
    expect(find.text('Camera unavailable\nGone'), findsOneWidget);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await t.pump();
    await t.pump();
    expect(src.calls, ['startScan', 'startScan']);
    expect(find.byType(Texture), findsOneWidget);
  });
}
