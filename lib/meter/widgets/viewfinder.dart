import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../exposure/solver.dart';
import '../../metering/histogram.dart';
import '../../metering/reading.dart';
import '../../ui/round_button.dart';
import '../../ui/theme.dart';
import 'histogram_overlay.dart';

/// Where the [preview] is drawn in [box]: scaled to cover the box, but no
/// further than keeps the whole [crop] (normalized in [preview]) inside it,
/// with the crop centred in the box.
Rect previewRect(Size box, Size preview, {Rect? crop}) {
  var s = math.max(box.width / preview.width, box.height / preview.height);
  var centre = const Offset(.5, .5);
  if (crop != null && !crop.isEmpty) {
    s = math.min(
      s,
      math.min(
        box.width / (crop.width * preview.width),
        box.height / (crop.height * preview.height),
      ),
    );
    centre = crop.center;
  }
  final w = preview.width * s, h = preview.height * s;
  return Rect.fromLTWH(
    box.width / 2 - centre.dx * w,
    box.height / 2 - centre.dy * h,
    w,
    h,
  );
}

/// "EV 12.3 · AVG": one decimal ("EV —" before a reading), ▲/▼ when the
/// phone's AE is out of range, then SPOT, AVG or HELD.
String evLine({
  required double? ev,
  required RangeFlag flag,
  required MeterArea area,
  required bool held,
  bool estimated = false,
}) {
  final value = ev == null
      ? '—'
      : '${estimated ? '\u2248' : ''}${ev.toStringAsFixed(1).replaceFirst('-', '\u2212')}';
  final mark = switch (flag) {
    RangeFlag.over => ' ▲',
    RangeFlag.under => ' ▼',
    RangeFlag.ok => '',
  };
  final tag = held
      ? 'HELD'
      : area == MeterArea.spot
      ? 'SPOT'
      : 'AVG';
  return 'EV $value$mark · $tag';
}

/// Radius of the faint outer ring drawn around a spot smaller than 8 px
/// (null when the metered circle is big enough to see).
double? faintRingRadius(double r) => r < 8 ? 8 : null;

/// Distance from the spot's centre to the start of its ticks.
double spotTickGap(double r) => math.max(r, 8) + 4;

/// Live preview in a rounded box, the lens crop as the clear area, a spot
/// reticle (or centre crosshair for average), the EV pill with a hold
/// button and, with [onToggleHistogram], a histogram toggle at the top left
/// and the [histogram] at the bottom right. Tap sets the spot, long-press
/// returns to average.
class Viewfinder extends StatelessWidget {
  const Viewfinder({
    super.key,
    required this.textureId,
    required this.previewSize,
    required this.crop,
    required this.area,
    required this.spot,
    required this.spotRadius,
    required this.ev,
    required this.flag,
    required this.held,
    required this.widerThanPhone,
    required this.onSpot,
    required this.onClearSpot,
    required this.onToggleHold,
    this.estimated = false,
    this.histogramOn = false,
    this.onToggleHistogram,
    this.histogram,
  });

  /// Null until the camera has started.
  final int? textureId;

  /// Preview buffer in portrait orientation; null until started.
  final Size? previewSize;

  /// Lens crop, normalized in [previewSize].
  final Rect? crop;
  final MeterArea area;

  /// Normalized in [previewSize].
  final Offset spot;

  /// Relative to the crop width.
  final double spotRadius;

  /// Scene EV at ISO 100; null before the first reading.
  final double? ev;

  /// Whether the phone's own AE ran out of range for [ev].
  final RangeFlag flag;
  final bool held;

  /// The phone reported no aperture, so [ev] assumes f/1.8.
  final bool estimated;
  final bool widerThanPhone;
  final ValueChanged<Offset> onSpot;
  final VoidCallback onClearSpot;
  final VoidCallback onToggleHold;
  final bool histogramOn;

  /// Null hides the histogram toggle.
  final VoidCallback? onToggleHistogram;
  final ValueListenable<HistogramView?>? histogram;

