import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../backup/ui.dart';
import '../exposure/scales.dart';
import '../exposure/stops.dart';
import '../gear/gear_controller.dart';
import '../gear/platform.dart';
import '../map/map_style_sheet.dart';
import '../rolls/roll_controller.dart';
import '../rolls/location.dart';
import '../ui/dial/swipe_dial.dart';
import '../ui/haptics.dart';
import '../ui/permissions.dart';
import '../ui/round_button.dart';
import '../ui/theme.dart';
import '../version.dart';
import 'licences.dart';
import 'settings.dart';

export '../version.dart' show appVersion;

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
    this.openSettings = openAppSettings,
    this.engineSwitch = false,
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

  /// Opened from the snackbar when location is blocked in the system.
  final OpenSettings openSettings;

  /// The backup's date (file name, share subject).
  final DateTime Function() now;

  /// Shows the phone-AE comparison switch (debug builds).
  final bool engineSwitch;

  /// The permission is requested only here, on turning the switch on.
  Future<void> _setLocation(BuildContext context, bool on) async {
    if (!on) return settings.setLocation(false);
    final messenger = ScaffoldMessenger.of(context);
    final outcome =
        await location?.requestPermission() ?? PermissionOutcome.denied;
    switch (outcome) {
      case PermissionOutcome.granted:
        return settings.setLocation(true);
      case PermissionOutcome.denied:
        messenger.showSnackBar(
          const SnackBar(content: Text('Location permission was not granted.')),
        );
      case PermissionOutcome.blocked:
        messenger.showSnackBar(
          SnackBar(
            content: const Text(
              'Location is off for Grain in the system settings.',
            ),
            action: SnackBarAction(
              label: 'Open settings',
              onPressed: openSettings,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
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
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: g.ink,
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
                  Text('CALIBRATION', style: g.label),
                  SwipeDial(
                    values: _calibrationValues,
                    index: settings.calibrationThirds + Settings.maxThirds,
                    onChanged: (i) =>
                        settings.setCalibrationThirds(i - Settings.maxThirds),
                    haptics: haptics,
                    valueFontSize: 44,
                  ),
                  Text(
                    'Compare with a camera you trust and nudge until they agree.',
                    style: TextStyle(fontSize: 13, color: g.secondary),
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
              label: 'Click sound',
              subtitle: 'A soft click at each dial step.',
              value: settings.clickSound,
              onChanged: settings.setClickSound,
            ),
            const _Divider(),
            _SwitchRow(
              label: 'Camera-shake warning',
              subtitle: 'Marks shutter speeds slower than 1/focal length (35 mm equivalent).',
              value: settings.shakeWarning,
              onChanged: settings.setShakeWarning,
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
            _LinkRow(
              label: 'Map: ${mapStyleLabels[settings.mapStyle]}',
              subtitle: mapStyleSubtitles[settings.mapStyle],
              onTap: () => showMapStyleSheet(context, settings),
            ),
            const _Divider(),
            _ThemeRow(value: settings.theme, onChanged: settings.setTheme),
            const _Divider(),
            if (engineSwitch) ...[
              _SwitchRow(
                label: 'Meter with the phone\u2019s auto-exposure',
                subtitle: 'For comparison only: reads brighter than Grain\u2019s own metering in dim light. The EV line shows AE while it is on.',
                value: settings.phoneAe,
                onChanged: settings.setPhoneAe,
              ),
              const _Divider(),
            ],
            BackupSection(
              gear: gear,
              rolls: rolls,
              settings: settings,
              platform: platform,
              now: now,
            ),
            const _Divider(),
            _LinkRow(
              label: 'Licences',
              subtitle: 'Notices for the code, font and data Grain ships.',
              onTap: () => showLicences(context),
            ),
            const _Divider(),
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Text(
                'Grain · GPLv3 · $appVersion',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: g.faded),
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
      SizedBox(height: 1, child: ColoredBox(color: context.grain.divider));
}

/// A row that opens another page.
class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap, this.subtitle});

  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(label, style: TextStyle(fontSize: 15, color: g.ink)),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: TextStyle(fontSize: 13, color: g.secondary),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: g.secondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
    final g = context.grain;
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
                    Text(label, style: TextStyle(fontSize: 15, color: g.ink)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13, color: g.secondary),
                      ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: g.ground,
                activeTrackColor: g.ink,
                inactiveThumbColor: g.faded,
                inactiveTrackColor: g.ground,
                trackOutlineColor: WidgetStatePropertyAll(g.border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Appearance: follow the system, or fix light or dark.
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.value, required this.onChanged});

  final ThemeChoice value;
  final ValueChanged<ThemeChoice> onChanged;

  static const _labels = {
    ThemeChoice.system: 'System',
    ThemeChoice.light: 'Light',
    ThemeChoice.dark: 'Dark',
  };

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Text('Appearance', style: TextStyle(fontSize: 15, color: g.ink)),
          SegmentedButton<ThemeChoice>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              backgroundColor: g.ground,
              foregroundColor: g.ink,
              selectedBackgroundColor: g.ink,
              selectedForegroundColor: g.ground,
              side: BorderSide(color: g.border),
              minimumSize: const Size(44, 44),
            ),
            segments: [
              for (final e in _labels.entries)
                ButtonSegment(value: e.key, label: Text(e.value)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}
