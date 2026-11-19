import 'package:venicare_shared/src/report/doctor_profile.dart';
import 'package:venicare_shared/src/report/report_models.dart';

enum ConsultMode { text, phone, video }

/// Set by the doctor in the workbench.
enum DoctorPresence { online, away, offline }

/// Derived by the server from presence, shifts and appointments.
enum DoctorStatus { idle, consulting, offShift, away, offline }

enum AppointmentStatus { booked, inConsultation, completed, cancelled, noShow }

DateTime _date(Object? value) => DateTime.parse(value! as String);

List<T> _list<T>(Object? value, T Function(Json) fromJson) {
  return (value as List<Object?>? ?? const [])
      .map((item) => fromJson(item! as Json))
      .toList();
}

class Department {
  const Department({required this.id, required this.name, this.intro = ''});

  factory Department.fromJson(Json json) {
    return Department(
      id: json['id']! as String,
      name: json['name']! as String,
      intro: json['intro'] as String? ?? '',
    );
  }

  final String id;
  final String name;
  final String intro;

  Json toJson() => {'id': id, 'name': name, 'intro': intro};
}

/// One working block, split into fixed-length slots that each accept
/// [capacityPerSlot] appointments.
class DoctorShift {
  const DoctorShift({
    required this.id,
    required this.doctorId,
    required this.startsAt,
    required this.endsAt,
    required this.slotMinutes,
    required this.capacityPerSlot,
    required this.modes,
  });

  factory DoctorShift.fromJson(Json json) {
    return DoctorShift(
      id: json['id']! as String,
      doctorId: json['doctorId']! as String,
      startsAt: _date(json['startsAt']),
      endsAt: _date(json['endsAt']),
      slotMinutes: json['slotMinutes']! as int,
      capacityPerSlot: json['capacityPerSlot']! as int,
      modes: (json['modes']! as List<Object?>)
          .map((m) => ConsultMode.values.byName(m! as String))
          .toList(),
    );
  }

  final String id;
  final String doctorId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int slotMinutes;
  final int capacityPerSlot;
  final List<ConsultMode> modes;

  int get slotCount => endsAt.difference(startsAt).inMinutes ~/ slotMinutes;

  int get capacity => slotCount * capacityPerSlot;

  bool covers(DateTime at) => !at.isBefore(startsAt) && at.isBefore(endsAt);

  String slotId(int index) => '$id#$index';

  DateTime slotStart(int index) =>
      startsAt.add(Duration(minutes: slotMinutes * index));

  /// Index of the slot [slotId] refers to, or null if it is not this shift's.
  int? slotIndexOf(String slotId) {
    final prefix = '$id#';
    if (!slotId.startsWith(prefix)) return null;
    final index = int.tryParse(slotId.substring(prefix.length));
    return index != null && index >= 0 && index < slotCount ? index : null;
  }

  Json toJson() => {
    'id': id,
    'doctorId': doctorId,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'slotMinutes': slotMinutes,
    'capacityPerSlot': capacityPerSlot,
    'modes': modes.map((m) => m.name).toList(),
  };
}

class ConsultSlot {
  const ConsultSlot({
    required this.id,
    required this.doctorId,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.booked,
    required this.modes,
  });

  factory ConsultSlot.fromJson(Json json) {
    return ConsultSlot(
      id: json['id']! as String,
      doctorId: json['doctorId']! as String,
      startsAt: _date(json['startsAt']),
      endsAt: _date(json['endsAt']),
      capacity: json['capacity']! as int,
      booked: json['booked']! as int,
      modes: (json['modes']! as List<Object?>)
          .map((m) => ConsultMode.values.byName(m! as String))
          .toList(),
    );
  }

  final String id;
  final String doctorId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int capacity;
  final int booked;
  final List<ConsultMode> modes;

  int get remaining => capacity - booked;

  Json toJson() => {
    'id': id,
    'doctorId': doctorId,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'capacity': capacity,
    'booked': booked,
    'modes': modes.map((m) => m.name).toList(),
  };
}

