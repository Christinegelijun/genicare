import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final alert = state.activeAlerts.isEmpty ? null : state.activeAlerts.first;

    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kPagePadding,
        children: [
          _HomeHeader(recipient: state.recipient, openCount: state.activeAlerts.length),
          const SizedBox(height: 16),
          if (alert != null)
            _UrgentAlertCard(alert: alert)
          else
            _StatusHero(recipient: state.recipient),
          if (state.protectionNote != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.shield_outlined,
              title: '保护范围有变化',
              message: state.protectionNote!,
              color: context.care.warning,
            ),
          ],
          const SizedBox(height: 16),
          _QuickActions(alertId: alert?.id),
          const SizedBox(height: 26),
          SectionHeader(
            title: '今日照护',
            action: TextButton(
              onPressed: () => context.push(AppPaths.medication),
              child: const Text('管理计划'),
            ),
          ),
          const SizedBox(height: 10),
          CareCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var index = 0; index < state.medicationTasks.length; index++) ...[
                  _MedicationRow(
                    task: state.medicationTasks[index],
                    onTap: () => context.push(AppPaths.medication),
                  ),
                  if (index != state.medicationTasks.length - 1)
                    Divider(height: 1, indent: 72, color: context.care.line),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          SectionHeader(
            title: '家庭设备',
            action: TextButton(
              onPressed: () => ref.read(appControllerProvider.notifier).selectTab(2),
              child: const Text('查看全部'),
            ),
          ),
          const SizedBox(height: 10),
          _DeviceSummary(state: state),
        ],
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    ref.read(appControllerProvider.notifier).markSynced();
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.recipient, required this.openCount});

  final CareRecipient recipient;
  final int openCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final now = DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greetingFor(now),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${recipient.name} · ${recipient.relationship}',
                style: TextStyle(color: colors.muted, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                recipient.presenceText,
                style: TextStyle(
                  color: recipient.protectionLevel == ProtectionLevel.urgent
                      ? colors.urgent
                      : colors.ink,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '事件',
          onPressed: () => ref.read(appControllerProvider.notifier).selectTab(1),
          icon: Badge(
            isLabelVisible: openCount > 0,
            label: Text('$openCount'),
            backgroundColor: colors.urgent,
            child: const Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    );
  }
}

class _UrgentAlertCard extends StatelessWidget {
  const _UrgentAlertCard({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return CareCard(
      onTap: () => context.push(AppPaths.alert(alert.id)),
      color: colors.urgentSoft,
      borderColor: colors.urgent.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.crisis_alert_rounded, color: colors.urgent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '紧急事件待处理',
                  style: TextStyle(
                    color: colors.urgent,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              StatusPill(
                label: alertStatusText(alert.status),
                color: colors.urgent,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(alert.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            '${alert.location} · ${relativeTime(alert.occurredAt)} · ${friendlyDateTime(alert.occurredAt)}',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 10),
          Text(
            alert.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.5, fontSize: 16),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '查看并处理',
                style: TextStyle(
                  color: colors.urgent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: colors.urgent, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.recipient});

  final CareRecipient recipient;

  @override
  Widget build(BuildContext context) {
    final gradient = switch (recipient.protectionLevel) {
      ProtectionLevel.attention || ProtectionLevel.incomplete =>
        CareGradients.attention,
      ProtectionLevel.urgent => CareGradients.urgent,
      ProtectionLevel.unknown => CareGradients.unknown,
      ProtectionLevel.normal => CareGradients.calm,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  protectionLabel(recipient.protectionLevel),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recipient.statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '更新于${relativeTime(recipient.lastUpdatedAt)} · ${friendlyDateTime(recipient.lastUpdatedAt)}',
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.alertId});

  final String? alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final actions = [
      (
        icon: Icons.phone_outlined,
        label: '联系老人',
        onTap: () => showCallSheet(context, ref, alertId: alertId),
      ),
      (
        icon: Icons.medication_outlined,
        label: '用药计划',
        onTap: () => context.push(AppPaths.medication),
      ),
      (
        icon: Icons.health_and_safety_outlined,
        label: '设备自检',
        onTap: () => context.push(AppPaths.selfCheck),
      ),
    ];

    return Row(
      children: [
        for (var index = 0; index < actions.length; index++) ...[
          Expanded(
            child: CareCard(
              onTap: actions[index].onTap,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(
                children: [
                  Icon(actions[index].icon, color: colors.primary),
                  const SizedBox(height: 6),
                  Text(
                    actions[index].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (index != actions.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _MedicationRow extends StatelessWidget {
  const _MedicationRow({required this.task, required this.onTap});

  final MedicationTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final phase = medicationPhase(task);
    final color = medicationTone(colors, phase);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            IconBadge(
              icon: phase == MedicationPhase.done
                  ? Icons.check_rounded
                  : Icons.schedule_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${clockTime(task.scheduledAt)} · ${task.compartment} · ${task.dosage}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            StatusPill(label: medicationStatusText(task), color: color),
          ],
        ),
      ),
    );
  }
}

class _DeviceSummary extends StatelessWidget {
  const _DeviceSummary({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final online = state.devices.where((d) => d.status == DeviceStatus.online).length;
    final warning = state.devices.where((d) => d.status == DeviceStatus.warning).length;
    final offline = state.devices.where((d) => d.status == DeviceStatus.offline).length;
    return CareCard(
      child: Column(
        children: [
          Row(
            children: [
              _Count(value: '$online', label: '在线', color: colors.primary),
              _Count(value: '$warning', label: '注意', color: colors.warning),
              _Count(value: '$offline', label: '离线', color: colors.urgent),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '最近同步 ${relativeTime(state.lastSyncedAt)} · ${friendlyDateTime(state.lastSyncedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
