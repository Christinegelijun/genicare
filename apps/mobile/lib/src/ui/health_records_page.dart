import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class HealthRecordsPage extends ConsumerWidget {
  const HealthRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final records = [...state.healthRecords]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return Scaffold(
      appBar: AppBar(title: const Text('健康记录')),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.record_voice_over_outlined,
            title: '${state.recipient.name}在老人模式里自己记录',
            message: '数据由老人说话或打字录入，仅供照护参考，不能替代医生诊断。',
            color: context.care.info,
          ),
          const SizedBox(height: 14),
          if (records.isEmpty)
            const EmptyHint(
              icon: Icons.mic_none_rounded,
              title: '还没有记录',
              message: '把老人的手机切到老人模式，说一句「血压 130 85」就能记下来。',
            )
          else
            CareCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < records.length; i++) ...[
                    HealthRecordRow(record: records[i]),
                    if (i != records.length - 1)
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
        ],
      ),
    );
  }
}

class HealthRecordRow extends StatelessWidget {
  const HealthRecordRow({required this.record, super.key});

  final HealthRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final high = isPressureAboveReference(record);
    final tone = high ? colors.warning : colors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: healthRecordIcon(record.kind), color: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthRecordTitle(record),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${friendlyDateTime(record.recordedAt)} · ${record.recordedBy}${recordSourceLabel(record.source)}',
                  style: TextStyle(color: colors.muted, fontSize: 12),
                ),
                if (record.transcript != null &&
                    record.source == RecordSource.voice) ...[
                  const SizedBox(height: 4),
                  Text(
                    '“${record.transcript}”',
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (high) StatusPill(label: '高于 140/90', color: colors.warning),
        ],
      ),
    );
  }
}
