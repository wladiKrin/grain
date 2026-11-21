import 'package:material_ui/material_ui.dart';

import '../../exposure/mode.dart';
import '../../exposure/scales.dart';
import '../../exposure/stops.dart';
import '../../gear/model.dart';
import '../../gear/ui/form_bits.dart';
import '../../metering/reading.dart';
import '../../ui/theme.dart';
import '../model.dart';
import '../roll_controller.dart';
import 'thumbnail.dart';

const _noLens = '';
const _keptLens = '\u0000kept';

String _num(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

double? _decimal(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

/// `1/N`, `N`, `N"` or `B` → the stored label (`1/N`, `N"`, `B`); null when
/// it is none of these.
String? normaliseShutter(String raw) {
  final s = raw.trim().replaceAll('”', '"');
  if (s.toUpperCase() == 'B') return 'B';
  final frac = RegExp(r'^1/(\d{1,6})$').firstMatch(s);
  if (frac != null) {
    final n = int.parse(frac[1]!);
    return n > 0 ? '1/$n' : null;
  }
  final whole = RegExp(r'^(\d+(?:[.,]\d+)?)"?$').firstMatch(s);
  if (whole == null) return null;
  final v = double.parse(whole[1]!.replaceAll(',', '.'));
  return v > 0 && v <= 3600 ? '${_num(v)}"' : null;
}

/// Edits one frame; pops after saving.
class FrameEditorScreen extends StatefulWidget {
  const FrameEditorScreen({
    super.key,
    required this.rolls,
    required this.roll,
    required this.frame,
    required this.lenses,
  });

  final RollController rolls;
  final Roll roll;
  final Frame frame;

  /// Lenses for the roll body's mount.
  final List<Lens> lenses;

  @override
  State<FrameEditorScreen> createState() => _FrameEditorScreenState();
}

class _FrameEditorScreenState extends State<FrameEditorScreen> {
  late Frame _frame;
  late final TextEditingController _aperture;
  late final TextEditingController _shutter;
  late final TextEditingController _iso;
  late final TextEditingController _focal;
  late final TextEditingController _note;
  late String _lensKey;
  MeterMode? _mode;
  DateTime? _takenAt;
  late int _offset;
  bool _saving = false;
  String? _saveError;

  Exposure get _e => widget.frame.exposure;

  @override
  void initState() {
    super.initState();
    _frame = widget.frame;
    final e = _e;
    _aperture = TextEditingController(
      text: e.aperture == null ? '' : _num(e.aperture!),
    );
    _shutter = TextEditingController(text: e.shutter ?? '');
    _iso = TextEditingController(text: e.iso == null ? '' : '${e.iso}');
    _focal = TextEditingController(text: e.focal == null ? '' : _num(e.focal!));
    _note = TextEditingController(text: _frame.note ?? '');
    _mode = e.mode;
    _takenAt = _frame.takenAt;
    _offset =
        _frame.utcOffsetMinutes ?? DateTime.now().timeZoneOffset.inMinutes;
    if (e.lensId != null && widget.lenses.any((l) => l.id == e.lensId)) {
      _lensKey = e.lensId!;
    } else if (e.lensId != null || e.lensName != null) {
      _lensKey = _keptLens;
    } else {
      _lensKey = _noLens;
    }
  }

  @override
  void dispose() {
    _aperture.dispose();
    _shutter.dispose();
    _iso.dispose();
    _focal.dispose();
    _note.dispose();
    super.dispose();
  }

  // ---- validation --------------------------------------------------------

  String? get _apertureError {
    final t = _aperture.text.trim();
    if (t.isEmpty) return null;
    final v = _decimal(t);
    return v != null && v >= 0.5 && v <= 128
        ? null
        : 'Aperture: 0.5 to 128, e.g. 5.6';
  }

  String? get _shutterError {
    final t = _shutter.text.trim();
    if (t.isEmpty) return null;
    return normaliseShutter(t) != null ? null : 'Shutter: 1/125, 2, 2" or B';
  }

  String? get _isoError {
    final t = _iso.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return v != null && v >= 1 && v <= 25600 ? null : 'ISO: 1 to 25600';
  }

  String? get _focalError {
    final t = _focal.text.trim();
    if (t.isEmpty) return null;
    final v = _decimal(t);
    return v != null && v > 0 && v <= 2000 ? null : 'Focal length: in mm';
  }

  bool get _valid =>
      _apertureError == null &&
      _shutterError == null &&
      _isoError == null &&
      _focalError == null;

  // ---- date and time -----------------------------------------------------

  /// The frame's wall-clock time, as a UTC-flagged DateTime.
  DateTime get _wall => _takenAt!.toUtc().add(Duration(minutes: _offset));

  void _setWall(DateTime w) => _takenAt = DateTime.utc(
    w.year,
    w.month,
    w.day,
    w.hour,
    w.minute,
  ).subtract(Duration(minutes: _offset));

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final w = _takenAt == null ? now : _wall;
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime(w.year, w.month, w.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (d == null || !mounted) return;
    setState(
      () => _setWall(DateTime.utc(d.year, d.month, d.day, w.hour, w.minute)),
    );
  }

  Future<void> _pickTime() async {
    final w = _takenAt == null ? DateTime.now() : _wall;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: w.hour, minute: w.minute),
    );
    if (t == null || !mounted) return;
    setState(
      () => _setWall(DateTime.utc(w.year, w.month, w.day, t.hour, t.minute)),
    );
  }

  // ---- save --------------------------------------------------------------

  Exposure _exposure() {
    var e = _e;
    final ap = _decimal(_aperture.text);
    final label = normaliseShutter(_shutter.text);
    final iso = int.tryParse(_iso.text.trim());
    final focal = _decimal(_focal.text);
    final keepTime = e.exposureTime;
    e = e.copyWith(
      mode: () => _mode,
      aperture: () => _aperture.text.trim().isEmpty ? null : ap,
      shutter: () => label,
      exposureTime: () => label == null
          ? null
          : label == 'B'
          ? keepTime
          : nominalValue(label),
      iso: () => _iso.text.trim().isEmpty ? null : iso,
      focal: () => _focal.text.trim().isEmpty ? null : focal,
    );
    if (_lensKey == _noLens) {
      e = e.copyWith(
        lensId: () => null,
        lensMake: () => null,
        lensName: () => null,
      );
    } else if (_lensKey != _keptLens) {
      final l = widget.lenses.firstWhere((l) => l.id == _lensKey);
      e = e.copyWith(
        lensId: () => l.id,
        lensMake: () => l.make,
        lensName: () => l.name,
      );
    }
    return e;
  }

  Future<void> _save() async {
    if (_saving || !_valid) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final note = _note.text.trim();
      await widget.rolls.updateFrame(
        _frame.copyWith(
          exposure: _exposure(),
          takenAt: () => _takenAt,
          utcOffsetMinutes: () => _takenAt == null ? null : _offset,
          note: () => note.isEmpty ? null : note,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (err) {
      if (mounted) setState(() => _saveError = 'Could not save: $err');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeLocation() async {
    await widget.rolls.deleteFrameLocation(widget.roll.id, _frame.id);
    if (mounted) setState(() => _frame = _frame.copyWith(location: () => null));
  }

  Future<void> _deleteSnapshot() async {
    await widget.rolls.deleteFrameSnapshot(widget.roll.id, _frame.id);
    if (mounted) setState(() => _frame = _frame.copyWith(snapshot: () => null));
  }

  // ---- widgets -----------------------------------------------------------

  Widget _field(
    String label,
    TextEditingController c,
    String? error, {
    bool number = false,
    bool wholeNumber = false,
    TextCapitalization caps = TextCapitalization.none,
    int? maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      textCapitalization: caps,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: !wholeNumber)
          : TextInputType.text,
      decoration: editorDecoration(label).copyWith(errorText: error),
      onChanged: (_) => setState(() {}),
    ),
  );

  String? get _measured {
    final e = _e;
    final parts = [
      if (e.meteredEv != null) 'Metered EV ${e.meteredEv!.toStringAsFixed(1)}',
      if (e.offset != null) 'offset ${formatStops(e.offset!)}',
      if (e.area != null) e.area == MeterArea.spot ? 'spot' : 'average',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String _lensLabel(Lens l) => l.name;

  Widget _action(String label, VoidCallback onTap) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 48),
        foregroundColor: GrainColors.accent,
      ),
      onPressed: onTap,
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final lenses = <String, String>{
      _noLens: 'No lens',
      for (final l in widget.lenses) l.id: _lensLabel(l),
      if (_lensKey == _keptLens) _keptLens: _e.lensName ?? 'Unknown lens',
    };
    final fix = _frame.location;
    final measured = _measured;
    final wall = _takenAt == null ? null : _wall;
    return Scaffold(
      appBar: AppBar(
        title: Text('Frame ${_frame.label}'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
            onPressed: _valid && !_saving ? _save : null,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Aperture', _aperture, _apertureError, number: true),
            _field('Shutter', _shutter, _shutterError),
            _field('ISO', _iso, _isoError, number: true, wholeNumber: true),
            EditorDropdown<String>(
              label: 'Lens',
              value: lenses.containsKey(_lensKey) ? _lensKey : _noLens,
              items: lenses,
              onChanged: (k) => setState(() {
                _lensKey = k;
                if (k != _noLens && k != _keptLens) {
                  final l = widget.lenses.firstWhere((l) => l.id == k);
                  if (!l.isZoom) _focal.text = _num(l.focalMin);
                }
              }),
            ),
            _field('Focal length (mm)', _focal, _focalError, number: true),
            const EditorSection('Mode'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SegmentedButton<MeterMode>(
                showSelectedIcon: false,
                emptySelectionAllowed: true,
                style: SegmentedButton.styleFrom(
                  backgroundColor: GrainColors.ground,
                  foregroundColor: GrainColors.ink,
                  selectedBackgroundColor: GrainColors.ink,
                  selectedForegroundColor: GrainColors.ground,
                  side: const BorderSide(color: GrainColors.border),
                  minimumSize: const Size(44, 48),
                ),
                segments: const [
                  ButtonSegment(
                    value: MeterMode.aperturePriority,
                    label: Text('A'),
                  ),
                  ButtonSegment(
                    value: MeterMode.shutterPriority,
                    label: Text('S'),
                  ),
                  ButtonSegment(value: MeterMode.manual, label: Text('M')),
                ],
                selected: {?_mode},
                onSelectionChanged: (s) =>
                    setState(() => _mode = s.isEmpty ? null : s.first),
              ),
            ),
            const EditorSection('Taken'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      foregroundColor: GrainColors.ink,
                      side: const BorderSide(color: GrainColors.border),
                    ),
                    onPressed: _pickDate,
                    child: Text(
                      wall == null ? 'Set date' : loc.formatMediumDate(wall),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(44, 48),
                      foregroundColor: GrainColors.ink,
                      side: const BorderSide(color: GrainColors.border),
                    ),
                    onPressed: _pickTime,
                    child: Text(
                      wall == null
                          ? 'Set time'
                          : loc.formatTimeOfDay(
                              TimeOfDay(hour: wall.hour, minute: wall.minute),
                              alwaysUse24HourFormat: true,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _field('Note', _note, null, caps: TextCapitalization.sentences),
            if (measured != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  measured,
                  style: const TextStyle(
                    color: GrainColors.secondary,
                    fontSize: 15,
                  ),
                ),
              ),
            if (fix != null) ...[
              const EditorSection('Location'),
              Text(
                '${fix.latitude.toStringAsFixed(4)}, '
                '${fix.longitude.toStringAsFixed(4)}'
                '${fix.accuracy == null ? '' : ' ± ${fix.accuracy!.round()} m'}',
                style: const TextStyle(fontSize: 16),
              ),
              _action('Remove location', _removeLocation),
            ],
            if (_frame.snapshot != null) ...[
              const EditorSection('Snapshot'),
              SnapshotThumb(
                store: widget.rolls.snapshots,
                name: _frame.snapshot,
                size: 240,
              ),
              _action('Delete snapshot', _deleteSnapshot),
            ],
            EditorError(_saveError),
          ],
        ),
      ),
    );
  }
}
