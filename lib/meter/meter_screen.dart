import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../exposure/scales.dart';
import '../exposure/solver.dart';
import '../gear/gear_controller.dart';
import '../ui/haptics.dart';
import '../ui/theme.dart';
import 'meter_controller.dart';
import 'widgets/camera_permission.dart';
import 'widgets/focal_chip.dart';
import 'widgets/header.dart';
import 'widgets/iso_stepper.dart';
import 'widgets/lens_chip.dart';
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
    this.onOpenSettings,
    this.onOpenLibrary,
    this.onOpenLensPicker,
    this.requestCameraPermission,
  });

  final MeterController controller;
  final Haptics haptics;

  /// Source of the header and lens chip, and the lens cycling.
  final GearController gear;

  /// Settings button action.
  final VoidCallback? onOpenSettings;

  /// Gear library: the header title and its camera button.
  final VoidCallback? onOpenLibrary;

  /// The lens list; also where a tap on the lens chip leads when there is
  /// no favorite lens to cycle.
  final VoidCallback? onOpenLensPicker;

  /// Defaults to the system permission request; tests pass a fake.
  final CameraPermissionRequest? requestCameraPermission;

  @override
  State<MeterScreen> createState() => _MeterScreenState();
}

class _MeterScreenState extends State<MeterScreen> {
  MeterController get _c => widget.controller;

  GearController get _gear => widget.gear;

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
  static const _rowSizes = [64.0, 52.0, 44.0];

  /// Smallest viewfinder height the numerals step down for.
  static const _viewfinderFloor = 150.0;

  /// Keeps a step down from flipping back on a pixel's difference.
  static const _hysteresis = 8.0;

  /// Index into [_rowSizes] of the numerals in use.
  int _rowStep = 0;
  bool _fitScheduled = false;

  /// Picks the largest numeral size that leaves the viewfinder its floor,
  /// given that it got [height] at the current size. Both value rows carry
  /// one numeral line each, so a step frees twice its size difference. The
  /// new size applies from the next frame.
  void _fitRows(double height) {
    final scaler = MediaQuery.textScalerOf(context);
    double line(int step) => scaler.scale(_rowSizes[step]);
    double at(int step) => height + 2 * (line(_rowStep) - line(step));
    var step = _rowSizes.length - 1;
    for (var i = 0; i < _rowSizes.length; i++) {
      final need = i < _rowStep
          ? _viewfinderFloor + _hysteresis
          : _viewfinderFloor;
      if (at(i) >= need) {
        step = i;
        break;
      }
    }
    if (step == _rowStep || _fitScheduled) return;
    _fitScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitScheduled = false;
      if (mounted && step != _rowStep) setState(() => _rowStep = step);
    });
  }

  Future<void> _onLensTap() async {
    if (await _gear.cycleLens()) {
      widget.haptics.tick(strong: false);
    } else {
      widget.onOpenLensPicker?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          math.max(52, inset.top + 12),
          24,
          math.max(28, inset.bottom + 12),
        ),
        child: _Select(
          controller: _c,
          select: (c) => c.viewfinderOn,
          builder: (context, viewfinderOn) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              _Select(
                controller: _c,
                select: (c) => (c.gear, c.focalValues, c.focalIndex, c.mode),
                builder: (context, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    ListenableBuilder(
                      listenable: _gear,
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
                      _fitRows(box.maxHeight);
                      return RepaintBoundary(child: _viewfinder());
                    },
                  ),
                )
              else ...[
                const Spacer(),
                _Select(
                  controller: _c,
                  // Without the preview, the EV line (and its range flag)
                  // still shows above the rows.
                  select: (c) => (
                    c.cameraDenied,
                    c.cameraError,
                    c.reading?.ev100,
                    c.reading?.flag,
                    c.area,
                    c.held,
                  ),
                  builder: (context, _) => _notice() ?? _evText(),
                ),
              ],
              RepaintBoundary(child: _valueRows(viewfinderOn)),
              _Select(
                controller: _c,
                select: (c) => (c.isoIndex, c.isos),
                builder: (context, sel) => IsoStepper(
                  values: sel.$2,
                  index: sel.$1,
                  onChanged: _c.setIso,
                  haptics: widget.haptics,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gearHeader(bool viewfinderOn) {
    final body = _gear.body;
    final onLibrary = widget.onOpenLibrary ?? () {};
    return MeterHeader(
      title: body?.displayName ?? 'No camera',
      subtitle: body?.format.label ?? 'Free mode',
      viewfinderOn: viewfinderOn,
      onToggleViewfinder: _c.toggleViewfinder,
      onOpenSettings: widget.onOpenSettings ?? () {},
      onOpenLibrary: onLibrary,
    );
  }

  Widget _chips() {
    final body = _gear.body;
    final showFocal = _c.focalValues.length > 1;
    if (body == null && !showFocal) return const SizedBox.shrink();
    final onMore = widget.onOpenLensPicker ?? () {};
    return Row(
      children: [
        if (body != null)
          Flexible(
            child: LensChip(
              label: _gear.lens?.shortName ?? 'Choose lens',
              onTap: _onLensTap,
              onMore: onMore,
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
      );
    }
    final error = _c.cameraError;
    if (error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          const Text(
            'Camera unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: GrainColors.ink),
          ),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: GrainColors.secondary),
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
    ),
    textAlign: TextAlign.center,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 12 * .06,
      color: GrainColors.secondary,
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
    ),
    builder: (context, _) {
      final notice = _notice();
      if (notice != null) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: GrainColors.divider),
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
        widerThanPhone: _c.lensWiderThanCamera,
        onSpot: _c.tapSpot,
        onClearSpot: _c.clearSpot,
        onToggleHold: _c.toggleHold,
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
    ),
    builder: (context, _) {
      final size = viewfinderOn ? _rowSizes[_rowStep] : 92.0;
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
            padding: const EdgeInsets.only(top: 10),
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
