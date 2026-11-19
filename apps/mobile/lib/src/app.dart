import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/alert_detail_page.dart';
import 'package:venicare_app/src/ui/consult_page.dart';
import 'package:venicare_app/src/ui/device_detail_page.dart';
import 'package:venicare_app/src/ui/devices_page.dart';
import 'package:venicare_app/src/ui/family_page.dart';
import 'package:venicare_app/src/ui/health_records_page.dart';
import 'package:venicare_app/src/ui/home_shell.dart';
import 'package:venicare_app/src/ui/medication_page.dart';
import 'package:venicare_app/src/ui/profile_page.dart';
import 'package:venicare_app/src/ui/settings_pages.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
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
          GoRoute(
            path: 'devices/:deviceId',
            builder: (context, state) =>
                DeviceDetailPage(deviceId: state.pathParameters['deviceId']!),
          ),
          GoRoute(
            path: 'medication',
            builder: (context, state) => const MedicationPage(),
          ),
          GoRoute(
            path: 'health',
            builder: (context, state) => const HealthRecordsPage(),
          ),
          GoRoute(
            path: 'consult',
            builder: (context, state) => const ConsultPage(),
            routes: [
              GoRoute(
                path: 'appointments',
                builder: (context, state) => const MyAppointmentsPage(),
              ),
              GoRoute(
                path: 'doctors/:doctorId',
                builder: (context, state) => DoctorBookingPage(
                  doctorId: state.pathParameters['doctorId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'family',
            builder: (context, state) => const FamilyPage(),
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountPage(),
          ),
          GoRoute(
            path: 'add-device',
            builder: (context, state) => const AddDevicePage(),
          ),
          GoRoute(
            path: 'self-check',
            builder: (context, state) => const SelfCheckPage(),
          ),
          GoRoute(
            path: 'settings/policy',
            builder: (context, state) => const PolicyPage(),
          ),
          GoRoute(
            path: 'settings/privacy',
            builder: (context, state) => const PrivacyPage(),
          ),
          GoRoute(
            path: 'settings/notifications',
            builder: (context, state) => const NotificationCheckPage(),
          ),
          GoRoute(
            path: 'settings/help',
            builder: (context, state) => const HelpPage(),
          ),
          GoRoute(
            path: 'settings/about',
            builder: (context, state) => const AboutPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class VeniCareApp extends ConsumerWidget {
  const VeniCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preference = ref.watch(
      appControllerProvider.select((state) => state.themePreference),
    );
    final themeMode = switch (preference) {
      AppThemePreference.system => ThemeMode.system,
      AppThemePreference.light => ThemeMode.light,
      AppThemePreference.dark => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: '安心守护',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildCareTheme(dark: false),
      darkTheme: buildCareTheme(dark: true),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final width = MediaQuery.sizeOf(context).width;
        if (width < 560 || child == null) {
          return child ?? const SizedBox.shrink();
        }
        final outer = Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF060A14)
            : const Color(0xFFDCE6F5);
        return ColoredBox(
          color: outer,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 440,
              height: MediaQuery.sizeOf(context).height,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
