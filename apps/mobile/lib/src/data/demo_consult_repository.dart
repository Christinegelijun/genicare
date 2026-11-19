import 'package:venicare_shared/venicare_shared.dart';

/// Local demo for family booking. Same shapes as the server API; replace with
/// HTTP when the App connects to the backend.
class DemoConsultRepository {
  DemoConsultRepository({DateTime? now}) : _now = now ?? DateTime.now() {
    _seed();
  }

  final DateTime _now;
  late final List<Department> _departments;
  late final List<_DoctorSeed> _doctors;
  final _shifts = <DoctorShift>[];
  final _appointments = <Appointment>[];
  var _seq = 0;

  List<Department> departments() => List.unmodifiable(_departments);

  List<DoctorCard> doctors({String? departmentId}) {
    final cards =
        [
          for (final seed in _doctors)
            if (departmentId == null ||
                seed.profile.departmentId == departmentId)
              _card(seed),
        ]..sort((a, b) {
          if (a.consultableNow != b.consultableNow) {
            return a.consultableNow ? -1 : 1;
          }
          return a.waitingCount.compareTo(b.waitingCount);
        });
    return cards;
  }

  DoctorCard? doctor(String doctorId) {
    final seed = _doctors.where((d) => d.profile.id == doctorId).firstOrNull;
    return seed == null ? null : _card(seed);
  }

  List<ConsultSlot> slots(String doctorId, {int days = 7}) {
    final from = _dayStart(_now);
    final to = from.add(Duration(days: days));
    final booked = _bookedBySlot(doctorId);
    return [
      for (final shift in _shifts.where((s) => s.doctorId == doctorId))
        if (!shift.endsAt.isBefore(from) && shift.startsAt.isBefore(to))
          for (var i = 0; i < shift.slotCount; i++)
            if (shift
                .slotStart(i)
                .add(Duration(minutes: shift.slotMinutes))
                .isAfter(_now))
              ConsultSlot(
                id: shift.slotId(i),
                doctorId: doctorId,
                startsAt: shift.slotStart(i),
                endsAt: shift
                    .slotStart(i)
                    .add(Duration(minutes: shift.slotMinutes)),
                capacity: shift.capacityPerSlot,
                booked: booked[shift.slotId(i)] ?? 0,
                modes: shift.modes,
              ),
    ];
  }

  List<MyAppointment> myAppointments(String careRecipientId) {
    return [
      for (final a in _appointments)
        if (a.careRecipientId == careRecipientId &&
            (a.active ||
                a.startsAt.isAfter(_now.subtract(const Duration(days: 1)))))
          MyAppointment(appointment: a, peopleAhead: _ahead(a)),
    ];
  }

  MyAppointment book({
    required String careRecipientId,
    required String patientName,
    required String slotId,
    required ConsultMode mode,
    required String bookedBy,
    String? note,
  }) {
    final separator = slotId.lastIndexOf('#');
    if (separator < 0) {
      throw StateError('找不到该时段');
    }
    final shift = _shifts
        .where((s) => s.id == slotId.substring(0, separator))
        .firstOrNull;
    final index = shift?.slotIndexOf(slotId);
    if (shift == null || index == null) {
      throw StateError('找不到该时段');
    }
    final seed = _doctors.where((d) => d.profile.id == shift.doctorId).first;
    if (!shift.modes.contains(mode)) {
      throw StateError('该医生这个时段不提供此咨询方式');
    }
    final startsAt = shift.slotStart(index);
    if (!startsAt.add(Duration(minutes: shift.slotMinutes)).isAfter(_now)) {
      throw StateError('该时段已结束，请选择其他时间');
    }
    final dayStart = _dayStart(startsAt);
    final duplicate = _appointments.any(
      (a) =>
          a.active &&
          a.doctorId == shift.doctorId &&
          a.careRecipientId == careRecipientId &&
          _dayStart(a.startsAt) == dayStart,
    );
    if (duplicate) {
      throw StateError('当天已预约过这位医生，如需改时间请先取消原预约');
    }
    final taken = _appointments
        .where((a) => a.slotId == slotId && a.active)
        .length;
    if (taken >= shift.capacityPerSlot) {
      throw StateError('该时段已约满，请选择其他时间');
    }
    final appointment = Appointment(
      id: 'local-apt-${++_seq}',
      careRecipientId: careRecipientId,
      patientName: patientName,
      doctorId: seed.profile.id,
      doctorName: seed.profile.name,
      departmentName: seed.profile.department,
      slotId: slotId,
      startsAt: startsAt,
      mode: mode,
      status: AppointmentStatus.booked,
      bookedBy: bookedBy,
      createdAt: _now,
      note: note,
    );
    _appointments.add(appointment);
    return MyAppointment(
      appointment: appointment,
      peopleAhead: _ahead(appointment),
    );
  }

