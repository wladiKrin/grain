import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';
import '../gear_controller.dart';
import '../model.dart';
import 'body_editor.dart';
import 'form_bits.dart';
import 'lens_picker.dart';
import 'profile_tile.dart';
import 'share_sheet.dart';

/// "No camera", favorites, then every body grouped by make.
class BodyPickerScreen extends StatelessWidget {
  const BodyPickerScreen({
    super.key,
    required this.gear,
    this.onShare,
    this.onImport,
  });

  final GearController gear;
  final void Function(GearDoc doc)? onShare;
  final VoidCallback? onImport;

  Future<void> _edit(BuildContext context, Body b, {required bool isNew}) =>
      Navigator.push<Body>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              BodyEditorScreen(gear: gear, initial: b, isNew: isNew),
        ),
      );

  List<ProfileAction> _actions(BuildContext context, Body b) {
    final user = gear.isUser(b);
    final kit = kitFor(gear, b);
    return [
      if (user) ProfileAction('Edit', () => _edit(context, b, isNew: false)),
      ProfileAction(
        'Duplicate and edit',
        () => _edit(context, gear.duplicateBody(b), isNew: true),
      ),
      if (onShare != null) ...[
        ProfileAction('Share', () => onShare!(b)),
        if (kit.lenses.isNotEmpty)
          ProfileAction('Share with lenses', () => onShare!(kit)),
      ],
      if (user)
        ProfileAction('Delete', () async {
          if (await confirmDelete(context, b.displayName)) {
            await gear.deleteUser(b);
          }
        }),
    ];
  }

  Widget _tile(BuildContext context, Body b) => ProfileTile(
    title: b.displayName,
    subtitle: b.format.label,
    selected: gear.body?.id == b.id,
    favorite: gear.isFavorite(b),
    user: gear.isUser(b),
    onTap: () async {
      await gear.selectBody(b);
      if (context.mounted) Navigator.pop(context);
    },
    onToggleFavorite: () => gear.toggleFavorite(b),
    actions: _actions(context, b),
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gear,
      builder: (context, _) {
        final favorites = gear.favoriteBodies;
        final byMake = <String, List<Body>>{};
        for (final b in gear.bodies) {
          byMake.putIfAbsent(b.make, () => []).add(b);
        }
        final selected = gear.body;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Library'),
            actions: [
              if (selected != null)
                TextButton(
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LensPickerScreen(
                        gear: gear,
                        mount: selected.mount,
                        onShare: onShare,
                        onImport: onImport,
                      ),
                    ),
                  ),
                  child: const Text('Lenses'),
                ),
              if (onImport != null)
                IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  tooltip: 'Import',
                  onPressed: onImport,
                  icon: const Icon(Icons.file_download_outlined),
                ),
              IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'New body',
                onPressed: () => _edit(context, newBodyTemplate(), isNew: true),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: ListView(
            children: [
              ProfileNoneTile(
                label: 'No camera',
                selected: selected == null,
                onTap: () async {
                  await gear.selectBody(null);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              if (favorites.isNotEmpty) ...[
                const SectionHeader('Favorites'),
                for (final b in favorites) _tile(context, b),
              ],
              const SectionHeader('All'),
              for (final e in byMake.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(e.key.toUpperCase(), style: grainLabelStyle),
                ),
                for (final b in e.value) _tile(context, b),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// The "No camera" / "No lens" row.
class ProfileNoneTile extends StatelessWidget {
  const ProfileNoneTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          const SizedBox(width: 16),
          SizedBox(
            width: 24,
            child: selected
                ? const Icon(Icons.check, size: 20, color: GrainColors.accent)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    ),
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: GrainColors.ink,
      ),
    ),
  );
}