class Appointment {
  const Appointment({
    required this.id,
    required this.careRecipientId,
    required this.patientName,
    required this.doctorId,
    required this.doctorName,
    required this.departmentName,
    required this.slotId,
    required this.startsAt,
    required this.mode,
    required this.status,
    required this.bookedBy,
    required this.createdAt,
    this.note,
  });

  factory Appointment.fromJson(Json json) {
    return Appointment(
      id: json['id']! as String,
      careRecipientId: json['careRecipientId']! as String,
      patientName: json['patientName']! as String,
      doctorId: json['doctorId']! as String,
      doctorName: json['doctorName']! as String,
      departmentName: json['departmentName']! as String,
      slotId: json['slotId']! as String,
      startsAt: _date(json['startsAt']),
      mode: ConsultMode.values.byName(json['mode']! as String),
      status: AppointmentStatus.values.byName(json['status']! as String),
      bookedBy: json['bookedBy']! as String,
      createdAt: _date(json['createdAt']),
      note: json['note'] as String?,
    );
  }

  final String id;
  final String careRecipientId;
  final String patientName;
  final String doctorId;
  final String doctorName;
  final String departmentName;
  final String slotId;
  final DateTime startsAt;
  final ConsultMode mode;
  final AppointmentStatus status;
  final String bookedBy;
  final DateTime createdAt;
  final String? note;

  /// Still holds a place in the slot.
  bool get active =>
      status == AppointmentStatus.booked ||
      status == AppointmentStatus.inConsultation;

  Appointment copyWith({AppointmentStatus? status}) {
    return Appointment(
      id: id,
      careRecipientId: careRecipientId,
      patientName: patientName,
      doctorId: doctorId,
      doctorName: doctorName,
      departmentName: departmentName,
      slotId: slotId,
      startsAt: startsAt,
      mode: mode,
      status: status ?? this.status,
      bookedBy: bookedBy,
      createdAt: createdAt,
      note: note,
    );
  }

  Json toJson() => {
    'id': id,
    'careRecipientId': careRecipientId,
    'patientName': patientName,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'departmentName': departmentName,
    'slotId': slotId,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'mode': mode.name,
    'status': status.name,
    'bookedBy': bookedBy,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'note': note,
  };
}

/// What families see when choosing a doctor. Never contains other patients.
class DoctorCard {
  const DoctorCard({
    required this.doctor,
    required this.status,
    required this.waitingCount,
    required this.modes,
    this.nextAvailableAt,
  });

  factory DoctorCard.fromJson(Json json) {
    final next = json['nextAvailableAt'] as String?;
    return DoctorCard(
      doctor: DoctorProfile.fromJson(json['doctor']! as Json),
      status: DoctorStatus.values.byName(json['status']! as String),
      waitingCount: json['waitingCount']! as int,
      modes: (json['modes']! as List<Object?>)
          .map((m) => ConsultMode.values.byName(m! as String))
          .toList(),
      nextAvailableAt: next == null ? null : DateTime.parse(next),
    );
  }

  final DoctorProfile doctor;
  final DoctorStatus status;
  final int waitingCount;
  final List<ConsultMode> modes;

  /// Start of the earliest slot that still has room, within the next 7 days.
  final DateTime? nextAvailableAt;

  bool get consultableNow =>
      status == DoctorStatus.idle || status == DoctorStatus.consulting;

  Json toJson() => {
    'doctor': doctor.toJson(),
    'status': status.name,
    'waitingCount': waitingCount,
    'modes': modes.map((m) => m.name).toList(),
    'nextAvailableAt': nextAvailableAt?.toUtc().toIso8601String(),
  };
}

class MyAppointment {
  const MyAppointment({required this.appointment, this.peopleAhead});

  factory MyAppointment.fromJson(Json json) {
    return MyAppointment(
      appointment: Appointment.fromJson(json['appointment']! as Json),
      peopleAhead: json['peopleAhead'] as int?,
    );
  }

