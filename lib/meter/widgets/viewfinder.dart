import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../exposure/solver.dart';
import '../../metering/histogram.dart';
import '../../metering/reading.dart';
import '../../ui/round_button.dart';
import '../../ui/theme.dart';
import 'histogram_overlay.dart';

/// The drawn preview's larger side is at most this many times the box's.
const maxPreviewZoom = 4.0;

/// Where the [preview] is drawn in [box]: zoomed until the [crop]
/// (normalized in [preview]) touches the box on one axis, centred in it; with
/// no crop, scaled to cover the box. The zoom stops at [maxPreviewZoom], so a
/// tiny crop is drawn smaller rather than as a huge texture.
Rect previewRect(Size box, Size preview, {Rect? crop}) {
  var s = math.max(box.width / preview.width, box.height / preview.height);
  var centre = const Offset(.5, .5);
  if (crop != null && !crop.isEmpty) {
    s = math.min(
      box.width / (crop.width * preview.width),
      box.height / (crop.height * preview.height),
    );
    centre = crop.center;
  }
  final cap =
      maxPreviewZoom *
      math.max(box.width, box.height) /
      math.max(preview.width, preview.height);
  if (s > cap) s = cap;
  final w = preview.width * s, h = preview.height * s;
  return Rect.fromLTWH(
    box.width / 2 - centre.dx * w,
    box.height / 2 - centre.dy * h,
    w,
    h,
  );
}

/// "EV 12.3 · AVG": one decimal ("EV —" before a reading), ▲/▼ when the
/// camera is out of range, then SPOT, AVG or HELD, and "· AE" when the
/// reading comes from the phone's auto-exposure ([ae]).
String evLine({
  required double? ev,
  required RangeFlag flag,
  required MeterArea area,
  required bool held,
  bool estimated = false,
  bool ae = false,
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
  return 'EV $value$mark · $tag${ae ? ' · AE' : ''}';
}

/// Radius of the faint outer ring drawn around a spot smaller than 8 px
/// (null when the metered circle is big enough to see).
double? faintRingRadius(double r) => r < 8 ? 8 : null;

/// Distance from the spot's centre to the start of its ticks.
double spotTickGap(double r) => math.max(r, 8) + 4;

/// The largest size of the [crop]'s shape (normalized in [preview]) that
/// fits in [box].
Size cropFrameSize(Size box, Size preview, Rect crop) {
  final aspect = crop.width * preview.width / (crop.height * preview.height);
  return box.width / box.height > aspect
      ? Size(box.height * aspect, box.height)
      : Size(box.width, box.width / aspect);
}

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
    this.frameLandscape = false,
    this.onToggleFrame,
    this.fitToCrop = false,
    this.ae = false,
    this.onSelectArea,
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

  /// The lens frame is drawn sideways; [onToggleFrame] turns it (null hides
  /// the button).
  final bool frameLandscape;
  final VoidCallback? onToggleFrame;

  /// The box shrinks to the crop's shape, so the crop fills it with no
  /// dimmed band.
  final bool fitToCrop;

  /// The reading comes from the phone's auto-exposure (see [evLine]).
  final bool ae;

  /// The AVG | SPOT switch at the bottom left; null hides it.
  final ValueChanged<MeterArea>? onSelectArea;

  String get _evLine => evLine(
    ev: ev,
    flag: flag,
    area: area,
    held: held,
    estimated: estimated,
    ae: ae,
  );

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    final p = previewSize, c = crop;
    if (!fitToCrop || p == null || c == null || c.isEmpty) return _box(g);
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: SizedBox.fromSize(
          size: cropFrameSize(constraints.biggest, p, c),
          child: _box(g),
        ),
      ),
    );
  }

  Widget _box(GrainPalette g) {
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
                Positioned(
                  top: 10,
                  left: 10,
                  child: Row(
                    spacing: 8,
                    children: [
                      if (onToggleHistogram != null)
                        RoundButton(
                          toggled: histogramOn,
                          background: g.ground,
                          semanticLabel: histogramOn
                              ? 'Hide histogram'
                              : 'Show histogram',
                          onPressed: onToggleHistogram!,
                          child: const Icon(Icons.bar_chart),
                        ),
                      if (onToggleFrame != null)
                        RoundButton(
                          background: g.ground,
                          semanticLabel: frameLandscape
                              ? 'Turn frame upright'
                              : 'Turn frame sideways',
                          onPressed: onToggleFrame!,
                          child: Icon(
                            frameLandscape
                                ? Icons.crop_landscape
                                : Icons.crop_portrait,
                          ),
                        ),
                    ],
                  ),
                ),
                if (histogramOn && histogram != null)
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: HistogramOverlay(view: histogram!),
                  ),
                if (onSelectArea != null)
                  Positioned(
                    left: 10,
                    bottom: 4,
                    child: AreaSwitch(area: area, onChanged: onSelectArea!),
                  ),
                if (widerThanPhone)
                  Positioned(
                    left: 12,
                    bottom: onSelectArea != null ? 52 : 10,
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
/// AVG | SPOT: shows the metering area and switches it in one tap.
class AreaSwitch extends StatelessWidget {
  const AreaSwitch({super.key, required this.area, required this.onChanged});

  final MeterArea area;
  final ValueChanged<MeterArea> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    Widget segment(MeterArea a, String label, String semantics) {
      final on = a == area;
      return Semantics(
        button: true,
        selected: on,
        label: semantics,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on ? null : () => onChanged(a),
          // 44 px tall to tap; the pill inside is 28.
          child: Container(
            height: 44,
            alignment: Alignment.center,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? g.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 12 * .06,
                  color: on ? g.ground : g.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // The pill is 32 px tall; both segments take the full 44 to tap.
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: g.ground,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              segment(MeterArea.average, 'AVG', 'Average metering'),
              segment(MeterArea.spot, 'SPOT', 'Spot metering'),
            ],
          ),
        ),
      ],
    );
  }
}

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
