import 'package:material_ui/material_ui.dart';

import '../settings/settings.dart';
import '../ui/theme.dart';

/// The name of each map style, as the sheet and Settings show it.
const mapStyleLabels = {
  MapStyle.offline: 'Offline',
  MapStyle.streets: 'Streets',
  MapStyle.minimal: 'Minimal',
  MapStyle.muted: 'Muted',
  MapStyle.standard: 'Standard',
  MapStyle.topographic: 'Topographic',
};

/// What each style is, and where its tiles come from.
const mapStyleSubtitles = {
  MapStyle.offline: 'Built into Grain; nothing goes online',
  MapStyle.streets: 'Clean street map from openfreemap.org',
  MapStyle.minimal: 'Quiet light or dark map from openfreemap.org',
  MapStyle.muted: 'OpenStreetMap in soft grey, from openstreetmap.org',
  MapStyle.standard: 'OpenStreetMap in full colour, from openstreetmap.org',
  MapStyle.topographic: 'Contour lines and relief, from opentopomap.org',
};

/// Lets the map style be picked; the choice is saved in [settings] at once.
/// Picking an online style turns online tiles on, Offline turns them off.
Future<void> showMapStyleSheet(BuildContext context, Settings settings) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MapStyleSheet(settings: settings),
    );

class _MapStyleSheet extends StatelessWidget {
  const _MapStyleSheet({required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('MAP STYLE', style: g.label),
            ),
            for (final style in MapStyle.values)
              _StyleRow(
                style: style,
                selected: style == settings.mapStyle,
                onTap: () {
                  settings.setMapStyle(style);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StyleRow extends StatelessWidget {
  const _StyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final MapStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        mapStyleLabels[style]!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: g.ink,
                        ),
                      ),
                      Text(
                        mapStyleSubtitles[style]!,
                        style: TextStyle(fontSize: 13, color: g.secondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: selected ? Icon(Icons.check, color: g.ink) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
