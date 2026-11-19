import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/health_records_page.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _room = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final alert = state.activeAlerts.isEmpty ? null : state.activeAlerts.first;
    final rooms = [
      '全屋',
      ...{for (final device in state.devices) device.location},
    ];
    final room = _room < rooms.length ? _room : 0;
    final devices = room == 0
        ? state.devices
        : state.devices
              .where((device) => device.location == rooms[room])
              .toList();
    final online = state.devices
        .where((d) => d.status == DeviceStatus.online)
        .length;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kPagePadding,
        children: [
          _HomeHeader(
            familyName: state.familyName,
            recipient: state.recipient,
            openCount: state.activeAlerts.length,
          ),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          _QuickActions(alertId: alert?.id),
          const SizedBox(height: 28),
          SectionHeader(
            title: '今日照护',
            action: SectionLink(
              label: '管理计划',
              onTap: () => context.push(AppPaths.medication),
            ),
          ),
          const SizedBox(height: 12),
          CareCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < state.medicationTasks.length;
                  index++
                ) ...[
                  _MedicationRow(
                    task: state.medicationTasks[index],
                    onTap: () => context.push(AppPaths.medication),
                  ),
                  if (index != state.medicationTasks.length - 1)
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 16,
                      color: context.care.line,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: '${state.recipient.name}自己记录的',
            action: SectionLink(
              label: '全部记录',
              onTap: () => context.push(AppPaths.health),
            ),
          ),
          const SizedBox(height: 12),
          CareCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            onTap: () => context.push(AppPaths.health),
            child: state.healthRecords.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '还没有记录。老人模式里说一句「血压 130 85」就能记下来。',
                      style: TextStyle(color: context.care.muted, height: 1.45),
                    ),
                  )
                : Column(
                    children: [
                      for (final record
                          in ([...state.healthRecords]..sort(
                                (a, b) => b.recordedAt.compareTo(a.recordedAt),
                              ))
                              .take(2))
                        HealthRecordRow(record: record),
                    ],
                  ),
          ),
          const SizedBox(height: 28),
          SectionHeader(
            title: '家庭设备',
            action: SectionLink(
              label: '$online/${state.devices.length} 在线',
              onTap: () =>
                  ref.read(appControllerProvider.notifier).selectTab(2),
            ),
          ),
          const SizedBox(height: 6),
          RoomTabs(
            labels: rooms,
            index: room,
            onChanged: (value) => setState(() => _room = value),
          ),
          const SizedBox(height: 12),
          if (devices.isEmpty)
            const EmptyHint(
              icon: Icons.sensors_off_outlined,
              title: '这个房间还没有设备',
              message: '可以在设备页添加。',
            )
          else
            DeviceGrid(
              devices: devices,
              onTap: (device) => context.push(AppPaths.device(device.id)),
            ),
          const SizedBox(height: 24),
          Center(
            child: SoftPill(
              icon: Icons.add_rounded,
              label: '添加设备',
              onTap: () => context.push(AppPaths.addDevice),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    ref.read(appControllerProvider.notifier).markSynced();
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.familyName,
    required this.recipient,
    required this.openCount,
  });

  final String familyName;
  final CareRecipient recipient;
  final int openCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        familyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(fontSize: 24),
                      ),
                    ),
                    Icon(Icons.expand_more_rounded, color: colors.muted),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${greetingFor(DateTime.now())}，${weekdayLabel(DateTime.now())}',
                  style: TextStyle(color: colors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          _RoundIcon(
            tooltip: '事件',
            onTap: () => ref.read(appControllerProvider.notifier).selectTab(1),
            child: Badge(
              isLabelVisible: openCount > 0,
              smallSize: 8,
              backgroundColor: colors.urgent,
              child: Icon(
                Icons.notifications_none_rounded,
                color: colors.ink,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _RoundIcon(
            tooltip: '添加设备',
            onTap: () => context.push(AppPaths.addDevice),
            child: Icon(Icons.add_rounded, color: colors.ink, size: 24),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: colors.card.withValues(alpha: 0.7),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Center(child: child)),
        ),
      ),
    );
  }
}

class _UrgentAlertCard extends ConsumerWidget {
  const _UrgentAlertCard({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    return CareCard(
      onTap: () => context.push(AppPaths.alert(alert.id)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.urgentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.crisis_alert_rounded,
                  color: colors.urgent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '紧急事件待处理',
                      style: TextStyle(
                        color: colors.urgent,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Text(
                relativeTime(alert.occurredAt),
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            alert.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 4),
          Text(
            '${alert.location} · ${friendlyDateTime(alert.occurredAt)} · ${alertStatusText(alert.status)}',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => context.push(AppPaths.alert(alert.id)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: colors.primary.withValues(alpha: 0.1),
                    foregroundColor: colors.primary,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('查看并处理'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () =>
                      showCallSheet(context, ref, alertId: alert.id),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: colors.muted.withValues(alpha: 0.1),
                    foregroundColor: colors.ink,
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: const Text('打电话'),
                ),
              ),
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
    final colors = context.care;
    final gradient = switch (recipient.protectionLevel) {
      ProtectionLevel.attention ||
      ProtectionLevel.incomplete => CareGradients.attention,
      ProtectionLevel.urgent => CareGradients.urgent,
      ProtectionLevel.unknown => CareGradients.unknown,
      ProtectionLevel.normal => CareGradients.calm,
    };
    return CareCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: gradient.last,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${recipient.name} · ${protectionLabel(recipient.protectionLevel)}',
                      style: TextStyle(
                        color: gradient.last,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  recipient.statusText,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(height: 1.35),
                ),
                const SizedBox(height: 6),
                Text(
                  '${recipient.presenceText} · 更新于${relativeTime(recipient.lastUpdatedAt)}',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
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
        icon: Icons.phone_in_talk_rounded,
        label: '联系老人',
        color: colors.primary,
        onTap: () => showCallSheet(context, ref, alertId: alertId),
      ),
      (
        icon: Icons.medication_rounded,
        label: '用药计划',
        color: colors.warning,
        onTap: () => context.push(AppPaths.medication),
      ),
      (
        icon: Icons.medical_services_outlined,
        label: '预约医生',
        color: colors.info,
        onTap: () => context.push(AppPaths.consult),
      ),
      (
        icon: Icons.groups_rounded,
        label: '家庭成员',
        color: const Color(0xFF7C5CFA),
        onTap: () => context.push(AppPaths.family),
      ),
    ];

    return Row(
      children: [
        for (final action in actions)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: action.onTap,
              child: Column(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: careShadow(colors),
                    ),
                    child: Icon(action.icon, color: action.color, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.ink, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${clockTime(task.scheduledAt)} · ${task.compartment} · ${task.dosage}',
                    style: TextStyle(color: colors.muted, fontSize: 12),
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
