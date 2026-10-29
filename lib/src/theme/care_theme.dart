import 'package:flutter/material.dart';

class CareColors extends ThemeExtension<CareColors> {
  const CareColors({
    required this.canvas,
    required this.card,
    required this.ink,
    required this.muted,
    required this.line,
    required this.primary,
    required this.primarySoft,
    required this.urgent,
    required this.urgentSoft,
    required this.warning,
    required this.warningSoft,
    required this.info,
    required this.infoSoft,
    required this.shadow,
  });

  final Color canvas;
  final Color card;
  final Color ink;
  final Color muted;
  final Color line;
  final Color primary;
  final Color primarySoft;
  final Color urgent;
  final Color urgentSoft;
  final Color warning;
  final Color warningSoft;
  final Color info;
  final Color infoSoft;
  final Color shadow;

  static const light = CareColors(
    canvas: Color(0xFFF3F1EA),
    card: Color(0xFFFFFCF8),
    ink: Color(0xFF1C2421),
    muted: Color(0xFF66716C),
    line: Color(0xFFE6E1D6),
    primary: Color(0xFF0F6E56),
    primarySoft: Color(0xFFE5F4EF),
    urgent: Color(0xFFC53636),
    urgentSoft: Color(0xFFFFF1EF),
    warning: Color(0xFFB86A12),
    warningSoft: Color(0xFFFFF6E8),
    info: Color(0xFF246B93),
    infoSoft: Color(0xFFEAF4FB),
    shadow: Color(0x141C2421),
  );

  static const dark = CareColors(
    canvas: Color(0xFF101614),
    card: Color(0xFF1A221F),
    ink: Color(0xFFF4F7F5),
    muted: Color(0xFFA7B2AC),
    line: Color(0xFF2C3833),
    primary: Color(0xFF3CB892),
    primarySoft: Color(0xFF14332B),
    urgent: Color(0xFFFF7B74),
    urgentSoft: Color(0xFF3A1E1C),
    warning: Color(0xFFF0B15A),
    warningSoft: Color(0xFF3A2C16),
    info: Color(0xFF7EB6E0),
    infoSoft: Color(0xFF162A38),
    shadow: Color(0x66000000),
  );

  static CareColors of(BuildContext context) {
    final colors = Theme.of(context).extension<CareColors>();
    assert(colors != null, 'CareColors is missing from ThemeData');
    return colors ?? light;
  }

  @override
  CareColors copyWith({
    Color? canvas,
    Color? card,
    Color? ink,
    Color? muted,
    Color? line,
    Color? primary,
    Color? primarySoft,
    Color? urgent,
    Color? urgentSoft,
    Color? warning,
    Color? warningSoft,
    Color? info,
    Color? infoSoft,
    Color? shadow,
  }) {
    return CareColors(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      urgent: urgent ?? this.urgent,
      urgentSoft: urgentSoft ?? this.urgentSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  CareColors lerp(ThemeExtension<CareColors>? other, double t) {
    if (other is! CareColors) {
      return this;
    }
    return CareColors(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      card: Color.lerp(card, other.card, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentSoft: Color.lerp(urgentSoft, other.urgentSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoSoft: Color.lerp(infoSoft, other.infoSoft, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension CareContext on BuildContext {
  CareColors get care => CareColors.of(this);
}

abstract final class CareGradients {
  static const calm = [Color(0xFF0C5B49), Color(0xFF1C8A6A)];
  static const attention = [Color(0xFF8A5310), Color(0xFFC9842A)];
  static const urgent = [Color(0xFF8E2C2C), Color(0xFFD4534A)];
  static const unknown = [Color(0xFF3E4A46), Color(0xFF5C6B66)];
}

ThemeData buildCareTheme({required bool dark}) {
  final colors = dark ? CareColors.dark : CareColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF0F6E56),
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: colors.primary,
    onPrimary: dark ? const Color(0xFF06241C) : Colors.white,
    surface: colors.canvas,
    onSurface: colors.ink,
    error: colors.urgent,
    surfaceTint: Colors.transparent,
  );

  final radius = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.canvas,
    extensions: [colors],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: colors.ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: colors.card,
      indicatorColor: colors.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? colors.primary : colors.muted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? colors.primary : colors.muted);
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colors.primary,
        foregroundColor: dark ? const Color(0xFF06241C) : Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: radius,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.45)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        shape: radius,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: colors.ink,
      ),
      contentTextStyle: TextStyle(
        fontSize: 15,
        height: 1.5,
        color: colors.ink,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      dragHandleColor: colors.line,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF2C3833) : colors.ink,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        height: 1.4,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF121A17) : Colors.white,
      hintStyle: TextStyle(color: colors.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.line,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w800,
        color: colors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.25,
        fontWeight: FontWeight.w800,
        color: colors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: colors.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: colors.ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: colors.muted),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
    ),
  );
}
