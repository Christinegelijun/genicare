import 'dart:math' as math;

import 'package:venicare_server/src/care_store.dart';
import 'package:venicare_shared/venicare_shared.dart';

const _departments = [
  Department(id: 'dept-general', name: '全科', intro: '常见病、慢病随访、用药咨询'),
  Department(id: 'dept-cardio', name: '心血管内科', intro: '高血压、冠心病、心律失常'),
  Department(id: 'dept-endo', name: '内分泌科', intro: '糖尿病、甲状腺疾病'),
  Department(id: 'dept-neuro', name: '神经内科', intro: '头晕头痛、脑卒中康复、睡眠'),
  Department(id: 'dept-geriatric', name: '老年医学科', intro: '多病共存、跌倒风险、营养评估'),
];

const _hospital = '市第一人民医院';

const _doctors = [
  (
    DoctorProfile(
      id: 'doctor-wang',
      name: '王医生',
      organization: _hospital,
      department: '心血管内科',
      departmentId: 'dept-cardio',
      title: '副主任医师',
      specialties: '高血压、心力衰竭',
    ),
    DoctorPresence.online,
    [ConsultMode.text, ConsultMode.video],
  ),
  (
    DoctorProfile(
      id: 'doctor-sun',
      name: '孙医生',
      organization: _hospital,
      department: '心血管内科',
      departmentId: 'dept-cardio',
      title: '主治医师',
      specialties: '心律失常、血脂管理',
    ),
    DoctorPresence.away,
    [ConsultMode.text, ConsultMode.phone, ConsultMode.video],
  ),
  (
    DoctorProfile(
      id: 'doctor-liu',
      name: '刘医生',
      organization: _hospital,
      department: '内分泌科',
      departmentId: 'dept-endo',
      title: '主任医师',
      specialties: '糖尿病、骨质疏松',
    ),
    DoctorPresence.online,
    [ConsultMode.text, ConsultMode.phone],
  ),
  (
    DoctorProfile(
      id: 'doctor-chen',
      name: '陈医生',
      organization: _hospital,
      department: '神经内科',
      departmentId: 'dept-neuro',
      title: '主治医师',
      specialties: '头晕、睡眠障碍',
    ),
    DoctorPresence.offline,
    [ConsultMode.video],
  ),
  (
    DoctorProfile(
      id: 'doctor-zhao',
      name: '赵医生',
      organization: _hospital,
      department: '老年医学科',
      departmentId: 'dept-geriatric',
      title: '副主任医师',
      specialties: '跌倒评估、多重用药',
    ),
    DoctorPresence.online,
    [ConsultMode.phone, ConsultMode.video],
  ),
];

const _otherPatients = [
  '赵秀兰', '孙桂英', '李建国', '周玉梅', '吴志强', '郑淑芬', '钱德明', '冯翠兰', //
  '陈宝华', '褚玉珍', '卫国强', '蒋素琴',
];

/// Doctors on shift right now: their shift today is placed around [now] so the
/// live board always has something to show.
const _onShiftNow = {'doctor-zhang', 'doctor-wang', 'doctor-sun', 'doctor-liu'};

