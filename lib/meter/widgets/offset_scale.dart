import 'package:material_ui/material_ui.dart';

import '../../exposure/stops.dart';
import '../../ui/theme.dart';
import '../../ui/stops_text.dart';

const _range = 3.0;

/// Manual-mode match-needle: a −3…+3 ruler with an accent marker at the
/// exposure [offset] (stops, + = over), and the offset as text.
class OffsetScale extends StatelessWidget {
  const OffsetScale({super.key, required this.offset});

  /// Null before the first reading.
  final double? offset;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
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
              Text('OFFSET', style: g.label),
              StopsText(
                o == null ? '—' : formatStops(o),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: g.accent,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 22,
            child: CustomPaint(painter: _OffsetPainter(o, g)),
          ),
        ],
      ),
    );
  }
}

class _OffsetPainter extends CustomPainter {
  _OffsetPainter(this.offset, this.g);

  final double? offset;
  final GrainPalette g;

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 8.0;
    final w = size.width - 2 * inset;
    double x(double stops) => inset + (stops + _range) / (2 * _range) * w;
    final major = Paint()
      ..color = g.ink
      ..strokeWidth = 1;
    final minor = Paint()
      ..color = g.border
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
        Paint()..color = g.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_OffsetPainter old) => old.offset != offset || old.g != g;
}