  final Appointment appointment;

  /// Set only once the appointment time has arrived and it is queuing.
  final int? peopleAhead;

  Json toJson() => {
    'appointment': appointment.toJson(),
    'peopleAhead': peopleAhead,
  };
}

class ShiftLoad {
  const ShiftLoad({required this.shift, required this.booked});

  factory ShiftLoad.fromJson(Json json) {
    return ShiftLoad(
      shift: DoctorShift.fromJson(json['shift']! as Json),
      booked: json['booked']! as int,
    );
  }

  final DoctorShift shift;
  final int booked;

  Json toJson() => {'shift': shift.toJson(), 'booked': booked};
}

/// One doctor on the admin live board.
class DoctorBoardRow {
  const DoctorBoardRow({
    required this.doctor,
    required this.presence,
    required this.status,
    required this.waiting,
    required this.laterToday,
    required this.todayShifts,
    this.current,
  });

  factory DoctorBoardRow.fromJson(Json json) {
    final current = json['current'] as Json?;
    return DoctorBoardRow(
      doctor: DoctorProfile.fromJson(json['doctor']! as Json),
      presence: DoctorPresence.values.byName(json['presence']! as String),
      status: DoctorStatus.values.byName(json['status']! as String),
      current: current == null ? null : Appointment.fromJson(current),
      waiting: _list(json['waiting'], Appointment.fromJson),
      laterToday: json['laterToday']! as int,
      todayShifts: _list(json['todayShifts'], ShiftLoad.fromJson),
    );
  }

  final DoctorProfile doctor;
  final DoctorPresence presence;
  final DoctorStatus status;
  final Appointment? current;

  /// Appointments whose time has come, in calling order.
  final List<Appointment> waiting;

  /// Booked appointments later today that are not queuing yet.
  final int laterToday;
  final List<ShiftLoad> todayShifts;

  Json toJson() => {
    'doctor': doctor.toJson(),
    'presence': presence.name,
    'status': status.name,
    'current': current?.toJson(),
    'waiting': waiting.map((a) => a.toJson()).toList(),
    'laterToday': laterToday,
    'todayShifts': todayShifts.map((s) => s.toJson()).toList(),
  };
}

class AdminBoard {
  const AdminBoard({
    required this.generatedAt,
    required this.departments,
    required this.rows,
  });

  factory AdminBoard.fromJson(Json json) {
    return AdminBoard(
      generatedAt: _date(json['generatedAt']),
      departments: _list(json['departments'], Department.fromJson),
      rows: _list(json['rows'], DoctorBoardRow.fromJson),
    );
  }

  final DateTime generatedAt;
  final List<Department> departments;
  final List<DoctorBoardRow> rows;

  Json toJson() => {
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'departments': departments.map((d) => d.toJson()).toList(),
    'rows': rows.map((r) => r.toJson()).toList(),
  };
}

class WeekSchedule {
  const WeekSchedule({
    required this.from,
    required this.days,
    required this.departments,
    required this.doctors,
    required this.shifts,
  });

  factory WeekSchedule.fromJson(Json json) {
    return WeekSchedule(
      from: _date(json['from']),
      days: json['days']! as int,
      departments: _list(json['departments'], Department.fromJson),
      doctors: _list(json['doctors'], DoctorProfile.fromJson),
      shifts: _list(json['shifts'], ShiftLoad.fromJson),
    );
  }

  final DateTime from;
  final int days;
  final List<Department> departments;
  final List<DoctorProfile> doctors;
  final List<ShiftLoad> shifts;

  Json toJson() => {
    'from': from.toUtc().toIso8601String(),
    'days': days,
    'departments': departments.map((d) => d.toJson()).toList(),
    'doctors': doctors.map((d) => d.toJson()).toList(),
    'shifts': shifts.map((s) => s.toJson()).toList(),
  };
}
