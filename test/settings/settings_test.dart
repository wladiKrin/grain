import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../meter/meter_controller_test.dart' show stats, settle;
import '../support/fake_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.calibrationThirds, 0);
    expect(s.calibrationEv, 0);
    expect(s.haptics, isTrue);
    expect(s.viewfinderOn, isTrue);
  });

  test('persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    await s.setCalibrationThirds(-4);
    await s.setHaptics(false);
    await s.setViewfinderOn(false);
    final r = await Settings.load();
    expect(r.calibrationThirds, -4);
    expect(r.calibrationEv, closeTo(-4 / 3, 1e-9));
    expect(r.haptics, isFalse);
    expect(r.viewfinderOn, isFalse);
  });

  test('reads stored values', () async {
    SharedPreferences.setMockInitialValues({
      'calibrationThirds': 2,
      'haptics': false,
      'viewfinderOn': false,
    });
    final s = await Settings.load();
    expect(s.calibrationThirds, 2);
    expect(s.haptics, isFalse);
    expect(s.viewfinderOn, isFalse);
  });

  test('calibration clamps to -9..9', () async {
    final s = Settings.inMemory();
    await s.setCalibrationThirds(20);
    expect(s.calibrationThirds, 9);
    await s.setCalibrationThirds(-20);
    expect(s.calibrationThirds, -9);
  });

  test('notifies listeners on change only', () async {
    final s = Settings.inMemory();
    var n = 0;
    s.addListener(() => n++);
    await s.setHaptics(false);
    await s.setHaptics(false);
    expect(n, 1);
  });

  test('+3 thirds shifts the controller reading by +1 EV', () async {
    final s = Settings.inMemory();
    final src = FakeMeterSource(size: const Size(4000, 3000));
    final c = MeterController(source: src);
    addTearDown(c.dispose);
    await c.resume();
    src.emit(stats());
    await settle();
    final base = c.reading!.ev100;
    await s.setCalibrationThirds(3);
    c.calibrationEv = s.calibrationEv;
    expect(c.reading!.ev100 - base, closeTo(1, 1e-6));
  });

  group('SystemHaptics', () {
    var calls = 0;
    setUp(() {
      calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') calls++;
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    test('enabled ticks reach the platform', () {
      SystemHaptics(enabled: true).tick(strong: false);
      expect(calls, 1);
    });

    test('disabled makes no platform calls', () {
      final h = SystemHaptics(enabled: false);
      h.tick(strong: false);
      h.tick(strong: true);
      expect(calls, 0);
    });
  });
}
