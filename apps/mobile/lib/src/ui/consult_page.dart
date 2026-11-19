import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/consult_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_shared/venicare_shared.dart';

final _date = DateFormat('MM-dd HH:mm');
final _clock = DateFormat('HH:mm');

const _weekday = ['一', '二', '三', '四', '五', '六', '日'];

String _dayLabel(DateTime day) =>
    '${day.month}月${day.day}日 周${_weekday[day.weekday - 1]}';

String _statusText(DoctorStatus status) {
  return switch (status) {
    DoctorStatus.idle => '空闲可约',
    DoctorStatus.consulting => '接诊中',
    DoctorStatus.offShift => '不在班',
    DoctorStatus.away => '暂离',
    DoctorStatus.offline => '离线',
  };
}

Color _statusColor(CareColors colors, DoctorStatus status) {
  return switch (status) {
    DoctorStatus.idle => const Color(0xFF1E9E5A),
    DoctorStatus.consulting => colors.primary,
    DoctorStatus.away => colors.warning,
    DoctorStatus.offShift || DoctorStatus.offline => colors.muted,
  };
}

String _modeText(ConsultMode mode) {
  return switch (mode) {
    ConsultMode.text => '图文',
    ConsultMode.phone => '电话',
    ConsultMode.video => '视频',
  };
}

class ConsultPage extends ConsumerWidget {
  const ConsultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final departments = ref.watch(consultDepartmentsProvider);
    final selected = ref.watch(consultDepartmentProvider);
    final doctors = ref.watch(consultDoctorsProvider);
    final mine = ref.watch(myAppointmentsProvider);
    final activeMine = mine.where((m) => m.appointment.active).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('咨询预约'),
        actions: [
          TextButton(
            onPressed: () => context.push(AppPaths.consultAppointments),
            child: Text(
              activeMine.isEmpty ? '我的预约' : '我的预约(${activeMine.length})',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.medical_services_outlined,
            title: '按科室预约咨询',
            message: '可查看医生空闲、排队和可约时段。咨询建议不构成诊断和处方。',
            color: colors.info,
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DeptChip(
                  label: '全部',
                  selected: selected == null,
                  onTap: () =>
                      ref.read(consultDepartmentProvider.notifier).set(null),
                ),
                for (final d in departments) ...[
                  const SizedBox(width: 8),
                  _DeptChip(
                    label: d.name,
                    selected: selected == d.id,
                    onTap: () =>
                        ref.read(consultDepartmentProvider.notifier).set(d.id),
                  ),
                ],
              ],
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 8),
            Text(
              departments.firstWhere((d) => d.id == selected).intro,
              style: TextStyle(color: colors.muted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          for (final card in doctors) ...[
            _DoctorCardTile(card: card),
            const SizedBox(height: 12),
          ],
          if (doctors.isEmpty)
            CareCard(
              child: Text('该科室暂无医生', style: TextStyle(color: colors.muted)),
            ),
        ],
      ),
    );
  }
}

class _DeptChip extends StatelessWidget {
  const _DeptChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colors.primarySoft,
      labelStyle: TextStyle(
        color: selected ? colors.primary : colors.ink,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
    );
  }
}

class _DoctorCardTile extends StatelessWidget {
  const _DoctorCardTile({required this.card});

