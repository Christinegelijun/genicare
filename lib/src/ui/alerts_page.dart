import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class AlertsPage extends ConsumerStatefulWidget {
  const AlertsPage({super.key});

  @override
  ConsumerState<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends ConsumerState<AlertsPage> {
  int _scope = 0;
  int _type = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final openCount = state.alerts.where((alert) => alert.status != AlertStatus.resolved).length;
    final visible = _visible(state.alerts);

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        ref.read(appControllerProvider.notifier).markSynced();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kPagePadding,
        children: [
          const TabHeading(title: '事件', subtitle: '风险事件和处置记录'),
          const SizedBox(height: 16),
          InfoBanner(
            icon: Icons.notifications_active_outlined,
            title: '告警接收能力正常',
            message: 'App 通知已开启，备用手机号已验证',
            color: colors.info,
            onTap: () => context.push(AppPaths.notifications),
          ),
          const SizedBox(height: 14),
          CareSegmented(
            labels: ['待处理 $openCount', '全部 ${state.alerts.length}'],
            index: _scope,
            onChanged: (value) => setState(() => _scope = value),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < _typeLabels.length; index++)
                ChoiceChip(
                  label: Text(_typeLabels[index]),
                  selected: _type == index,
                  onSelected: (_) => setState(() => _type = index),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const EmptyHint(
              icon: Icons.inbox_outlined,
              title: '没有符合条件的事件',
              message: '换个筛选，或下拉同步最新状态。',
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              _AlertCard(alert: visible[index]),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  static const _typeLabels = ['全部类型', '紧急', '提醒', '记录'];

  List<CareAlert> _visible(List<CareAlert> alerts) {
    final filtered = alerts.where((alert) {
      final scopeOk = _scope == 1 || alert.status != AlertStatus.resolved;
      final typeOk = switch (_type) {
        1 => alert.severity == AlertSeverity.critical,
        2 => alert.severity == AlertSeverity.warning,
        3 => alert.severity == AlertSeverity.info,
        _ => true,
      };
      return scopeOk && typeOk;
    }).toList();
    filtered.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return filtered;
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final CareAlert alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final color = severityColor(colors, alert.severity);
    return CareCard(
      onTap: () => context.push(AppPaths.alert(alert.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: alertIcon(alert.severity), color: color),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: alertStatusText(alert.status), color: color),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${severityLabel(alert.severity)} · ${alert.location} · ${relativeTime(alert.occurredAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  alert.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(height: 1.45),
                ),
                if (alert.claimedBy != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    alert.status == AlertStatus.resolved
                        ? '处置人 ${alert.claimedBy}'
                        : '${alert.claimedBy}正在处理',
                    style: TextStyle(
                      color: colors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
