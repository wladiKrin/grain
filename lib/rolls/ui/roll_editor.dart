import 'package:material_ui/material_ui.dart';

import '../../exposure/scales.dart';
import '../../exposure/stops.dart';
import '../../gear/model.dart';
import '../../gear/ui/form_bits.dart';
import '../../ui/dial/swipe_dial.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';
import '../film_stocks.dart';
import '../latitude.dart';
import '../model.dart';
import '../push.dart';
import '../roll_controller.dart';
import '../../ui/stops_text.dart';

const _sizeChips = [12, 24, 36, 72];

const _keptBody = '\u0000kept';

/// −9 … +9 thirds, labelled in stops.
final List<ScaleValue> _pushScale = [
  for (var t = -9; t <= 9; t++)
    ScaleValue(formatStops(t / 3), t / 3, t % 3 == 0),
];

/// −5 … 0 stops in halves.
final List<ScaleValue> _underScale = [
  for (var h = latitudeUnderHalvesMin; h <= 0; h++)
    ScaleValue(formatHalfStops(h), h / 2, h % 2 == 0),
];

/// 0 … +6 stops in halves.
final List<ScaleValue> _overScale = [
  for (var h = 0; h <= latitudeOverHalvesMax; h++)
    ScaleValue(formatHalfStops(h), h / 2, h % 2 == 0),
];

/// Start a roll (initial == null) or edit one. Pops with the saved [Roll];
/// null on back.
class RollEditorScreen extends StatefulWidget {
  const RollEditorScreen({
    super.key,
    required this.rolls,
    required this.haptics,
    this.body,
    this.initial,
    this.bodies = const [],
  });

  final RollController rolls;
  final Haptics haptics;

  /// Body of a new roll.
  final Body? body;

  /// The roll being edited.
  final Roll? initial;

  /// Bodies the edited roll's camera can be corrected to (its format).
  final List<Body> bodies;

  @override
  State<RollEditorScreen> createState() => _RollEditorScreenState();
}

class _RollEditorScreenState extends State<RollEditorScreen> {
  GrainPalette get g => context.grain;

  late final TextEditingController _film;
  final _filmFocus = FocusNode();
  late final TextEditingController _notes;
  late final TextEditingController _custom;
  late FilmType _type;
  late int _box;
  int _push = 0;
  int? _latUnder, _latOver;
  late int _size;
  late bool _customSize;
  late StartFrame _start;

  /// The edited roll's camera: a body id, or [_keptBody] for its own.
  String _bodyKey = _keptBody;
  String? _error;
  bool _saving = false;

