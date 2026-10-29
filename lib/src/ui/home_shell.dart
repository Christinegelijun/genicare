import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/alerts_page.dart';
import 'package:venicare_app/src/ui/dashboard_page.dart';
import 'package:venicare_app/src/ui/devices_page.dart';
import 'package:venicare_app/src/ui/profile_page.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final openCount = state.activeAlerts.length;
    return Scaffold(
      body: SafeArea(
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
          border: Border(top: BorderSide(color: colors.line)),
        ),
        child: NavigationBar(
          selectedIndex: state.selectedTab,
          onDestinationSelected: ref.read(appControllerProvider.notifier).selectTab,
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
                child: const Icon(Icons.notifications_active_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: openCount > 0,
                label: Text('$openCount'),
                backgroundColor: colors.urgent,
                child: const Icon(Icons.notifications_active),
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
    );
  }
}
