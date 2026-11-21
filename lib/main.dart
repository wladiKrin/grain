import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'db/database.dart';
import 'gear/gear_controller.dart';
import 'gear/gear_repository.dart';
import 'gear/library.dart';
import 'gear/model.dart';
import 'gear/platform.dart';
import 'gear/ui/body_picker.dart';
import 'gear/ui/import_flow.dart';
import 'gear/ui/lens_picker.dart';
import 'gear/ui/share_sheet.dart';
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
    GearPlatform? platform,
  }) : source = source ?? MeterChannel(),
       platform = platform ?? const SystemGearPlatform(),
       settings = settings ?? Settings.inMemory(),
       gear = gear ?? GearController.inMemory();

  final MeterSource source;

  /// Overrides the system haptics (tests); otherwise [SystemHaptics] follows
  /// the haptics setting.
  final Haptics? haptics;
  final Settings settings;
  final GearController gear;
  final GearPlatform platform;

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
      onResume: _controller.enterForeground,
      onInactive: _controller.enterBackground,
      onHide: _controller.enterBackground,
      onPause: _controller.enterBackground,
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

  /// A context under the app's navigator, for sheets and dialogs started
  /// from the pickers' callbacks.
  BuildContext? get _overlayContext =>
      _navigator.currentState?.overlay?.context;

  void _share(GearDoc doc) {
    final c = _overlayContext;
    if (c != null) {
      showShareSheet(c, doc: doc, platform: widget.platform);
    }
  }

  void _import() {
    final c = _overlayContext;
    if (c != null) {
      showImportSheet(
        c,
        gear: _gear,
        platform: widget.platform,
        meter: _controller,
        source: widget.source,
      );
    }
  }

  /// Pushes a full-screen route with the meter's camera released while it
  /// (and anything opened from it) is up; the meter resumes on the way back.
  void _pushLent(WidgetBuilder builder) {
    final navigator = _navigator.currentState;
    if (navigator == null) return;
    unawaited(
      _controller.lendCamera(
        () => navigator.push(MaterialPageRoute<void>(builder: builder)),
        waitForRelease: false,
      ),
    );
  }

  void _openLibrary() => _pushLent(
    (_) => BodyPickerScreen(gear: _gear, onShare: _share, onImport: _import),
  );

  /// Lenses of the selected body's mount; without a body, the library.
  void _openLensPicker() {
    final body = _gear.body;
    if (body == null) return _openLibrary();
    _pushLent(
      (_) => LensPickerScreen(
        gear: _gear,
        mount: body.mount,
        onShare: _share,
        onImport: _import,
      ),
    );
  }

  void _openSettings() =>
      _pushLent((_) => SettingsScreen(settings: _settings, haptics: _haptics));

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
        onOpenLibrary: _openLibrary,
        onOpenLensPicker: _openLensPicker,
        onOpenSettings: _openSettings,
      ),
    );
  }
}
