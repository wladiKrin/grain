import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/backup/backup.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/rolls/model.dart';
import 'package:grain/rolls/roll_controller.dart';
import 'package:grain/settings/licences.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/settings/settings_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/permissions.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/rolls_fixtures.dart';
import '../support/fake_location.dart';
import '../support/fake_platform.dart';
import '../support/stops_finder.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

/// The Switch in the row that carries [label].
Finder _switchOf(String label) => find.descendant(
  of: find.ancestor(
    of: find.text(label),
    matching: find.byType(MergeSemantics),
  ),
  matching: find.byType(Switch),
);

Widget _app(
  Settings s, [
  FakeLocation? location,
  RollController? rolls,
  FakeGearPlatform? platform,
  GearController? gear,
  OpenSettings? openSettings,
]) => MaterialApp(
  theme: grainTheme(),
  home: SettingsScreen(
    settings: s,
    haptics: _Haptics(),
    location: location,
    gear: gear ?? GearController.inMemory(),
    rolls: rolls ?? inMemoryRolls(settings: s),
    platform: platform ?? FakeGearPlatform(),
    now: () => DateTime(2026, 11, 21, 9, 30),
    openSettings: openSettings ?? () async => true,
  ),
);

/// Lets real async work (isolates, files) run until [done].
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
  }
  expect(done(), isTrue, reason: 'timed out');
}

/// Scrolls the settings list until [f] is fully on screen.
Future<void> _reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

bool _shows(String text) => find.text(text).evaluate().isNotEmpty;

bool _showsPart(String text) => find.textContaining(text).evaluate().isNotEmpty;

