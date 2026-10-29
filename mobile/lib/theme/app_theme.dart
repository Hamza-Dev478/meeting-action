import 'package:flutter/material.dart';

import 'glass_theme.dart';

const _brand = Color(0xFF3949AB);

/// Material 3 theme tuned for the glass look: the existing indigo brand,
/// bolder iOS-style titles, translucent inputs, capsule buttons, round
/// checkboxes and floating snack bars.
ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: _brand, brightness: brightness);
  final glass = dark ? GlassTheme.dark : GlassTheme.light;
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme;

  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    extensions: [glass],
    scaffoldBackgroundColor: glass.backdropBase.first,
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: field(glass.rimShade),
      enabledBorder: field(glass.rimShade),
      disabledBorder: field(glass.rimShade.withValues(alpha: 0.05)),
      focusedBorder: field(scheme.primary, 1.6),
      errorBorder: field(scheme.error),
      focusedErrorBorder: field(scheme.error, 1.6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: const CircleBorder(),
      side: BorderSide(color: scheme.outline, width: 1.6),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: dark ? const Color(0xF0262540) : const Color(0xF01F2238),
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
      actionTextColor: scheme.inversePrimary,
    ),
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: scheme.surfaceContainer.withValues(alpha: 0.97),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.97),
    ),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0),
    expansionTileTheme: const ExpansionTileThemeData(shape: Border(), collapsedShape: Border()),
    dividerTheme: DividerThemeData(color: glass.rimShade, space: 1),
  );
}
