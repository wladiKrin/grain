import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

import '../exposure/mode.dart';
import '../exposure/scales.dart';
import '../exposure/solver.dart';
import '../gear/gear_controller.dart';
import '../rolls/push.dart';
import '../rolls/roll_controller.dart';
import '../ui/haptics.dart';
import '../ui/permissions.dart';
import '../ui/theme.dart';
import 'meter_controller.dart';
import 'widgets/camera_permission.dart';
import 'widgets/focal_chip.dart';
import 'widgets/gear_chip.dart';
import 'widgets/header.dart';
import 'widgets/iso_stepper.dart';
import 'widgets/log_button.dart';
import 'widgets/mode_tabs.dart';
import 'widgets/offset_scale.dart';
import 'widgets/value_row.dart';
import 'widgets/viewfinder.dart';

/// The main screen: header, focal chip, mode tabs, viewfinder, the two value
/// rows and the ISO stepper.
class MeterScreen extends StatefulWidget {
  const MeterScreen({
    super.key,
    required this.controller,
    required this.haptics,
    required this.gear,
    required this.rolls,
    this.onStartRoll,
    this.onOpenRolls,
    this.onOpenSettings,
    this.onOpenLibrary,
    this.onOpenLensPicker,
    this.onBodyCycled,
    this.requestCameraPermission,
    this.openSettings,
  });

  final MeterController controller;
  final Haptics haptics;

  /// Source of the header and lens chip, and the lens cycling.
  final GearController gear;

  /// The active roll and saved readings the Log / Save button writes to.
  final RollController rolls;

  /// The "Start roll" link under the button (shown when no roll logs).
  final VoidCallback? onStartRoll;

  /// The rolls button beside the Log / Save button.
  final VoidCallback? onOpenRolls;

  /// Settings button action.
  final VoidCallback? onOpenSettings;

  /// Gear library (the body list): the camera chip's ▾, and where a tap on
  /// the camera chip leads when there is no favorite body to cycle.
  final VoidCallback? onOpenLibrary;

  /// The lens list; also where a tap on the lens chip leads when there is
  /// no favorite lens to cycle.
  final VoidCallback? onOpenLensPicker;

  /// After a tap on the camera chip moved to another favorite body.
  final VoidCallback? onBodyCycled;

  /// Defaults to the system permission request; tests pass a fake.
  final CameraPermissionRequest? requestCameraPermission;

