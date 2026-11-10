import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? MwColors.dark : MwColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primarySoft,
    onPrimaryContainer: c.primary,
    secondary: c.accent,
    onSecondary: const Color(0xFF2B1D00),
    error: c.red,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkSoft,
    surfaceContainerHighest: c.surfaceAlt,
    surfaceContainerHigh: c.surfaceAlt,
    surfaceContainer: c.surface,
    surfaceContainerLow: c.surface,
    outline: c.line,
    outlineVariant: c.line,
  );

  final text = TextTheme(
    displaySmall: displayStyle(34, color: c.ink),
    headlineMedium: displayStyle(28, color: c.ink),
    headlineSmall: displayStyle(23, color: c.ink),
    titleLarge: displayStyle(19, weight: 600, color: c.ink, height: 1.2),
    titleMedium: bodyStyle(16, weight: 600, color: c.ink, height: 1.3),
    titleSmall: bodyStyle(14, weight: 600, color: c.ink, height: 1.3),
    bodyLarge: bodyStyle(16, color: c.ink),
    bodyMedium: bodyStyle(14.5, color: c.ink),
    bodySmall: bodyStyle(13, color: c.inkSoft),
    labelLarge: bodyStyle(15, weight: 600, color: c.ink, height: 1.2),
    labelMedium: bodyStyle(13, weight: 600, color: c.inkSoft, height: 1.2),
    labelSmall: bodyStyle(12, weight: 500, color: c.inkSoft, height: 1.2),
  );

  const buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  );
  OutlineInputBorder field(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: bodyFont,
    textTheme: text,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: displayStyle(19, weight: 600, color: c.ink),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: c.surface,
        systemNavigationBarIconBrightness: brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        disabledBackgroundColor: c.surfaceAlt,
        disabledForegroundColor: c.inkFaint,
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        shape: buttonShape,
        textStyle: bodyStyle(16, weight: 600, height: 1.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(64, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        side: BorderSide(color: c.line),
        shape: buttonShape,
        textStyle: bodyStyle(16, weight: 600, height: 1.2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.primary,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: buttonShape,
        textStyle: bodyStyle(15, weight: 600, height: 1.2),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: c.ink,
        minimumSize: const Size(44, 44),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: bodyStyle(16, color: c.inkFaint),
      labelStyle: bodyStyle(16, color: c.inkSoft),
      floatingLabelStyle: bodyStyle(16, weight: 600, color: c.primary),
      errorStyle: bodyStyle(13, color: c.red),
      border: field(c.line),
      enabledBorder: field(c.line),
      focusedBorder: field(c.primary, 1.6),
      errorBorder: field(c.red),
      focusedErrorBorder: field(c.red, 1.6),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.inkFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceAlt,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.line,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primarySoft,
      height: 68,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => bodyStyle(
          12,
          weight: s.contains(WidgetState.selected) ? 700 : 500,
          color: s.contains(WidgetState.selected) ? c.primary : c.inkSoft,
          height: 1.2,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected) ? c.primary : c.inkSoft,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: displayStyle(21, weight: 600, color: c.ink),
      contentTextStyle: bodyStyle(15, color: c.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brightness == Brightness.dark ? c.surfaceAlt : c.ink,
      contentTextStyle: bodyStyle(
        14.5,
        weight: 500,
        color: brightness == Brightness.dark ? c.ink : c.bg,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.line),
      ),
      textStyle: bodyStyle(15, weight: 500, color: c.ink),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.primary,
      linearTrackColor: c.surfaceAlt,
      circularTrackColor: Colors.transparent,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.onPrimary,
      elevation: 2,
      highlightElevation: 2,
      extendedTextStyle: bodyStyle(15.5, weight: 600, height: 1.2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
  );
}
