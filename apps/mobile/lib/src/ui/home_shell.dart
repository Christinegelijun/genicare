import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/alerts_page.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/dashboard_page.dart';
import 'package:venicare_app/src/ui/devices_page.dart';
import 'package:venicare_app/src/ui/elder_home_page.dart';
import 'package:venicare_app/src/ui/profile_page.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    if (state.appMode == AppMode.elder) {
      return const ElderHomePage();
    }
    final colors = context.care;
    final openCount = state.activeAlerts.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: BackdropView(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: IndexedStack(
              index: state.selectedTab,
              children: const [
                DashboardPage(),
                AlertsPage(),
                DevicesPage(),
                ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.card,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              selectedIndex: state.selectedTab,
              onDestinationSelected: ref
                  .read(appControllerProvider.notifier)
                  .selectTab,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: '首页',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: openCount > 0,
                    label: Text('$openCount'),
                    backgroundColor: colors.urgent,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: openCount > 0,
                    label: Text('$openCount'),
                    backgroundColor: colors.urgent,
                    child: const Icon(Icons.notifications_rounded),
                  ),
                  label: '事件',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.sensors_outlined),
                  selectedIcon: Icon(Icons.sensors),
                  label: '设备',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
