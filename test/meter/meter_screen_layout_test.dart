import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/gear/gear_controller.dart';
import 'package:grain/meter/meter_controller.dart';
import 'package:grain/meter/meter_screen.dart';
import 'package:grain/meter/widgets/lens_chip.dart';
import 'package:grain/meter/widgets/viewfinder.dart';
import 'package:grain/ui/dial/swipe_dial.dart';
import 'package:grain/ui/haptics.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_source.dart';
import '../support/gear_fixtures.dart';

class _NoHaptics implements Haptics {
  @override
  void tick({required bool strong}) {}
}

Future<void> _loadFonts() async {
  final loader = FontLoader('InterTight');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold']) {
    final bytes = File('assets/fonts/InterTight-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFonts);

  final library = fixtureLibrary();
  // The bundled lens with the longest chip label, on a body of its mount.
  final longest = library.lenses.reduce(
    (a, b) => b.shortName.length > a.shortName.length ? b : a,
  );
  final body = library.bodies.firstWhere((b) => b.mount == longest.mount);

  for (final size in const [Size(392, 872), Size(360, 800)]) {
    for (final mode in const [MeterMode.manual, MeterMode.aperturePriority]) {
      for (final viewfinderOn in const [true, false]) {
        final name =
            '${size.width.toInt()}×${size.height.toInt()} ${mode.name} '
            'viewfinder ${viewfinderOn ? 'on' : 'off'}: no overflow';
        testWidgets(name, (t) async {
          t.view.physicalSize = size * 3;
          t.view.devicePixelRatio = 3;
          // Status bar and gesture bar insets of a current phone.
          t.view.padding = const FakeViewPadding(top: 48 * 3, bottom: 24 * 3);
          addTearDown(t.view.reset);
          final gear = GearController.inMemory(library: library);
          addTearDown(gear.dispose);
          await t.runAsync(() async {
            await gear.selectBody(body);
            await gear.selectLens(longest);
          });
          final src = FakeMeterSource();
          final c = MeterController(
            source: src,
            gear: gear.setup,
            viewfinderOn: viewfinderOn,
          );
          addTearDown(c.dispose);
          c.setMode(mode);
          await t.pumpWidget(
            MaterialApp(
              theme: grainTheme(),
              home: MeterScreen(
                controller: c,
                gear: gear,
                haptics: _NoHaptics(),
              ),
            ),
          );
          await c.resume();
          await t.pump();
          expect(t.takeException(), isNull);
          expect(find.text(longest.shortName), findsOneWidget);
          expect(find.byType(LensChip), findsOneWidget);
          final numeral = t
              .widget<SwipeDial>(find.byType(SwipeDial).first)
              .valueFontSize;
          if (viewfinderOn) {
            // The numerals step down rather than squeeze the viewfinder
            // below its floor, and only as far as needed.
            expect(
              t.getSize(find.byType(Viewfinder)).height,
              greaterThanOrEqualTo(150),
            );
            final small = size.width == 360 && mode == MeterMode.manual;
            expect(numeral, small ? lessThan(64) : 64);
          } else {
            expect(numeral, 92);
          }
        });
      }
    }
  }

  test('the longest lens label is the zoom chip a narrow phone must fit', () {
    expect(longest.shortName, 'Zoom-Nikkor 35-105/3.5-4.5 AI-S');
    expect(longest.focalMax, greaterThan(longest.focalMin));
  });

  testWidgets('the numerals grow back when room returns', (t) async {
    t.view.physicalSize = const Size(360, 800) * 3;
    t.view.devicePixelRatio = 3;
    t.view.padding = const FakeViewPadding(top: 48 * 3, bottom: 24 * 3);
    addTearDown(t.view.reset);
    final gear = GearController.inMemory(library: library);
    addTearDown(gear.dispose);
    final c = MeterController(source: FakeMeterSource());
    addTearDown(c.dispose);
    c.setMode(MeterMode.manual);
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(),
        home: MeterScreen(controller: c, gear: gear, haptics: _NoHaptics()),
      ),
    );
    await t.pump();
    double numeral() =>
        t.widget<SwipeDial>(find.byType(SwipeDial).first).valueFontSize;
    expect(numeral(), lessThan(64));
    c.setMode(MeterMode.aperturePriority);
    await t.pump();
    await t.pump();
    expect(t.takeException(), isNull);
    expect(numeral(), 64);
  });
}
