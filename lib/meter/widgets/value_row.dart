import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../exposure/solver.dart';
import '../../ui/dial/swipe_dial.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';

/// One exposure value under a letter-spaced label: either a [SwipeDial] the
/// user sets, or the metered result in the accent colour.
class ValueRow extends StatelessWidget {
  const ValueRow.input({
    super.key,
    required this.label,
    required List<ScaleValue> this.values,
    required int this.index,
    required ValueChanged<int> this.onChanged,
    required Haptics this.haptics,
    required this.fontSize,
  }) : solved = null,
       flag = RangeFlag.ok;

  const ValueRow.solved({
    super.key,
    required this.label,
    required this.solved,
    required this.flag,
    required this.fontSize,
  }) : values = null,
       index = null,
       onChanged = null,
       haptics = null;

  final String label;
  final double fontSize;

  final List<ScaleValue>? values;
  final int? index;
  final ValueChanged<int>? onChanged;
  final Haptics? haptics;

  /// Metered value's label; null before the first reading.
  final String? solved;
  final RangeFlag flag;

  bool get _isInput => values != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GrainColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 2,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: grainLabelStyle),
              if (_isInput)
                const Text(
                  '← swipe →',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 12 * .04,
                    color: GrainColors.secondary,
                  ),
                )
              else
                const Text(
                  '● METERED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 12 * .06,
                    color: GrainColors.accent,
                  ),
                ),
            ],
          ),
          if (_isInput)
            SwipeDial(
              values: values!,
              index: index!,
              onChanged: onChanged!,
              haptics: haptics!,
              valueFontSize: fontSize,
            )
          else
            _solvedValue(),
        ],
      ),
    );
  }

  Widget _solvedValue() {
    final flagText = switch (flag) {
      RangeFlag.over => '▲ over',
      RangeFlag.under => '▼ under',
      RangeFlag.ok => null,
    };
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 10,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              solved ?? '—',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                letterSpacing: -.05 * fontSize,
                height: 1.05,
                color: GrainColors.accent,
              ),
            ),
          ),
        ),
        if (flagText != null)
          Text(
            flagText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: GrainColors.accent,
            ),
          ),
      ],
    );
  }
}
