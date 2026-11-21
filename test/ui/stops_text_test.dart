import 'package:flutter_test/flutter_test.dart';
import 'package:grain/meter/widgets/offset_scale.dart';
import 'package:grain/ui/stops_text.dart';
import 'package:material_ui/material_ui.dart';

/// The spans the [RichText] under [of] draws: (text, has frac).
List<(String, bool)> _spans(WidgetTester t, Finder of) {
  final rich = t.widget<RichText>(
    find.descendant(of: of, matching: find.byType(RichText)),
  );
  final out = <(String, bool)>[];
  rich.text.visitChildren((s) {
    final span = s as TextSpan;
    if (span.text != null) {
      final features = span.style?.fontFeatures ?? const <FontFeature>[];
      out.add((span.text!, features.contains(const FontFeature.fractions())));
    }
    return true;
  });
  return out;
}

Future<void> _pump(WidgetTester t, Widget w) => t.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: w)),
  ),
);

void main() {
  testWidgets('+⅔: the sign plain, 2⁄3 alone with fractions', (t) async {
    await _pump(t, const StopsText('+⅔'));
    expect(_spans(t, find.byType(StopsText)), [('+', false), ('2⁄3', true)]);
  });

  testWidgets('−1⅓: the whole stop plain, 1⁄3 alone with fractions', (t) async {
    await _pump(t, const StopsText('−1⅓'));
    expect(_spans(t, find.byType(StopsText)), [('−1', false), ('1⁄3', true)]);
  });

  testWidgets('halves and fractions inside a longer label', (t) async {
    await _pump(t, const StopsText('Default: −2½ to +½'));
    expect(_spans(t, find.byType(StopsText)), [
      ('Default: −2', false),
      ('1⁄2', true),
      (' to +', false),
      ('1⁄2', true),
    ]);
  });

  testWidgets('a label without a fraction stays one plain span', (t) async {
    await _pump(t, const StopsText('1/250'));
    expect(_spans(t, find.byType(StopsText)), [('1/250', false)]);
    expect(find.text('1/250'), findsOneWidget);
  });

  testWidgets('the style stays on the root, frac only on the fraction', (
    t,
  ) async {
    final span = stopsSpan('−1⅓', style: const TextStyle(fontSize: 22));
    expect(span.style!.fontSize, 22);
    expect(span.style!.fontFeatures, isNull);
    final kids = span.children!.cast<TextSpan>();
    expect(kids.first.style, isNull);
    expect(kids.last.style!.fontFeatures, [const FontFeature.fractions()]);
  });

  testWidgets('screen readers get the glyph label', (t) async {
    final h = t.ensureSemantics();
    await _pump(t, const StopsText('−1⅓'));
    expect(find.bySemanticsLabel('−1⅓'), findsOneWidget);
    h.dispose();
  });

  testWidgets('the offset readout draws +⅔ as + and 2⁄3', (t) async {
    await _pump(
      t,
      const SizedBox(width: 300, child: OffsetScale(offset: 2 / 3)),
    );
    expect(_spans(t, find.byType(StopsText)), [('+', false), ('2⁄3', true)]);
  });
}
