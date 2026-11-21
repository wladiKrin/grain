import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../ui/haptics.dart';
import '../../ui/round_button.dart';
import '../../ui/theme.dart';

/// "ISO" label with − value + buttons stepping one scale value at a time.
class IsoStepper extends StatelessWidget {
  const IsoStepper({
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

  void _step(int delta) {
    final i = (index + delta).clamp(0, values.length - 1);
    if (i == index) return;
    haptics.tick(strong: values[i].isFullStop);
    onChanged(i);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Text('ISO', style: grainLabelStyle)),
        RoundButton(
          semanticLabel: 'Lower ISO',
          onPressed: () => _step(-1),
          child: const Icon(Icons.remove),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 72),
          alignment: Alignment.center,
          child: Text(
            values[index].label,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: GrainColors.ink,
            ),
          ),
        ),
        RoundButton(
          semanticLabel: 'Raise ISO',
          onPressed: () => _step(1),
          child: const Icon(Icons.add),
        ),
      ],
    );
  }
}
