import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../ui/theme.dart';
import '../codec.dart';
import '../gear_controller.dart';
import '../ids.dart';
import '../model.dart';
import 'form_bits.dart';

const _standardShutter = [
  '1/8000', '1/4000', '1/2000', '1/1000', '1/500', '1/250', '1/125', '1/60',
  '1/30', '1/15', '1/8', '1/4', '1/2', '1', '2', '4', '8', '15', '30', //
  'B', 'T',
];

/// A blank body: 135, 1/1000 to 1 s and B.
Body newBodyTemplate() => const Body(
  id: '',
  make: '',
  model: '',
  mount: '',
  format: FilmFormat.f135,
  frames: 36,
  shutter: [
    '1/1000', '1/500', '1/250', '1/125', '1/60', '1/30', '1/15', '1/8', //
    '1/4', '1/2', '1', 'B',
  ],
);

double _markSeconds(String m) {
  if (m == 'B' || m == 'T') return double.infinity;
  if (m.startsWith('1/')) return 1 / (double.tryParse(m.substring(2)) ?? 1);
  return double.tryParse(m) ?? double.infinity;
}

class BodyEditorScreen extends StatefulWidget {
  const BodyEditorScreen({
    super.key,
    required this.gear,
    required this.initial,
    required this.isNew,
  });

  final GearController gear;
  final Body initial;
  final bool isNew;

  @override
  State<BodyEditorScreen> createState() => _BodyEditorScreenState();
}

class _BodyEditorScreenState extends State<BodyEditorScreen> {
  late final _make = TextEditingController(text: widget.initial.make);
  late final _model = TextEditingController(text: widget.initial.model);
  late final _mount = TextEditingController(text: widget.initial.mount);
  late final _frames = TextEditingController(text: '${widget.initial.frames}');
  late FilmFormat _format = widget.initial.format;
  late final Set<String> _shutter = {...widget.initial.shutter};
  late final List<String> _marks = _allMarks();
  late final Map<int, String> _isoItems = {
    for (final v in isoScale()) int.parse(v.label): v.label,
  };
  late int _isoMin = _nearestIso(widget.initial.isoMin);
  late int _isoMax = _nearestIso(widget.initial.isoMax);
  String? _error;

  List<String> _allMarks() {
    final extra = [
      for (final m in widget.initial.shutter)
        if (!_standardShutter.contains(m)) m,
    ];
    return [..._standardShutter, ...extra]
      ..sort((a, b) => _markSeconds(a).compareTo(_markSeconds(b)));
  }

  int _nearestIso(int v) =>
      _isoItems.keys.reduce((a, b) => (a - v).abs() <= (b - v).abs() ? a : b);

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _mount.dispose();
    _frames.dispose();
    super.dispose();
  }

  void _onFormat(FilmFormat f) {
    setState(() {
      if (_frames.text.trim() == '${_format.defaultFrames}') {
        _frames.text = '${f.defaultFrames}';
      }
      _format = f;
    });
  }

  /// Set once a valid profile is being stored: a second tap neither saves
  /// again nor pops the screen below.
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final make = _make.text.trim();
    final model = _model.text.trim();
    final frames = int.tryParse(_frames.text.trim());
    if (frames == null) {
      setState(() => _error = 'frames: must be an integer from 1 to 200');
      return;
    }
    final body = Body(
      id: widget.isNew ? slugify('$make $model') : widget.initial.id,
      make: make,
      model: model,
      mount: _mount.text.trim(),
      format: _format,
      frames: frames,
      shutter: [
        for (final m in _marks)
          if (_shutter.contains(m)) m,
      ],
      isoMin: _isoMin,
      isoMax: _isoMax,
    );
    final Body parsed;
    try {
      parsed = parseGear(gearToJson(body)) as Body;
    } on GearFormatException catch (e) {
      setState(() => _error = e.errors.first);
      return;
    }
    setState(() => _saving = true);
    final saved = await widget.gear.saveUser(parsed);
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New body' : 'Edit body'),
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
                EditorTextField(label: 'Model', controller: _model),
                EditorTextField(label: 'Mount', controller: _mount),
                MountSuggestions(
                  mounts: widget.gear.mounts,
                  controller: _mount,
                ),
                EditorDropdown<FilmFormat>(
                  label: 'Format',
                  value: _format,
                  items: {for (final f in FilmFormat.values) f: f.label},
                  onChanged: _onFormat,
                ),
                EditorTextField(label: 'Frames', controller: _frames),
                const EditorSection('Shutter speeds'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in _marks)
                      FilterChip(
                        label: Text(m),
                        selected: _shutter.contains(m),
                        showCheckmark: false,
                        selectedColor: GrainColors.ink,
                        backgroundColor: GrainColors.ground,
                        side: const BorderSide(color: GrainColors.border),
                        labelStyle: TextStyle(
                          color: _shutter.contains(m)
                              ? GrainColors.ground
                              : GrainColors.ink,
                        ),
                        onSelected: (on) => setState(
                          () => on ? _shutter.add(m) : _shutter.remove(m),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                EditorDropdown<int>(
                  label: 'ISO from',
                  value: _isoMin,
                  items: _isoItems,
                  onChanged: (v) => setState(() => _isoMin = v),
                ),
                EditorDropdown<int>(
                  label: 'ISO to',
                  value: _isoMax,
                  items: _isoItems,
                  onChanged: (v) => setState(() => _isoMax = v),
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
