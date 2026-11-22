import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../metering/histogram.dart';
import '../../ui/theme.dart';

/// The crop's histogram with the film's latitude band and the metered luma
/// marked. Repaints straight from [view], so a new frame neither rebuilds
/// this widget nor repaints anything around it.
class HistogramOverlay extends StatelessWidget {
  const HistogramOverlay({super.key, required this.view});

  final ValueListenable<HistogramView?> view;

  static const size = Size(128, 52);

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.fromSize(
      size: size,
      child: CustomPaint(
        painter: _HistogramPainter(view, context.grain.accent),
      ),
    ),
  );
}

class _HistogramPainter extends CustomPainter {
  _HistogramPainter(this.view, this.accent) : super(repaint: view);

  final ValueListenable<HistogramView?> view;
  final Color accent;

  // Over the preview, which is dark in both themes.
  static final _ink = GrainPalette.light.ink;
  static final _ground = GrainPalette.light.ground;

  static const _inset = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final v = view.value;
    if (v == null) return;
    final panel = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(panel, const Radius.circular(8)),
      Paint()..color = _ink.withValues(alpha: .55),
    );
    final area = panel.deflate(_inset);
    double x(double t) => area.left + t.clamp(0.0, 1.0) * area.width;

    canvas.drawRect(
      Rect.fromLTRB(x(v.bandStart), area.top, x(v.bandEnd), area.bottom),
      Paint()..color = _ground.withValues(alpha: .18),
    );

    final n = v.heights.length;
    if (n > 0) {
      final w = area.width / n;
      final bars = Path();
      for (var i = 0; i < n; i++) {
        final h = v.heights[i] * area.height;
        if (h <= 0) continue;
        bars.addRect(Rect.fromLTWH(area.left + i * w, area.bottom - h, w, h));
      }
      canvas.drawPath(bars, Paint()..color = _ground.withValues(alpha: .85));
    }

    final mx = x(v.marker);
    canvas.drawLine(
      Offset(mx, area.top),
      Offset(mx, area.bottom),
      Paint()
        ..color = accent
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_HistogramPainter old) =>
      old.view != view || old.accent != accent;
}
