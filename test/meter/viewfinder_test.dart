import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/meter/widgets/viewfinder.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/reading.dart';
import 'package:grain/ui/theme.dart';
import 'package:material_ui/material_ui.dart';

/// Portrait preview buffer, as the controller reports it.
const _preview = Size(1080, 1440);

Future<Rect> _pump(
  WidgetTester t,
  Size box,
  Rect crop, {
  bool fitToCrop = false,
}) async {
  await t.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox.fromSize(
          size: box,
          child: Viewfinder(
            textureId: 1,
            previewSize: _preview,
            crop: crop,
            area: MeterArea.average,
            spot: const Offset(.5, .5),
            spotRadius: .02,
            ev: null,
            flag: RangeFlag.ok,
            held: false,
            widerThanPhone: false,
            onSpot: (_) {},
            onClearSpot: () {},
            onToggleHold: () {},
            fitToCrop: fitToCrop,
          ),
        ),
      ),
    ),
  );
  // The texture is drawn over the content rect; map the crop into it.
  final content = t.getRect(find.byType(Texture));
  return Rect.fromLTRB(
    content.left + crop.left * content.width,
    content.top + crop.top * content.height,
    content.left + crop.right * content.width,
    content.top + crop.bottom * content.height,
  );
}

void main() {
  testWidgets('a long-press on the EV pill no longer switches anything', (
    t,
  ) async {
    Widget vf({bool ae = false}) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 364,
          height: 335,
          child: Viewfinder(
            textureId: 1,
            previewSize: _preview,
            crop: null,
            area: MeterArea.average,
            spot: const Offset(.5, .5),
            spotRadius: .02,
            ev: 12,
            flag: RangeFlag.ok,
            held: false,
            widerThanPhone: false,
            onSpot: (_) {},
            onClearSpot: () {},
            onToggleHold: () {},
            ae: ae,
          ),
        ),
      ),
    );
    await t.pumpWidget(vf());
    expect(find.text('EV 12.0 · AVG'), findsOneWidget);
    await t.pumpWidget(vf(ae: true));
    expect(find.text('EV 12.0 · AVG · AE'), findsOneWidget);
  });

  testWidgets('the box stays near-black under the dark theme', (t) async {
    await t.pumpWidget(
      MaterialApp(
        theme: grainTheme(Brightness.dark),
        home: Center(
          child: SizedBox(
            width: 364,
            height: 335,
            child: Viewfinder(
              textureId: 1,
              previewSize: _preview,
              crop: null,
              area: MeterArea.average,
              spot: const Offset(.5, .5),
              spotRadius: .02,
              ev: null,
              flag: RangeFlag.ok,
              held: false,
              widerThanPhone: false,
              onSpot: (_) {},
              onClearSpot: () {},
              onToggleHold: () {},
            ),
          ),
        ),
      ),
    );
    final box = t.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(Viewfinder),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(box.color, const Color(0xFF141414));
  });

  for (final box in const [Size(364, 335), Size(364, 239)]) {
    for (final focal in const [28.0, 50.0]) {
      testWidgets('${focal.toInt()} mm crop fits inside a '
          '${box.width.toInt()}×${box.height.toInt()} box', (t) async {
        final crop = lensCrop(
          preview: _preview,
          lensFocal: focal,
          phoneEqFocal: 25,
        );
        final cropPx = await _pump(t, box, crop);
        final boxRect = t.getRect(find.byType(Viewfinder));
        const eps = 1e-6;
        expect(cropPx.left, greaterThanOrEqualTo(boxRect.left - eps));
        expect(cropPx.top, greaterThanOrEqualTo(boxRect.top - eps));
        expect(cropPx.right, lessThanOrEqualTo(boxRect.right + eps));
        expect(cropPx.bottom, lessThanOrEqualTo(boxRect.bottom + eps));
        // Centred in the box.
        expect(cropPx.center.dx, closeTo(boxRect.center.dx, .5));
        expect(cropPx.center.dy, closeTo(boxRect.center.dy, .5));
        // No smaller than needed: the preview still covers the box, or the
        // crop touches the box on one axis.
        final content = t.getRect(find.byType(Texture));
        expect(
          content.contains(boxRect.topLeft) &&
                  content.contains(boxRect.bottomRight - const Offset(1, 1)) ||
              (cropPx.height - boxRect.height).abs() < .5 ||
              (cropPx.width - boxRect.width).abs() < .5,
          isTrue,
        );
      });
    }
  }

  testWidgets('tap at the crop centre meters the crop centre', (t) async {
    final crop = lensCrop(preview: _preview, lensFocal: 28, phoneEqFocal: 25);
    Offset? tapped;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 364,
            height: 239,
            child: Viewfinder(
              textureId: 1,
              previewSize: _preview,
              crop: crop,
              area: MeterArea.average,
              spot: const Offset(.5, .5),
              spotRadius: .02,
              ev: null,
              flag: RangeFlag.ok,
              held: false,
              widerThanPhone: false,
              onSpot: (p) => tapped = p,
              onClearSpot: () {},
              onToggleHold: () {},
            ),
          ),
        ),
      ),
    );
    final box = t.getRect(find.byType(Viewfinder));
    // Left of centre by a quarter of the box width.
    final content = t.getRect(find.byType(Texture));
    // A quarter of the crop's width left of centre: inside the crop.
    final dx = crop.width * content.width / 4;
    await t.tapAt(box.center - Offset(dx, 0));
    expect(
      tapped!.dx,
      closeTo((box.center.dx - dx - content.left) / content.width, 1e-6),
    );
    expect(tapped!.dy, closeTo(.5, 1e-6));
  });

  test('estimated EV line', () {
    expect(
      evLine(
        ev: 12.34,
        flag: RangeFlag.ok,
        area: MeterArea.average,
        held: false,
        estimated: true,
      ),
      'EV \u224812.3 · AVG',
    );
    expect(
      evLine(
        ev: null,
        flag: RangeFlag.ok,
        area: MeterArea.average,
        held: false,
        estimated: true,
      ),
      'EV — · AVG',
    );
  });

  test('small spots get a faint ring', () {
    expect(faintRingRadius(3), 8);
    expect(spotTickGap(3), 12);
    expect(faintRingRadius(10), isNull);
    expect(spotTickGap(10), 14);
  });

  testWidgets('a tap in the dimmed band meters the nearest crop edge', (
    t,
  ) async {
    final crop = lensCrop(preview: _preview, lensFocal: 50, phoneEqFocal: 25);
    Offset? tapped;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 100,
            height: 400,
            child: Viewfinder(
              textureId: 1,
              previewSize: _preview,
              crop: crop,
              area: MeterArea.average,
              spot: const Offset(.5, .5),
              spotRadius: .02,
              ev: null,
              flag: RangeFlag.ok,
              held: false,
              widerThanPhone: false,
              onSpot: (p) => tapped = p,
              onClearSpot: () {},
              onToggleHold: () {},
            ),
          ),
        ),
      ),
    );
    final box = t.getRect(find.byType(Viewfinder));
    final content = t.getRect(find.byType(Texture));
    // Inside the box but in the dimmed band beside and above the crop.
    expect(
      content.left + crop.left * content.width,
      greaterThanOrEqualTo(box.left),
    );
    await t.tapAt(box.topLeft + const Offset(2, 2));
    // The crop fills the box's width here, so only the vertical axis clamps.
    expect(tapped!.dy, closeTo(crop.top, 1e-9));
    expect(
      tapped!.dx,
      closeTo((box.left + 2 - content.left) / content.width, 1e-9),
    );
  });

  for (final (focal, zoom) in const [(200.0, 6.0), (400.0, 13.0)]) {
    testWidgets('with camera zoom, a ${focal.toInt()} mm crop meets the box', (
      t,
    ) async {
      const box = Size(364, 335);
      final crop = lensCrop(
        preview: _preview,
        lensFocal: focal,
        phoneEqFocal: 25 * zoom,
      );
      final cropPx = await _pump(t, box, crop);
      expect(
        (cropPx.width - box.width).abs() < .5 ||
            (cropPx.height - box.height).abs() < .5,
        isTrue,
      );
    });
  }

  for (final landscape in [false, true]) {
    testWidgets('600 mm without camera zoom draws no giant texture '
        '(${landscape ? 'sideways' : 'upright'})', (t) async {
      const box = Size(364, 335);
      final crop = lensCrop(
        preview: _preview,
        lensFocal: 600,
        phoneEqFocal: 25,
        aspect: landscape ? 3 / 2 : 2 / 3,
      );
      final cropPx = await _pump(t, box, crop);
      final content = t.getRect(find.byType(Texture));
      expect(
        math.max(content.width, content.height),
        lessThanOrEqualTo(maxPreviewZoom * 364 + 1e-6),
      );
      // The frame is drawn smaller, centred, inside the box.
      final boxRect = t.getRect(find.byType(Viewfinder));
      expect(cropPx.width, lessThan(box.width));
      expect(cropPx.height, lessThan(box.height));
      expect(cropPx.center.dx, closeTo(boxRect.center.dx, .5));
      expect(cropPx.center.dy, closeTo(boxRect.center.dy, .5));
    });
  }

  test('previewRect caps the zoom for every focal stop', () {
    const box = Size(364, 335);
    for (final f in focalStops) {
      final r = previewRect(
        box,
        _preview,
        crop: lensCrop(
          preview: _preview,
          lensFocal: f.toDouble(),
          phoneEqFocal: 25,
        ),
      );
      expect(
        math.max(r.width, r.height),
        lessThanOrEqualTo(maxPreviewZoom * 364 + 1e-6),
      );
    }
  });

  testWidgets('fitted to a sideways crop, the box takes its shape', (t) async {
    const box = Size(364, 335);
    final crop = lensCrop(
      preview: _preview,
      lensFocal: 50,
      phoneEqFocal: 25,
      aspect: 3 / 2,
    );
    final cropPx = await _pump(t, box, crop, fitToCrop: true);
    final frame = t.getRect(find.byType(ClipRRect));
    expect(frame.width, closeTo(364, .5));
    expect(frame.height, closeTo(364 / 1.5, .5));
    expect(frame.center, t.getRect(find.byType(Viewfinder)).center);
    // The crop fills the frame: nothing is dimmed.
    expect(cropPx.left, closeTo(frame.left, .5));
    expect(cropPx.right, closeTo(frame.right, .5));
    expect(cropPx.top, closeTo(frame.top, .5));
    expect(cropPx.bottom, closeTo(frame.bottom, .5));
  });

  test('cropFrameSize fits the crop shape in the box', () {
    // A square 6×6 crop in a wide box is limited by the height.
    final square = Rect.fromCenter(
      center: const Offset(.5, .5),
      width: .4,
      height: .4 * 1080 / 1440,
    );
    final size = cropFrameSize(const Size(364, 200), _preview, square);
    expect(size.width, closeTo(200, 1e-9));
    expect(size.height, 200);
  });
}
