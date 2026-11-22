import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The "Paper" palette (light) and its dark counterpart, as a theme extension.
@immutable
class GrainPalette extends ThemeExtension<GrainPalette> {
  const GrainPalette({
    required this.ground,
    required this.ink,
    required this.secondary,
    required this.divider,
    required this.border,
    required this.faded,
    required this.accent,
    required this.minorTick,
  });

  static const light = GrainPalette(
    ground: Color(0xFFF4F2EE),
    ink: Color(0xFF141414),
    secondary: Color(0xFF5E5B55),
    divider: Color(0xFFD9D5CD),
    border: Color(0xFFC9C4BA),
    faded: Color(0xFF8C877E),
    accent: Color(0xFFB8321A),
    minorTick: Color(0xFFB4AEA3),
  );

  static const dark = GrainPalette(
    ground: Color(0xFF151413),
    ink: Color(0xFFECE8E1),
    secondary: Color(0xFFA39E95),
    divider: Color(0xFF2C2A27),
    border: Color(0xFF3A3733),
    faded: Color(0xFF7A756D),
    accent: Color(0xFFE0553A),
    minorTick: Color(0xFF4A4741),
  );

  static GrainPalette of(Brightness b) => b == Brightness.dark ? dark : light;

  final Color ground;
  final Color ink;
  final Color secondary;
  final Color divider;
  final Color border;
  final Color faded;
  final Color accent;
  final Color minorTick;

  /// 12 px letter-spaced label, e.g. "APERTURE".
  TextStyle get label => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 12 * .14,
    color: secondary,
  );

  @override
  bool operator ==(Object other) =>
      other is GrainPalette &&
      other.ground == ground &&
      other.ink == ink &&
      other.secondary == secondary &&
      other.divider == divider &&
      other.border == border &&
      other.faded == faded &&
      other.accent == accent &&
      other.minorTick == minorTick;

  @override
  int get hashCode => Object.hash(
    ground,
    ink,
    secondary,
    divider,
    border,
    faded,
    accent,
    minorTick,
  );

  @override
  GrainPalette copyWith({
    Color? ground,
    Color? ink,
    Color? secondary,
    Color? divider,
    Color? border,
    Color? faded,
    Color? accent,
    Color? minorTick,
  }) => GrainPalette(
    ground: ground ?? this.ground,
    ink: ink ?? this.ink,
    secondary: secondary ?? this.secondary,
    divider: divider ?? this.divider,
    border: border ?? this.border,
    faded: faded ?? this.faded,
    accent: accent ?? this.accent,
    minorTick: minorTick ?? this.minorTick,
  );

  @override
  GrainPalette lerp(GrainPalette? other, double t) {
    if (other == null) return this;
    return GrainPalette(
      ground: Color.lerp(ground, other.ground, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      faded: Color.lerp(faded, other.faded, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      minorTick: Color.lerp(minorTick, other.minorTick, t)!,
    );
  }
}

extension GrainContext on BuildContext {
  /// The palette of the enclosing theme (light without a Grain theme).
  GrainPalette get grain =>
      Theme.of(this).extension<GrainPalette>() ?? GrainPalette.light;
}

const grainFont = 'InterTight';

/// Status and navigation bar style for [b]: dark icons on the light ground,
/// light icons on the dark one.
SystemUiOverlayStyle grainOverlayStyle(Brightness b) {
  final icons = b == Brightness.dark ? Brightness.light : Brightness.dark;
  final ground = GrainPalette.of(b).ground;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    statusBarBrightness: b,
    systemNavigationBarColor: ground,
    systemNavigationBarDividerColor: ground,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

ThemeData grainTheme([Brightness brightness = Brightness.light]) {
  final p = GrainPalette.of(brightness);
  final scheme = brightness == Brightness.dark
      ? const ColorScheme.dark()
      : const ColorScheme.light();
  return ThemeData(
    fontFamily: grainFont,
    scaffoldBackgroundColor: p.ground,
    extensions: [p],
    colorScheme: scheme.copyWith(
      primary: p.ink,
      onPrimary: p.ground,
      secondary: p.accent,
      onSecondary: p.ground,
      surface: p.ground,
      onSurface: p.ink,
      onSurfaceVariant: p.secondary,
      outline: p.border,
      outlineVariant: p.divider,
      surfaceTint: Colors.transparent,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
    ),
  );
}
