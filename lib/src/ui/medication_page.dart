import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class MedicationPage extends ConsumerWidget {
  const MedicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(appControllerProvider).medicationTasks;
    return Scaffold(
      appBar: AppBar(title: const Text('用药计划')),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.health_and_safety_outlined,
            title: '这里不是处方',
            message: '计划由家属录入。本产品不提供诊断、药物推荐或剂量建议，只记录是否按计划确认。',
            color: context.care.warning,
          ),
          const SizedBox(height: 14),
          for (final task in tasks) ...[
            _TaskCard(task: task),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final MedicationTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final phase = medicationPhase(task);
    final color = medicationTone(colors, phase);
    return CareCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              StatusPill(label: medicationStatusText(task), color: color),
            ],
          ),
          const SizedBox(height: 8),
          SpecRow(label: '时间', value: '${task.scheduleText} · ${friendlyDateTime(task.scheduledAt)}'),
          SpecRow(label: '药仓', value: '${task.compartment} · ${task.dosage}'),
          SpecRow(label: '周期', value: task.periodLabel),
          SpecRow(label: '提醒', value: task.remindRule),
          SpecRow(label: '录入', value: '${task.createdBy} · ${friendlyDateTime(task.updatedAt)}'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('未确认时通知家属', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('只通知是否确认，不包含用药建议'),
            value: task.notifyFamilyIfMissed,
            onChanged: (_) {
              ref.read(appControllerProvider.notifier).toggleMedicationNotify(task.id);
            },
          ),
          const SizedBox(height: 4),
          if (phase == MedicationPhase.done)
            OutlinedButton(
              onPressed: () => _setCompleted(context, ref, completed: false),
              child: const Text('撤销确认'),
            )
          else
            FilledButton(
              onPressed: () => _setCompleted(context, ref, completed: true),
              child: Text(phase == MedicationPhase.upcoming ? '提前确认' : '标记已确认'),
            ),
        ],
      ),
    );
  }

  Future<void> _setCompleted(
    BuildContext context,
    WidgetRef ref, {
    required bool completed,
  }) async {
    final upcoming = medicationPhase(task) == MedicationPhase.upcoming;
    final confirmed = await showCareConfirm(
      context,
      title: completed ? '确认这次用药？' : '撤销确认？',
      message: completed
          ? (upcoming
                ? '计划时间还没到。请只在老人已经完成这次操作后确认。'
                : '确认后会计入今日照护记录，不代表药物或剂量建议。')
          : '撤销后，这项计划会回到未确认。',
      confirmLabel: completed ? '确认' : '撤销',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).setMedicationCompleted(
      task.id,
      completed: completed,
    );
    if (!context.mounted) {
      return;
    }
    showCareToast(context, completed ? '已记录确认' : '已撤销确认');
  }
}
