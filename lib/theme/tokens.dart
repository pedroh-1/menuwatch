import 'package:flutter/material.dart';

/// Cores do MenuWatch: berinjela como cor da marca, açafrão para o que
/// pede atenção, folha e pimenta para disponível e indisponível.
@immutable
class MwColors extends ThemeExtension<MwColors> {
  const MwColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.line,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.primary,
    required this.onPrimary,
    required this.primarySoft,
    required this.accent,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.feature,
    required this.onFeature,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color line;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color primary;
  final Color onPrimary;
  final Color primarySoft;
  final Color accent;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;

  /// Fundo do bloco de destaque (favoritos do dia), berinjela nos dois temas.
  final Color feature;
  final Color onFeature;

  static const light = MwColors(
    bg: Color(0xFFFBFAFD),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1EEF6),
    line: Color(0xFFE4DFEC),
    ink: Color(0xFF1E1626),
    inkSoft: Color(0xFF5E546B),
    inkFaint: Color(0xFF9189A0),
    primary: Color(0xFF4A2462),
    onPrimary: Color(0xFFFFFFFF),
    primarySoft: Color(0xFFEDE4F4),
    accent: Color(0xFFE5A11A),
    green: Color(0xFF24805A),
    greenSoft: Color(0xFFE2F2EA),
    red: Color(0xFFC4432F),
    redSoft: Color(0xFFFAE7E3),
    feature: Color(0xFF4A2462),
    onFeature: Color(0xFFFBFAFD),
  );

  static const dark = MwColors(
    bg: Color(0xFF141018),
    surface: Color(0xFF1D1723),
    surfaceAlt: Color(0xFF272030),
    line: Color(0xFF352C40),
    ink: Color(0xFFF1ECF6),
    inkSoft: Color(0xFFB3A8C2),
    inkFaint: Color(0xFF7F748E),
    primary: Color(0xFFC9A6E8),
    onPrimary: Color(0xFF2A1238),
    primarySoft: Color(0xFF33243F),
    accent: Color(0xFFF2B63C),
    green: Color(0xFF5CC596),
    greenSoft: Color(0xFF1B3229),
    red: Color(0xFFF0806C),
    redSoft: Color(0xFF3B211D),
    feature: Color(0xFF3A1D4D),
    onFeature: Color(0xFFF1ECF6),
  );

  @override
  MwColors copyWith() => this;

  @override
  MwColors lerp(MwColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MwColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      line: c(line, other.line),
      ink: c(ink, other.ink),
      inkSoft: c(inkSoft, other.inkSoft),
      inkFaint: c(inkFaint, other.inkFaint),
      primary: c(primary, other.primary),
      onPrimary: c(onPrimary, other.onPrimary),
      primarySoft: c(primarySoft, other.primarySoft),
      accent: c(accent, other.accent),
      green: c(green, other.green),
      greenSoft: c(greenSoft, other.greenSoft),
      red: c(red, other.red),
      redSoft: c(redSoft, other.redSoft),
      feature: c(feature, other.feature),
      onFeature: c(onFeature, other.onFeature),
    );
  }
}

extension MwTheme on BuildContext {
  MwColors get mw => Theme.of(this).extension<MwColors>()!;
}

const displayFont = 'Bricolage';
const bodyFont = 'Hanken';

FontWeight _weight(int w) => FontWeight.values[(w ~/ 100 - 1).clamp(0, 8)];

/// Títulos, nomes e números: Bricolage Grotesque.
TextStyle displayStyle(
  double size, {
  int weight = 650,
  Color? color,
  double height = 1.12,
}) => TextStyle(
  fontFamily: displayFont,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: size >= 24 ? -0.022 * size : -0.012 * size,
  fontWeight: _weight(weight),
  fontVariations: [
    FontVariation('wght', weight.toDouble()),
    FontVariation('opsz', size.clamp(12, 96).toDouble()),
  ],
);

/// Texto corrido e rótulos: Hanken Grotesk.
TextStyle bodyStyle(
  double size, {
  int weight = 400,
  Color? color,
  double height = 1.4,
}) => TextStyle(
  fontFamily: bodyFont,
  fontSize: size,
  height: height,
  color: color,
  letterSpacing: 0,
  fontWeight: _weight(weight),
  fontVariations: [FontVariation('wght', weight.toDouble())],
);

/// Margem lateral padrão das telas.
const double gutter = 20;
