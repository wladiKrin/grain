import 'package:material_ui/material_ui.dart';

import '../../ui/round_button.dart';
import '../../ui/theme.dart';

/// Gear profile and mode on the left; viewfinder toggle and settings right.
class MeterHeader extends StatelessWidget {
  const MeterHeader({
    super.key,
    required this.viewfinderOn,
    required this.onToggleViewfinder,
    required this.onOpenSettings,
  });

  final bool viewfinderOn;
  final VoidCallback onToggleViewfinder;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'No camera',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: GrainColors.ink,
                ),
              ),
              Text(
                'Free mode',
                style: TextStyle(fontSize: 13, color: GrainColors.secondary),
              ),
            ],
          ),
        ),
        RoundButton(
          filled: viewfinderOn,
          toggled: viewfinderOn,
          semanticLabel: viewfinderOn ? 'Hide viewfinder' : 'Show viewfinder',
          onPressed: onToggleViewfinder,
          child: Icon(viewfinderOn ? Icons.visibility : Icons.visibility_off),
        ),
        const SizedBox(width: 8),
        RoundButton(
          semanticLabel: 'Settings',
          onPressed: onOpenSettings,
          child: const Icon(Icons.tune),
        ),
      ],
    );
  }
}
