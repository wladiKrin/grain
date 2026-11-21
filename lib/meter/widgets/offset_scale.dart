import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';

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

const _range = 3.0;

/// Manual-mode match-needle: a −3…+3 ruler with an accent marker at the
/// exposure [offset] (stops, + = over), and the offset as text.
class OffsetScale extends StatelessWidget {
  const OffsetScale({super.key, required this.offset});

  /// Null before the first reading.
  final double? offset;

  @override
  Widget build(BuildContext context) {
    final o = offset;
    return Semantics(
      label: 'Exposure offset',
      value: o == null ? 'no reading' : formatStops(o),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('OFFSET', style: grainLabelStyle),
              Text(
                o == null ? '—' : formatStops(o),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: GrainColors.accent,
                ),
              ),
            ],
          ),
          SizedBox(height: 22, child: CustomPaint(painter: _OffsetPainter(o))),
        ],
      ),
    );
  }
}

class _OffsetPainter extends CustomPainter {
  _OffsetPainter(this.offset);

  final double? offset;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final w = size.width - 2 * inset;
    double x(double stops) => inset + (stops + _range) / (2 * _range) * w;
    final major = Paint()
      ..color = GrainColors.ink
      ..strokeWidth = 1;
    final minor = Paint()
      ..color = GrainColors.border
      ..strokeWidth = 1;
    for (var k = -9; k <= 9; k++) {
      final full = k % 3 == 0;
      final px = x(k / 3);
      canvas.drawLine(
        Offset(px, full ? size.height * .2 : size.height * .55),
        Offset(px, size.height),
        full ? major : minor,
      );
    }
    final o = offset;
    if (o != null) {
      final px = x(o.clamp(-_range, _range));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(px - 1.5, 0, 3, size.height),
          const Radius.circular(2),
        ),
        Paint()..color = GrainColors.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_OffsetPainter old) => old.offset != offset;
}
