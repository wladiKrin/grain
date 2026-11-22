import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';

/// Lens pill: tap cycles the favorite lenses, the trailing "more…" opens the
/// lens picker.
class LensChip extends StatelessWidget {
  const LensChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.onMore,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Semantics(
              button: true,
              label: 'Lens',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: g.border),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          ),
          Semantics(
            button: true,
            label: 'More lenses',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onMore,
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                child: Text(
                  'more…',
                  style: TextStyle(fontSize: 15, color: g.secondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
