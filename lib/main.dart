import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'db/database.dart';
import 'gear/gear_controller.dart';
import 'gear/gear_repository.dart';
import 'gear/library.dart';
import 'meter/meter_controller.dart';
import 'meter/meter_screen.dart';
import 'metering/meter_channel.dart';
import 'settings/settings.dart';
import 'settings/settings_screen.dart';
import 'ui/haptics.dart';
import 'ui/theme.dart';

/// The meter layout is portrait only.
Future<void> lockPortrait() =>
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockPortrait();
  final (settings, library) = await (
    Settings.load(),
    GearLibrary.load(rootBundle),
  ).wait;
  final gear = GearController(
    library: library,
    repository: DriftGearRepository(GrainDatabase.open()),
  );
  await gear.load();
  runApp(GrainApp(settings: settings, gear: gear));
}

class GrainApp extends StatefulWidget {
  GrainApp({
    super.key,
    MeterSource? source,
    this.haptics,
    Settings? settings,
    GearController? gear,
  }) : source = source ?? MeterChannel(),
       settings = settings ?? Settings.inMemory(),
       gear = gear ?? GearController.inMemory();

  final MeterSource source;

  /// Overrides the system haptics (tests); otherwise [SystemHaptics] follows
  /// the haptics setting.
  final Haptics? haptics;
  final Settings settings;
  final GearController gear;

  @override
  State<GrainApp> createState() => _GrainAppState();
}

class _GrainAppState extends State<GrainApp> {
  Settings get _settings => widget.settings;
  GearController get _gear => widget.gear;
  late final MeterController _controller = MeterController(
    source: widget.source,
    gear: _gear.setup,
    calibrationEv: _settings.calibrationEv,
    viewfinderOn: _settings.viewfinderOn,
  );
  late final SystemHaptics _systemHaptics = SystemHaptics(
    enabled: _settings.haptics,
  );
  Haptics get _haptics => widget.haptics ?? _systemHaptics;
  final _navigator = GlobalKey<NavigatorState>();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Camera is held only while the app is in the foreground.
    _lifecycle = AppLifecycleListener(
      onResume: _controller.resume,
      onInactive: _controller.pause,
      onHide: _controller.pause,
      onPause: _controller.pause,
    );
    _settings.addListener(_onSettings);
    _controller.addListener(_onController);
    _gear.addListener(_onGear);
    _controller.resume();
  }

  void _onSettings() {
    _systemHaptics.enabled = _settings.haptics;
    _controller.calibrationEv = _settings.calibrationEv;
    if (_controller.viewfinderOn != _settings.viewfinderOn) {
      _controller.toggleViewfinder();
    }
  }

  /// Equal setups are a no-op on the controller, so the two-way sync below
  /// settles after one round trip.
  void _onGear() => _controller.setGear(_gear.setup);

  /// The eye toggle is the same preference as the settings switch; a zoom
  /// change goes back to the gear selection.
  void _onController() {
    if (_controller.focal != _gear.focal) _gear.setFocal(_controller.focal);
    if (_settings.viewfinderOn != _controller.viewfinderOn) {
      _settings.setViewfinderOn(_controller.viewfinderOn);
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    _controller.removeListener(_onController);
    _gear.removeListener(_onGear);
    _lifecycle.dispose();
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  /// Placeholder routes until the gear screens arrive.
  void _push(String title) => _navigator.currentState?.push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: Text(title))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grain',
      theme: grainTheme(),
      navigatorKey: _navigator,
      // Every route sits on the paper ground: dark bar icons, even when the
      // system is in dark mode.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: grainOverlayStyle,
        child: child!,
      ),
      home: MeterScreen(
        controller: _controller,
        haptics: _haptics,
        gear: _gear,
        onOpenLibrary: () => _push('Library'),
        onOpenLensPicker: () => _push('Lenses'),
        onOpenSettings: () => _navigator.currentState?.push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SettingsScreen(settings: _settings, haptics: _haptics),
          ),
        ),
      ),
    );
  }
}
