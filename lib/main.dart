import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'rolls/latitude.dart';
import 'rolls/location.dart';
import 'rolls/location_channel.dart';
import 'rolls/model.dart';
import 'rolls/roll_controller.dart';
import 'rolls/roll_repository.dart';
import 'rolls/snapshot_store.dart';
import 'rolls/ui/body_change_dialog.dart';
import 'rolls/ui/export_sheet.dart';
import 'rolls/ui/roll_editor.dart';
import 'rolls/ui/rolls_screen.dart';
import 'settings/licences.dart';
import 'settings/settings.dart';
import 'settings/settings_screen.dart';
import 'ui/click_sound.dart';
import 'ui/haptics.dart';
import 'ui/theme.dart';

/// The meter layout is portrait only.
Future<void> lockPortrait() =>
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicences();
  final db = GrainDatabase.open();
  final source = MeterChannel();
  // One bridge, shared by the settings screen (permission) and the roll
  // controller (fixes).
  final location = LocationChannel();
  final (:settings, :gear, :rolls) = await loadStartup(
    settings: Settings.load(),
    library: GearLibrary.load(rootBundle),
    snapshots: SnapshotStore.open(),
    alongside: lockPortrait(),
    makeGear: (library) =>
        GearController(library: library, repository: DriftGearRepository(db)),
    makeRolls: (settings, snapshots) => RollController(
      repository: DriftRollRepository(db),
      snapshots: snapshots,
      settings: settings,
      takeSnapshot: source.snapshot,
      location: location,
    ),
  );
  runApp(
    GrainApp(
      source: source,
      settings: settings,
      gear: gear,
      location: location,
      rolls: rolls,
    ),
  );
}

/// Everything the app needs before its first frame, loaded on two
/// independent chains so neither waits on the other's inputs: the gear
/// (library asset, then its tables) and the rolls (settings and snapshot
/// directory, then its tables). [alongside] (the orientation lock) runs in
/// parallel. Both controllers are loaded when this returns.
Future<({Settings settings, GearController gear, RollController rolls})>
loadStartup({
  required Future<Settings> settings,
  required Future<GearLibrary> library,
  required Future<SnapshotStore> snapshots,
  required GearController Function(GearLibrary library) makeGear,
  required RollController Function(Settings settings, SnapshotStore snapshots)
  makeRolls,
  Future<void>? alongside,
}) async {
  Future<GearController> gear() async {
    final g = makeGear(await library);
    await g.load();
    return g;
  }

  Future<RollController> rolls() async {
    final (s, store) = await (settings, snapshots).wait;
    final r = makeRolls(s, store);
    await r.load();
    return r;
  }

  final (s, g, r, _) = await (
    settings,
    gear(),
    rolls(),
    alongside ?? Future<void>.value(),
  ).wait;
  return (settings: s, gear: g, rolls: r);
}

class GrainApp extends StatefulWidget {
  GrainApp({
    super.key,
    MeterSource? source,
    this.haptics,
    this.clickSound,
    Settings? settings,
    GearController? gear,
    GearPlatform? platform,
    LocationSource? location,
    this.rolls,
    this.engineSwitch = kDebugMode,
  }) : source = source ?? MeterChannel(),
       platform = platform ?? const SystemGearPlatform(),
       settings = settings ?? Settings.inMemory(),
       gear = gear ?? GearController.inMemory(),
       location = location ?? LocationChannel();

  final MeterSource source;

  /// Overrides the system haptics (tests); otherwise [SystemHaptics] follows
  /// the haptics setting.
  final Haptics? haptics;

  /// Overrides the native click (tests); defaults to [ClickChannel].
  final ClickSound? clickSound;
  final Settings settings;
  final GearController gear;
  final GearPlatform platform;
  final LocationSource location;

  /// Defaults to an in-memory controller owned by the app (tests).
  final RollController? rolls;

  /// Whether the phone-AE setting is offered and obeyed: debug builds only,
  /// for comparing the engines. Release builds always meter with Grain's
  /// own engine where the camera allows it.
  final bool engineSwitch;

