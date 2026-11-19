import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/state/admin_controller.dart';
import 'package:venicare_doctor/src/state/workbench_controller.dart';
import 'package:venicare_doctor/src/ui/admin_page.dart';
import 'package:venicare_doctor/src/ui/format.dart';
import 'package:venicare_doctor/src/ui/report_detail.dart';
import 'package:venicare_shared/venicare_shared.dart';

class WorkbenchPage extends ConsumerWidget {
  const WorkbenchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(doctorProfileProvider).value;
    final isAdmin = profile?.isAdmin ?? false;
    final section = isAdmin
        ? ref.watch(workbenchSectionProvider)
        : WorkbenchSection.reports;
    return Scaffold(
      appBar: AppBar(
        title: const Text('安心守护 · 医生工作台'),
        actions: [
          const _PresenceButton(),
          const SizedBox(width: 12),
          if (profile != null)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${profile.name}　${profile.title}　'
                  '${profile.organization} ${profile.department}',
                ),
              ),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isAdmin) ...[
            NavigationRail(
              selectedIndex: section.index,
              labelType: NavigationRailLabelType.all,
              onDestinationSelected: (index) => ref
                  .read(workbenchSectionProvider.notifier)
                  .set(WorkbenchSection.values[index]),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.inbox_outlined),
                  selectedIcon: Icon(Icons.inbox),
                  label: Text('报告'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.event_note_outlined),
                  selectedIcon: Icon(Icons.event_note),
                  label: Text('排班与接诊'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            child: switch (section) {
              WorkbenchSection.reports => const _ReportsView(),
              WorkbenchSection.admin => const AdminPage(),
            },
          ),
        ],
      ),
    );
  }
}

class _PresenceButton extends ConsumerWidget {
  const _PresenceButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presence = ref.watch(presenceProvider).value;
    if (presence == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Color colorOf(DoctorPresence p) => switch (p) {
      DoctorPresence.online => doctorStatusColor(scheme, DoctorStatus.idle),
      DoctorPresence.away => doctorStatusColor(scheme, DoctorStatus.away),
      DoctorPresence.offline => scheme.outline,
    };
    return PopupMenuButton<DoctorPresence>(
      tooltip: '切换接诊状态',
      initialValue: presence,
      onSelected: (value) async {
        try {
          await ref.read(presenceProvider.notifier).set(value);
        } on Object catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('$error')));
          }
        }
      },
      itemBuilder: (context) => [
        for (final p in DoctorPresence.values)
          PopupMenuItem(
            value: p,
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: colorOf(p)),
                const SizedBox(width: 8),
                Text(presenceText(p)),
              ],
            ),
          ),
      ],
      child: Chip(
        avatar: Icon(Icons.circle, size: 10, color: colorOf(presence)),
        label: Text(presenceText(presence)),
        deleteIcon: const Icon(Icons.arrow_drop_down),
        onDeleted: null,
      ),
    );
  }
}

class _ReportsView extends ConsumerWidget {
  const _ReportsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDeliveryProvider);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(width: 360, child: _Inbox()),
        const VerticalDivider(width: 1),
        Expanded(
          child: switch (selected) {
            null => const _Placeholder(text: '从左侧选择一份报告查看'),
            AsyncData(:final value) => ReportDetail(delivery: value),
            AsyncError(:final error) => _Placeholder(text: '$error'),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _Inbox extends ConsumerWidget {
  const _Inbox();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(inboxFilterProvider);
    final inbox = ref.watch(inboxProvider);
    final selectedId = ref.watch(selectedDeliveryProvider)?.value?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: [
              Text('收到的报告', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: () => ref.invalidate(inboxProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            children: [
              for (final (label, status) in const [
                ('全部', null),
                ('未读', DeliveryStatus.sent),
                ('已读', DeliveryStatus.read),
                ('已回复', DeliveryStatus.replied),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: filter == status,
                  onSelected: (_) =>
                      ref.read(inboxFilterProvider.notifier).set(status),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: switch (inbox) {
            AsyncData(:final value) when value.isEmpty => const _Placeholder(
              text: '暂无报告',
            ),
            AsyncData(:final value) => ListView.separated(
              itemCount: value.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _InboxTile(
                item: value[index],
                selected: value[index].deliveryId == selectedId,
              ),
            ),
            AsyncError(:final error) => _Placeholder(text: '$error'),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ],
    );
  }
}

class _InboxTile extends ConsumerWidget {
  const _InboxTile({required this.item, required this.selected});

  final ReportInboxItem item;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final unread = item.status == DeliveryStatus.sent;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withAlpha(110),
      onTap: () =>
          ref.read(selectedDeliveryProvider.notifier).open(item.deliveryId),
      leading: CircleAvatar(child: Text(item.patientName.characters.first)),
      title: Row(
        children: [
          Text(
            item.patientName,
            style: TextStyle(
              fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            deliveryStatusText(item.status),
            style: TextStyle(
              fontSize: 12,
              color: unread ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatPeriod(item.periodStart, item.periodEnd)),
          if (item.flaggedReadingCount > 0 || item.criticalEventCount > 0)
            Text(
              [
                if (item.flaggedReadingCount > 0)
                  '${item.flaggedReadingCount} 条读数超参考线',
                if (item.criticalEventCount > 0)
                  '${item.criticalEventCount} 次紧急事件',
              ].join(' · '),
              style: TextStyle(color: scheme.error),
            ),
        ],
      ),
      trailing: Text(
        formatDateTime(item.sentAt),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
