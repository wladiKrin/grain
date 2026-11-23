import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';

/// Camera or lens pill: tap cycles the favorites, the trailing ▾ opens the
/// picker.
class GearChip extends StatelessWidget {
  const GearChip({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.moreLabel,
    required this.onTap,
    required this.onMore,
  });

  final String label;

  /// "Camera" or "Lens".
  final String semanticLabel;

  /// Screen-reader label of the ▾, e.g. "More lenses".
  final String moreLabel;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    // The pill is drawn 32 px tall; both tap targets take the full 44.
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: g.border),
              ),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Semantics(
                button: true,
                label: semanticLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.only(left: 14, right: 2),
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
            Semantics(
              button: true,
              label: moreLabel,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onMore,
                child: Container(
                  height: 44,
                  width: 34,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.expand_more, size: 20, color: g.secondary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
