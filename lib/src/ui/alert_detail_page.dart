import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class AlertDetailPage extends ConsumerWidget {
  const AlertDetailPage({required this.alertId, super.key});

  final String alertId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(appControllerProvider).alerts;
    final alert = _findAlert(alerts);

    if (alert == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('事件详情')),
        body: const Center(child: Text('事件不存在或已被删除')),
      );
    }

    final color = alertColor(alert.severity);
    return Scaffold(
      appBar: AppBar(title: const Text('事件详情')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _AlertSummary(alert: alert, color: color),
                  const SizedBox(height: 20),
                  _SafetyActions(alert: alert),
                  const SizedBox(height: 24),
                  const SectionHeader(title: '事件进展'),
                  const SizedBox(height: 12),
                  _Timeline(entries: alert.timeline, color: color),
                  const SizedBox(height: 20),
                  const _ResponsibilityNotice(),
                ],
              ),
            ),
            _ActionBar(alert: alert),
          ],
        ),
      ),
    );
  }

  CareAlert? _findAlert(List<CareAlert> alerts) {
    for (final alert in alerts) {
      if (alert.id == alertId) {
        return alert;
      }
    }
    return null;
  }
}

class _AlertSummary extends StatelessWidget {
  const _AlertSummary({required this.alert, required this.color});

  final CareAlert alert;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.crisis_alert_rounded, color: color, size: 30),
                const SizedBox(width: 10),
                StatusPill(label: alertStatusText(alert.status), color: color),
                const Spacer(),
                Text(
                  relativeTime(alert.occurredAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              alert.title,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 5),
                Text(alert.location),
                const SizedBox(width: 16),
                const Icon(Icons.schedule_rounded, size: 18),
                const SizedBox(width: 5),
                Text(clockTime(alert.occurredAt)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              alert.description,
              style: const TextStyle(fontSize: 16, height: 1.55),
            ),
            if (alert.claimedBy != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert.status == AlertStatus.resolved
                      ? '处置人员：${alert.claimedBy}'
                      : '${alert.claimedBy}正在处理此事件',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SafetyActions extends StatelessWidget {
  const _SafetyActions({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    if (alert.status == AlertStatus.resolved) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('正在调用系统电话联系老人')));
            },
            icon: const Icon(Icons.phone_outlined),
            label: const Text('联系老人'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('家庭中枢将在现场播放询问')));
            },
            icon: const Icon(Icons.record_voice_over_outlined),
            label: const Text('再次询问'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
      ],
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, required this.color});

  final List<AlertTimelineEntry> entries;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
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
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        clockTime(entry.occurredAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(entry.detail, style: const TextStyle(height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibilityNotice extends StatelessWidget {
  const _ResponsibilityNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF68746F)),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '系统提示为照护辅助信息，可能存在误报或漏报。如无法确认老人安全，请及时联系当地专业救援服务。',
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
}

class _ActionBar extends ConsumerWidget {
  const _ActionBar({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alert.status == AlertStatus.resolved) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE4EAE7))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: FilledButton.icon(
            onPressed: () {
              if (alert.status == AlertStatus.pending) {
                final success = ref
                    .read(appControllerProvider.notifier)
                    .claimAlert(alert.id);
                _showResult(
                  context,
                  success ? '已认领，其他联系人将同步看到' : '事件状态已变化，请刷新',
                );
                return;
              }
              _confirmResolve(context, ref);
            },
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
                    backgroundColor: const Color(0xFFD43D3D),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmResolve(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认结束事件？'),
        content: const Text('请仅在已联系老人或确认现场安全后结束。该操作会写入处置记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('继续处理'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认安全'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }
    final success = ref
        .read(appControllerProvider.notifier)
        .resolveAlert(alert.id);
    _showResult(context, success ? '事件已完成处置' : '事件状态已变化，请刷新');
  }

  void _showResult(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
