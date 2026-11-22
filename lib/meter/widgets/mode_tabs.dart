import 'package:material_ui/material_ui.dart';

import '../../exposure/mode.dart';
import '../../ui/theme.dart';

const _labels = {
  MeterMode.aperturePriority: 'Aperture priority',
  MeterMode.shutterPriority: 'Shutter priority',
  MeterMode.manual: 'Manual',
};

/// Text tabs over a divider; the selected one is semibold with a 2 px
/// underline.
class ModeTabs extends StatelessWidget {
  const ModeTabs({super.key, required this.mode, required this.onChanged});

  final MeterMode mode;
  final ValueChanged<MeterMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: g.divider)),
      ),
      child: Row(
        spacing: 24,
        children: [
          for (final m in MeterMode.values)
            Flexible(child: _tab(g, m, _labels[m]!, m == mode)),
        ],
      ),
    );
  }

  Widget _tab(GrainPalette g, MeterMode m, String label, bool selected) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(m),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          // Overlaps the row's divider like the mockup's -1 px margin.
          transform: Matrix4.translationValues(0, 1, 0),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected ? g.ink : Colors.transparent,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? g.ink : g.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
