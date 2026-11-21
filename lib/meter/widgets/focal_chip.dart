import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../metering/fov.dart';
import '../../ui/dial/swipe_dial.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';

final _focalValues = [
  for (final f in focalStops) ScaleValue('$f', f.toDouble(), false),
];

/// "50 mm" pill; tapping it opens a focal-length dial in a bottom sheet.
class FocalChip extends StatelessWidget {
  const FocalChip({
    super.key,
    required this.focalIndex,
    required this.onChanged,
    required this.haptics,
  });

  final int focalIndex;
  final ValueChanged<int> onChanged;
  final Haptics haptics;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: 'Focal length',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _open(context),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GrainColors.border),
              ),
              child: Text(
                '${focalStops[focalIndex]} mm',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: GrainColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _FocalSheet(
        initial: focalIndex,
        onChanged: onChanged,
        haptics: haptics,
      ),
    );
  }
}

class _FocalSheet extends StatefulWidget {
  const _FocalSheet({
    required this.initial,
    required this.onChanged,
    required this.haptics,
  });

  final int initial;
  final ValueChanged<int> onChanged;
  final Haptics haptics;

  @override
  State<_FocalSheet> createState() => _FocalSheetState();
}

class _FocalSheetState extends State<_FocalSheet> {
  late int _index = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('FOCAL LENGTH', style: grainLabelStyle),
                Text(
                  '${focalStops[_index]} mm',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: GrainColors.ink,
                  ),
                ),
              ],
            ),
            SwipeDial(
              values: _focalValues,
              index: _index,
              haptics: widget.haptics,
              onChanged: (i) {
                setState(() => _index = i);
                widget.onChanged(i);
              },
            ),
          ],
        ),
      ),
    );
  }
}
