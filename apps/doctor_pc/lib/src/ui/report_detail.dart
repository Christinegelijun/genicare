import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/state/workbench_controller.dart';
import 'package:venicare_doctor/src/ui/format.dart';
import 'package:venicare_doctor/src/ui/pressure_chart.dart';
import 'package:venicare_shared/venicare_shared.dart';

class ReportDetail extends StatelessWidget {
  const ReportDetail({super.key, required this.delivery});

  final ReportDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final report = delivery.report;
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
      children: [
        _PatientHeader(delivery: delivery),
        if (report.familyNote case final note?) ...[
          const SizedBox(height: 16),
          _Section(
            title: '家属留言',
            icon: Icons.chat_bubble_outline,
            child: Text(note, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
        const SizedBox(height: 16),
        _SummaryRow(report: report),
        const SizedBox(height: 16),
        _Section(
          title: '血压趋势',
          icon: Icons.show_chart,
          child: PressureChart(readings: report.readings),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '全部测量记录（${report.readings.length} 条）',
          icon: Icons.table_rows_outlined,
          child: _ReadingsTable(readings: report.readings),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '用药记录',
          icon: Icons.medication_outlined,
          child: _DoseList(report: report),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '照护事件（${report.events.length}）',
          icon: Icons.notifications_none,
          child: _EventList(events: report.events),
        ),
        const SizedBox(height: 16),
        _Section(
          title: '医生回复',
          icon: Icons.reply_outlined,
          child: _Replies(key: ValueKey(delivery.id), delivery: delivery),
        ),
        const SizedBox(height: 16),
        Text(
          '数据由老人及家属在家中自行测量和记录，未经医疗设备校准，标记线仅为居家参考，不构成诊断依据。'
          '报告编号 ${report.id}，生成于 ${formatDateTime(report.generatedAt)}。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PatientHeader extends StatelessWidget {
  const _PatientHeader({required this.delivery});

  final ReportDelivery delivery;

  @override
  Widget build(BuildContext context) {
    final report = delivery.report;
    final patient = report.patient;
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(patient.name, style: theme.textTheme.headlineSmall),
            const SizedBox(width: 12),
            Text(
              [
                ?patient.gender,
                ageText(patient.birthYear, report.generatedAt),
              ].join(' · '),
              style: muted,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '报告周期 ${formatPeriod(report.periodStart, report.periodEnd)}'
          '　·　${report.totalDays} 天中 ${report.daysWithReadings} 天有测量'
          '　·　由 ${report.requestedBy} 发送于 ${formatDateTime(delivery.sentAt)}',
          style: muted,
        ),
        if (patient.conditions.isNotEmpty ||
            patient.currentMedications.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in patient.conditions)
                Chip(label: Text(c), visualDensity: VisualDensity.compact),
              for (final m in patient.currentMedications)
                Chip(
                  avatar: const Icon(Icons.medication_outlined, size: 16),
                  label: Text(m),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('病史与用药为家属填写，未经核实', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.report});

  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    final bp = report.bloodPressure;
    final hr = report.heartRate;
    final sugar = report.bloodSugar;
    final medication = report.medication;
    final rate = medication.confirmationRate;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          label: '平均血压',
          value: bp == null
              ? '无记录'
              : '${trimNumber(bp.systolic.average)}/${trimNumber(bp.diastolic.average)}',
          detail: bp == null
              ? null
              : '${bp.count} 次 · 最高 ${trimNumber(bp.systolic.max)}/${trimNumber(bp.diastolic.max)}',
          warning: bp == null || bp.aboveReferenceCount == 0
              ? null
              : '${bp.aboveReferenceCount} 次高于 140/90',
        ),
        _SummaryCard(
          label: '平均心率',
          value: hr == null ? '无记录' : '${trimNumber(hr.average)} 次/分',
          detail: hr == null
              ? null
              : '${hr.count} 次 · ${trimNumber(hr.min)}–${trimNumber(hr.max)}',
          warning: hr == null || hr.flaggedCount == 0
              ? null
              : '${hr.flaggedCount} 次超出 50–100',
        ),
        _SummaryCard(
          label: '平均血糖',
          value: sugar == null ? '无记录' : '${trimNumber(sugar.average)} mmol/L',
          detail: sugar == null
              ? null
              : '${sugar.count} 次 · ${trimNumber(sugar.min)}–${trimNumber(sugar.max)}',
          warning: sugar == null || sugar.flaggedCount == 0
              ? null
              : '${sugar.flaggedCount} 次超出参考',
        ),
        _SummaryCard(
          label: '用药确认',
          value: rate == null ? '无计划' : '${(rate * 100).round()}%',
          detail: '${medication.confirmed}/${medication.scheduled} 次已确认',
          warning: medication.missed == 0 ? null : '${medication.missed} 次未确认',
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    this.detail,
    this.warning,
  });

  final String label;
  final String value;
  final String? detail;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(value, style: theme.textTheme.headlineSmall),
              if (detail case final detail?)
                Text(detail, style: theme.textTheme.bodySmall),
              if (warning case final warning?) ...[
                const SizedBox(height: 6),
                Text(
                  warning,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadingsTable extends StatelessWidget {
  const _ReadingsTable({required this.readings});

  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    if (readings.isEmpty) {
      return const Text('报告周期内没有测量记录');
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 56,
        columns: const [
          DataColumn(label: Text('时间')),
          DataColumn(label: Text('类型')),
          DataColumn(label: Text('数值')),
          DataColumn(label: Text('来源')),
          DataColumn(label: Text('原话')),
        ],
        rows: [
          for (final r in readings.reversed)
            DataRow(
              color: r.flagged
                  ? WidgetStatePropertyAll(scheme.errorContainer.withAlpha(90))
                  : null,
              cells: [
                DataCell(Text(formatDateTime(r.measuredAt))),
                DataCell(Text(readingKindText(r.kind))),
                DataCell(
                  Text(
                    readingValueText(r),
                    style: r.flagged
                        ? TextStyle(
                            color: scheme.error,
                            fontWeight: FontWeight.w600,
                          )
                        : null,
                  ),
                ),
                DataCell(Text(readingSourceText(r.source))),
                DataCell(Text(r.transcript ?? '—')),
              ],
            ),
        ],
      ),
    );
  }
}

class _DoseList extends StatelessWidget {
  const _DoseList({required this.report});

  final HealthReport report;

  @override
  Widget build(BuildContext context) {
    if (report.doses.isEmpty) {
      return const Text('报告周期内没有用药计划');
    }
    final missed = report.doses
        .where((d) => d.status == DoseStatus.missed)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          missed.isEmpty
              ? '周期内 ${report.doses.length} 次计划用药均已确认。'
              : '周期内 ${report.doses.length} 次计划用药，以下 ${missed.length} 次未确认：',
        ),
        for (final d in missed)
          ListTile(
            dense: true,
            leading: Icon(Icons.error_outline, color: scheme.error),
            title: Text('${d.planName} · ${formatDateTime(d.scheduledAt)}'),
          ),
        const SizedBox(height: 4),
        Text(
          '「确认」来自老人或家属在 App 中的操作；药仓打开只表示有开盒动作，不代表已服药。',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<CareEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text('报告周期内没有照护事件');
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final e in events.reversed)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.severity == EventSeverity.critical
                  ? Icons.warning_amber_rounded
                  : Icons.info_outline,
              color: e.severity == EventSeverity.critical
                  ? scheme.error
                  : scheme.onSurfaceVariant,
            ),
            title: Text(
              '[${severityText(e.severity)}] ${e.title} · ${e.location}',
            ),
            subtitle: Text(
              '${formatDateTime(e.occurredAt)}'
              '${e.resolution == null ? '' : '　${e.resolution}'}',
            ),
          ),
      ],
    );
  }
}

class _Replies extends ConsumerStatefulWidget {
  const _Replies({super.key, required this.delivery});

  final ReportDelivery delivery;

  @override
  ConsumerState<_Replies> createState() => _RepliesState();
}

class _RepliesState extends ConsumerState<_Replies> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _sending) return;
    setState(() => _sending = true);
    final error = await ref
        .read(selectedDeliveryProvider.notifier)
        .reply(content);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _controller.clear();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reply in widget.delivery.replies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reply.doctorName} · ${formatDateTime(reply.createdAt)}',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(reply.content),
              ],
            ),
          ),
        TextField(
          controller: _controller,
          minLines: 3,
          maxLines: 6,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: '给家属的建议，例如复测要求、是否需要就诊。回复会推送到家属 App。',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send),
            label: Text(_sending ? '发送中…' : '发送回复'),
          ),
        ),
      ],
    );
  }
}
