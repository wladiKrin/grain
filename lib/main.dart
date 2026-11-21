import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

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
  final settings = await Settings.load();
  runApp(GrainApp(settings: settings));
}

class GrainApp extends StatefulWidget {
  GrainApp({
    super.key,
    MeterSource? source,
    this.haptics,
    Settings? settings,
  }) : source = source ?? MeterChannel(),
       settings = settings ?? Settings.inMemory();

  final MeterSource source;

  /// Overrides the system haptics (tests); otherwise [SystemHaptics] follows
  /// the haptics setting.
  final Haptics? haptics;
  final Settings settings;

  @override
  State<GrainApp> createState() => _GrainAppState();
}

class _GrainAppState extends State<GrainApp> {
  Settings get _settings => widget.settings;
  late final MeterController _controller = MeterController(
    source: widget.source,
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
    _controller.resume();
  }

  void _onSettings() {
    _systemHaptics.enabled = _settings.haptics;
    _controller.calibrationEv = _settings.calibrationEv;
    if (_controller.viewfinderOn != _settings.viewfinderOn) {
      _controller.toggleViewfinder();
    }
  }

  /// The eye toggle is the same preference as the settings switch.
  void _onController() {
    if (_settings.viewfinderOn != _controller.viewfinderOn) {
      _settings.setViewfinderOn(_controller.viewfinderOn);
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    _controller.removeListener(_onController);
    _lifecycle.dispose();
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

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