void seedConsultData(InMemoryCareStore store, DateTime now) {
  _departments.forEach(store.addDepartment);
  store.setPresence('doctor-zhang', DoctorPresence.online);
  for (final (doctor, presence, _) in _doctors) {
    store
      ..addDoctor(doctor)
      ..setPresence(doctor.id, presence);
  }

  final modes = {
    'doctor-zhang': [ConsultMode.text, ConsultMode.phone],
    for (final (doctor, _, doctorModes) in _doctors) doctor.id: doctorModes,
  };
  final today = DateTime(now.year, now.month, now.day);
  final todayShifts = <String, DoctorShift>{};
  var patient = 0;
  String nextPatient() => _otherPatients[patient++ % _otherPatients.length];

  for (final (i, doctorId) in modes.keys.indexed) {
    for (var d = -6; d <= 6; d++) {
      final day = today.add(Duration(days: d));
      final blocks = <(DateTime, DateTime)>[];
      if (d == 0 && _onShiftNow.contains(doctorId)) {
        final hour = DateTime(now.year, now.month, now.day, now.hour);
        blocks.add((
          _later(today, hour.subtract(const Duration(hours: 2))),
          _earlier(
            today.add(const Duration(days: 1)),
            hour.add(const Duration(hours: 3)),
          ),
        ));
      } else if (d != 0) {
        if ((d + i) % 2 == 0) {
          blocks.add((_at(day, 8), _at(day, 11, 30)));
        }
        if ((d + i) % 3 != 0) {
          blocks.add((_at(day, 14), _at(day, 17)));
        }
      }
      for (final (b, (start, end)) in blocks.indexed) {
        final shift = DoctorShift(
          id: 'shift-$doctorId-${_dateKey(day)}-$b',
          doctorId: doctorId,
          startsAt: start,
          endsAt: end,
          slotMinutes: 30,
          capacityPerSlot: modes[doctorId]!.contains(ConsultMode.text) ? 3 : 2,
          modes: modes[doctorId]!,
        );
        store.addShift(shift);
        if (d == 0) todayShifts[doctorId] = shift;
        if (d != 0) {
          for (var n = 0; n < (i + d.abs()) % 4 + 1; n++) {
            final index = (n * 2 + i) % shift.slotCount;
            _book(
              store,
              shift,
              index,
              nextPatient(),
              d < 0 ? AppointmentStatus.completed : AppointmentStatus.booked,
              now,
            );
          }
        }
      }
    }
  }

  void queue(
    String doctorId,
    List<(int offset, AppointmentStatus status)> plan,
  ) {
    final shift = todayShifts[doctorId];
    if (shift == null) return;
    final current = math.min(
      now.difference(shift.startsAt).inMinutes ~/ shift.slotMinutes,
      shift.slotCount - 1,
    );
    for (final (offset, status) in plan) {
      final index = (current + offset).clamp(0, shift.slotCount - 1);
      _book(store, shift, index, nextPatient(), status, now);
    }
  }

  queue('doctor-wang', [
    (-1, AppointmentStatus.inConsultation),
    (-1, AppointmentStatus.booked),
    (0, AppointmentStatus.booked),
    (0, AppointmentStatus.booked),
    (2, AppointmentStatus.booked),
    (3, AppointmentStatus.booked),
  ]);
  queue('doctor-zhang', [
    (-2, AppointmentStatus.completed),
    (0, AppointmentStatus.booked),
    (2, AppointmentStatus.booked),
  ]);
  queue('doctor-sun', [(0, AppointmentStatus.booked)]);
  queue('doctor-liu', [(-1, AppointmentStatus.completed)]);
}

void _book(
  InMemoryCareStore store,
  DoctorShift shift,
  int index,
  String patientName,
  AppointmentStatus status,
  DateTime now,
) {
  final doctor = store.doctor(shift.doctorId)!;
  store.saveAppointment(
    Appointment(
      id: 'seed-apt-${shift.id}-$index-$patientName',
      careRecipientId: 'seed-patient-$patientName',
      patientName: patientName,
      doctorId: doctor.id,
      doctorName: doctor.name,
      departmentName: doctor.department,
      slotId: shift.slotId(index),
      startsAt: shift.slotStart(index),
      mode: shift.modes.first,
      status: status,
      bookedBy: '家属',
      createdAt: now.subtract(Duration(hours: 30 - index)),
    ),
    slotCapacity: shift.capacityPerSlot,
  );
}

DateTime _at(DateTime day, int hour, [int minute = 0]) =>
    DateTime(day.year, day.month, day.day, hour, minute);

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

String _dateKey(DateTime day) =>
    '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
