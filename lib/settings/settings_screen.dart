import 'package:material_ui/material_ui.dart';

import '../backup/ui.dart';
import '../exposure/scales.dart';
import '../exposure/stops.dart';
import '../gear/gear_controller.dart';
import '../gear/platform.dart';
import '../rolls/roll_controller.dart';
import '../rolls/location.dart';
import '../ui/dial/swipe_dial.dart';
import '../ui/haptics.dart';
import '../ui/round_button.dart';
import '../ui/theme.dart';
import 'settings.dart';

/// Version shown in the footer; keep in step with pubspec.yaml.
const appVersion = '1.0.0';

/// Calibration dial values: -9..+9 thirds of a stop.
final List<ScaleValue> _calibrationValues = [
  for (var k = -Settings.maxThirds; k <= Settings.maxThirds; k++)
    ScaleValue(formatStops(k / 3), k / 3, k % 3 == 0),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.haptics,
    required this.gear,
    required this.rolls,
    required this.platform,
    this.location,
    this.now = DateTime.now,
  });

  final Settings settings;

  /// Used for the calibration dial's detent ticks.
  final Haptics haptics;

  /// Asked for the permission when location is turned on. Without one the
  /// switch cannot be turned on.
  final LocationSource? location;

  /// What a backup holds, and how it is shared or picked.
  final GearController gear;
  final RollController rolls;
  final GearPlatform platform;

  /// The backup's date (file name, share subject).
  final DateTime Function() now;

  /// The permission is requested only here, on turning the switch on.
  Future<void> _setLocation(BuildContext context, bool on) async {
    if (!on) return settings.setLocation(false);
    final messenger = ScaffoldMessenger.of(context);
    final granted = await location?.requestPermission() ?? false;
    if (granted) return settings.setLocation(true);
    messenger.showSnackBar(
      const SnackBar(content: Text('Location permission was not granted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            24,
            inset.top + 12,
            24,
            inset.bottom + 24,
          ),
          children: [
            Row(
              spacing: 12,
              children: [
                RoundButton(
                  semanticLabel: 'Back',
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Icon(Icons.arrow_back),
                ),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: GrainColors.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  const Text('CALIBRATION', style: grainLabelStyle),
                  SwipeDial(
                    values: _calibrationValues,
                    index: settings.calibrationThirds + Settings.maxThirds,
                    onChanged: (i) =>
                        settings.setCalibrationThirds(i - Settings.maxThirds),
                    haptics: haptics,
                    valueFontSize: 44,
                  ),
                  const Text(
                    'Compare with a camera you trust and nudge until they agree.',
                    style: TextStyle(
                      fontSize: 13,
                      color: GrainColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            const _Divider(),
            _SwitchRow(
              label: 'Haptic feedback',
              value: settings.haptics,
              onChanged: settings.setHaptics,
            ),
            const _Divider(),
            _SwitchRow(
              label: 'Open with viewfinder on',
              value: settings.viewfinderOn,
              onChanged: settings.setViewfinderOn,
            ),
            const _Divider(),
            _SwitchRow(
              label: 'Reference snapshots',
              subtitle: 'A small picture of the scene with each frame, kept on this phone.',
              value: settings.snapshots,
              onChanged: settings.setSnapshots,
            ),
            const _Divider(),
            _SwitchRow(
              label: 'Save location',
              subtitle: 'Off: no location is stored anywhere.',
              value: settings.location,
              onChanged: (v) => _setLocation(context, v),
            ),
            const _Divider(),
            BackupSection(
              gear: gear,
              rolls: rolls,
              settings: settings,
              platform: platform,
              now: now,
            ),
            const _Divider(),
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Grain · GPLv3 · $appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: GrainColors.faded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 1, child: ColoredBox(color: GrainColors.divider));
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        color: GrainColors.ink,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GrainColors.secondary,
                        ),
                      ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: GrainColors.ground,
                activeTrackColor: GrainColors.ink,
                inactiveThumbColor: GrainColors.faded,
                inactiveTrackColor: GrainColors.ground,
                trackOutlineColor: const WidgetStatePropertyAll(
                  GrainColors.border,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
