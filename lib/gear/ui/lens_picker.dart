import 'package:material_ui/material_ui.dart';

import '../gear_controller.dart';
import '../model.dart';
import 'body_picker.dart' show ProfileNoneTile, SectionHeader;
import 'form_bits.dart';
import 'lens_editor.dart';
import 'profile_tile.dart';

String _mm(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

String lensSubtitle(Lens l) {
  final focal = l.isZoom
      ? '${_mm(l.focalMin)}-${_mm(l.focalMax)} mm'
      : '${_mm(l.focalMin)} mm';
  final first = l.maxAperture.first.aperture;
  final last = l.maxAperture.last.aperture;
  final ap = first == last ? 'f/${_mm(first)}' : 'f/${_mm(first)}-${_mm(last)}';
  return '$focal, $ap';
}

/// "No lens", favorites, then the mount's lenses in focal order.
class LensPickerScreen extends StatelessWidget {
  const LensPickerScreen({
    super.key,
    required this.gear,
    required this.mount,
    this.onShare,
    this.onImport,
  });

  final GearController gear;
  final String mount;
  final void Function(GearDoc doc)? onShare;
  final VoidCallback? onImport;

  Future<void> _edit(BuildContext context, Lens l, {required bool isNew}) =>
      Navigator.push<Lens>(
        context,
        MaterialPageRoute(
          builder: (_) => LensEditorScreen(
            gear: gear,
            initial: l,
            isNew: isNew,
            mount: mount,
          ),
        ),
      );

  List<ProfileAction> _actions(BuildContext context, Lens l) {
    final user = gear.isUser(l);
    return [
      if (user) ProfileAction('Edit', () => _edit(context, l, isNew: false)),
      ProfileAction(
        'Duplicate and edit',
        () => _edit(context, gear.duplicateLens(l), isNew: true),
      ),
      if (onShare != null) ProfileAction('Share', () => onShare!(l)),
      if (user)
        ProfileAction('Delete', () async {
          if (await confirmDelete(context, l.displayName)) {
            await gear.deleteUser(l);
          }
        }),
    ];
  }

  Widget _tile(BuildContext context, Lens l) => ProfileTile(
    title: l.displayName,
    subtitle: lensSubtitle(l),
    selected: gear.lens?.id == l.id,
    favorite: gear.isFavorite(l),
    user: gear.isUser(l),
    onTap: () async {
      await _select(l);
      if (context.mounted) Navigator.pop(context);
    },
    onToggleFavorite: () => gear.toggleFavorite(l),
    actions: _actions(context, l),
  );

  Future<void> _select(Lens? l) async {
    if (l != null && gear.body?.mount != l.mount) return;
    await gear.selectLens(l);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: gear,
      builder: (context, _) {
        final lenses = gear.lensesFor(mount);
        final favorites = gear.favoriteLensesFor(mount);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Lenses'),
            actions: [
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
                tooltip: 'New lens',
                onPressed: () =>
                    _edit(context, newLensTemplate(mount), isNew: true),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          body: lenses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No lenses for this mount yet.'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () =>
                            _edit(context, newLensTemplate(mount), isNew: true),
                        child: const Text('Create lens'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    ProfileNoneTile(
                      label: 'No lens',
                      selected: gear.lens == null,
                      onTap: () async {
                        await _select(null);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    if (favorites.isNotEmpty) ...[
                      const SectionHeader('Favorites'),
                      for (final l in favorites) _tile(context, l),
                    ],
                    const SectionHeader('All'),
                    for (final l in lenses) _tile(context, l),
                  ],
                ),
        );
      },
    );
  }
}
