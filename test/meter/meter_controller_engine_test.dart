import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/metering/reading.dart';

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

  test('setPhoneAe asks the camera for AE and back', () async {
    await c.setPhoneAe(true);
    expect(src.calls.last, 'setEngine(ae)');
    expect(c.phoneAe, isTrue);
    await c.setPhoneAe(false);
    expect(src.calls.last, 'setEngine(manual)');
  });

  test('the reading says whether it came from the phone\'s AE', () async {
    await c.resume();
    src.emit(manualStats());
    await Future<void>.delayed(Duration.zero);
    expect(c.readingFromAe, isFalse);
    src.emit(
      MeterStats.fromMap({
        'exposureNs': 10000000,
        'sensitivity': 100,
        'boost': 100,
        'aperture': 2.0,
        'minExposureNs': 10000,
        'maxExposureNs': 1000000000,
        'minIso': 50,
        'maxIso': 3200,
        'frameLuma': .18,
        'cropLuma': .18,
        'spotLuma': .18,
        'histogram': List<int>.filled(64, 0),
      }),
    );
    await Future<void>.delayed(Duration.zero);
    expect(c.readingFromAe, isTrue);
  });
}
