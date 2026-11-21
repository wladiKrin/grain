import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The "Paper" palette.
abstract final class GrainColors {
  static const ground = Color(0xFFF4F2EE);
  static const ink = Color(0xFF141414);
  static const secondary = Color(0xFF5E5B55);
  static const divider = Color(0xFFD9D5CD);
  static const border = Color(0xFFC9C4BA);
  static const faded = Color(0xFF8C877E);
  static const accent = Color(0xFFB8321A);
}

const grainFont = 'InterTight';

/// Dark status and navigation bar icons over the paper ground, whatever the
/// system's dark mode.
const grainOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: GrainColors.ground,
  systemNavigationBarDividerColor: GrainColors.ground,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarContrastEnforced: false,
);

/// 12 px letter-spaced label, e.g. "APERTURE".
const grainLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w500,
  letterSpacing: 12 * .14,
  color: GrainColors.secondary,
);

ThemeData grainTheme() => ThemeData(
  fontFamily: grainFont,
  scaffoldBackgroundColor: GrainColors.ground,
  colorScheme: const ColorScheme.light(
    primary: GrainColors.ink,
    onPrimary: GrainColors.ground,
    secondary: GrainColors.accent,
    onSecondary: GrainColors.ground,
    surface: GrainColors.ground,
    onSurface: GrainColors.ink,
    onSurfaceVariant: GrainColors.secondary,
    outline: GrainColors.border,
    outlineVariant: GrainColors.divider,
    surfaceTint: Colors.transparent,
  ),
  splashFactory: NoSplash.splashFactory,
  highlightColor: Colors.transparent,
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: GrainColors.ground,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    modalElevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
  ),
);
