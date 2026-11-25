import 'package:material_ui/material_ui.dart';

import '../../ui/round_button.dart';
import '../../ui/theme.dart';

/// The bottom row of the meter: the filled Log / Save button, the Skip
/// frame button when a roll logs, the rolls button, and a "Start roll" link
/// beneath when no roll logs.
class LogButton extends StatelessWidget {
  const LogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.onSkip,
    this.onStartRoll,
    required this.onOpenRolls,
  });

  final String label;
  final VoidCallback onPressed;

  /// Records a frame shot without a reading; the button shows when set.
  final VoidCallback? onSkip;

  /// Shown as a link under the row when set.
  final VoidCallback? onStartRoll;
  final VoidCallback onOpenRolls;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: label,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPressed,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: g.ink,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: g.ground,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (onSkip != null)
              RoundButton(
                semanticLabel: 'Skip frame',
                onPressed: onSkip!,
                child: const Icon(Icons.skip_next),
              ),
            RoundButton(
              semanticLabel: 'Rolls and saved readings',
              onPressed: onOpenRolls,
              child: const Icon(Icons.view_list_outlined),
            ),
          ],
        ),
        if (onStartRoll != null)
          Semantics(
            button: true,
            label: 'Start roll',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onStartRoll,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  'Start roll',
                  style: TextStyle(fontSize: 13, color: g.secondary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
