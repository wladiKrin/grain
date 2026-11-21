import 'package:flutter_test/flutter_test.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/settings/settings_screen.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

class _Haptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

Widget _app(Settings s) => MaterialApp(
  theme: grainTheme(),
  home: SettingsScreen(settings: s, haptics: _Haptics()),
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
