import 'package:material_ui/material_ui.dart';

import '../../gear/gear_controller.dart';
import '../../gear/model.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';
import '../model.dart';
import '../numbering.dart';
import '../push.dart';
import '../roll_controller.dart';
import 'frame_editor.dart';
import 'roll_editor.dart';
import 'thumbnail.dart';
import '../../ui/stops_text.dart';

enum _RowAction { before, after, renumber, deleteSnapshot, delete }

enum _RollAction { edit, export, finish, delete }

/// Whole numbers without ".0".
String formatNum(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

/// "FD 50mm f/1.8" becomes "FD 50/1.8" (as [Lens.shortName]).
String shortLensName(String name) =>
    name.replaceAllMapped(RegExp(r'(\d)mm f/'), (m) => '${m[1]}/');

/// One roll: its header and every frame, newest last.
class RollScreen extends StatefulWidget {
  const RollScreen({
    super.key,
    required this.rolls,
    required this.gear,
    required this.haptics,
    required this.rollId,
    this.onExport,
  });

  final RollController rolls;
  final GearController gear;
  final Haptics haptics;
  final String rollId;
  final void Function(Roll roll)? onExport;

  @override
  State<RollScreen> createState() => _RollScreenState();
}

class _RollScreenState extends State<RollScreen> {
  GrainPalette get g => context.grain;

  List<Frame>? _frames;

  Roll? get _roll =>
      widget.rolls.rolls.where((r) => r.id == widget.rollId).firstOrNull;

  @override
  void initState() {
    super.initState();
    widget.rolls.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.rolls.removeListener(_sync);
    super.dispose();
  }

  void _sync() {
    if (_roll == null) return;
    widget.rolls.framesOf(widget.rollId).then((f) {
      if (mounted) setState(() => _frames = f);
    });
  }

  Future<bool> _confirm(String text, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: g.ground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: g.border),
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

  Future<int?> _askNumber() => showDialog<int>(
    context: context,
    builder: (c) {
      final controller = TextEditingController();
      String? error;
      return StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          backgroundColor: g.ground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: g.border),
          ),
          title: const Text('Renumber from here'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'This frame becomes',
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final n = parseFrameLabel(controller.text.trim());
                if (n == null) {
                  setState(() => error = 'Use 00, 0 or a number');
                } else {
                  Navigator.pop(c, n);
                }
              },
              child: const Text('Renumber'),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _rowAction(_RowAction a, Frame f, int i) async {
    final rolls = widget.rolls;
    switch (a) {
      case _RowAction.before:
        await rolls.insertBlank(widget.rollId, i);
      case _RowAction.after:
        await rolls.insertBlank(widget.rollId, i + 1);
      case _RowAction.renumber:
        final n = await _askNumber();
        if (n != null) await rolls.renumberFrom(widget.rollId, i, n);
      case _RowAction.deleteSnapshot:
        await rolls.deleteFrameSnapshot(widget.rollId, f.id);
      case _RowAction.delete:
        final ok = await _confirm(
          'Delete frame ${f.label}? Later frames move down by one.',
          'Delete',
        );
        if (ok) await rolls.deleteFrame(widget.rollId, f.id);
    }
  }

  Future<void> _rollAction(_RollAction a, Roll roll) async {
    final rolls = widget.rolls;
    switch (a) {
      case _RollAction.edit:
        await Navigator.push(
          context,
          MaterialPageRoute<Roll>(
            builder: (_) => RollEditorScreen(
              rolls: rolls,
              haptics: widget.haptics,
              initial: roll,
              bodies: _bodiesFor(roll),
            ),
          ),
        );
      case _RollAction.export:
        widget.onExport?.call(roll);
      case _RollAction.finish:
        if (await _confirm('Finish roll ${roll.number}?', 'Finish')) {
          await rolls.finishRoll(roll.id);
        }
      case _RollAction.delete:
        final n = _frames?.length ?? 0;
        final ok = await _confirm(
          'Delete roll ${roll.number} and its $n frames?',
          'Delete',
        );
        if (!ok) return;
        await rolls.deleteRoll(roll.id);
        if (mounted) Navigator.pop(context);
    }
  }

  /// Bodies that take the roll's film.
  List<Body> _bodiesFor(Roll roll) => [
    for (final b in widget.gear.bodies)
      if (b.format == roll.format) b,
  ];

  void _open(Roll roll, Frame f) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => FrameEditorScreen(
        rolls: widget.rolls,
        roll: roll,
        frame: f,
        bodies: _bodiesFor(roll),
        lensesFor: widget.gear.lensesFor,
      ),
    ),
  );

  Widget _header(Roll roll, List<Frame> frames, MaterialLocalizations loc) {
    final pushed = roll.pushThirds != 0;
    final dates = [
      'Started ${loc.formatMediumDate(roll.startedAt.toLocal())}',
      if (roll.finishedAt != null)
        'Finished ${loc.formatMediumDate(roll.finishedAt!.toLocal())}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roll.filmStock,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          if (pushed)
            StopsText(
              '${pushLabel(roll.pushThirds)} · exposed at ISO ${roll.exposedIso}',
              style: TextStyle(color: g.accent, fontSize: 17),
            )
          else
            Text(
              'Box speed · ISO ${roll.boxIso}',
              style: TextStyle(color: g.ink, fontSize: 17),
            ),
          const SizedBox(height: 4),
          Text(
            '${camerasLabel(roll, frames)} · ${roll.size} frames · '
            'first frame ${roll.startFrame.label}',
            style: TextStyle(color: g.secondary, fontSize: 15),
          ),
          Text(dates, style: TextStyle(color: g.secondary, fontSize: 15)),
          if (roll.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(roll.notes, style: const TextStyle(fontSize: 15)),
            ),
        ],
      ),
    );
  }

  Widget _row(
    Roll roll,
    Frame f,
    int i,
    MaterialLocalizations loc, {
    required bool multiCamera,
  }) {
    final e = f.exposure;
    final over = overrun(roll, f.number);
    final settings = [
      if (e.aperture != null) 'f/${formatNum(e.aperture!)}',
      if (e.shutter != null) e.shutter!,
    ].join(' · ');
    final lens = [
      if (e.lensName != null) shortLensName(e.lensName!),
      if (e.focal != null) '${formatNum(e.focal!)} mm',
    ].join(' · ');
    String? time;
    if (f.takenAt != null) {
      final w = f.takenAt!.toUtc().add(
        Duration(minutes: f.utcOffsetMinutes ?? 0),
      );
      time = loc.formatTimeOfDay(
        TimeOfDay(hour: w.hour, minute: w.minute),
        alwaysUse24HourFormat: true,
      );
    }
    final differs = e.iso != null && e.iso != roll.exposedIso;
    // Only a roll shot with more than one camera names each frame's.
    final detail = [
      if (multiCamera) f.bodyName,
      if (lens.isNotEmpty) lens,
      ?time,
    ].join(' · ');
    return InkWell(
      onTap: () => _open(roll, f),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          child: Row(
            children: [
              SnapshotThumb(store: widget.rolls.snapshots, name: f.snapshot),
              const SizedBox(width: 12),
              SizedBox(
                width: 52,
                child: Row(
                  children: [
                    Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (over > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          '+$over',
                          style: TextStyle(fontSize: 12, color: g.accent),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.isBlank)
                      Text(
                        'Blank',
                        style: TextStyle(color: g.faded, fontSize: 16),
                      )
                    else if (settings.isNotEmpty)
                      Text(settings, style: const TextStyle(fontSize: 16)),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: TextStyle(color: g.secondary, fontSize: 13),
                      ),
                    if (e.iso != null)
                      Semantics(
                        container: true,
                        label: isoSemantics('${e.iso}', differs: differs),
                        excludeSemantics: true,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (differs)
                              Container(
                                width: 7,
                                height: 7,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: g.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              'ISO ${e.iso}',
                              style: TextStyle(
                                color: g.secondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (f.note != null && f.note!.isNotEmpty)
                      Text(
                        f.note!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_RowAction>(
                tooltip: 'Frame ${f.label} actions',
                color: g.ground,
                elevation: 0,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onSelected: (a) => _rowAction(a, f, i),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _RowAction.before,
                    child: Text('Insert blank before'),
                  ),
                  const PopupMenuItem(
                    value: _RowAction.after,
                    child: Text('Insert blank after'),
                  ),
                  const PopupMenuItem(
                    value: _RowAction.renumber,
                    child: Text('Renumber from here…'),
                  ),
                  if (f.snapshot != null)
                    const PopupMenuItem(
                      value: _RowAction.deleteSnapshot,
                      child: Text('Delete snapshot'),
                    ),
                  const PopupMenuItem(
                    value: _RowAction.delete,
                    child: Text('Delete frame'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roll = _roll;
    if (roll == null) return const Scaffold();
    final loc = MaterialLocalizations.of(context);
    final frames = _frames ?? const <Frame>[];
    final multi = isMultiCamera(roll, frames);
    return Scaffold(
      appBar: AppBar(
        title: Text('Roll ${roll.number}'),
        actions: [
          PopupMenuButton<_RollAction>(
            tooltip: 'Roll actions',
            color: g.ground,
            elevation: 0,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onSelected: (a) => _rollAction(a, roll),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _RollAction.edit,
                child: Text('Edit roll'),
              ),
              PopupMenuItem(
                value: _RollAction.export,
                enabled: widget.onExport != null,
                child: const Text('Export'),
              ),
              if (roll.isActive)
                const PopupMenuItem(
                  value: _RollAction.finish,
                  child: Text('Finish roll'),
                ),
              const PopupMenuItem(
                value: _RollAction.delete,
                child: Text('Delete roll'),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: frames.length + 1,
        itemBuilder: (context, i) => i == 0
            ? _header(roll, frames, loc)
            : _row(roll, frames[i - 1], i - 1, loc, multiCamera: multi),
      ),
    );
  }
}