  MyAppointment cancel(String careRecipientId, String appointmentId) {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index < 0 || _appointments[index].careRecipientId != careRecipientId) {
      throw StateError('找不到该预约');
    }
    final current = _appointments[index];
    if (current.status != AppointmentStatus.booked) {
      throw StateError('医生已开始接诊或预约已结束，不能取消');
    }
    final cancelled = current.copyWith(status: AppointmentStatus.cancelled);
    _appointments[index] = cancelled;
    return MyAppointment(appointment: cancelled);
  }

  DoctorCard _card(_DoctorSeed seed) {
    final queue = _queue(seed.profile.id);
    final upcoming = _slotsFor(
      seed.profile.id,
    ).where((s) => s.remaining > 0).firstOrNull;
    return DoctorCard(
      doctor: seed.profile,
      status: _status(seed),
      waitingCount: queue.waiting.length,
      modes: seed.modes,
      nextAvailableAt: upcoming?.startsAt,
    );
  }

  DoctorStatus _status(_DoctorSeed seed) {
    if (seed.presence == DoctorPresence.offline) return DoctorStatus.offline;
    if (seed.presence == DoctorPresence.away) return DoctorStatus.away;
    if (_queue(seed.profile.id).current != null) {
      return DoctorStatus.consulting;
    }
    final onShift = _shifts
        .where((s) => s.doctorId == seed.profile.id)
        .any((s) => s.covers(_now));
    return onShift ? DoctorStatus.idle : DoctorStatus.offShift;
  }

  ({Appointment? current, List<Appointment> waiting}) _queue(String doctorId) {
    final today = _dayStart(_now);
    final active = _appointments.where(
      (a) =>
          a.doctorId == doctorId && a.active && _dayStart(a.startsAt) == today,
    );
    final booked = active.where((a) => a.status == AppointmentStatus.booked);
    return (
      current: active
          .where((a) => a.status == AppointmentStatus.inConsultation)
          .firstOrNull,
      waiting: booked.where((a) => !a.startsAt.isAfter(_now)).toList(),
    );
  }

  int? _ahead(Appointment appointment) {
    if (appointment.status != AppointmentStatus.booked ||
        appointment.startsAt.isAfter(_now) ||
        _dayStart(appointment.startsAt) != _dayStart(_now)) {
      return null;
    }
    final queue = _queue(appointment.doctorId);
    final position = queue.waiting.indexWhere((a) => a.id == appointment.id);
    return position < 0 ? null : position + (queue.current == null ? 0 : 1);
  }

  List<ConsultSlot> _slotsFor(String doctorId) => slots(doctorId);

  Map<String, int> _bookedBySlot(String doctorId) {
    final counts = <String, int>{};
    for (final a in _appointments) {
      if (a.doctorId == doctorId && a.active) {
        counts[a.slotId] = (counts[a.slotId] ?? 0) + 1;
      }
    }
    return counts;
  }

  void _seed() {
    _departments = const [
      Department(id: 'dept-general', name: '全科', intro: '常见病、慢病随访、用药咨询'),
      Department(id: 'dept-cardio', name: '心血管内科', intro: '高血压、冠心病、心律失常'),
      Department(id: 'dept-endo', name: '内分泌科', intro: '糖尿病、甲状腺疾病'),
      Department(id: 'dept-neuro', name: '神经内科', intro: '头晕头痛、脑卒中康复、睡眠'),
      Department(id: 'dept-geriatric', name: '老年医学科', intro: '多病共存、跌倒风险、营养评估'),
    ];
    _doctors = const [
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-zhang',
          name: '张医生',
          organization: '社区卫生服务中心',
          department: '全科',
          departmentId: 'dept-general',
          title: '主治医师',
          specialties: '慢病随访、老年人用药管理',
        ),
        DoctorPresence.online,
        [ConsultMode.text, ConsultMode.phone],
      ),
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-wang',
          name: '王医生',
          organization: '市第一人民医院',
          department: '心血管内科',
          departmentId: 'dept-cardio',
          title: '副主任医师',
          specialties: '高血压、心力衰竭',
        ),
        DoctorPresence.online,
        [ConsultMode.text, ConsultMode.video],
      ),
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-sun',
          name: '孙医生',
          organization: '市第一人民医院',
          department: '心血管内科',
          departmentId: 'dept-cardio',
          title: '主治医师',
          specialties: '心律失常、血脂管理',
        ),
        DoctorPresence.away,
        [ConsultMode.text, ConsultMode.phone, ConsultMode.video],
      ),
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-liu',
          name: '刘医生',
          organization: '市第一人民医院',
          department: '内分泌科',
          departmentId: 'dept-endo',
          title: '主任医师',
          specialties: '糖尿病、骨质疏松',
        ),
        DoctorPresence.online,
        [ConsultMode.text, ConsultMode.phone],
      ),
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-chen',
          name: '陈医生',
          organization: '市第一人民医院',
          department: '神经内科',
          departmentId: 'dept-neuro',
          title: '主治医师',
          specialties: '头晕、睡眠障碍',
        ),
        DoctorPresence.offline,
        [ConsultMode.video],
      ),
      _DoctorSeed(
        DoctorProfile(
          id: 'doctor-zhao',
          name: '赵医生',
          organization: '市第一人民医院',
          department: '老年医学科',
          departmentId: 'dept-geriatric',
          title: '副主任医师',
          specialties: '跌倒评估、多重用药',
        ),
        DoctorPresence.online,
        [ConsultMode.phone, ConsultMode.video],
      ),
    ];

    final today = _dayStart(_now);
    final hour = DateTime(_now.year, _now.month, _now.day, _now.hour);
    for (final seed in _doctors) {
      final onShiftNow = {
        'doctor-zhang',
        'doctor-wang',
        'doctor-sun',
        'doctor-liu',
      }.contains(seed.profile.id);
      for (var d = 0; d <= 6; d++) {
        final day = today.add(Duration(days: d));
        if (d == 0 && onShiftNow) {
          _shifts.add(
            DoctorShift(
              id: 'shift-${seed.profile.id}-${_ymd(day)}-0',
              doctorId: seed.profile.id,
              startsAt: hour.subtract(const Duration(hours: 2)),
              endsAt: hour.add(const Duration(hours: 3)),
              slotMinutes: 30,
              capacityPerSlot: seed.profile.id == 'doctor-wang' ? 4 : 2,
              modes: seed.modes,
            ),
          );
        } else if (d > 0 || !onShiftNow) {
          if (day.weekday == DateTime.saturday ||
              day.weekday == DateTime.sunday) {
            continue;
          }
          _shifts.add(
            DoctorShift(
              id: 'shift-${seed.profile.id}-${_ymd(day)}-am',
              doctorId: seed.profile.id,
              startsAt: day.add(const Duration(hours: 9)),
              endsAt: day.add(const Duration(hours: 12)),
              slotMinutes: 30,
              capacityPerSlot: 2,
              modes: seed.modes,
            ),
          );
        }
      }
    }

    // Seed a live queue on 王医生 so the family list shows waiting counts.
    final wangShift = _shifts.firstWhere((s) => s.doctorId == 'doctor-wang');
    final wangIndex =
        (_now.difference(wangShift.startsAt).inMinutes ~/ wangShift.slotMinutes)
            .clamp(0, wangShift.slotCount - 1);
    final slotStart = wangShift.slotStart(wangIndex);
    _appointments.addAll([
      Appointment(
        id: 'local-demo-current',
        careRecipientId: 'other-1',
        patientName: '赵秀兰',
        doctorId: 'doctor-wang',
        doctorName: '王医生',
        departmentName: '心血管内科',
        slotId: wangShift.slotId(wangIndex),
        startsAt: slotStart,
        mode: ConsultMode.video,
        status: AppointmentStatus.inConsultation,
        bookedBy: '家属',
        createdAt: _now.subtract(const Duration(hours: 1)),
      ),
      for (final (i, name) in ['孙桂英', '李建国'].indexed)
        Appointment(
          id: 'local-demo-wait-$i',
          careRecipientId: 'other-${i + 2}',
          patientName: name,
          doctorId: 'doctor-wang',
          doctorName: '王医生',
          departmentName: '心血管内科',
          slotId: wangShift.slotId(wangIndex),
          startsAt: slotStart,
          mode: ConsultMode.text,
          status: AppointmentStatus.booked,
          bookedBy: '家属',
          createdAt: _now.subtract(Duration(minutes: 40 - i * 5)),
        ),
    ]);
  }

  static DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _ymd(DateTime day) =>
      '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
}

class _DoctorSeed {
  const _DoctorSeed(this.profile, this.presence, this.modes);

  final DoctorProfile profile;
  final DoctorPresence presence;
  final List<ConsultMode> modes;
}
