import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/ui/alert_detail_page.dart';
import 'package:venicare_app/src/ui/home_shell.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeShell(),
      routes: [
        GoRoute(
          path: 'alerts/:alertId',
          builder: (context, state) =>
              AlertDetailPage(alertId: state.pathParameters['alertId']!),
        ),
      ],
    ),
  ],
);

class VeniCareApp extends StatelessWidget {
  const VeniCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF176B5B);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF7F9F7),
    );

    return MaterialApp.router(
      title: '安心守护',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE4EAE7)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
