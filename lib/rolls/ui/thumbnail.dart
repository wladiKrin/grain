import 'package:material_ui/material_ui.dart';

import '../../ui/theme.dart';
import '../snapshot_store.dart';

/// A square snapshot thumbnail, decoded at its display size so long lists
/// scroll smoothly. A missing name or file shows a placeholder; never throws.
class SnapshotThumb extends StatelessWidget {
  const SnapshotThumb({
    super.key,
    required this.store,
    required this.name,
    this.size = 56,
  });

  final SnapshotStore store;
  final String? name;
  final double size;

  Widget _placeholder() => Container(
    width: size,
    height: size,
    color: GrainColors.divider,
    alignment: Alignment.center,
    child: Icon(
      Icons.image_not_supported_outlined,
      size: size * .45,
      color: GrainColors.faded,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final n = name;
    if (n == null) return _placeholder();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Image.file(
      store.file(n),
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: (size * dpr).round(),
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }
}
