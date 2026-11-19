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
    canvas: Color(0xFFF4F6FA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF1A1F2B),
    muted: Color(0xFF8A92A3),
    line: Color(0xFFEDF0F5),
    primary: Color(0xFF2F7BF6),
    primarySoft: Color(0xFFEBF2FF),
    urgent: Color(0xFFF0473E),
    urgentSoft: Color(0xFFFFF2F1),
    warning: Color(0xFFF08A1C),
    warningSoft: Color(0xFFFFF5EA),
    info: Color(0xFF14A3C7),
    infoSoft: Color(0xFFE7F7FB),
    shadow: Color(0x0F2A3B5C),
  );

  static const dark = CareColors(
    canvas: Color(0xFF0B1220),
    card: Color(0xFF141E30),
    ink: Color(0xFFF1F5FB),
    muted: Color(0xFF9AA8BD),
    line: Color(0xFF243149),
    primary: Color(0xFF5B9BFF),
    primarySoft: Color(0xFF15284A),
    urgent: Color(0xFFFF7B74),
    urgentSoft: Color(0xFF3A1E22),
    warning: Color(0xFFF0B15A),
    warningSoft: Color(0xFF3A2C16),
    info: Color(0xFF5CC8E4),
    infoSoft: Color(0xFF12303A),
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
  static const calm = [Color(0xFF1656C9), Color(0xFF3D8BFF)];
  static const attention = [Color(0xFFB4630C), Color(0xFFE8962E)];
  static const urgent = [Color(0xFFB02A2A), Color(0xFFE5574D)];
  static const unknown = [Color(0xFF475569), Color(0xFF6B7A90)];
}

abstract final class CareBackdrop {
  static const light = [
    Color(0xFFC6DDFF),
    Color(0xFFE3EEFF),
    Color(0xFFF4F6FA),
  ];
  static const dark = [Color(0xFF1A2B4D), Color(0xFF111B31), Color(0xFF0B1220)];
  static const stops = [0.0, 0.28, 0.55];

  static List<Color> of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildCareTheme({required bool dark}) {
  final colors = dark ? CareColors.dark : CareColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF1F6FEB),
        brightness: dark ? Brightness.dark : Brightness.light,
      ).copyWith(
        primary: colors.primary,
        onPrimary: dark ? const Color(0xFF061A3A) : Colors.white,
        surface: colors.canvas,
        onSurface: colors.ink,
        error: colors.urgent,
        surfaceTint: Colors.transparent,
      );

  const radius = StadiumBorder();

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: colors.canvas,
    extensions: [colors],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colors.canvas,
      foregroundColor: colors.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.line, space: 1, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      backgroundColor: colors.card,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
        minimumSize: const Size.fromHeight(50),
        backgroundColor: colors.primary,
        foregroundColor: dark ? const Color(0xFF061A3A) : Colors.white,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: radius,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        foregroundColor: colors.primary,
        side: BorderSide(color: colors.line, width: 1.2),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: radius,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      contentTextStyle: TextStyle(fontSize: 15, height: 1.5, color: colors.ink),
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
      backgroundColor: dark ? const Color(0xFF243149) : colors.ink,
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
      fillColor: dark ? const Color(0xFF0F1828) : Colors.white,
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
    chipTheme: ChipThemeData(
      backgroundColor: colors.card,
      selectedColor: colors.primarySoft,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      labelStyle: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: colors.ink,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primary,
      linearTrackColor: colors.line,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.2,
        fontWeight: FontWeight.w700,
        color: colors.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: colors.ink),
      bodyMedium: TextStyle(fontSize: 15, height: 1.45, color: colors.ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.4, color: colors.muted),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: colors.ink,
      ),
    ),
  );
}
