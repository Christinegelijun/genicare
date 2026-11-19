import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:venicare_server/src/care_store.dart';
import 'package:venicare_server/src/http_utils.dart';
import 'package:venicare_shared/venicare_shared.dart';

/// Departments, doctor availability, booking and the admin board.
///
/// Queue rule: a booked appointment starts queuing once its slot time has
/// arrived; the queue is ordered by slot time, then by booking time.
class ConsultApi {
  ConsultApi(this.store, this._clock);

  final CareStore store;
  final Clock _clock;

  static const _lookahead = Duration(days: 7);

  void mount(Router router) {
    router
      ..get('/api/v1/departments', _departments)
      ..get('/api/v1/consult/doctors', _doctorCards)
      ..get('/api/v1/consult/doctors/<did>/slots', _doctorSlots)
      ..get('/api/v1/care-recipients/<rid>/appointments', _myAppointments)
      ..post('/api/v1/care-recipients/<rid>/appointments', _book)
      ..post('/api/v1/care-recipients/<rid>/appointments/<id>/cancel', _cancel)
      ..get('/api/v1/doctors/<did>/presence', _presence)
      ..put('/api/v1/doctors/<did>/presence', _setPresence)
      ..get('/api/v1/doctors/<did>/admin/board', _board)
      ..get('/api/v1/doctors/<did>/admin/schedule', _schedule);
  }

  Response _departments(Request request) {
    return jsonResponse({
      'items': store.departments().map((d) => d.toJson()).toList(),
    });
  }

  Response _doctorCards(Request request) {
    final departmentId = request.url.queryParameters['departmentId'];
    final cards =
        [
          for (final doctor in store.doctors())
            if (departmentId == null || doctor.departmentId == departmentId)
              _card(doctor),
        ]..sort((a, b) {
          if (a.consultableNow != b.consultableNow) {
            return a.consultableNow ? -1 : 1;
          }
          final byQueue = a.waitingCount.compareTo(b.waitingCount);
          if (byQueue != 0) return byQueue;
          final aNext = a.nextAvailableAt, bNext = b.nextAvailableAt;
          if (aNext == null || bNext == null) {
            return aNext == null ? (bNext == null ? 0 : 1) : -1;
          }
          return aNext.compareTo(bNext);
        });
    return jsonResponse({'items': cards.map((c) => c.toJson()).toList()});
  }

  Response _doctorSlots(Request request, String did) {
    final doctor = _requireDoctor(did);
    final from = _dateParam(request, 'from') ?? _dayStart(_clock());
    final days = _daysParam(request, fallback: 7);
    return jsonResponse({
      'doctor': _card(doctor).toJson(),
      'slots': _slots(
        did,
        from,
        from.add(Duration(days: days)),
      ).map((s) => s.toJson()).toList(),
    });
  }

  Response _myAppointments(Request request, String rid) {
    _requirePatient(rid);
    final now = _clock();
    final items = store
        .appointments(careRecipientId: rid)
        .where((a) => a.active || a.startsAt.isAfter(now.subtract(_lookahead)))
        .map((a) => MyAppointment(appointment: a, peopleAhead: _ahead(a)))
        .toList();
    return jsonResponse({'items': items.map((i) => i.toJson()).toList()});
  }

  Future<Response> _book(Request request, String rid) async {
    final patient = _requirePatient(rid);
    final body = await readJsonBody(request);
    final slotId = requireField<String>(body, 'slotId');
    final mode = parseEnum(ConsultMode.values, body['mode'] as String?, 'mode');
    final bookedBy = requireField<String>(body, 'bookedBy').trim();
    final note = (body['note'] as String?)?.trim();

    final separator = slotId.lastIndexOf('#');
    final shift = separator < 0
        ? null
        : store.shift(slotId.substring(0, separator));
    final index = shift?.slotIndexOf(slotId);
    if (shift == null || index == null) {
      throw const ApiException(404, 'NOT_FOUND', '找不到该时段');
    }
    final doctor = _requireDoctor(shift.doctorId);
    final startsAt = shift.slotStart(index);
    final now = _clock();
    if (!startsAt.add(Duration(minutes: shift.slotMinutes)).isAfter(now)) {
      throw const ApiException(409, 'SLOT_EXPIRED', '该时段已结束，请选择其他时间');
    }
    if (!shift.modes.contains(mode)) {
      throw const ApiException(409, 'MODE_UNAVAILABLE', '该医生这个时段不提供此咨询方式');
    }
    final dayStart = _dayStart(startsAt);
    final duplicate = store
        .appointments(
          doctorId: doctor.id,
          careRecipientId: rid,
          from: dayStart,
          to: dayStart.add(const Duration(days: 1)),
        )
        .any((a) => a.active);
    if (duplicate) {
      throw const ApiException(
        409,
        'APPOINTMENT_EXISTS',
        '当天已预约过这位医生，如需改时间请先取消原预约',
      );
    }

    final appointment = Appointment(
      id: newId('apt'),
      careRecipientId: rid,
      patientName: patient.name,
      doctorId: doctor.id,
      doctorName: doctor.name,
      departmentName: doctor.department,
      slotId: slotId,
      startsAt: startsAt,
      mode: mode,
      status: AppointmentStatus.booked,
      bookedBy: bookedBy,
      createdAt: now,
      note: note == null || note.isEmpty ? null : note,
    );
    if (!store.saveAppointment(
      appointment,
      slotCapacity: shift.capacityPerSlot,
    )) {
      throw const ApiException(409, 'SLOT_FULL', '该时段已约满，请选择其他时间');
    }
    return jsonResponse(
      MyAppointment(
        appointment: appointment,
        peopleAhead: _ahead(appointment),
      ).toJson(),
      status: 201,
    );
  }