  /// Opens the system settings (default: the app's settings page).
  final OpenSettings? openSettings;

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> {
  GrainPalette get g => context.grain;

  MeterController get _c => widget.controller;

  GearController get _gear => widget.gear;

  RollController get _rolls => widget.rolls;

  final _logKey = GlobalKey();

  /// Records the current exposure, as a frame of the active roll when it
  /// logs for the selected body, else as a saved reading. The new state is
  /// in memory before this returns; the writes follow on their own.
  void _log() {
    final e = _c.captureExposure();
    widget.haptics.tick(strong: true);
    final messenger = ScaffoldMessenger.of(context);
    final String message;
    final Future<void> Function() undo;
    final Future<void> done;
    if (_rolls.logsFor(_gear.body)) {
      message = 'Frame ${_rolls.nextLabel} logged';
      final frame = _rolls.logFrame(e);
      done = frame;
      undo = () async {
        final f = await frame;
        await _rolls.deleteFrame(f.rollId, f.id);
      };
    } else {
      message = 'Reading saved';
      final reading = _rolls.saveReading(
        e,
        body: _gear.body,
        format: _c.format,
      );
      done = reading;
      undo = () async => _rolls.deleteReading((await reading).id);
    }
    unawaited(
      done.then<void>(
        (_) {},
        onError: (Object error) {
          messenger.clearSnackBars();
          messenger.showSnackBar(const SnackBar(content: Text('Not saved')));
        },
      ),
    );
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        // An action would otherwise keep it up until dismissed; with a
        // screen reader it stays, so Undo can be reached.
        persist: MediaQuery.accessibleNavigationOf(context),
        behavior: SnackBarBehavior.floating,
        // Above the button row, so the next log is never covered.
        margin: EdgeInsets.fromLTRB(24, 0, 24, _aboveLogButton()),
        action: SnackBarAction(
          label: 'Undo',
          // A write that failed has nothing to undo; its error is already
          // reported by "Not saved".
          onPressed: () =>
              unawaited(undo().then<void>((_) {}, onError: (Object _) {})),
        ),
      ),
    );
  }

  /// Bottom margin that floats a snack bar just above the button row.
  double _aboveLogButton() {
    final box = _logKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return 16;
    final top = box.localToGlobal(Offset.zero).dy;
    return math.max(16, MediaQuery.sizeOf(context).height - top + 8);
  }

  /// Line 2 of the header: roll progress, the meter-only note, or the format.
  String _statusLine(String formatLabel) {
    final roll = _rolls.active;
    if (roll == null) return formatLabel;
    if (_rolls.logsFor(_gear.body)) {
      return rollStatus(roll, _rolls.nextFrameNumber!);
    }
    return 'Meter only · roll ${roll.number} is in the ${roll.bodyName}';
  }

  /// Aperture scale labelled "f/5.6" for display, rebuilt whenever the
  /// controller swaps its aperture list (gear or focal change).
  List<ScaleValue>? _aperturesFor;
  List<ScaleValue> _apertures = const [];

  List<ScaleValue> _displayApertures() {
    if (!identical(_aperturesFor, _c.apertures)) {
      _aperturesFor = _c.apertures;
      _apertures = [
        for (final v in _c.apertures)
          ScaleValue('f/${v.label}', v.value, v.isFullStop),
      ];
    }
    return _apertures;
  }

  /// Value numeral sizes with the viewfinder on, largest first.
  static const _rowSizes = [64.0, 52.0, 44.0, 36.0];

  /// Same with the viewfinder off, where the numerals are bigger.
  static const _bareSizes = [92.0, 72.0, 56.0, 44.0, 36.0, 28.0];

  /// Smallest viewfinder height the numerals step down for.
  static const _viewfinderFloor = 150.0;

  /// Room the EV line needs above the rows when the viewfinder is off.
  static const _bareFloor = 24.0;

  /// Keeps a step down from flipping back on a pixel's difference.
  static const _hysteresis = 8.0;

  /// Index into [_rowSizes] / [_bareSizes] of the numerals in use.
  int _rowStep = 0, _bareStep = 0;

  /// Height last measured at each numeral step (see [_fitRows]).
  final _seenRows = List<double?>.filled(_rowSizes.length, null);
  final _seenBare = List<double?>.filled(_bareSizes.length, null);
  bool _fitScheduled = false;

  /// Picks the largest numeral size that leaves the viewfinder (or, bare,
  /// the EV line) its floor, given that it got [height] at the current size.
  /// Both value rows carry one numeral line each, so a step frees twice its
  /// size difference. The new size applies from the next frame.
  void _fitRows(double height, {required bool bare}) {
    final sizes = bare ? _bareSizes : _rowSizes;
    final floor = bare ? _bareFloor : _viewfinderFloor;
    final current = bare ? _bareStep : _rowStep;
    final scaler = MediaQuery.textScalerOf(context);
    double line(int step) => scaler.scale(sizes[step]);
    // What this step gave last time it was in use, when that is still
    // current; else the estimate. Without the record a step whose real
    // effect is larger than the estimate would flip back and forth.
    final seen = bare ? _seenBare : _seenRows;
    if (seen[current] != null && (seen[current]! - height).abs() > .5) {
      seen.fillRange(0, seen.length, null);
    }
    seen[current] = height;
    double at(int step) =>
        seen[step] ?? height + 2 * (line(current) - line(step));
    var step = sizes.length - 1;
    for (var i = 0; i < sizes.length; i++) {
      final need = i < current ? floor + _hysteresis : floor;
      if (at(i) >= need) {
        step = i;
        break;
      }
    }
    if (step == current || _fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (!mounted) return;
      setState(() {
        if (bare) {
          _bareStep = step;
        } else {
          _rowStep = step;
        }
      });
    });
  }

  Future<void> _onBodyTap() async {
    final before = _gear.body?.id;
    if (await _gear.cycleBody()) {
      widget.haptics.tick(strong: false);
      if (_gear.body?.id != before) widget.onBodyCycled?.call();
    } else {
      widget.onOpenLibrary?.call();
    }
  }

  Future<void> _onLensTap() async {
    if (await _gear.cycleLens()) {
      widget.haptics.tick(strong: false);
    } else {
      widget.onOpenLensPicker?.call();
    }
  }

  bool _seeded = false;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    if (!_seeded) {
      _seeded = true;
      // The first frame cannot measure itself (the fit runs after layout):
      // a short screen starts the bare numerals one step down so that frame
      // does not overflow either.
      if (MediaQuery.sizeOf(context).height < 840) _bareStep = 1;
    }
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          math.max(44, inset.top + 8),
          24,
          math.max(24, inset.bottom + 8),
        ),
        child: _Select(
          controller: _c,
          select: (c) => c.viewfinderOn,
          builder: (context, viewfinderOn) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              _Select(
                controller: _c,
                select: (c) => (c.gear, c.focalValues, c.focalIndex, c.mode),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([_gear, _rolls]),
                      builder: (context, _) => _gearHeader(viewfinderOn),
                    ),
                    ListenableBuilder(
                      listenable: _gear,
                      builder: (context, _) => _chips(),
                    ),
                    ModeTabs(mode: _c.mode, onChanged: _c.setMode),
                  ],
                ),
              ),
              if (viewfinderOn)
                // Takes the remaining height; the value numerals step down
                // when that falls below the viewfinder's floor.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      _fitRows(box.maxHeight, bare: false);
                      return RepaintBoundary(child: _viewfinder());
                    },
                  ),
                )
              else ...[
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      _fitRows(box.maxHeight, bare: true);
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: _Select(
                          controller: _c,
                          // Without the preview, the EV line (and its range
                          // flag) still shows above the rows.
                          select: (c) => (
                            c.cameraDenied,
                            c.cameraError,
                            c.reading?.ev100,
                            c.reading?.flag,
                            c.area,
                            c.held,
                            c.apertureAssumed,
                          ),
                          builder: (context, _) => _notice() ?? _evText(),
                        ),
                      );
                    },
                  ),
                ),
              ],
              RepaintBoundary(child: _valueRows(viewfinderOn)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [
                  _Select(
                    controller: _c,
                    select: (c) => (c.isoIndex, c.isos, c.isoDiffersFromRoll),
                    builder: (context, sel) => IsoStepper(
                      values: sel.$2,
                      index: sel.$1,
                      onChanged: _c.setIso,
                      haptics: widget.haptics,
                      marked: sel.$3,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([_gear, _rolls]),
                    builder: (context, _) {
                      final logs = _rolls.logsFor(_gear.body);
                      return LogButton(
                        key: _logKey,
                        label: logs
                            ? 'Log frame ${_rolls.nextLabel}'
                            : 'Save reading',
                        onPressed: _log,
                        onStartRoll: logs
                            ? null
                            : (widget.onStartRoll ?? () {}),
                        onOpenRolls: widget.onOpenRolls ?? () {},
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gearHeader(bool viewfinderOn) {
    final body = _gear.body;
    final roll = _rolls.active;
    return MeterHeader(
      title: _statusLine(body?.format.label ?? 'Free mode'),
      subtitle: roll != null && _rolls.logsFor(body) && roll.pushThirds != 0
          ? filmLine(roll)
          : null,
      viewfinderOn: viewfinderOn,
      onToggleViewfinder: _c.toggleViewfinder,
      onOpenSettings: widget.onOpenSettings ?? () {},
    );
  }

  /// Camera, lens and (for a zoom) focal length, side by side.
  Widget _chips() {
    final body = _gear.body;
    final showFocal = _c.focalValues.length > 1;
    final onLibrary = widget.onOpenLibrary ?? () {};
    return Row(
      spacing: 8,
      children: [
        Flexible(
          child: GearChip(
            label: body?.displayName ?? 'No camera',
            semanticLabel: 'Camera',
            moreLabel: 'More cameras',
            onTap: _onBodyTap,
            onMore: onLibrary,
          ),
        ),
        if (body != null)
          Flexible(
            child: GearChip(
              label: _gear.lens?.shortName ?? 'Choose lens',
              semanticLabel: 'Lens',
              moreLabel: 'More lenses',
              onTap: _onLensTap,
              onMore: widget.onOpenLensPicker ?? () {},
            ),
          ),
        if (showFocal)
          FocalChip(
            values: _c.focalValues,
            index: _c.focalIndex,
            onChanged: _c.setFocal,
            haptics: widget.haptics,
          ),
      ],
    );
  }

  /// Explanation for a missing permission or a failed camera; null when the
  /// camera is fine.
  Widget? _notice() {
    if (_c.cameraDenied) {
      return CameraPermissionPrompt(
        onGranted: _c.resume,
        request: widget.requestCameraPermission ?? requestCameraPermission,
        openSettings: widget.openSettings ?? openAppSettings,
      );
    }
    final error = _c.cameraError;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            'Camera unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: g.ink),
          ),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: g.secondary),
          ),
        ],
      );
    }
    return null;
  }

  Widget _evText() => Text(
    evLine(
      ev: _c.reading?.ev100,
      flag: _c.reading?.flag ?? RangeFlag.ok,
      area: _c.area,
      held: _c.held,
      estimated: _c.apertureAssumed,
    ),
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 12 * .06,
      color: g.secondary,
    ),
  );

  Widget _viewfinder() => _Select(
    controller: _c,
    select: (c) => (
      c.cameraDenied,
      c.cameraError,
      c.preview,
      c.focalIndex,
      c.format,
      c.area,
      c.spot,
      c.reading?.ev100,
      c.reading?.flag,
      c.held,
      c.apertureAssumed,
      c.histogramOn,
      c.frameLandscape,
    ),
    builder: (context, _) {
      final notice = _notice();
      if (notice != null) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: g.divider),
          ),
          alignment: Alignment.center,
          child: notice,
        );
      }
      final p = _c.preview;
      return Viewfinder(
        textureId: p?.textureId,
        previewSize: _c.previewSize,
        crop: _c.cropRect,
        area: _c.area,
        spot: _c.spot,
        spotRadius: _c.spotRadius,
        ev: _c.reading?.ev100,
        flag: _c.reading?.flag ?? RangeFlag.ok,
        held: _c.held,
        estimated: _c.apertureAssumed,
        widerThanPhone: _c.lensWiderThanCamera,
        onSpot: _c.tapSpot,
        onClearSpot: _c.clearSpot,
        onToggleHold: _c.toggleHold,
        histogramOn: _c.histogramOn,
        onToggleHistogram: _c.toggleHistogram,
        histogram: _c.histogram,
        frameLandscape: _c.frameLandscape,
        onToggleFrame: _c.toggleFrameOrientation,
        // Sideways, the box takes the frame's shape; upright, it keeps its
        // height and shows the dimmed surroundings.
        fitToCrop: _c.frameLandscape,
      );
    },
  );

  Widget _valueRows(bool viewfinderOn) => _Select(
    controller: _c,
    select: (c) => (
      c.mode,
      c.apertures,
      c.shutters,
      c.bulbSeconds,
      c.apertureIndex,
      c.shutterIndex,
      c.solvedShutter?.index,
      c.solvedShutter?.flag,
      c.solvedAperture?.index,
      c.solvedAperture?.flag,
      c.shakeRiskNow,
    ),
    builder: (context, _) {
      final size = viewfinderOn ? _rowSizes[_rowStep] : _bareSizes[_bareStep];
      final apertures = _displayApertures();
      final bulb = _c.bulbSeconds;
      final aperture = ValueRow.input(
        label: 'APERTURE',
        values: apertures,
        index: _c.apertureIndex,
        onChanged: _c.setAperture,
        haptics: widget.haptics,
        fontSize: size,
      );
      final shutter = ValueRow.input(
        label: 'SHUTTER',
        values: _c.shutters,
        index: _c.shutterIndex,
        onChanged: _c.setShutter,
        haptics: widget.haptics,
        fontSize: size,
        warning: _c.shakeRiskNow,
      );
      final rows = switch (_c.mode) {
        MeterMode.aperturePriority => [
          aperture,
          ValueRow.solved(
            label: 'SHUTTER',
            solved: bulb != null
                ? 'B'
                : _c.solvedShutter == null
                ? null
                : _c.shutters[_c.solvedShutter!.index].label,
            note: bulb == null ? null : formatSeconds(bulb),
            flag: _c.solvedShutter?.flag ?? .ok,
            fontSize: size,
            warning: _c.shakeRiskNow,
          ),
        ],
        MeterMode.shutterPriority => [
          ValueRow.solved(
            label: 'APERTURE',
            solved: _c.solvedAperture == null
                ? null
                : apertures[_c.solvedAperture!.index].label,
            flag: _c.solvedAperture?.flag ?? .ok,
            fontSize: size,
          ),
          shutter,
        ],
        MeterMode.manual => [
          aperture,
          shutter,
          Padding(
            padding: const EdgeInsets.only(top: 6),
            // Own selector so offset changes don't rebuild the dials.
            child: _Select(
              controller: _c,
              select: (c) => c.offset,
              builder: (context, offset) =>
                  RepaintBoundary(child: OffsetScale(offset: offset)),
            ),
          ),
        ],
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      );
    },
  );
}

/// Rebuilds [builder] only when [select]ed controller state changes, so
/// live stats don't rebuild parts that don't show them.
class _Select<T> extends StatefulWidget {
  const _Select({
    super.key,
    required this.controller,
    required this.select,
    required this.builder,
  });

  final MeterController controller;
  final T Function(MeterController) select;
  final Widget Function(BuildContext, T) builder;

  @override
  State<_Select<T>> createState() => _SelectState<T>();
}

class _SelectState<T> extends State<_Select<T>> {
  late T _value = widget.select(widget.controller);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(_Select<T> old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    _value = widget.select(widget.controller);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final v = widget.select(widget.controller);
    if (v != _value) setState(() => _value = v);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
