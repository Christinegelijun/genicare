import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_doctor/src/state/admin_controller.dart';
import 'package:venicare_doctor/src/ui/format.dart';
import 'package:venicare_shared/venicare_shared.dart';

Color doctorStatusColor(ColorScheme scheme, DoctorStatus status) {
  return switch (status) {
    DoctorStatus.idle => const Color(0xFF1E9E5A),
    DoctorStatus.consulting => scheme.primary,
    DoctorStatus.away => const Color(0xFFD9822B),
    DoctorStatus.offShift => scheme.onSurfaceVariant,
    DoctorStatus.offline => scheme.outline,
  };
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '实时看板'),
              Tab(text: '排班表'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [_LiveBoard(), _WeekScheduleView()]),
          ),
        ],
      ),
    );
  }
}

class _LiveBoard extends ConsumerStatefulWidget {
  const _LiveBoard();

  @override
  ConsumerState<_LiveBoard> createState() => _LiveBoardState();
}

class _LiveBoardState extends ConsumerState<_LiveBoard> {
  late final Timer _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ref.invalidate(adminBoardProvider),
    );
  }

  @override
  void dispose() {
    _refresh.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(adminBoardProvider);
    final departmentId = ref.watch(boardDepartmentProvider);
    return switch (board) {
      AsyncValue(:final value?) => ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        children: [
          _BoardSummary(board: value),
          const SizedBox(height: 16),
          _DepartmentFilter(departments: value.departments),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              for (final row in _sorted(value.rows))
                if (departmentId == null ||
                    row.doctor.departmentId == departmentId)
                  _DoctorBoardCard(row: row),
            ],
          ),
        ],
      ),
      AsyncError(:final error) => _Message(text: '$error'),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  List<DoctorBoardRow> _sorted(List<DoctorBoardRow> rows) {
    return [...rows]..sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      return byStatus != 0
          ? byStatus
          : b.waiting.length.compareTo(a.waiting.length);
    });
  }
}

class _BoardSummary extends ConsumerWidget {
  const _BoardSummary({required this.board});

  final AdminBoard board;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = board.rows;
    int count(DoctorStatus status) =>
        rows.where((r) => r.status == status).length;
    final shifts = rows.expand((r) => r.todayShifts);
    final booked = shifts.fold(0, (sum, s) => sum + s.booked);
    final capacity = shifts.fold(0, (sum, s) => sum + s.shift.capacity);
    final waiting = rows.fold(0, (sum, r) => sum + r.waiting.length);
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Metric(
                label: '在线医生',
                value: '${rows.where((r) => r.presence == DoctorPresence.online).length}/${rows.length}',
              ),
              _Metric(
                label: '空闲可咨询',
                value: '${count(DoctorStatus.idle)}',
                color: doctorStatusColor(scheme, DoctorStatus.idle),
              ),
              _Metric(
                label: '接诊中',
                value: '${count(DoctorStatus.consulting)}',
                color: scheme.primary,
              ),
              _Metric(
                label: '排队人数',
                value: '$waiting',
                color: waiting > 0 ? scheme.error : null,
              ),
              _Metric(label: '今日预约 / 号源', value: '$booked/$capacity'),
            ],
          ),
        ),
        Text(
          '更新于 ${formatClock(board.generatedAt)}，每 30 秒自动刷新',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: () => ref.invalidate(adminBoardProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepartmentFilter extends ConsumerWidget {
  const _DepartmentFilter({required this.departments});

  final List<Department> departments;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(boardDepartmentProvider);
    final notifier = ref.read(boardDepartmentProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('全部科室'),
          selected: selected == null,
          onSelected: (_) => notifier.set(null),
        ),
        for (final d in departments)
          ChoiceChip(
            label: Text(d.name),
            selected: selected == d.id,
            onSelected: (_) => notifier.set(d.id),
          ),
      ],
    );
  }
}

class _DoctorBoardCard extends StatelessWidget {
  const _DoctorBoardCard({required this.row});

  final DoctorBoardRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final statusColor = doctorStatusColor(scheme, row.status);
    final current = row.current;
    const shown = 4;
    return SizedBox(
      width: 340,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(row.doctor.name.characters.first),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${row.doctor.name}  ${row.doctor.title}',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(row.doctor.department, style: muted),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: doctorStatusText(row.status),
                    color: statusColor,
                  ),
                ],
              ),
              const Divider(height: 24),
              _Line(
                label: '正在接诊',
                child: Text(
                  current == null
                      ? '—'
                      : '${current.patientName} · ${consultModeText(current.mode)} · ${formatClock(current.startsAt)} 号',
                ),
              ),
              _Line(
                label: '排队 ${row.waiting.length} 人',
                child: row.waiting.isEmpty
                    ? const Text('—')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final (i, a) in row.waiting.take(shown).indexed)
                            Text(
                              '${i + 1}. ${a.patientName}　${formatClock(a.startsAt)} · ${consultModeText(a.mode)}',
                            ),
                          if (row.waiting.length > shown)
                            Text(
                              '还有 ${row.waiting.length - shown} 人',
                              style: muted,
                            ),
                        ],
                      ),
              ),
              _Line(
                label: '今日稍后',
                child: Text(
                  row.laterToday == 0 ? '无预约' : '已约 ${row.laterToday} 人',
                ),
              ),
              _Line(
                label: '今日排班',
                child: row.todayShifts.isEmpty
                    ? Text('今日无排班', style: muted)
                    : Column(
                        children: [
                          for (final load in row.todayShifts)
                            _LoadBar(load: load),
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

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.load});

  final ShiftLoad load;

  @override
  Widget build(BuildContext context) {
    final capacity = load.shift.capacity;
    final ratio = capacity == 0 ? 0.0 : load.booked / capacity;
    final color = _loadColor(Theme.of(context).colorScheme, ratio);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(formatSpan(load.shift.startsAt, load.shift.endsAt)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: math.min(ratio, 1),
              color: color,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Text('${load.booked}/$capacity'),
        ],
      ),
    );
  }
}

