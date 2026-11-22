import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';

class ProfileAction {
  const ProfileAction(this.label, this.onSelected);
  final String label;
  final VoidCallback onSelected;
}

/// One row of a picker: check, title/subtitle, "Yours" tag, favorite star and
/// an optional overflow menu. Every target is at least 44 px.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.favorite,
    required this.user,
    required this.onTap,
    required this.onToggleFavorite,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool favorite;
  final bool user;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final List<ProfileAction> actions;

  @override
  Widget build(BuildContext context) {
    final g = context.grain;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            const SizedBox(width: 16),
            SizedBox(
              width: 24,
              child: selected
                  ? Icon(Icons.check, size: 20, color: g.accent)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, color: g.ink)),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontSize: 13, color: g.secondary),
                      ),
                  ],
                ),
              ),
            ),
            if (user)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(
                  'Yours',
                  style: TextStyle(fontSize: 12, color: g.accent),
                ),
              ),
            Semantics(
              button: true,
              excludeSemantics: true,
              label: favorite ? 'Remove from favorites' : 'Add to favorites',
              onTap: onToggleFavorite,
              child: IconButton(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: favorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
                onPressed: onToggleFavorite,
                icon: Icon(
                  favorite ? Icons.star : Icons.star_border,
                  color: favorite ? g.accent : g.faded,
                ),
              ),
            ),
            if (actions.isNotEmpty)
              PopupMenuButton<ProfileAction>(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                tooltip: 'More',
                elevation: 0,
                color: g.ground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: g.border),
                ),
                icon: Icon(Icons.more_vert, color: g.secondary),
                onSelected: (a) => a.onSelected(),
                itemBuilder: (_) => [
                  for (final a in actions)
                    PopupMenuItem(value: a, child: Text(a.label)),
                ],
              )
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
