import 'package:flutter_test/flutter_test.dart';
import 'package:grain/ui/stops_text.dart';

/// A [StopsText] showing [text] (with its fraction glyphs, e.g. `−1⅓`). A
/// label with a fraction is drawn as spans with `1⁄3`, so `find.text` with
/// the glyph does not match it.
Finder findStops(String text) => find.byWidgetPredicate(
  (w) => w is StopsText && w.text == text,
  description: 'StopsText "$text"',
);
