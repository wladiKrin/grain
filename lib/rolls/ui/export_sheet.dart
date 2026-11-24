import 'package:material_ui/material_ui.dart';

import '../../gear/platform.dart';
import '../../gear/save.dart';
import '../export.dart';
import '../model.dart';
import '../roll_controller.dart';

Future<void> showExportSheet(
  BuildContext context, {
  required Roll roll,
  required RollController rolls,
  required GearPlatform platform,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ExportSheet(roll: roll, rolls: rolls, platform: platform),
);

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({
    required this.roll,
    required this.rolls,
    required this.platform,
  });

  final Roll roll;
  final RollController rolls;
  final GearPlatform platform;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  List<Frame>? _frames;
  bool _snapshots = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.rolls.framesOf(widget.roll.id).then((f) {
      if (mounted) setState(() => _frames = f);
    });
  }

  bool get _hasSnapshots => _frames?.any((f) => f.snapshot != null) ?? false;

  Future<void> _share() => _export(save: false);

  Future<void> _save() => _export(save: true);

  Future<void> _export({required bool save}) async {
    final frames = _frames;
    if (frames == null || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dir = await widget.platform.exportDirectory();
      final files = await exportRoll(
        widget.roll,
        frames,
        out: dir,
        store: widget.rolls.snapshots,
        withSnapshots: _snapshots && _hasSnapshots,
      );
      final paths = [for (final f in files) f.path];
      if (save) {
        final r = await widget.platform.saveFiles(paths);
        if (!mounted) return;
        switch (r) {
          case Saved(:final names):
            messenger.showSnackBar(
              SnackBar(content: Text(savedMessage(names))),
            );
            Navigator.pop(context);
          case SaveCancelled():
            setState(() => _busy = false);
          case SaveFailed(:final message):
            messenger.showSnackBar(
              SnackBar(content: Text("Couldn't save: $message")),
            );
            setState(() => _busy = false);
        }
        return;
      }
      await widget.platform.sharePaths(
        paths,
        subject: 'Roll ${widget.roll.number} · ${widget.roll.filmStock}',
      );
      if (mounted) Navigator.pop(context);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not export the roll.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Text(
              'Export roll ${widget.roll.number}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const Text(
              'A spreadsheet (CSV) and a JSON file with every exposure value.',
              textAlign: TextAlign.center,
            ),
            if (_hasSnapshots)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include snapshots (zip)'),
                value: _snapshots,
                onChanged: (v) => setState(() => _snapshots = v),
              ),
            if (_error != null) Text(_error!, textAlign: TextAlign.center),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _frames == null || _busy ? null : _save,
                    child: const Text('Save to device'),
                  ),
                ),
                Expanded(
                  child: FilledButton(
                    onPressed: _frames == null || _busy ? null : _share,
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
