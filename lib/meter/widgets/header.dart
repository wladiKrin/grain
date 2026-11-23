import 'package:material_ui/material_ui.dart';

import '../../ui/round_button.dart';
import '../../ui/theme.dart';

/// Film format or roll status on the left; gear library, viewfinder toggle
/// and settings right.
class MeterHeader extends StatelessWidget {
  const MeterHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.viewfinderOn,
    required this.onToggleViewfinder,
    required this.onOpenSettings,
    required this.onOpenLibrary,
  });

  final String title;

  /// Optional second line in the secondary colour.
  final String? subtitle;
  final bool viewfinderOn;
  final VoidCallback onToggleViewfinder;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: g.ink,
                ),
              ),
              if (subtitle case final line?)
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: g.secondary),
                ),
            ],
          ),
        ),
        RoundButton(
          semanticLabel: 'Gear library',
          onPressed: onOpenLibrary,
          child: const Icon(Icons.photo_camera_outlined),
        ),
        const SizedBox(width: 8),
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
