import 'package:flutter_test/flutter_test.dart';
import 'package:grain/main.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/settings/settings.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import 'support/fake_source.dart';

void main() {
  Future<GrainPalette> pump(
    WidgetTester t,
    ThemeChoice choice,
    Brightness platform,
  ) async {
    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 2.75;
    t.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(t.view.reset);
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final settings = Settings.inMemory();
    await settings.setTheme(choice);
    await t.pumpWidget(GrainApp(source: FakeMeterSource(), settings: settings));
    await t.pump();
    return t.element(find.byType(MeterScreen)).grain;
  }

  testWidgets('dark choice uses the dark palette on a light system', (t) async {
    final g = await pump(t, ThemeChoice.dark, Brightness.light);
    expect(g.ground, const Color(0xFF151413));
    expect(g, GrainPalette.dark);
  });

  testWidgets('light choice uses the light palette on a dark system', (
    t,
  ) async {
    final g = await pump(t, ThemeChoice.light, Brightness.dark);
    expect(g, GrainPalette.light);
  });

  testWidgets('system choice follows the platform brightness', (t) async {
    expect(
      await pump(t, ThemeChoice.system, Brightness.dark),
      GrainPalette.dark,
    );
    t.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.element(find.byType(MeterScreen)).grain, GrainPalette.light);
  });

  testWidgets('changing the choice rebuilds the app', (t) async {
    await pump(t, ThemeChoice.light, Brightness.light);
    final app = t.widget<GrainApp>(find.byType(GrainApp));
    await app.settings.setTheme(ThemeChoice.dark);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(t.element(find.byType(MeterScreen)).grain, GrainPalette.dark);
  });
}
