import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/meter_controller.dart';

import '../support/fake_source.dart';

void main() {
  late FakeMeterSource src;
  late MeterController c;
  setUp(() {
    src = FakeMeterSource(size: const Size(1440, 1080));
    c = MeterController(source: src, statsLog: (_, {wrapWidth}) {});
  });
  tearDown(() => c.dispose());

  test('manual-engine stats drive the reading', () async {
    await c.resume();
    src.emit(manualStats(crop: .36));
    await Future<void>.delayed(Duration.zero);
    // f/2, 1/100 s, ISO 100 at twice mid grey: 8.64 + 1.
    expect(c.reading!.ev100, closeTo(9.64, .01));
  });

  test('a clipped manual frame keeps the last reading', () async {
    await c.resume();
    src.emit(manualStats());
    await Future<void>.delayed(Duration.zero);
    final before = c.reading!.ev100;
    src.emit(manualStats(crop: .98, loop: 'clipped'));
    await Future<void>.delayed(Duration.zero);
    expect(c.reading!.ev100, before);
  });

  test('the regions say whether the spot is metered', () async {
    await c.resume();
    expect(src.spotMetering.last, isFalse);
    c.tapSpot(const Offset(.5, .5));
    expect(src.spotMetering.last, isTrue);
    c.clearSpot();
    expect(src.spotMetering.last, isFalse);
  });

  test('hold freezes the reading while the loop keeps exposing', () async {
    await c.resume();
    src.emit(manualStats());
    await Future<void>.delayed(Duration.zero);
    final held = c.reading!.ev100;
    c.toggleHold();
    src.emit(manualStats(exposureNs: 2500000, crop: .2));
    await Future<void>.delayed(Duration.zero);
    expect(c.reading!.ev100, held);
    c.toggleHold();
    expect(c.reading!.ev100, isNot(held));
  });

  testWidgets('toggleEngine asks for AE, shows it briefly, then back', (
    t,
  ) async {
    await c.toggleEngine();
    expect(src.calls.last, 'setEngine(ae)');
    expect(c.engineHint, 'AE');
    await t.pump(const Duration(seconds: 2));
    expect(c.engineHint, isNull);
    await c.toggleEngine();
    expect(src.calls.last, 'setEngine(manual)');
    expect(c.engineHint, 'M');
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('without manual support the hint says AE', (t) async {
    src.manualSupported = false;
    await c.toggleEngine(); // to AE
    await c.toggleEngine(); // asks for manual, gets AE
    expect(src.calls.last, 'setEngine(manual)');
    expect(c.engineHint, 'AE');
    await t.pump(const Duration(seconds: 2));
  });
}
