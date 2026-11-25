/// The glyphs MapLibre draws the offline map's labels with.
///
/// Pure Dart (no Flutter), so `tool/basemap/glyphs.dart` can use it.
library;

/// The bundled glyphs (Noto Sans, cut to the characters the place names
/// use; see `tool/basemap/glyphs.dart`), read by MapLibre from the APK.
const glyphsUrl =
    'asset://flutter_assets/assets/map/glyphs/{fontstack}/{range}.pbf';

/// The bundled glyph fonts, by the folder their ranges are in.
const regularFont = 'grain-regular', boldFont = 'grain-bold';

/// The glyph ranges bundled for each font (256 code points each, by their
/// first): Latin-1, Latin Extended-A and -B, Latin Extended Additional and
/// General Punctuation.
const glyphRanges = [0, 256, 512, 7680, 8192];