  String get _evLine =>
      evLine(ev: ev, flag: flag, area: area, held: held, estimated: estimated);

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: ColoredBox(
        color: _previewInk,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final box = constraints.biggest;
            final content = previewSize == null
                ? Offset.zero & box
                : previewRect(box, previewSize!, crop: crop);
            // Taps are clamped to the lens crop, so the spot stays inside it.
            final c = crop;
            Offset normalize(Offset p) {
              final x = ((p.dx - content.left) / content.width).clamp(0.0, 1.0);
              final y = ((p.dy - content.top) / content.height).clamp(0.0, 1.0);
              if (c == null) return Offset(x, y);
              return Offset(
                x.clamp(c.left, c.right).toDouble(),
                y.clamp(c.top, c.bottom).toDouble(),
              );
            }

            return Stack(
              children: [
                if (textureId != null)
                  Positioned.fromRect(
                    rect: content,
                    child: Texture(textureId: textureId!),
                  ),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) => onSpot(normalize(d.localPosition)),
                    onLongPress: onClearSpot,
                    child: CustomPaint(
                      painter: _OverlayPainter(
                        content: content,
                        crop: crop,
                        spot: area == MeterArea.spot ? spot : null,
                        spotRadius: spotRadius,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Row(
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: g.ground,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _evLine,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: g.ink,
                          ),
                        ),
                      ),
                      RoundButton(
                        filled: held,
                        toggled: held,
                        background: g.ground,
                        semanticLabel: held
                            ? 'Release held reading'
                            : 'Hold reading',
                        onPressed: onToggleHold,
                        child: Icon(held ? Icons.lock : Icons.lock_open),
                      ),
                    ],
                  ),
                ),
                if (onToggleHistogram != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: RoundButton(
                      toggled: histogramOn,
                      background: g.ground,
                      semanticLabel: histogramOn
                          ? 'Hide histogram'
                          : 'Show histogram',
                      onPressed: onToggleHistogram!,
                      child: const Icon(Icons.bar_chart),
                    ),
                  ),
                if (histogramOn && histogram != null)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: HistogramOverlay(view: histogram!),
                  ),
                if (widerThanPhone)
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Text(
                      'Wider than this camera',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 12 * .04,
                        color: _previewPaper,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// The preview is dark in both themes, so what sits directly on it (the box,
// the crop dimming, the reticle) uses the light palette, not the themed one.
final _previewInk = GrainPalette.light.ink;
final _previewPaper = GrainPalette.light.ground;

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.content,
    required this.crop,
    required this.spot,
    required this.spotRadius,
  });

  /// Where the preview is drawn, in box coordinates.
  final Rect content;
  final Rect? crop;

  /// Null for average metering.
  final Offset? spot;
  final double spotRadius;

  Offset _map(Offset n) => Offset(
    content.left + n.dx * content.width,
    content.top + n.dy * content.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final c = crop;
    var cropPx = Offset.zero & size;
    if (c != null) {
      cropPx = Rect.fromPoints(_map(c.topLeft), _map(c.bottomRight));
      final dim = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(cropPx);
      canvas.drawPath(dim, Paint()..color = _previewInk.withValues(alpha: .6));
    }

    final stroke = Paint()
      ..color = _previewPaper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final s = spot;
    if (s != null) {
      final centre = _map(s);
      // The circle is the metered area; the ticks keep it findable.
      final r = spotRadius * cropPx.width;
      final faint = faintRingRadius(r);
      if (faint != null) {
        canvas.drawCircle(
          centre,
          faint,
          Paint()
            ..color = _previewPaper.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas.drawCircle(centre, r, stroke);
      _ticks(canvas, centre, spotTickGap(r), 8, stroke);
    } else {
      _ticks(canvas, cropPx.center, 6, 10, stroke);
    }
  }

  /// Four ticks pointing at [centre], starting [gap] px from it.
  void _ticks(Canvas canvas, Offset centre, double gap, double len, Paint p) {
    for (final d in const [
      Offset(0, -1),
      Offset(0, 1),
      Offset(-1, 0),
      Offset(1, 0),
    ]) {
      canvas.drawLine(centre + d * gap, centre + d * (gap + len), p);
    }
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.content != content ||
      old.crop != crop ||
      old.spot != spot ||
      old.spotRadius != spotRadius;
}