  Roll? get _editing => widget.initial;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    final last = e ?? widget.rolls.latest;
    _film = TextEditingController(text: last?.filmStock ?? '');
    _type = last?.filmType ?? FilmType.colorNeg;
    _box = last?.boxIso ?? 400;
    // A new roll never inherits the last roll's push.
    _push = e?.pushThirds ?? 0;
    _latUnder = e?.latitudeUnderHalves;
    _latOver = e?.latitudeOverHalves;
    _size = e?.size ?? widget.body?.frames ?? 36;
    _customSize = !_sizeChips.contains(_size);
    _custom = TextEditingController(text: '$_size');
    _start = last?.startFrame ?? StartFrame.one;
    _notes = TextEditingController(text: e?.notes ?? '');
    final id = e?.bodyId;
    if (id != null && widget.bodies.any((b) => b.id == id)) _bodyKey = id;
  }

  @override
  void dispose() {
    _film.dispose();
    _filmFocus.dispose();
    _notes.dispose();
    _custom.dispose();
    super.dispose();
  }

  String get _newBodyName {
    final b = widget.body;
    return b == null ? 'No camera' : '${b.make} ${b.model}';
  }

  FilmLatitude get _default => FilmLatitude.forType(_type);
  int get _underHalves => _latUnder ?? (_default.under * 2).round();
  int get _overHalves => _latOver ?? (_default.over * 2).round();

  int? get _exposed => exposedIsoFor(_box, _push);

  int? get _chosenSize {
    if (!_customSize) return _size;
    final n = int.tryParse(_custom.text.trim());
    return n != null && n >= 1 && n <= 200 ? n : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    final film = _film.text.trim();
    if (film.isEmpty) {
      setState(() => _error = 'Film: enter a film stock.');
      return;
    }
    if (_exposed == null) {
      setState(
        () => _error = 'Push or pull is out of range for this box speed.',
      );
      return;
    }
    final size = _chosenSize;
    if (size == null) {
      setState(() => _error = 'Size: a whole number from 1 to 200.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Roll saved;
      final e = _editing;
      if (e == null) {
        saved = await widget.rolls.startRoll(
          filmStock: film,
          filmType: _type,
          boxIso: _box,
          pushThirds: _push,
          body: widget.body,
          size: size,
          startFrame: _start,
          notes: _notes.text.trim(),
          latitudeUnderHalves: _latUnder,
          latitudeOverHalves: _latOver,
        );
      } else {
        // Whatever happened to the roll since the editor opened (it may have
        // been finished) stays; only the form's fields are written.
        final current = widget.rolls.rolls.where((r) => r.id == e.id);
        var base = current.isEmpty ? e : current.first;
        final body = widget.bodies.where((b) => b.id == _bodyKey).firstOrNull;
        // A new camera here corrects the roll's (see RollController.updateRoll).
        if (body != null && body.id != e.bodyId) {
          base = base.copyWith(
            bodyId: () => body.id,
            bodyMake: body.make,
            bodyModel: body.model,
          );
        }
        saved = base.copyWith(
          filmStock: film,
          filmType: _type,
          boxIso: _box,
          pushThirds: _push,
          size: size,
          startFrame: _start,
          notes: _notes.text.trim(),
          latitudeUnderHalves: () => _latUnder,
          latitudeOverHalves: () => _latOver,
        );
        await widget.rolls.updateRoll(saved);
      }
      if (mounted) Navigator.pop(context, saved);
    } catch (err) {
      if (mounted) setState(() => _error = 'Could not save: $err');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ButtonStyle get _segStyle => SegmentedButton.styleFrom(
    backgroundColor: g.ground,
    foregroundColor: g.ink,
    selectedBackgroundColor: g.ink,
    selectedForegroundColor: g.ground,
    side: BorderSide(color: g.border),
    minimumSize: const Size(44, 48),
    padding: const EdgeInsets.symmetric(horizontal: 6),
  );

  Widget _segLabel(String s) => Text(
    s,
    textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 13),
  );

  Widget _filmField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: RawAutocomplete<FilmStock>(
      textEditingController: _film,
      focusNode: _filmFocus,
      displayStringForOption: (f) => f.name,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<FilmStock>.empty();
        return filmStocks.where(
          (f) =>
              f.name.toLowerCase().contains(q) ||
              f.short.toLowerCase().contains(q),
        );
      },
      onSelected: (f) => setState(() {
        _type = f.type;
        _box = f.iso;
      }),
      fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
        controller: controller,
        focusNode: focus,
        textCapitalization: TextCapitalization.words,
        decoration: editorDecoration(context, 'Film'),
        onChanged: (_) => setState(() {}),
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: g.ground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: g.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final f in options)
                  InkWell(
                    onTap: () => onSelected(f),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(f.name),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => ChoiceChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    selectedColor: g.ink,
    backgroundColor: g.ground,
    side: BorderSide(color: g.border),
    labelStyle: TextStyle(color: selected ? g.ground : g.ink),
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    final e = _editing;
    final active = widget.rolls.active;
    final finishes = e == null && active != null;
    final exposed = _exposed;
    final isoItems = <int, String>{
      for (final v in isoScale()) int.parse(v.label): v.label,
    };
    isoItems.putIfAbsent(_box, () => '$_box');
    return Scaffold(
      appBar: AppBar(
        title: Text(e == null ? 'Start roll' : 'Edit roll'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
            onPressed: _saving ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _filmField(),
            const EditorSection('Type'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<FilmType>(
                showSelectedIcon: false,
                style: _segStyle,
                segments: [
                  for (final t in FilmType.values)
                    ButtonSegment(value: t, label: _segLabel(t.label)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
            ),
            EditorDropdown<int>(
              label: 'Box speed',
              value: _box,
              items: isoItems,
              onChanged: (v) => setState(() => _box = v),
            ),
            const EditorSection('Push / pull'),
            SwipeDial(
              values: _pushScale,
              index: _push + 9,
              valueFontSize: 40,
              haptics: widget.haptics,
              onChanged: (i) => setState(() => _push = i - 9),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                exposed == null
                    ? 'Out of range (ISO 6–12800)'
                    : 'Exposed at ISO $exposed',
                style: TextStyle(color: g.accent, fontSize: 16),
              ),
            ),
            const EditorSection('Latitude'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Under'),
                      SwipeDial(
                        values: _underScale,
                        index: _underHalves - latitudeUnderHalvesMin,
                        valueFontSize: 32,
                        haptics: widget.haptics,
                        onChanged: (i) => setState(
                          () => _latUnder = i + latitudeUnderHalvesMin,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Over'),
                      SwipeDial(
                        values: _overScale,
                        index: _overHalves,
                        valueFontSize: 32,
                        haptics: widget.haptics,
                        onChanged: (i) => setState(() => _latOver = i),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _latUnder == null && _latOver == null
                  ? StopsText(
                      'Default for ${_type.label}: '
                      '${formatHalfStops(_underHalves)} to '
                      '${formatHalfStops(_overHalves)}',
                      style: TextStyle(color: g.secondary),
                    )
                  : Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 48),
                        ),
                        onPressed: () => setState(() {
                          _latUnder = null;
                          _latOver = null;
                        }),
                        child: const Text('Use film default'),
                      ),
                    ),
            ),
            const EditorSection('Body'),
            if (e != null && widget.bodies.isNotEmpty)
              EditorDropdown<String>(
                label: 'Camera',
                value: _bodyKey,
                items: {
                  for (final b in widget.bodies) b.id: b.displayName,
                  if (_bodyKey == _keptBody) _keptBody: e.bodyName,
                },
                onChanged: (k) => setState(() => _bodyKey = k),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  e?.bodyName ?? _newBodyName,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const EditorSection('Frames'),
            Wrap(
              spacing: 8,
              children: [
                for (final n in _sizeChips)
                  _chip(
                    '$n',
                    !_customSize && _size == n,
                    () => setState(() {
                      _customSize = false;
                      _size = n;
                    }),
                  ),
                _chip(
                  'Custom',
                  _customSize,
                  () => setState(() {
                    _customSize = true;
                    _custom.text = '$_size';
                  }),
                ),
              ],
            ),
            if (_customSize) ...[
              const SizedBox(height: 12),
              EditorTextField(
                label: 'Custom size',
                controller: _custom,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const EditorSection('First frame'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<StartFrame>(
                showSelectedIcon: false,
                style: _segStyle,
                segments: [
                  for (final s in StartFrame.values)
                    ButtonSegment(value: s, label: _segLabel(s.label)),
                ],
                selected: {_start},
                onSelectionChanged: (s) => setState(() => _start = s.first),
              ),
            ),
            const SizedBox(height: 4),
            EditorTextField(label: 'Notes', controller: _notes),
            if (finishes)
              Text(
                'Saving finishes Roll ${active.number}.',
                style: TextStyle(color: g.secondary),
              ),
            EditorError(_error),
          ],
        ),
      ),
    );
  }
}
