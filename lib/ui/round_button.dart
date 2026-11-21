import 'package:material_ui/material_ui.dart';

import 'theme.dart';

/// 44 px circular button: thin border, or filled ink when [filled].
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.filled = false,
    this.background = Colors.transparent,
    this.toggled,
  });

  final Widget child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final bool filled;

  /// Fill when not [filled].
  final Color background;

  /// For toggle buttons: whether the toggle is on.
  final bool? toggled;

  static const size = 44.0;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? GrainColors.ground : GrainColors.ink;
    return Semantics(
      button: true,
      toggled: toggled,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? GrainColors.ink : background,
            border: Border.all(
              color: filled ? GrainColors.ink : GrainColors.border,
            ),
          ),
          alignment: Alignment.center,
          child: IconTheme.merge(
            data: IconThemeData(color: fg, size: 20),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg, fontSize: 20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
