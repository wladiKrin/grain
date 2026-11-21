const _fractions = ['', '⅓', '⅔'];

/// Stops rounded to thirds with fraction glyphs: `0`, `+⅔`, `−1⅓` (U+2212).
String formatStops(double stops) {
  final thirds = (stops * 3).round();
  if (thirds == 0) return '0';
  final sign = thirds > 0 ? '+' : '−';
  final whole = thirds.abs() ~/ 3;
  final frac = _fractions[thirds.abs() % 3];
  return '$sign${whole == 0 ? '' : whole}$frac';
}
