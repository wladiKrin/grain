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

  test('theme choice defaults to system, persists and reloads', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.theme, ThemeChoice.system);
    await s.setTheme(ThemeChoice.dark);
    expect((await Settings.load()).theme, ThemeChoice.dark);
    await s.setTheme(ThemeChoice.light);
    expect((await Settings.load()).theme, ThemeChoice.light);
  });

  test('an unknown stored theme choice falls back to system', () async {
    SharedPreferences.setMockInitialValues({'themeChoice': 'sepia'});
    expect((await Settings.load()).theme, ThemeChoice.system);
  });

  test('snapshots default on, location default off, both persist', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.snapshots, isTrue);
    expect(s.location, isFalse);
    await s.setSnapshots(false);
    await s.setLocation(true);
    final r = await Settings.load();
    expect(r.snapshots, isFalse);
    expect(r.location, isTrue);
  });

  test(
    'shake warning defaults off, persists and travels in the backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await Settings.load();
      expect(s.shakeWarning, isFalse);
      expect(s.backupMap()['shakeWarning'], isFalse);
      await s.setShakeWarning(true);
      final r = await Settings.load();
      expect(r.shakeWarning, isTrue);
      expect(r.backupMap()['shakeWarning'], isTrue);
      await r.applyBackupMap({'shakeWarning': false});
      expect(r.shakeWarning, isFalse);
      await r.applyBackupMap({'shakeWarning': 'yes'});
      expect(r.shakeWarning, isFalse);
    },
  );

  test(
    'click sound defaults off, persists and travels in the backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await Settings.load();
      expect(s.clickSound, isFalse);
      expect(s.backupMap()['clickSound'], isFalse);
      await s.setClickSound(true);
      final r = await Settings.load();
      expect(r.clickSound, isTrue);
      expect(r.backupMap()['clickSound'], isTrue);
      await r.applyBackupMap({'clickSound': false});
      expect(r.clickSound, isFalse);
      await r.applyBackupMap({'clickSound': 'yes'});
      expect(r.clickSound, isFalse);
    },
  );

  test('phone AE defaults off, persists, and stays out of backups', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.phoneAe, isFalse);
    await s.setPhoneAe(true);
    expect((await Settings.load()).phoneAe, isTrue);
    expect(s.backupMap().containsKey('phoneAe'), isFalse);
  });

  test('the online map defaults off, persists, and stays out of backups and '
      'off when a backup names it', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.onlineMap, isFalse);
    expect(Settings.inMemory().onlineMap, isFalse);
    await s.setOnlineMap(true);
    final r = await Settings.load();
    expect(r.onlineMap, isTrue);
    expect(r.backupMap().containsKey('onlineMap'), isFalse);
    await s.setOnlineMap(false);
    final fresh = await Settings.load();
    await fresh.applyBackupMap({'onlineMap': true});
    expect(fresh.onlineMap, isFalse);
    expect((await Settings.load()).onlineMap, isFalse);
  });

  test(
    'the frame defaults sideways, persists and travels in the backup',
    () async {
      SharedPreferences.setMockInitialValues({});
      final s = await Settings.load();
      expect(s.frameLandscape, isTrue);
      expect(s.backupMap()['frameLandscape'], isTrue);
      await s.setFrameLandscape(false);
      final r = await Settings.load();
      expect(r.frameLandscape, isFalse);
      await r.applyBackupMap({'frameLandscape': true});
      expect(r.frameLandscape, isTrue);
    },
  );

  test('histogram defaults off, persists and travels in the backup', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect(s.histogram, isFalse);
    expect(s.backupMap()['histogram'], isFalse);
    await s.setHistogram(true);
    expect(s.histogram, isTrue);
    final r = await Settings.load();
    expect(r.histogram, isTrue);
    expect(r.backupMap()['histogram'], isTrue);
    await r.applyBackupMap({'histogram': false});
    expect(r.histogram, isFalse);
    await r.applyBackupMap({'histogram': 'yes'});
    expect(r.histogram, isFalse);
    expect((await Settings.load()).histogram, isFalse);
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
