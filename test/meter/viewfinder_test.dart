import 'package:flutter_test/flutter_test.dart';
import 'package:grain/exposure/solver.dart';
import 'package:grain/meter/widgets/viewfinder.dart';
import 'package:grain/metering/fov.dart';
import 'package:grain/metering/reading.dart';
import 'package:material_ui/material_ui.dart';

/// Portrait preview buffer, as the controller reports it.
const _preview = Size(1080, 1440);

Future<Rect> _pump(WidgetTester t, Size box, Rect crop) async {
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
    await t.tapAt(box.center - Offset(box.width / 4, 0));
    final content = t.getRect(find.byType(Texture));
    expect(
      tapped!.dx,
      closeTo(
        (box.center.dx - box.width / 4 - content.left) / content.width,
        1e-6,
      ),
    );
    expect(tapped!.dy, closeTo(.5, 1e-6));
  });
}
