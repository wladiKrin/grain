import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../ui/dial/swipe_dial.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';

/// "50 mm" pill; tapping it opens a focal-length dial in a bottom sheet.
class FocalChip extends StatelessWidget {
  const FocalChip({
    super.key,
    required this.values,
    required this.index,
    required this.onChanged,
    required this.haptics,
  });

  final List<ScaleValue> values;
  final int index;
  final ValueChanged<int> onChanged;
  final Haptics haptics;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
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
                border: Border.all(color: g.border),
              ),
              child: Text(
                '${values[index].label} mm',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: g.ink,
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
        values: values,
        initial: index,
        onChanged: onChanged,
        haptics: haptics,
      ),
    );
  }
}

class _FocalSheet extends StatefulWidget {
  const _FocalSheet({
    required this.values,
    required this.initial,
    required this.onChanged,
    required this.haptics,
  });

  final List<ScaleValue> values;
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
    final g = context.grain;
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
                Text('FOCAL LENGTH', style: g.label),
                Text(
                  '${widget.values[_index].label} mm',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: g.ink,
                  ),
                ),
              ],
            ),
            SwipeDial(
              values: widget.values,
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
