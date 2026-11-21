import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../codec.dart';
import '../gear_controller.dart';
import '../ids.dart';
import '../model.dart';
import 'form_bits.dart';

/// A blank 50 mm f/2 prime for [mount].
Lens newLensTemplate(String mount) => Lens(
  id: '',
  make: '',
  name: '',
  mount: mount,
  focalMin: 50,
  focalMax: 50,
  maxAperture: const [ApertureAt(50, 2)],
  minAperture: 16,
  apertureStep: StepSize.third,
);

String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class LensEditorScreen extends StatefulWidget {
  const LensEditorScreen({
    super.key,
    required this.gear,
    required this.initial,
    required this.isNew,
    this.mount,
  });

  final GearController gear;
  final Lens initial;
  final bool isNew;

  /// Overrides the initial mount (a new lens made from a mount's picker).
  final String? mount;

  @override
  State<LensEditorScreen> createState() => _LensEditorScreenState();
}

class _LensEditorScreenState extends State<LensEditorScreen> {
  late final _make = TextEditingController(text: widget.initial.make);
  late final _name = TextEditingController(text: widget.initial.name);
  late final _mount = TextEditingController(
    text: widget.mount ?? widget.initial.mount,
  );
  late bool _zoom = widget.initial.isZoom;
  late final _focal = TextEditingController(
    text: _num(widget.initial.focalMin),
  );
  late final _focalTo = TextEditingController(
    text: _num(widget.initial.focalMax),
  );
  late final _wide = TextEditingController(
    text: _num(widget.initial.maxAperture.first.aperture),
  );
  late final _long = TextEditingController(
    text: _num(widget.initial.maxAperture.last.aperture),
  );
  late final _min = TextEditingController(
    text: _num(widget.initial.minAperture),
  );
  late StepSize _step = widget.initial.apertureStep;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _make,
      _name,
      _mount,
      _focal,
      _focalTo,
      _wide,
      _long,
      _min,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _d(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  /// Set once a valid profile is being stored: a second tap neither saves
  /// again nor pops the screen below.
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final focalMin = _d(_focal);
    final focalMax = _zoom ? _d(_focalTo) : focalMin;
    final wide = _d(_wide);
    final long = _zoom ? _d(_long) : wide;
    final min = _d(_min);
    final missing = [
      if (focalMin == null || focalMax == null) 'focal',
      if (wide == null || long == null) 'maxAperture',
      if (min == null) 'minAperture',
    ];
    if (missing.isNotEmpty) {
      setState(() => _error = '${missing.first}: must be a number');
      return;
    }
    final make = _make.text.trim();
    final name = _name.text.trim();
    final lens = Lens(
      id: widget.isNew ? slugify('$make $name') : widget.initial.id,
      make: make,
      name: name,
      mount: _mount.text.trim(),
      focalMin: focalMin!,
      focalMax: focalMax!,
      maxAperture: _zoom
          ? [ApertureAt(focalMin, wide!), ApertureAt(focalMax, long!)]
          : [ApertureAt(focalMin, wide!)],
      minAperture: min!,
      apertureStep: _step,
    );
    final Lens parsed;
    try {
      parsed = parseGear(gearToJson(lens)) as Lens;
    } on GearFormatException catch (e) {
      setState(() => _error = e.errors.first);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.gear.saveUser(parsed);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New lens' : 'Edit lens'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                EditorTextField(label: 'Make', controller: _make),
                EditorTextField(label: 'Name', controller: _name),
                EditorTextField(label: 'Mount', controller: _mount),
                MountSuggestions(
                  mounts: widget.gear.mounts,
                  controller: _mount,
                ),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Prime')),
                    ButtonSegment(value: true, label: Text('Zoom')),
                  ],
                  selected: {_zoom},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _zoom = s.first),
                ),
                const SizedBox(height: 16),
                if (_zoom) ...[
                  EditorTextField(
                    label: 'Focal length from (mm)',
                    controller: _focal,
                    number: true,
                  ),
                  EditorTextField(
                    label: 'Focal length to (mm)',
                    controller: _focalTo,
                    number: true,
                  ),
                  EditorTextField(
                    label: 'Widest aperture at wide end (f/)',
                    controller: _wide,
                    number: true,
                  ),
                  EditorTextField(
                    label: 'Widest aperture at long end (f/)',
                    controller: _long,
                    number: true,
                  ),
                ] else ...[
                  EditorTextField(
                    label: 'Focal length (mm)',
                    controller: _focal,
                    number: true,
                  ),
                  EditorTextField(
                    label: 'Widest aperture (f/)',
                    controller: _wide,
                    number: true,
                  ),
                ],
                EditorTextField(
                  label: 'Smallest aperture (f/)',
                  controller: _min,
                  number: true,
                ),
                const EditorSection('Aperture step'),
                SegmentedButton<StepSize>(
                  segments: const [
                    ButtonSegment(value: StepSize.full, label: Text('Full')),
                    ButtonSegment(value: StepSize.half, label: Text('Half')),
                    ButtonSegment(value: StepSize.third, label: Text('Third')),
                  ],
                  selected: {_step},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _step = s.first),
                ),
              ],
            ),
          ),
          EditorError(_error),
        ],
      ),
    );
  }
}
