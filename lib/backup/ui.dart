import 'package:material_ui/material_ui.dart';

import '../gear/gear_controller.dart';
import '../gear/platform.dart';
import '../rolls/roll_controller.dart';
import '../settings/settings.dart';
import '../ui/theme.dart';
import 'backup.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `21 Nov 2026`.
String backupDateLabel(DateTime d) =>
    '${d.day} ${_months[d.month - 1]} ${d.year}';

String _n(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// `Import 3 rolls, 12 saved readings and 2 profiles?`
String importQuestion(BackupContents c) =>
    'Import ${_n(c.rolls.length, 'roll', 'rolls')}, '
    '${_n(c.readings.length, 'saved reading', 'saved readings')} and '
    '${_n(c.profiles.length, 'profile', 'profiles')}?';

ShapeBorder _dialogShape(BuildContext context) => RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(12),
  side: BorderSide(color: context.grain.border),
);

/// Settings section: export everything into one zip, or import one.
class BackupSection extends StatefulWidget {
  const BackupSection({
    super.key,
    required this.gear,
    required this.rolls,
    required this.settings,
    required this.platform,
    required this.now,
  });

  final GearController gear;
  final RollController rolls;
  final Settings settings;
  final GearPlatform platform;
  final DateTime Function() now;

  @override
  State<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<BackupSection> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() work) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() => _run(() async {
    try {
      final now = widget.now();
      final dir = await widget.platform.exportDirectory();
      final file = await writeBackup(
        out: dir,
        gear: widget.gear,
        rolls: widget.rolls,
        settings: widget.settings,
        now: now,
      );
      await widget.platform.sharePaths([
        file.path,
      ], subject: 'Grain backup ${backupDateLabel(now)}');
    } on Object {
      await _message("Can't export", 'The backup could not be written.');
    }
  });

  Future<void> _import() => _run(() async {
    try {
      final path = await widget.platform.pickFilePath();
      if (path == null) return;
      final ImportReport? report;
      try {
        report = await _importFrom(path);
      } finally {
        await widget.platform.discardPicked(path);
      }
      if (report != null) await _message('Imported', report.summary);
    } on BackupFormatException catch (e) {
      await _message("Can't import", e.message);
    } on Object {
      await _message("Can't import", 'The file could not be imported.');
    }
  });

  /// Null when cancelled at the confirmation.
  Future<ImportReport?> _importFrom(String path) async {
    final contents = await readBackup(path);
    if (!mounted) return null;
    final useSettings = await _confirm(contents);
    if (useSettings == null) return null;
    return importBackup(
      contents,
      gear: widget.gear,
      rolls: widget.rolls,
      settings: widget.settings,
      applySettings: useSettings,
    );
  }

  /// Null when cancelled; else whether to use the file's settings.
  Future<bool?> _confirm(BackupContents c) {
    var useSettings = false;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: ctx.grain.ground,
          elevation: 0,
          shape: _dialogShape(ctx),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(importQuestion(c)),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Use the settings from the file'),
                value: useSettings,
                onChanged: (v) => setState(() => useSettings = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, useSettings),
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _message(String title, String text) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.grain.ground,
        elevation: 0,
        shape: _dialogShape(ctx),
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Text('BACKUP', style: g.label),
          Text(
            'Rolls, frames, saved readings, your gear and favorites in one '
            'zip. Importing keeps everything already here.',
            style: TextStyle(fontSize: 13, color: g.secondary),
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _export,
                  child: const Text('Export everything'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : _import,
                  child: const Text('Import everything'),
                ),
              ),
            ],
          ),
          if (_busy)
            LinearProgressIndicator(color: g.ink, backgroundColor: g.divider),
        ],
      ),
    );
  }
}