  final DoctorCard card;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final doctor = card.doctor;
    final statusColor = _statusColor(colors, card.status);
    return CareCard(
      onTap: () => context.push(AppPaths.consultDoctor(doctor.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialAvatar(
                name: doctor.name,
                background: colors.primarySoft,
                foreground: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${doctor.name}  ${doctor.title}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${doctor.department} · ${doctor.organization}',
                      style: TextStyle(color: colors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusPill(label: _statusText(card.status), color: statusColor),
            ],
          ),
          if (doctor.specialties.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(doctor.specialties, style: TextStyle(color: colors.ink)),
          ],
          const SizedBox(height: 10),
          Text(
            [
              if (card.waitingCount > 0) '排队 ${card.waitingCount} 人',
              if (card.nextAvailableAt != null)
                '最早可约 ${_date.format(card.nextAvailableAt!.toLocal())}',
              if (card.modes.isNotEmpty) card.modes.map(_modeText).join(' / '),
            ].join(' · '),
            style: TextStyle(color: colors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class DoctorBookingPage extends ConsumerStatefulWidget {
  const DoctorBookingPage({super.key, required this.doctorId});

  final String doctorId;

  @override
  ConsumerState<DoctorBookingPage> createState() => _DoctorBookingPageState();
}

class _DoctorBookingPageState extends ConsumerState<DoctorBookingPage> {
  ConsultMode? _mode;
  String? _slotId;
  final _note = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final repo = ref.watch(consultRepositoryProvider);
    final card = repo.doctor(widget.doctorId);
    if (card == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('预约咨询')),
        body: const Center(child: Text('找不到该医生')),
      );
    }
    final slots = repo.slots(widget.doctorId);
    final modes = card.modes;
    final selectedMode = _mode ?? (modes.isEmpty ? null : modes.first);
    final byDay = <DateTime, List<ConsultSlot>>{};
    for (final slot in slots) {
      final day = DateTime(
        slot.startsAt.year,
        slot.startsAt.month,
        slot.startsAt.day,
      );
      byDay.putIfAbsent(day, () => []).add(slot);
    }

    return Scaffold(
      appBar: AppBar(title: Text('预约 ${card.doctor.name}')),
      body: ListView(
        padding: kPagePadding,
        children: [
          CareCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${card.doctor.name}  ${card.doctor.title}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${card.doctor.department} · ${card.doctor.specialties}',
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 8),
                StatusPill(
                  label: _statusText(card.status),
                  color: _statusColor(colors, card.status),
                ),
                if (card.waitingCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '当前排队 ${card.waitingCount} 人',
                    style: TextStyle(color: colors.warning),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('咨询方式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in modes)
                ChoiceChip(
                  label: Text(_modeText(mode)),
                  selected: selectedMode == mode,
                  onSelected: (_) => setState(() => _mode = mode),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('可选时段', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (byDay.isEmpty)
            Text('近 7 天暂无可约时段', style: TextStyle(color: colors.muted))
          else
            for (final entry in byDay.entries) ...[
              Text(
                _dayLabel(entry.key),
                style: TextStyle(
                  color: colors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final slot in entry.value)
                    ChoiceChip(
                      label: Text(
                        '${_clock.format(slot.startsAt.toLocal())}'
                        '${slot.remaining <= 0 ? ' 已满' : ' 余${slot.remaining}'}',
                      ),
                      selected: _slotId == slot.id,
                      onSelected:
                          slot.remaining <= 0 ||
                              selectedMode == null ||
                              !slot.modes.contains(selectedMode)
                          ? null
                          : (_) => setState(() => _slotId = slot.id),
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          Text('给医生的说明（选填）', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: '例如：妈妈最近晨起头晕，想问是否需要调血压药',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting || _slotId == null || selectedMode == null
                ? null
                : () => _submit(selectedMode),
            child: Text(_submitting ? '提交中…' : '确认预约'),
          ),
          const SizedBox(height: 12),
          Text(
            '预约成功后可在「我的预约」中查看排队位置；医生开始接诊后不可取消。',
            style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(ConsultMode mode) async {
    setState(() => _submitting = true);
    final error = ref
        .read(myAppointmentsProvider.notifier)
        .book(
          slotId: _slotId!,
          mode: mode,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('预约成功'),
        content: const Text('可在「我的预约」中查看排队与时段。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go(AppPaths.consultAppointments);
  }
}

class MyAppointmentsPage extends ConsumerWidget {
  const MyAppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final items = ref.watch(myAppointmentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('我的预约')),
      body: items.isEmpty
          ? Center(
              child: Text('暂无预约', style: TextStyle(color: colors.muted)),
            )
          : ListView.separated(
              padding: kPagePadding,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final a = item.appointment;
                return CareCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${a.doctorName} · ${a.departmentName}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatusPill(
                            label: _appointmentStatus(a.status),
                            color: a.active ? colors.primary : colors.muted,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_date.format(a.startsAt.toLocal())} · ${_modeText(a.mode)}',
                      ),
                      if (item.peopleAhead != null)
                        Text(
                          item.peopleAhead == 0
                              ? '前面没有人，请保持电话畅通'
                              : '前面还有 ${item.peopleAhead} 人',
                          style: TextStyle(color: colors.warning),
                        ),
                      if (a.note != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '说明：${a.note}',
                          style: TextStyle(color: colors.muted),
                        ),
                      ],
                      if (a.status == AppointmentStatus.booked) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () async {
                            final error = ref
                                .read(myAppointmentsProvider.notifier)
                                .cancel(a.id);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(error ?? '已取消预约')),
                            );
                          },
                          child: const Text('取消预约'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _appointmentStatus(AppointmentStatus status) {
    return switch (status) {
      AppointmentStatus.booked => '已预约',
      AppointmentStatus.inConsultation => '接诊中',
      AppointmentStatus.completed => '已完成',
      AppointmentStatus.cancelled => '已取消',
      AppointmentStatus.noShow => '未到诊',
    };
  }
}
