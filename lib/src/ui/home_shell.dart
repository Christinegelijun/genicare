import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _titles = ['首页', '事件', '设备', '我的'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final pages = [
      const DashboardPage(),
      const AlertsPage(),
      const DevicesPage(),
      const ProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _titles[state.selectedTab],
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (state.selectedTab == 0)
            IconButton(
              tooltip: '通知',
              onPressed: () {
                ref.read(appControllerProvider.notifier).selectTab(1);
              },
              icon: Badge(
                isLabelVisible: state.activeAlerts.isNotEmpty,
                label: Text('${state.activeAlerts.length}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(index: state.selectedTab, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.selectedTab,
        onDestinationSelected: ref
            .read(appControllerProvider.notifier)
            .selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            selectedIcon: Icon(Icons.notifications_active),
            label: '事件',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final recipient = state.recipient;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _RecipientHeader(recipient: recipient),
        const SizedBox(height: 16),
        if (state.activeAlerts.isNotEmpty) ...[
          _UrgentAlertCard(alert: state.activeAlerts.first),
          const SizedBox(height: 24),
        ],
        const SectionHeader(title: '今日照护'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (
                var index = 0;
                index < state.medicationTasks.length;
                index++
              ) ...[
                _MedicationRow(task: state.medicationTasks[index]),
                if (index != state.medicationTasks.length - 1)
                  const Divider(height: 1, indent: 64),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SectionHeader(
          title: '设备状态',
          action: TextButton(
            onPressed: () {
              ref.read(appControllerProvider.notifier).selectTab(2);
            },
            child: const Text('查看全部'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _DeviceSummary(
                  icon: Icons.check_circle_outline,
                  value:
                      '${state.devices.where((d) => d.status == DeviceStatus.online).length}',
                  label: '运行正常',
                  color: const Color(0xFF218765),
                ),
                const _VerticalDivider(),
                _DeviceSummary(
                  icon: Icons.warning_amber_rounded,
                  value:
                      '${state.devices.where((d) => d.status == DeviceStatus.warning).length}',
                  label: '需要注意',
                  color: const Color(0xFFD9822B),
                ),
                const _VerticalDivider(),
                _DeviceSummary(
                  icon: Icons.cloud_done_outlined,
                  value: relativeTime(state.devices.first.lastSeenAt),
                  label: '最近同步',
                  color: const Color(0xFF2878B5),
                  compact: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipientHeader extends StatelessWidget {
  const _RecipientHeader({required this.recipient});

  final CareRecipient recipient;

  @override
  Widget build(BuildContext context) {
    final isUrgent = recipient.protectionLevel == ProtectionLevel.urgent;
    final color = isUrgent ? const Color(0xFFD43D3D) : const Color(0xFF218765);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.1),
              foregroundColor: color,
              child: Text(
                recipient.name.substring(0, 1),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipient.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${recipient.statusText} · 更新于${relativeTime(recipient.lastUpdatedAt)}',
                    style: TextStyle(color: color, height: 1.35),
                  ),
                ],
              ),
            ),
            Icon(
              isUrgent ? Icons.error_rounded : Icons.verified_rounded,
              color: color,
              size: 30,
            ),
          ],
        ),
      ),
    );
  }
}

class _UrgentAlertCard extends StatelessWidget {
  const _UrgentAlertCard({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFD43D3D);
    return Card(
      color: const Color(0xFFFFF7F6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFF0B8B4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/alerts/${alert.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.crisis_alert_rounded, color: color),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '紧急事件待处理',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                alert.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${alert.location} · ${relativeTime(alert.occurredAt)}',
                style: const TextStyle(color: Color(0xFF715C59)),
              ),
              const SizedBox(height: 12),
              Text(alert.description, style: const TextStyle(height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.task});

  final MedicationTask task;

  @override
  Widget build(BuildContext context) {
    final color = task.completed
        ? const Color(0xFF218765)
        : const Color(0xFFD9822B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              task.completed ? Icons.check_rounded : Icons.schedule_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${clockTime(task.scheduledAt)} · ${task.dosage}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          StatusPill(label: task.completed ? '已确认' : '待进行', color: color),
        ],
      ),
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  const _DeviceSummary({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 13 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 58, color: const Color(0xFFE4EAE7));
  }
}

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(appControllerProvider).alerts;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: alerts.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const _NotificationHealthCard();
        }
        return _AlertListTile(alert: alerts[index - 1]);
      },
    );
  }
}

class _NotificationHealthCard extends StatelessWidget {
  const _NotificationHealthCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF1F7FF),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: Color(0xFF2878B5)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '告警接收能力正常',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 3),
                  Text('App 通知已开启，备用手机号已验证', style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _AlertListTile extends StatelessWidget {
  const _AlertListTile({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    final color = alertColor(alert.severity);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/alerts/${alert.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  alert.severity == AlertSeverity.critical
                      ? Icons.crisis_alert_rounded
                      : alert.severity == AlertSeverity.warning
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        StatusPill(
                          label: alertStatusText(alert.status),
                          color: color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${alert.location} · ${relativeTime(alert.occurredAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      alert.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(appControllerProvider).devices;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: const Color(0xFFF3FAF7),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF218765),
                  size: 30,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '家庭保护在线',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 3),
                      Text('关键设备运行正常，1 台设备需要注意'),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('设备自检已完成')));
                  },
                  child: const Text('一键自检'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final device in devices) ...[
          _DeviceCard(device: device),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('下一步将进入扫码与蓝牙配网')));
          },
          icon: const Icon(Icons.add_rounded),
          label: const Text('添加设备'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final CareDevice device;

  @override
  Widget build(BuildContext context) {
    final color = deviceColor(device.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(deviceIcon(device.icon), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.location} · ${device.statusText}',
                    style: TextStyle(color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最近通信 ${relativeTime(device.lastSeenAt)}'
                    '${device.batteryPercent == null ? '' : ' · 电量 ${device.batteryPercent}%'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  child: Text(
                    '李',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '李俊',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text('家庭管理员 · 手机号已验证'),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.group_outlined,
                title: '家庭成员',
                subtitle: '3 位联系人',
                onTap: () => _showDemoMessage(context, '家庭成员管理'),
              ),
              const Divider(height: 1, indent: 64),
              _SettingsTile(
                icon: Icons.add_alert_outlined,
                title: '告警策略',
                subtitle: 'App → 短信 → 电话',
                onTap: () => _showDemoMessage(context, '告警策略设置'),
              ),
              const Divider(height: 1, indent: 64),
              _SettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                title: '数据与权限',
                subtitle: '查看共享范围和访问记录',
                onTap: () => _showDemoMessage(context, '数据与权限'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: [
              _SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: '通知能力检查',
                subtitle: '当前状态正常',
                onTap: () => _showDemoMessage(context, '通知能力检查'),
              ),
              const Divider(height: 1, indent: 64),
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: '帮助与反馈',
                onTap: () => _showDemoMessage(context, '帮助与反馈'),
              ),
              const Divider(height: 1, indent: 64),
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: '关于安心守护',
                subtitle: '初版 0.1.0',
                onTap: () => _showDemoMessage(context, '关于安心守护'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '本产品用于居家生活照护辅助，不能替代专业医疗、人工护理或紧急救援服务。',
            style: TextStyle(
              color: Color(0xFF68746F),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  static void _showDemoMessage(BuildContext context, String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature将在后续版本接入')));
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 64,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
