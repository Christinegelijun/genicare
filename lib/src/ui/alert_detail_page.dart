import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class AlertDetailPage extends ConsumerWidget {
  const AlertDetailPage({required this.alertId, super.key});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alert = _find(ref.watch(appControllerProvider).alerts);
    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('事件详情')),
        body: const MissingBody(message: '事件不存在或已被删除'),
      );
    }

    final colors = context.care;
    final color = severityColor(colors, alert.severity);
    return Scaffold(
      appBar: AppBar(title: const Text('事件详情')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                _Summary(alert: alert, color: color),
                if (alert.status != AlertStatus.resolved) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showCallSheet(context, ref, alertId: alert.id),
                          icon: const Icon(Icons.phone_outlined),
                          label: const Text('联系老人'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => showVoiceSheet(context, ref, alertId: alert.id),
                          icon: const Icon(Icons.record_voice_over_outlined),
                          label: const Text('再次询问'),
                        ),
                      ),
                    ],
                  ),
                  if (alert.status == AlertStatus.claimed) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _askForHelp(context, ref, alert.id),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('需要继续协助'),
                    ),
                  ],
                ],
                const SizedBox(height: 22),
                const SectionHeader(title: '事件进展'),
                const SizedBox(height: 10),
                _Timeline(entries: alert.timeline, color: color),
                const SizedBox(height: 16),
                const _Notice(),
              ],
            ),
          ),
          _ActionBar(alert: alert),
        ],
      ),
    );
  }

  CareAlert? _find(List<CareAlert> alerts) {
    for (final alert in alerts) {
      if (alert.id == alertId) {
        return alert;
      }
    }
    return null;
  }

  Future<void> _askForHelp(BuildContext context, WidgetRef ref, String id) async {
    final choice = await showChoiceSheet(
      context,
      title: '需要继续协助',
      message: '选择当前情况，会写入处置记录，事件保持处理中。',
      options: const ['暂时联系不上', '已到场，仍需协助', '已通知其他家属', '准备联系当地救援'],
    );
    if (choice == null || !context.mounted) {
      return;
    }
    final ok = ref.read(appControllerProvider.notifier).appendTimeline(
      id,
      title: '需要继续协助',
      detail: choice,
    );
    if (!context.mounted) {
      return;
    }
    showCareToast(context, ok ? '已记录：$choice' : '事件状态已变化');
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.alert, required this.color});

  final CareAlert alert;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return CareCard(
      color: color.withValues(alpha: 0.08),
      borderColor: color.withValues(alpha: 0.28),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alertIcon(alert.severity), color: color),
              const SizedBox(width: 8),
              StatusPill(label: severityLabel(alert.severity), color: color),
              const SizedBox(width: 8),
              StatusPill(label: alertStatusText(alert.status), color: color),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 14),
          Text(alert.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${alert.location} · ${friendlyDateTime(alert.occurredAt)} · ${relativeTime(alert.occurredAt)}',
            style: TextStyle(color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            alert.description,
            style: const TextStyle(fontSize: 16, height: 1.55),
          ),
          if (alert.claimedBy != null) ...[
            const SizedBox(height: 14),
            Text(
              alert.status == AlertStatus.resolved
                  ? '处置人：${alert.claimedBy}'
                  : '${alert.claimedBy}正在处理此事件',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, required this.color});

  final List<AlertTimelineEntry> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CareCard(
      child: Column(
        children: [
          for (var index = 0; index < entries.length; index++)
            _TimelineEntry(
              entry: entries[index],
              color: color,
              isLast: index == entries.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.entry,
    required this.color,
    required this.isLast,
  });

  final AlertTimelineEntry entry;
  final Color color;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: color.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(entry.detail, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 4),
                  Text(
                    friendlyDateTime(entry.occurredAt),
                    style: TextStyle(color: colors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice();

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: colors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '系统提示用于照护辅助，可能误报或漏报。无法确认安全时，请联系当地专业救援。',
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alert.status == AlertStatus.resolved) {
      return const SizedBox.shrink();
    }
    final colors = context.care;
    final mine = alert.claimedBy == null || alert.claimedBy == '我';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (alert.status == AlertStatus.claimed)
                Row(
                  children: [
                    if (mine)
                      Expanded(
                        child: TextButton(
                          onPressed: () => _release(context, ref),
                          child: const Text('解除认领'),
                        ),
                      ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _falseAlarm(context, ref),
                        child: Text(
                          '标记误报',
                          style: TextStyle(color: colors.warning),
                        ),
                      ),
                    ),
                  ],
                ),
              if (alert.status == AlertStatus.pending)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _falseAlarm(context, ref),
                    child: Text('标记误报', style: TextStyle(color: colors.warning)),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => _primary(context, ref),
                icon: Icon(
                  alert.status == AlertStatus.pending
                      ? Icons.pan_tool_alt_outlined
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  alert.status == AlertStatus.pending ? '我来处理' : '老人安全，结束事件',
                ),
                style: alert.severity == AlertSeverity.critical
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFC53636),
                        foregroundColor: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _primary(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    if (alert.status == AlertStatus.pending) {
      final success = controller.claimAlert(alert.id);
      showCareToast(context, success ? '已认领，其他联系人将同步看到' : '事件状态已变化，请刷新');
      return;
    }
    _confirmResolve(context, ref);
  }

  Future<void> _confirmResolve(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCareConfirm(
      context,
      title: '确认结束事件？',
      message: '请仅在已联系老人或确认现场安全后结束。该操作会写入处置记录。',
      confirmLabel: '确认安全',
      cancelLabel: '继续处理',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final success = ref.read(appControllerProvider.notifier).resolveAlert(alert.id);
    if (!context.mounted) {
      return;
    }
    showCareToast(context, success ? '事件已完成处置' : '事件状态已变化，请刷新');
  }

  Future<void> _release(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCareConfirm(
      context,
      title: '解除认领？',
      message: '解除后，事件会重新变成待处理，其他联系人可以接手。',
      confirmLabel: '解除认领',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final success = ref.read(appControllerProvider.notifier).releaseAlert(alert.id);
    if (!context.mounted) {
      return;
    }
    showCareToast(context, success ? '已解除认领' : '当前不能解除认领');
  }

  Future<void> _falseAlarm(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCareConfirm(
      context,
      title: '标记为误报？',
      message: '仅在确认现场没有风险后使用。事件会结束，并留下误报记录。',
      confirmLabel: '确认误报',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    final success = ref.read(appControllerProvider.notifier).resolveAlert(
      alert.id,
      resultTitle: '已标记为误报',
      resultDetail: '家属确认现场无风险，本次事件按误报结束。',
    );
    if (!context.mounted) {
      return;
    }
    showCareToast(context, success ? '已按误报结束事件' : '事件状态已变化，请刷新');
  }
}