  @override
  State<GrainApp> createState() => _GrainAppState();
}

class _GrainAppState extends State<GrainApp> {
  Settings get _settings => widget.settings;

  /// The phone-AE setting where it applies (see [GrainApp.engineSwitch]).
  bool get _phoneAe => widget.engineSwitch && _settings.phoneAe;
  GearController get _gear => widget.gear;
  late final MeterController _controller = MeterController(
    source: widget.source,
    gear: _gear.setup,
    calibrationEv: _settings.calibrationEv,
    viewfinderOn: _settings.viewfinderOn,
    histogramOn: _settings.histogram,
    frameLandscape: _settings.frameLandscape,
  );
  late final bool _ownsRolls = widget.rolls == null;

  /// Snapshot directory of the default (test) controller; removed on dispose.
  Directory? _tempSnapshots;
  late final RollController _rolls =
      widget.rolls ??
      RollController.inMemory(
        settings: _settings,
        snapshots: SnapshotStore(
          _tempSnapshots = Directory.systemTemp.createTempSync(
            'grain-snapshots',
          ),
        ),
        takeSnapshot: widget.source.snapshot,
        location: widget.location,
      );
  late final SystemHaptics _systemHaptics = SystemHaptics(
    enabled: _settings.haptics,
  );
  late final ClickingHaptics _haptics = ClickingHaptics(
    widget.haptics ?? _systemHaptics,
    widget.clickSound ?? ClickChannel(),
    enabled: _settings.clickSound,
  );
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
    if (_phoneAe) unawaited(_controller.setPhoneAe(true));
    _controller.shakeWarning = _settings.shakeWarning;
    _controller.addListener(_onController);
    _gear.addListener(_onGear);
    _rolls.addListener(_onRolls);
    _syncRollIso();
    _controller.resume();
  }

  void _onSettings() {
    _systemHaptics.enabled = _settings.haptics;
    _haptics.enabled = _settings.clickSound;
    _controller.calibrationEv = _settings.calibrationEv;
    _controller.shakeWarning = _settings.shakeWarning;
    if (_controller.viewfinderOn != _settings.viewfinderOn) {
      _controller.toggleViewfinder();
    }
    if (_controller.histogramOn != _settings.histogram) {
      _controller.toggleHistogram();
    }
    if (_controller.frameLandscape != _settings.frameLandscape) {
      _controller.toggleFrameOrientation();
    }
    if (_controller.phoneAe != _phoneAe) {
      unawaited(_controller.setPhoneAe(_phoneAe));
    }
  }

  /// Equal setups are a no-op on the controller, so the two-way sync below
  /// settles after one round trip.
  void _onGear() {
    _controller.setGear(_gear.setup);
    _syncRollIso();
  }

  String? _rollId;

  /// The meter follows the active roll's exposed-at ISO and latitude while
  /// the roll logs for the selected body.
  void _onRolls() => _syncRollIso();

  void _syncRollIso() {
    final logs = _rolls.logsFor(_gear.body);
    final roll = _rolls.active;
    // A new roll starts at its own ISO even when it equals the old roll's.
    if (roll?.id != _rollId) {
      _rollId = roll?.id;
      _controller.setRollIso(null);
    }
    _controller.setRollIso(logs ? roll!.exposedIso : null);
    _controller.setLatitude(logs ? roll!.latitude : FilmLatitude.negative);
  }

  /// The eye, histogram and frame toggles are the same preferences as the
  /// settings; a zoom change goes back to the gear selection.
  void _onController() {
    if (_controller.focal != _gear.focal) _gear.setFocal(_controller.focal);
    if (_settings.viewfinderOn != _controller.viewfinderOn) {
      _settings.setViewfinderOn(_controller.viewfinderOn);
    }
    if (_settings.histogram != _controller.histogramOn) {
      _settings.setHistogram(_controller.histogramOn);
    }
    if (_settings.frameLandscape != _controller.frameLandscape) {
      _settings.setFrameLandscape(_controller.frameLandscape);
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    _controller.removeListener(_onController);
    _gear.removeListener(_onGear);
    _rolls.removeListener(_onRolls);
    if (_ownsRolls) {
      _rolls.dispose();
      try {
        _tempSnapshots?.deleteSync(recursive: true);
      } on FileSystemException {
        // best effort
      }
    }
    _haptics.enabled = false;
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

  void _export(Roll roll) {
    final c = _overlayContext;
    if (c != null) {
      showExportSheet(c, roll: roll, rolls: _rolls, platform: widget.platform);
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
  /// When the route returns with another body selected while a roll is active
  /// in a different one, asks what to do with the roll.
  Future<T?> _pushLent<T>(WidgetBuilder builder) async {
    final navigator = _navigator.currentState;
    if (navigator == null) return null;
    final before = _gear.body?.id;
    final result = await _controller.lendCamera(
      () => navigator.push(MaterialPageRoute<T>(builder: builder)),
      waitForRelease: false,
    );
    if (mounted && _gear.body?.id != before) await _askBodyChange();
    return result;
  }

  Future<void> _askBodyChange() async {
    final roll = _rolls.active;
    final c = _overlayContext;
    if (roll == null || c == null || _rolls.logsFor(_gear.body)) return;
    final body = _gear.body;
    final choice = await showBodyChangeDialog(
      c,
      roll: roll,
      nextLabel: _rolls.nextLabel!,
      to: body,
    );
    if (!mounted) return;
    switch (choice) {
      case BodyChangeChoice.continueRoll:
        await _rolls.continueRoll(roll.id, body!);
      case BodyChangeChoice.finishAndStart:
        await _startRoll();
      case BodyChangeChoice.meterOnly || null:
        break;
    }
  }

  Future<void> _startRoll() => _pushLent<Roll>(
    (_) => RollEditorScreen(rolls: _rolls, haptics: _haptics, body: _gear.body),
  );

  void _openLibrary() => unawaited(
    _pushLent<void>(
      (_) => BodyPickerScreen(gear: _gear, onShare: _share, onImport: _import),
    ),
  );

  /// Lenses of the selected body's mount; without a body, the library.
  void _openLensPicker() {
    final body = _gear.body;
    if (body == null) return _openLibrary();
    unawaited(
      _pushLent<void>(
        (_) => LensPickerScreen(
          gear: _gear,
          mount: body.mount,
          onShare: _share,
          onImport: _import,
        ),
      ),
    );
  }

  void _openRolls() => unawaited(
    _pushLent<void>(
      (_) => RollsScreen(
        rolls: _rolls,
        gear: _gear,
        haptics: _haptics,
        onExport: _export,
      ),
    ),
  );

  void _openSettings() => unawaited(
    _pushLent<void>(
      (_) => SettingsScreen(
        settings: _settings,
        haptics: _haptics,
        location: widget.location,
        gear: _gear,
        rolls: _rolls,
        platform: widget.platform,
        engineSwitch: widget.engineSwitch,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => _app(),
    );
  }

  Widget _app() {
    return MaterialApp(
      title: 'Grain',
      theme: grainTheme(),
      darkTheme: grainTheme(Brightness.dark),
      themeMode: switch (_settings.theme) {
        ThemeChoice.system => ThemeMode.system,
        ThemeChoice.light => ThemeMode.light,
        ThemeChoice.dark => ThemeMode.dark,
      },
      navigatorKey: _navigator,
      // System bar icons follow the effective brightness, on the palette's
      // ground: dark icons on light, light icons on dark.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: grainOverlayStyle(Theme.of(context).brightness),
        child: child!,
      ),
      home: MeterScreen(
        controller: _controller,
        haptics: _haptics,
        gear: _gear,
        rolls: _rolls,
        onOpenLibrary: _openLibrary,
        onOpenLensPicker: _openLensPicker,
        onBodyCycled: () => unawaited(_askBodyChange()),
        onOpenSettings: _openSettings,
        onOpenRolls: _openRolls,
        onStartRoll: () => unawaited(_startRoll()),
      ),
    );
  }
}
