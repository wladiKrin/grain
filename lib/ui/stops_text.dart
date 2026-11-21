import 'package:material_ui/material_ui.dart';

/// The vulgar-fraction glyphs that stop labels use (see `formatStops`), and
/// how they are drawn: digits around U+2044 FRACTION SLASH, which Inter
/// Tight's `frac` feature turns into a proper fraction. Inter Tight has no
/// ⅔, so drawing the glyph itself would mix in a system-font fallback.
const _fractions = {'⅓': '1⁄3', '⅔': '2⁄3', '½': '1⁄2'};

const _fractionFeatures = [FontFeature.fractions()];

/// [text] as spans: everything but the fractions in plain spans, each
/// fraction (⅓, ⅔, ½) in its own span with [FontFeature.fractions] and
/// nothing else. `frac` is contextual: on a whole label it would also make
/// a numerator of the whole number before it (`−1` + `1⁄3`) and shrink
/// `1/250`, so it must never reach the surrounding text.
///
/// Returns a single span without children when [text] has no fraction.
TextSpan stopsSpan(String text, {TextStyle? style}) {
  final children = <TextSpan>[];
  final plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    children.add(TextSpan(text: plain.toString()));
    plain.clear();
  }

  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final f = _fractions[ch];
    if (f == null) {
      plain.write(ch);
    } else {
      flush();
      children.add(
        TextSpan(
          text: f,
          style: const TextStyle(fontFeatures: _fractionFeatures),
        ),
      );
    }
  }
  if (children.isEmpty) return TextSpan(text: text, style: style);
  flush();
  return TextSpan(style: style, children: children);
}

/// A label that may hold stop fractions (`+⅔`, `−1⅓`, `Push +⅔`, `+3½`),
/// drawn with [stopsSpan]. Screen readers get [text] unchanged.
class StopsText extends StatelessWidget {
  const StopsText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.softWrap,
  });

  /// The label as data, with the fraction glyphs.
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  @override
  Widget build(BuildContext context) {
    final span = stopsSpan(text);
    if (span.children == null) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        softWrap: softWrap,
      );
    }
    return Text.rich(
      span,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      softWrap: softWrap,
      semanticsLabel: text,
    );
  }
}