Color _loadColor(ColorScheme scheme, double ratio) {
  if (ratio >= 0.9) return scheme.error;
  if (ratio >= 0.6) return const Color(0xFFD9822B);
  return const Color(0xFF1E9E5A);
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _WeekScheduleView extends ConsumerWidget {
  const _WeekScheduleView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final week = ref.watch(scheduleWeekProvider);
    final schedule = ref.watch(weekScheduleProvider);
    final notifier = ref.read(scheduleWeekProvider.notifier);
    final end = week.add(const Duration(days: 6));
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '上一周',
              onPressed: () => notifier.shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${formatDate(week)} 至 ${formatDate(end)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              tooltip: '下一周',
              onPressed: () => notifier.shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(onPressed: notifier.reset, child: const Text('本周')),
            const Spacer(),
            const _LoadLegend(),
          ],
        ),
        const SizedBox(height: 12),
        if (schedule.value?.departments case final departments?) ...[
          _DepartmentFilter(departments: departments),
          const SizedBox(height: 16),
        ],
        switch (schedule) {
          AsyncValue(:final value?) => _ScheduleTable(schedule: value),
          AsyncError(:final error) => _Message(text: '$error'),
          _ => const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _LoadLegend extends StatelessWidget {
  const _LoadLegend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget dot(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: 12),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(_loadColor(scheme, 0), '宽松'),
        dot(_loadColor(scheme, 0.6), '较满 ≥60%'),
        dot(_loadColor(scheme, 0.9), '将满 ≥90%'),
      ],
    );
  }
}

class _ScheduleTable extends ConsumerWidget {
  const _ScheduleTable({required this.schedule});

  final WeekSchedule schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentId = ref.watch(boardDepartmentProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [
      for (var i = 0; i < schedule.days; i++)
        DateTime(
          schedule.from.toLocal().year,
          schedule.from.toLocal().month,
          schedule.from.toLocal().day + i,
        ),
    ];
    final order = {
      for (final (i, d) in schedule.departments.indexed) d.id: i,
    };
    final doctors =
        schedule.doctors
            .where((d) => departmentId == null || d.departmentId == departmentId)
            .toList()
          ..sort(
            (a, b) => (order[a.departmentId] ?? 99).compareTo(
              order[b.departmentId] ?? 99,
            ),
          );
    final byCell = <(String, DateTime), List<ShiftLoad>>{};
    for (final load in schedule.shifts) {
      final start = load.shift.startsAt.toLocal();
      byCell
          .putIfAbsent((
            load.shift.doctorId,
            DateTime(start.year, start.month, start.day),
          ), () => [])
          .add(load);
    }

    Widget cell(Widget child, {Color? color}) => Container(
      color: color,
      padding: const EdgeInsets.all(8),
      child: child,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: math.max(constraints.maxWidth, 1080),
          child: Table(
            border: TableBorder.all(color: scheme.outlineVariant),
            columnWidths: const {0: FixedColumnWidth(170)},
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              TableRow(
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh),
                children: [
                  cell(Text('医生', style: theme.textTheme.labelLarge)),
                  for (final day in days)
                    cell(
                      Text(
                        '${weekdayText(day)}  ${day.month}-${day.day}${day == today ? '（今天）' : ''}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: day == today ? scheme.primary : null,
                        ),
                      ),
                    ),
                ],
              ),
              for (final doctor in doctors)
                TableRow(
                  children: [
                    cell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.name, style: theme.textTheme.titleSmall),
                          Text(
                            '${doctor.department} · ${doctor.title}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    for (final day in days)
                      cell(
                        color: day == today
                            ? scheme.primaryContainer.withValues(alpha: 0.25)
                            : null,
                        _ScheduleCell(loads: byCell[(doctor.id, day)] ?? []),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCell extends StatelessWidget {
  const _ScheduleCell({required this.loads});

  final List<ShiftLoad> loads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (loads.isEmpty) {
      return Text('休', style: TextStyle(color: scheme.outline));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final load in loads)
          Builder(
            builder: (context) {
              final capacity = load.shift.capacity;
              final ratio = capacity == 0 ? 0.0 : load.booked / capacity;
              final color = _loadColor(scheme, ratio);
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border(left: BorderSide(color: color, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatSpan(load.shift.startsAt, load.shift.endsAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '已约 ${load.booked}/$capacity · ${load.shift.modes.map(consultModeText).join('/')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
