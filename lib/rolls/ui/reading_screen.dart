import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../exposure/mode.dart';
import '../../exposure/stops.dart';
import '../../metering/reading.dart';
import '../../ui/theme.dart';
import '../model.dart';
import '../roll_controller.dart';
import 'roll_screen.dart' show formatNum, shortLensName;
import 'thumbnail.dart';

/// "f/5.6 · 1/125 · ISO 400" for a list row or heading.
String exposureSummary(Exposure e) => [
  if (e.aperture != null) 'f/${formatNum(e.aperture!)}',
  if (e.shutter != null) e.shutter!,
  if (e.iso != null) 'ISO ${e.iso}',
].join(' · ');

/// Wall-clock date and time of a reading, in the zone it was taken in.
String readingWhen(MaterialLocalizations loc, SavedReading r) {
  final w = r.takenAt.toUtc().add(Duration(minutes: r.utcOffsetMinutes));
  return '${loc.formatMediumDate(w)} · '
      '${loc.formatTimeOfDay(TimeOfDay(hour: w.hour, minute: w.minute), alwaysUse24HourFormat: true)}';
}

/// One saved reading: snapshot, values, location and an editable note.
class ReadingScreen extends StatefulWidget {
  const ReadingScreen({
    super.key,
    required this.rolls,
    required this.readingId,
  });

  final RollController rolls;
  final String readingId;

  @override
  State<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends State<ReadingScreen> {
  late final TextEditingController _note;
  late final AppLifecycleListener _lifecycle;
  Timer? _debounce;

  /// The note as last handed to the controller (or loaded).
  String _lastSaved = '';

  SavedReading? get _reading =>
      widget.rolls.readings.where((r) => r.id == widget.readingId).firstOrNull;

  @override
  void initState() {
    super.initState();
    _lastSaved = _reading?.note ?? '';
    _note = TextEditingController(text: _lastSaved)..addListener(_typed);
    widget.rolls.addListener(_changed);
    // A note typed just before the app is backgrounded must survive the
    // process being killed.
    _lifecycle = AppLifecycleListener(
      onInactive: _flush,
      onHide: _flush,
      onPause: _flush,
    );
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _typed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _flush);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _lifecycle.dispose();
    widget.rolls.removeListener(_changed);
    // Leaving by any route saves the note; deferred so listeners are not
    // notified while the tree is being torn down.
    final text = _note.text;
    Future.microtask(() => _save(text));
    _note.dispose();
    super.dispose();
  }

  void _flush() {
    _debounce?.cancel();
    unawaited(_save(_note.text));
  }

  Future<void> _save(String text) async {
    final r = _reading;
    if (r == null) return;
    final trimmed = text.trim();
    if (trimmed == _lastSaved.trim()) return;
    _lastSaved = text;
    await widget.rolls.updateReading(
      r.copyWith(note: () => trimmed.isEmpty ? null : trimmed),
    );
  }

  Future<bool> _confirm(String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: GrainColors.ground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: GrainColors.border),
        ),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete() async {
    if (!await _confirm('Delete this reading?', 'Delete')) return;
    _debounce?.cancel();
    await widget.rolls.deleteReading(widget.readingId);
    if (mounted) Navigator.pop(context);
  }

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

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: GrainColors.secondary, fontSize: 15),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
      ],
    ),
  );

  static String _modeLabel(MeterMode m) => switch (m) {
    MeterMode.aperturePriority => 'Aperture priority',
    MeterMode.shutterPriority => 'Shutter priority',
    MeterMode.manual => 'Manual',
  };

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    if (r == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Saved reading')),
        body: const Center(child: Text('Reading deleted')),
      );
    }
    final loc = MaterialLocalizations.of(context);
    final e = r.exposure;
    final fix = r.location;
    final lens = [
      if (e.lensName != null) shortLensName(e.lensName!),
      if (e.focal != null) '${formatNum(e.focal!)} mm',
    ].join(' · ');
    return PopScope<void>(
      onPopInvokedWithResult: (_, _) => _flush(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Saved reading')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (r.snapshot != null) ...[
                Center(
                  child: SnapshotThumb(
                    store: widget.rolls.snapshots,
                    name: r.snapshot,
                    size: 240,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                exposureSummary(e),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _line('Taken', readingWhen(loc, r)),
              _line('Camera', r.bodyName),
              if (lens.isNotEmpty) _line('Lens', lens),
              if (e.mode != null) _line('Mode', _modeLabel(e.mode!)),
              if (e.meteredEv != null)
                _line('Metered EV', e.meteredEv!.toStringAsFixed(1)),
              if (e.offset != null) _line('Offset', formatStops(e.offset!)),
              if (e.area != null)
                _line(
                  'Metering',
                  e.area == MeterArea.spot ? 'Spot' : 'Average',
                ),
              if (fix != null) ...[
                _line(
                  'Location',
                  '${fix.latitude.toStringAsFixed(4)}, '
                      '${fix.longitude.toStringAsFixed(4)}'
                      '${fix.accuracy == null ? '' : ' ± ${fix.accuracy!.round()} m'}',
                ),
                _action(
                  'Remove location',
                  () => widget.rolls.deleteReadingLocation(r.id),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: null,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              if (r.snapshot != null)
                _action(
                  'Delete snapshot',
                  () => widget.rolls.deleteReadingSnapshot(r.id),
                ),
              _action('Delete reading', _delete),
            ],
          ),
        ),
      ),
    );
  }
}
