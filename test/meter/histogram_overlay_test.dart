import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/widgets/histogram_overlay.dart';
import 'package:grain/metering/histogram.dart';
import 'package:grain/rolls/latitude.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  HistogramView view(double luma) => histogramView(
    bins: List<int>.generate(64, (i) => i),
    meteredLuma: luma,
    latitude: FilmLatitude.negative,
  )!;

  testWidgets('repaints from the notifier without rebuilding', (t) async {
    final v = ValueNotifier<HistogramView?>(null);
    addTearDown(v.dispose);
    var builds = 0;
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: Builder(
            builder: (context) {
              builds++;
              return HistogramOverlay(view: v);
            },
          ),
        ),
      ),
    );
    // A null view paints nothing and does not throw.
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byType(HistogramOverlay)), const Size(128, 52));
    expect(
      find.descendant(
        of: find.byType(HistogramOverlay),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );

    v.value = view(.18);
    await t.pump();
    v.value = view(.5);
    await t.pump();
    expect(builds, 1);
    expect(t.takeException(), isNull);

    v.value = null;
    await t.pump();
    expect(builds, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('a new view marks only the overlay for repaint', (t) async {
    final v = ValueNotifier<HistogramView?>(view(.18));
    addTearDown(v.dispose);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: HistogramOverlay(view: v)),
      ),
    );
    final paint = t.renderObject<RenderCustomPaint>(
      find.descendant(
        of: find.byType(HistogramOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(paint.debugNeedsPaint, isFalse);
    v.value = view(.5);
    expect(paint.debugNeedsPaint, isTrue);
    await t.pump();
    expect(paint.debugNeedsPaint, isFalse);
  });
}
