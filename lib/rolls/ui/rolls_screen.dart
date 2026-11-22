import 'package:material_ui/material_ui.dart';

import '../../gear/gear_controller.dart';
import '../../ui/haptics.dart';
import '../../ui/theme.dart';
import '../model.dart';
import '../push.dart';
import '../roll_controller.dart';
import 'reading_screen.dart';
import 'roll_editor.dart';
import 'roll_screen.dart' show RollScreen, shortLensName;
import 'thumbnail.dart';
import '../../ui/stops_text.dart';

/// Rolls and saved readings, in two tabs.
class RollsScreen extends StatefulWidget {
  const RollsScreen({
    super.key,
    required this.rolls,
    required this.gear,
    required this.haptics,
    this.onExport,
  });

  final RollController rolls;
  final GearController gear;
  final Haptics haptics;
  final void Function(Roll roll)? onExport;

  @override
  State<RollsScreen> createState() => _RollsScreenState();
}

class _RollsScreenState extends State<RollsScreen> {
  GrainPalette get g => context.grain;

  final Set<String> _requested = {};

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

  /// Loads the frames of rolls not cached yet, once each; later counts come
  /// from the controller's cache.
  void _sync() {
    if (mounted) setState(() {});
    for (final r in widget.rolls.rolls) {
      if (widget.rolls.frameCount(r.id) == null && _requested.add(r.id)) {
        widget.rolls.framesOf(r.id).then((_) {
          if (mounted) setState(() {});
        });
      }
    }
  }

  void _newRoll() => Navigator.push(
    context,
    MaterialPageRoute<Roll>(
      builder: (_) => RollEditorScreen(
        rolls: widget.rolls,
        haptics: widget.haptics,
        body: widget.gear.body,
      ),
    ),
  );

  void _openRoll(Roll r) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => RollScreen(
        rolls: widget.rolls,
        gear: widget.gear,
        haptics: widget.haptics,
        rollId: r.id,
        onExport: widget.onExport,
      ),
    ),
  );

  void _openReading(SavedReading r) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (_) => ReadingScreen(rolls: widget.rolls, readingId: r.id),
    ),
  );

  Widget _empty(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: g.secondary, fontSize: 16),
      ),
    ),
  );

  Widget _rollRow(Roll r, MaterialLocalizations loc) {
    final count = widget.rolls.frameCount(r.id);
    final detail = [
      if (r.pushThirds != 0) pushLabel(r.pushThirds),
      r.bodyName,
      '${count ?? '—'}/${r.size}',
    ].join(' · ');
    return InkWell(
      onTap: () => _openRoll(r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Roll ${r.number} · ${r.filmStock}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    StopsText(
                      detail,
                      style: TextStyle(color: g.secondary, fontSize: 14),
                    ),
                    Text(
                      loc.formatMediumDate(r.startedAt.toLocal()),
                      style: TextStyle(color: g.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (r.isActive)
                Text(
                  'Active',
                  style: TextStyle(
                    color: g.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readingRow(SavedReading r, MaterialLocalizations loc) {
    final e = r.exposure;
    final sub = [
      r.bodyName,
      if (e.lensName != null) shortLensName(e.lensName!),
    ].join(' · ');
    return InkWell(
      onTap: () => _openReading(r),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              SnapshotThumb(store: widget.rolls.snapshots, name: r.snapshot),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exposureSummary(e),
                      style: const TextStyle(fontSize: 17),
                    ),
                    Text(
                      sub,
                      style: TextStyle(color: g.secondary, fontSize: 14),
                    ),
                    Text(
                      readingWhen(loc, r),
                      style: TextStyle(color: g.secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final rolls = widget.rolls.rolls;
    final readings = widget.rolls.readings;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Rolls'),
          actions: [
            IconButton(
              tooltip: 'New roll',
              icon: const Icon(Icons.add),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: _newRoll,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Rolls'),
              Tab(text: 'Saved readings'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            rolls.isEmpty
                ? _empty('No rolls yet. Start one from the meter or with +.')
                : ListView.builder(
                    itemCount: rolls.length,
                    itemBuilder: (_, i) => _rollRow(rolls[i], loc),
                  ),
            readings.isEmpty
                ? _empty(
                    "No saved readings. With no roll loaded, the meter's "
                    'button saves one.',
                  )
                : ListView.builder(
                    itemCount: readings.length,
                    itemBuilder: (_, i) => _readingRow(readings[i], loc),
                  ),
          ],
        ),
      ),
    );
  }
}