  Response _cancel(Request request, String rid, String id) {
    final appointment = store.appointment(id);
    if (appointment == null || appointment.careRecipientId != rid) {
      throw const ApiException(404, 'NOT_FOUND', '找不到该预约');
    }
    if (appointment.status != AppointmentStatus.booked) {
      throw const ApiException(409, 'NOT_CANCELLABLE', '医生已开始接诊或预约已结束，不能取消');
    }
    final cancelled = appointment.copyWith(status: AppointmentStatus.cancelled);
    store.updateAppointment(cancelled);
    return jsonResponse(MyAppointment(appointment: cancelled).toJson());
  }

  Response _presence(Request request, String did) {
    _requireDoctor(did);
    return _presenceResponse(did);
  }

  Future<Response> _setPresence(Request request, String did) async {
    _requireDoctor(did);
    final body = await readJsonBody(request);
    store.setPresence(
      did,
      parseEnum(DoctorPresence.values, body['presence'] as String?, 'presence'),
    );
    return _presenceResponse(did);
  }

  Response _presenceResponse(String did) {
    return jsonResponse({
      'presence': store.presence(did).name,
      'status': _status(did).name,
    });
  }

  Response _board(Request request, String did) {
    _requireAdmin(did);
    final now = _clock();
    final today = _dayStart(now);
    final tomorrow = today.add(const Duration(days: 1));
    final rows = [
      for (final doctor in store.doctors())
        () {
          final queue = _queue(doctor.id);
          return DoctorBoardRow(
            doctor: doctor,
            presence: store.presence(doctor.id),
            status: _status(doctor.id),
            current: queue.current,
            waiting: queue.waiting,
            laterToday: queue.laterToday,
            todayShifts: _loads(doctor.id, today, tomorrow),
          );
        }(),
    ];
    return jsonResponse(
      AdminBoard(
        generatedAt: now,
        departments: store.departments(),
        rows: rows,
      ).toJson(),
    );
  }

  Response _schedule(Request request, String did) {
    _requireAdmin(did);
    final today = _dayStart(_clock());
    final from =
        _dateParam(request, 'from') ??
        today.subtract(Duration(days: today.weekday - 1));
    final days = _daysParam(request, fallback: 7);
    return jsonResponse(
      WeekSchedule(
        from: from,
        days: days,
        departments: store.departments(),
        doctors: store.doctors(),
        shifts: _loads(null, from, from.add(Duration(days: days))),
      ).toJson(),
    );
  }

  DoctorCard _card(DoctorProfile doctor) {
    final now = _clock();
    final upcoming = store.shifts(
      doctorId: doctor.id,
      from: _dayStart(now),
      to: now.add(_lookahead),
    );
    final next = _slots(
      doctor.id,
      now,
      now.add(_lookahead),
    ).where((s) => s.remaining > 0).firstOrNull;
    return DoctorCard(
      doctor: doctor,
      status: _status(doctor.id),
      waitingCount: _queue(doctor.id).waiting.length,
      modes: {for (final s in upcoming) ...s.modes}.toList()
        ..sort((a, b) => a.index.compareTo(b.index)),
      nextAvailableAt: next?.startsAt,
    );
  }

