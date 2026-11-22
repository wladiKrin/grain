import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../exposure/scales.dart';
import '../haptics.dart';
import '../theme.dart';
import '../stops_text.dart';

const _ink = GrainColors.ink;
const _faded = GrainColors.faded;
const _minorTick = Color(0xFFB4AEA3);
const _accent = GrainColors.accent;
const _fontFamily = grainFont;

const _rulerHeight = 22.0;
const _minTarget = 44.0;

/// Release speed (px/s) below which the dial stops where the finger left it.
const _minFlingVelocity = 300.0;

/// Friction of a fling: it travels velocity / ln(1 / drag) px, about half a
/// second's worth of the release speed.
const _flingDrag = 0.135;

/// Horizontal swipe dial: one value per [detent] px of drag, a haptic tick per
/// value. A fast release keeps it spinning, slowing to a stop on a value; a
/// touch stops it. Dragging left increases the index.
class SwipeDial extends StatefulWidget {
  const SwipeDial({
    super.key,
    required this.values,
    required this.index,
    required this.onChanged,
    required this.haptics,
    this.valueFontSize = 64,
    this.detent = 40,
  });

  final List<ScaleValue> values;
  final int index;
  final ValueChanged<int> onChanged;
  final Haptics haptics;
  final double valueFontSize;
  final double detent;

  @override
  State<SwipeDial> createState() => _SwipeDialState();
}

class _SwipeDialState extends State<SwipeDial>
    with SingleTickerProviderStateMixin {
  final _rulerOffset = ValueNotifier<double>(0);
  late final _fling = AnimationController.unbounded(vsync: this)
    ..addListener(_onFlingTick)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _settle(_flingRest);
    });
  int _startIndex = 0;
  double _startX = 0;
  int _dragIndex = 0;

  /// Position along the scale, in px: index × detent at a value.
  double _position = 0;

  /// Where the running fling comes to rest.
  double _flingRest = 0;

  double get _maxPosition => (widget.values.length - 1) * widget.detent;

  @override
  void dispose() {
    _fling.dispose();
    _rulerOffset.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final idx = (widget.index + delta).clamp(0, widget.values.length - 1);
    if (idx == widget.index) return;
    widget.haptics.tick(strong: widget.values[idx].isFullStop);
    widget.onChanged(idx);
  }

  void _stopFling(PointerDownEvent _) {
    if (!_fling.isAnimating) return;
    _fling.stop();
    _rulerOffset.value = 0;
  }

  void _onStart(DragStartDetails d) {
    _startIndex = widget.index;
    _dragIndex = widget.index;
    _startX = d.globalPosition.dx;
  }

  void _onUpdate(DragUpdateDetails d) =>
      _moveTo(_startIndex * widget.detent - (d.globalPosition.dx - _startX));

  /// Moves to [position], ticking once per value passed.
  void _moveTo(double position) {
    _position = position;
    final idx = (position / widget.detent).round().clamp(
      0,
      widget.values.length - 1,
    );
    if (idx != _dragIndex) {
      final dir = idx > _dragIndex ? 1 : -1;
      for (var i = _dragIndex + dir; i != idx + dir; i += dir) {
        widget.haptics.tick(strong: widget.values[i].isFullStop);
      }
      _dragIndex = idx;
      widget.onChanged(idx);
    }
    _rulerOffset.value = (idx * widget.detent - position).clamp(
      -widget.detent,
      widget.detent,
    );
  }

  void _onEnd(DragEndDetails d) {
    final v = -d.velocity.pixelsPerSecond.dx;
    final atEnd =
        (v < 0 && _position <= 0) || (v > 0 && _position >= _maxPosition);
    if (v.abs() < _minFlingVelocity || atEnd) {
      _rulerOffset.value = 0;
      return;
    }
    // Aim the fling at the value nearest where it would coast to, so it
    // never comes to rest between two.
    final coast = _position + v / math.log(1 / _flingDrag);
    final rest = (coast / widget.detent).round() * widget.detent;
    _flingRest = rest.clamp(0, _maxPosition);
    _fling.animateWith(
      FrictionSimulation(
        _flingDrag,
        _position,
        (rest - _position) * math.log(1 / _flingDrag),
        tolerance: const Tolerance(velocity: 5),
      ),
    );
  }

  void _onCancel() => _rulerOffset.value = 0;

  void _onFlingTick() {
    final p = _fling.value;
    if (p <= 0 || p >= _maxPosition) {
      _fling.stop();
      _settle(p.clamp(0, _maxPosition));
      return;
    }
    _moveTo(p);
  }

  void _settle(double position) {
    _moveTo(position);
    _rulerOffset.value = 0;
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final i = widget.index;
    final prev = i > 0 ? values[i - 1].label : null;
    final next = i < values.length - 1 ? values[i + 1].label : null;

    return Semantics(
      value: values[i].label,
      increasedValue: next,
      decreasedValue: prev,
      onIncrease: next == null ? null : () => _step(1),
      onDecrease: prev == null ? null : () => _step(-1),
      child: Listener(
        onPointerDown: _stopFling,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          onHorizontalDragCancel: _onCancel,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _neighbour(prev, -1, Alignment.centerLeft)),
                    StopsText(
                      values[i].label,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: _fontFamily,
                        fontSize: widget.valueFontSize,
                        fontWeight: FontWeight.w300,
                        color: _ink,
                        height: 1,
                      ),
                    ),
                    Expanded(child: _neighbour(next, 1, Alignment.centerRight)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: _rulerHeight,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _RulerPainter(
                      count: values.length,
                      index: i,
                      detent: widget.detent,
                      offset: _rulerOffset,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _neighbour(String? label, int delta, Alignment align) {
    if (label == null) return const SizedBox.shrink();
    return Align(
      alignment: align,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _step(delta),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTarget,
            minHeight: _minTarget,
          ),
          child: Center(
            widthFactor: 1,
            child: StopsText(
              label,
              softWrap: false,
              style: const TextStyle(
                fontFamily: _fontFamily,
                fontSize: 24,
                fontWeight: FontWeight.w300,
                color: _faded,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter({
    required this.count,
    required this.index,
    required this.detent,
    required this.offset,
  }) : super(repaint: offset);

  final int count;
  final int index;
  final double detent;
  final ValueListenable<double> offset;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 + offset.value;
    final minor = Paint()
      ..color = _minorTick
      ..strokeWidth = 1;
    final major = Paint()
      ..color = _faded
      ..strokeWidth = 1.5;
    for (var i = 0; i < count; i++) {
      final x = cx + (i - index) * detent;
      if (x < -detent || x > size.width + detent) continue;
      canvas.drawLine(
        Offset(x, size.height * 0.2),
        Offset(x, size.height),
        major,
      );
      if (i < count - 1) {
        for (final f in const [1 / 3, 2 / 3]) {
          final mx = x + detent * f;
          canvas.drawLine(
            Offset(mx, size.height * 0.55),
            Offset(mx, size.height),
            minor,
          );
        }
      }
    }
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2 - 1.5, 0, 3, size.height),
      Paint()..color = _accent,
    );
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.count != count || old.index != index || old.detent != detent;
}