void main() {
  testWidgets('shows calibration, helper text and footer', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    expect(find.text('CALIBRATION'), findsOneWidget);
    expect(
      find.text('Compare with a camera you trust and nudge until they agree.'),
      findsOneWidget,
    );
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('Open with viewfinder on'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    await _reveal(tester, find.textContaining('Grain · GPLv3 · '));
    expect(find.textContaining('Grain · GPLv3 · '), findsOneWidget);
  });

  testWidgets('dial shows stored calibration label', (tester) async {
    final s = Settings.inMemory();
    await s.setCalibrationThirds(-4);
    await tester.pumpWidget(_app(s));
    expect(findStops('−1⅓'), findsWidgets);
  });

  testWidgets('swiping the dial updates calibration', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    await tester.drag(find.text('0'), const Offset(-80, 0));
    await tester.pump();
    expect(s.calibrationThirds, 2);
  });

  testWidgets('switches write through', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    await tester.tap(find.text('Haptic feedback'));
    await tester.pump();
    expect(s.haptics, isFalse);
    await tester.tap(find.text('Click sound'));
    await tester.pump();
    expect(s.clickSound, isTrue);
    await tester.tap(find.text('Camera-shake warning'));
    await tester.pump();
    expect(s.shakeWarning, isTrue);
    await tester.tap(find.text('Open with viewfinder on'));
    await tester.pump();
    expect(s.viewfinderOn, isFalse);
  });

  testWidgets('appearance row picks the theme', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    await _reveal(tester, find.text('Appearance'));
    expect(s.theme, ThemeChoice.system);
    for (final label in ['System', 'Light', 'Dark']) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(s.theme, ThemeChoice.dark);
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(s.theme, ThemeChoice.light);
    await tester.tap(find.text('System'));
    await tester.pump();
    expect(s.theme, ThemeChoice.system);
  });

  testWidgets('turning location on asks for permission first', (tester) async {
    final s = Settings.inMemory();
    final loc = FakeLocation();
    await tester.pumpWidget(_app(s, loc));
    await _reveal(tester, find.text('Save location'));
    expect(find.text('Save location'), findsOneWidget);
    expect(find.text('Off: no location is stored anywhere.'), findsOneWidget);
    expect(loc.permissionRequests, 0);
    await _reveal(tester, find.text('Save location'));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    expect(loc.permissionRequests, 1);
    expect(s.location, isTrue);
    expect(tester.widget<Switch>(_switchOf('Save location')).value, isTrue);
    expect(loc.calls, 0);
  });

  testWidgets('turning location off does not ask', (tester) async {
    final s = Settings.inMemory();
    await s.setLocation(true);
    final loc = FakeLocation();
    await tester.pumpWidget(_app(s, loc));
    await _reveal(tester, find.text('Save location'));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    expect(s.location, isFalse);
    expect(loc.permissionRequests, 0);
  });

  testWidgets('refused permission keeps location off', (tester) async {
    final s = Settings.inMemory();
    final loc = FakeLocation()..outcome = PermissionOutcome.denied;
    await tester.pumpWidget(_app(s, loc));
    await _reveal(tester, find.text('Save location'));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    await tester.pump();
    expect(s.location, isFalse);
    expect(find.text('Location permission was not granted.'), findsOneWidget);
    expect(tester.widget<Switch>(_switchOf('Save location')).value, isFalse);
  });

  testWidgets('blocked location offers the system settings', (tester) async {
    final s = Settings.inMemory();
    final loc = FakeLocation()..outcome = PermissionOutcome.blocked;
    var opened = 0;
    await tester.pumpWidget(
      _app(s, loc, null, null, null, () async {
        opened++;
        return true;
      }),
    );
    await _reveal(tester, find.text('Save location'));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Location is off for Grain in the system settings.'),
      findsOneWidget,
    );
    expect(s.location, isFalse);
    expect(tester.widget<Switch>(_switchOf('Save location')).value, isFalse);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    expect(opened, 1);
    expect(s.location, isFalse);
  });

  testWidgets('snapshots switch toggles the setting', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    expect(
      find.text(
        'A small picture of the scene with each frame, kept on this phone.',
      ),
      findsOneWidget,
    );
    expect(s.snapshots, isTrue);
    await tester.tap(find.text('Reference snapshots'));
    await tester.pump();
    expect(s.snapshots, isFalse);
    await tester.tap(find.text('Reference snapshots'));
    await tester.pump();
    expect(s.snapshots, isTrue);
  });

  testWidgets('back button pops', (tester) async {
    final s = Settings.inMemory();
    await tester.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  settings: s,
                  haptics: _Haptics(),
                  gear: GearController.inMemory(),
                  rolls: inMemoryRolls(settings: s),
                  platform: FakeGearPlatform(),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('CALIBRATION'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('CALIBRATION'), findsNothing);
  });

  testWidgets('export everything shares the zip', (tester) async {
    final s = Settings.inMemory();
    final platform = FakeGearPlatform();
    addTearDown(() => platform.exportDir?.deleteSync(recursive: true));
    await tester.pumpWidget(_app(s, null, null, platform));
    await _reveal(tester, find.text('Export everything'));
    expect(find.text('BACKUP'), findsOneWidget);
    await tester.tap(find.text('Export everything'));
    await _until(tester, () => platform.sharedPaths.isNotEmpty);
    expect(platform.sharedPaths.single.map((p) => p.split('/').last), [
      'grain-backup-2026-11-21.zip',
    ]);
    expect(platform.sharedSubjects.single, 'Grain backup 21 Nov 2026');
    await tester.pumpAndSettle();
  });

  testWidgets('import everything confirms and reports', (tester) async {
    final s = Settings.inMemory();
    final source = inMemoryRolls();
    final here = inMemoryRolls(settings: s);
    final dir = Directory.systemTemp.createTempSync('grain-backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    final zip = await tester.runAsync(() async {
      await source.startRoll(
        filmStock: 'Kodak Tri-X 400',
        filmType: FilmType.bwNeg,
        boxIso: 400,
        pushThirds: 0,
        body: null,
        size: 36,
        startFrame: StartFrame.one,
      );
      return writeBackup(
        out: dir,
        gear: GearController.inMemory(),
        rolls: source,
        settings: Settings.inMemory(),
        now: DateTime(2026, 11, 21),
      );
    });
    final platform = FakeGearPlatform()..pickedPath = zip!.path;
    await tester.pumpWidget(_app(s, null, here, platform));
    await _reveal(tester, find.text('Import everything'));
    await tester.tap(find.text('Import everything'));
    await _until(
      tester,
      () => _shows('Import 1 roll, 0 saved readings and 0 profiles?'),
    );
    expect(find.text('Use the settings from the file'), findsOneWidget);
    await tester.tap(find.text('Import'));
    await _until(tester, () => _showsPart('Added 1 roll,'));
    expect(here.rolls.single.filmStock, 'Kodak Tri-X 400');
    expect(platform.discarded, [zip.path]);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Added 1 roll,'), findsNothing);
  });

  testWidgets('a file that is not a backup cannot be imported', (tester) async {
    final s = Settings.inMemory();
    final dir = Directory.systemTemp.createTempSync('grain-backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/notes.txt')..writeAsStringSync('hello');
    final platform = FakeGearPlatform()..pickedPath = bad.path;
    await tester.pumpWidget(_app(s, null, null, platform));
    await _reveal(tester, find.text('Import everything'));
    await tester.tap(find.text('Import everything'));
    await _until(tester, () => _shows("Can't import"));
    expect(find.text('Not a Grain backup'), findsOneWidget);
  });

  testWidgets('Licences opens the licence page with the bundled notices', (
    tester,
  ) async {
    registerLicences();
    final s = Settings.inMemory();
    await tester.pumpWidget(_app(s));
    await _reveal(tester, find.text('Licences'));
    await tester.tap(find.text('Licences'));
    await _until(tester, () => _shows('ZXing core'));
    await tester.pumpAndSettle();
    expect(find.text('Grain'), findsWidgets);
    expect(find.text(appVersion), findsOneWidget);
    expect(find.text('GPLv3'), findsOneWidget);
    for (final p in licencePackages) {
      await tester.scrollUntilVisible(find.text(p), 200);
      expect(find.text(p), findsOneWidget, reason: p);
    }
    expect(licencePackages, [
      'ZXing core',
      'Inter Tight',
      'SQLite',
      'Grain gear library',
    ]);
  });
}
