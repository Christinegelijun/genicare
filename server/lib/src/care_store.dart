import 'package:venicare_shared/venicare_shared.dart';

/// Persistence boundary. [InMemoryCareStore] backs development and tests; the
/// PostgreSQL implementation follows db/migrations/0001_init.sql.
abstract interface class CareStore {
  ReportPatient? patient(String recipientId);

  DoctorProfile? doctor(String doctorId);

  List<DoctorProfile> doctorsFor(String recipientId);

  bool isAuthorized({required String recipientId, required String doctorId});

  /// Upserts by id so the app's outbox can safely retry the same batch.
  void upsertCareData(
    String recipientId, {
    Iterable<VitalReading> readings = const [],
    Iterable<MedicationDose> doses = const [],
    Iterable<CareEvent> events = const [],
  });

  List<VitalReading> readings(String recipientId);

  List<MedicationDose> doses(String recipientId);

  List<CareEvent> events(String recipientId);

  void saveDelivery(ReportDelivery delivery);

  ReportDelivery? delivery(String deliveryId);

  List<ReportDelivery> deliveriesForDoctor(String doctorId);

  List<ReportDelivery> deliveriesForPatient(String recipientId);

  List<Department> departments();

  List<DoctorProfile> doctors();

  DoctorPresence presence(String doctorId);

  void setPresence(String doctorId, DoctorPresence presence);

  DoctorShift? shift(String shiftId);

  /// Shifts that start inside [from, to), ordered by start time.
  List<DoctorShift> shifts({
    String? doctorId,
    required DateTime from,
    required DateTime to,
  });

  Appointment? appointment(String appointmentId);

  /// Appointments starting inside [from, to) when a range is given.
  List<Appointment> appointments({
    String? doctorId,
    String? careRecipientId,
    DateTime? from,
    DateTime? to,
  });

  /// Writes the appointment only if the slot still has room once it is
  /// counted, so concurrent bookings cannot oversell a slot. Returns false
  /// when the slot is full.
  bool saveAppointment(Appointment appointment, {required int slotCapacity});

  void updateAppointment(Appointment appointment);
}

class InMemoryCareStore implements CareStore {
  final _patients = <String, ReportPatient>{};
  final _doctors = <String, DoctorProfile>{};
  final _bindings = <String, Set<String>>{};
  final _readings = <String, Map<String, VitalReading>>{};
  final _doses = <String, Map<String, MedicationDose>>{};
  final _events = <String, Map<String, CareEvent>>{};
  final _deliveries = <String, ReportDelivery>{};
  final _departments = <String, Department>{};
  final _presence = <String, DoctorPresence>{};
  final _shifts = <String, DoctorShift>{};
  final _appointments = <String, Appointment>{};

  void addPatient(ReportPatient patient) => _patients[patient.id] = patient;

  void addDoctor(DoctorProfile doctor) => _doctors[doctor.id] = doctor;

  void addDepartment(Department department) =>
      _departments[department.id] = department;

  void addShift(DoctorShift shift) => _shifts[shift.id] = shift;

  void bind({required String recipientId, required String doctorId}) {
    _bindings.putIfAbsent(recipientId, () => {}).add(doctorId);
  }

  @override
  ReportPatient? patient(String recipientId) => _patients[recipientId];

  @override
  DoctorProfile? doctor(String doctorId) => _doctors[doctorId];

  @override
  List<DoctorProfile> doctorsFor(String recipientId) => [
    for (final id in _bindings[recipientId] ?? const <String>{}) ?_doctors[id],
  ];

  @override
  bool isAuthorized({required String recipientId, required String doctorId}) {
    return _bindings[recipientId]?.contains(doctorId) ?? false;
  }

  @override
  void upsertCareData(
    String recipientId, {
    Iterable<VitalReading> readings = const [],
    Iterable<MedicationDose> doses = const [],
    Iterable<CareEvent> events = const [],
  }) {
    final readingMap = _readings.putIfAbsent(recipientId, () => {});
    for (final r in readings) {
      readingMap[r.id] = r;
    }
    final doseMap = _doses.putIfAbsent(recipientId, () => {});
    for (final d in doses) {
      doseMap[d.id] = d;
    }
    final eventMap = _events.putIfAbsent(recipientId, () => {});
    for (final e in events) {
      eventMap[e.id] = e;
    }
  }

  @override
  List<VitalReading> readings(String recipientId) =>
      _readings[recipientId]?.values.toList() ?? [];

  @override
  List<MedicationDose> doses(String recipientId) =>
      _doses[recipientId]?.values.toList() ?? [];

  @override
  List<CareEvent> events(String recipientId) =>
      _events[recipientId]?.values.toList() ?? [];

  @override
  void saveDelivery(ReportDelivery delivery) =>
      _deliveries[delivery.id] = delivery;

  @override
  ReportDelivery? delivery(String deliveryId) => _deliveries[deliveryId];

  @override
  List<ReportDelivery> deliveriesForDoctor(String doctorId) =>
      _deliveries.values.where((d) => d.doctorId == doctorId).toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  @override
  List<ReportDelivery> deliveriesForPatient(String recipientId) =>
      _deliveries.values
          .where((d) => d.report.patient.id == recipientId)
          .toList()
        ..sort((a, b) => b.sentAt.compareTo(a.sentAt));

  @override
  List<Department> departments() => _departments.values.toList();

  @override
  List<DoctorProfile> doctors() => _doctors.values.toList();

  @override
  DoctorPresence presence(String doctorId) =>
      _presence[doctorId] ?? DoctorPresence.offline;

  @override
  void setPresence(String doctorId, DoctorPresence presence) =>
      _presence[doctorId] = presence;

  @override
  DoctorShift? shift(String shiftId) => _shifts[shiftId];

  @override
  List<DoctorShift> shifts({
    String? doctorId,
    required DateTime from,
    required DateTime to,
  }) =>
      _shifts.values
          .where((s) => doctorId == null || s.doctorId == doctorId)
          .where((s) => !s.startsAt.isBefore(from) && s.startsAt.isBefore(to))
          .toList()
        ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

  @override
  Appointment? appointment(String appointmentId) =>
      _appointments[appointmentId];

  @override
  List<Appointment> appointments({
    String? doctorId,
    String? careRecipientId,
    DateTime? from,
    DateTime? to,
  }) =>
      _appointments.values
          .where((a) => doctorId == null || a.doctorId == doctorId)
          .where(
            (a) =>
                careRecipientId == null || a.careRecipientId == careRecipientId,
          )
          .where((a) => from == null || !a.startsAt.isBefore(from))
          .where((a) => to == null || a.startsAt.isBefore(to))
          .toList()
        ..sort((a, b) {
          final byTime = a.startsAt.compareTo(b.startsAt);
          return byTime != 0 ? byTime : a.createdAt.compareTo(b.createdAt);
        });

  @override
  bool saveAppointment(Appointment appointment, {required int slotCapacity}) {
    final taken = _appointments.values
        .where((a) => a.slotId == appointment.slotId && a.active)
        .length;
    if (taken >= slotCapacity) return false;
    _appointments[appointment.id] = appointment;
    return true;
  }

  @override
  void updateAppointment(Appointment appointment) =>
      _appointments[appointment.id] = appointment;
}