  DoctorStatus _status(String doctorId) {
    final presence = store.presence(doctorId);
    if (presence == DoctorPresence.offline) return DoctorStatus.offline;
    if (presence == DoctorPresence.away) return DoctorStatus.away;
    if (_queue(doctorId).current != null) return DoctorStatus.consulting;
    final now = _clock();
    final onShift = store
        .shifts(
          doctorId: doctorId,
          from: _dayStart(now).subtract(const Duration(days: 1)),
          to: now.add(const Duration(seconds: 1)),
        )
        .any((s) => s.covers(now));
    return onShift ? DoctorStatus.idle : DoctorStatus.offShift;
  }

  ({Appointment? current, List<Appointment> waiting, int laterToday}) _queue(
    String doctorId,
  ) {
    final now = _clock();
    final today = _dayStart(now);
    final active = store
        .appointments(
          doctorId: doctorId,
          from: today,
          to: today.add(const Duration(days: 1)),
        )
        .where((a) => a.active);
    final booked = active.where((a) => a.status == AppointmentStatus.booked);
    return (
      current: active
          .where((a) => a.status == AppointmentStatus.inConsultation)
          .firstOrNull,
      waiting: booked.where((a) => !a.startsAt.isAfter(now)).toList(),
      laterToday: booked.where((a) => a.startsAt.isAfter(now)).length,
    );
  }

  int? _ahead(Appointment appointment) {
    final now = _clock();
    if (appointment.status != AppointmentStatus.booked ||
        appointment.startsAt.isAfter(now) ||
        _dayStart(appointment.startsAt) != _dayStart(now)) {
      return null;
    }
    final queue = _queue(appointment.doctorId);
    final position = queue.waiting.indexWhere((a) => a.id == appointment.id);
    return position < 0 ? null : position + (queue.current == null ? 0 : 1);
  }

  List<ConsultSlot> _slots(String doctorId, DateTime from, DateTime to) {
    final now = _clock();
    final booked = _bookedBySlot(doctorId, from, to);
    return [
      for (final shift in store.shifts(
        doctorId: doctorId,
        from: _dayStart(from),
        to: to,
      ))
        for (var i = 0; i < shift.slotCount; i++)
          if (_slotEnd(shift, i).isAfter(now) &&
              _slotEnd(shift, i).isAfter(from))
            ConsultSlot(
              id: shift.slotId(i),
              doctorId: doctorId,
              startsAt: shift.slotStart(i),
              endsAt: _slotEnd(shift, i),
              capacity: shift.capacityPerSlot,
              booked: booked[shift.slotId(i)] ?? 0,
              modes: shift.modes,
            ),
    ];
  }

  List<ShiftLoad> _loads(String? doctorId, DateTime from, DateTime to) {
    final booked = _bookedBySlot(doctorId, from, to);
    return [
      for (final shift in store.shifts(doctorId: doctorId, from: from, to: to))
        ShiftLoad(
          shift: shift,
          booked: [
            for (var i = 0; i < shift.slotCount; i++)
              booked[shift.slotId(i)] ?? 0,
          ].fold(0, (sum, n) => sum + n),
        ),
    ];
  }

  Map<String, int> _bookedBySlot(String? doctorId, DateTime from, DateTime to) {
    final counts = <String, int>{};
    for (final a in store.appointments(
      doctorId: doctorId,
      from: _dayStart(from),
      to: to,
    )) {
      if (a.active) counts[a.slotId] = (counts[a.slotId] ?? 0) + 1;
    }
    return counts;
  }

  DateTime _slotEnd(DoctorShift shift, int index) =>
      shift.slotStart(index).add(Duration(minutes: shift.slotMinutes));

  ReportPatient _requirePatient(String rid) {
    return store.patient(rid) ??
        (throw const ApiException(404, 'NOT_FOUND', '找不到该照护对象'));
  }

  DoctorProfile _requireDoctor(String did) {
    return store.doctor(did) ??
        (throw const ApiException(404, 'NOT_FOUND', '找不到该医生'));
  }

  void _requireAdmin(String did) {
    if (!_requireDoctor(did).isAdmin) {
      throw const ApiException(403, 'FORBIDDEN', '只有管理员可以查看医生排班与接诊情况');
    }
  }
}

DateTime _dayStart(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime? _dateParam(Request request, String name) {
  final raw = request.url.queryParameters[name];
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    throw ApiException(400, 'INVALID_REQUEST', '日期格式应为 YYYY-MM-DD：$name');
  }
  return _dayStart(parsed);
}

int _daysParam(Request request, {required int fallback}) {
  final raw = request.url.queryParameters['days'];
  final days = raw == null ? fallback : int.tryParse(raw);
  if (days == null || days < 1 || days > 31) {
    throw const ApiException(400, 'INVALID_REQUEST', 'days 取值范围为 1～31');
  }
  return days;
}
