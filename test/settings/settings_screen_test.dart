import 'package:flutter_test/flutter_test.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/settings/settings_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';

import '../support/fake_location.dart';

import 'package:material_ui/material_ui.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

Widget _app(Settings s, [FakeLocation? location]) => MaterialApp(
  theme: grainTheme(),
  home: SettingsScreen(settings: s, haptics: _Haptics(), location: location),
);

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
    expect(find.textContaining('Grain · GPLv3 · '), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('dial shows stored calibration label', (tester) async {
    final s = Settings.inMemory();
    await s.setCalibrationThirds(-4);
    await tester.pumpWidget(_app(s));
    expect(find.text('−1⅓'), findsWidgets);
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
    await tester.tap(find.text('Open with viewfinder on'));
    await tester.pump();
    expect(s.viewfinderOn, isFalse);
  });

  testWidgets('turning location on asks for permission first', (tester) async {
    final s = Settings.inMemory();
    final loc = FakeLocation();
    await tester.pumpWidget(_app(s, loc));
    expect(find.text('Save location'), findsOneWidget);
    expect(find.text('Off: no location is stored anywhere.'), findsOneWidget);
    expect(loc.permissionRequests, 0);
    await tester.tap(find.text('Save location'));
    await tester.pump();
    expect(loc.permissionRequests, 1);
    expect(s.location, isTrue);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isTrue);
    expect(loc.calls, 0);
  });

  testWidgets('turning location off does not ask', (tester) async {
    final s = Settings.inMemory();
    await s.setLocation(true);
    final loc = FakeLocation();
    await tester.pumpWidget(_app(s, loc));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    expect(s.location, isFalse);
    expect(loc.permissionRequests, 0);
  });

  testWidgets('refused permission keeps location off', (tester) async {
    final s = Settings.inMemory();
    final loc = FakeLocation()..granted = false;
    await tester.pumpWidget(_app(s, loc));
    await tester.tap(find.text('Save location'));
    await tester.pump();
    await tester.pump();
    expect(s.location, isFalse);
    expect(find.text('Location permission was not granted.'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).at(3)).value, isFalse);
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
                builder: (_) =>
                    SettingsScreen(settings: s, haptics: _Haptics()),
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
}
