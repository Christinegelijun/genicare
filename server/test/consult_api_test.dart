import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:venicare_server/venicare_server.dart';
import 'package:venicare_shared/venicare_shared.dart';

void main() {
  // Monday 10:10. Doctors on shift today work 08:00–13:00 in 30-minute slots,
  // so the slot in progress is index 4 (10:00–10:30).
  final now = DateTime(2026, 11, 16, 10, 10);
  late InMemoryCareStore store;
  late Handler handler;

  setUp(() {
    store = InMemoryCareStore();
    seedDemoData(store, now);
    store.addPatient(const ReportPatient(id: 'p2', name: '隔壁王阿姨'));
    handler = CareApi(store, clock: () => now).handler;
  });

  Future<(int, Json)> call(String method, String path, [Object? body]) async {
    final response = await handler(
      Request(
        method,
        Uri.parse('http://localhost$path'),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return (
      response.statusCode,
      jsonDecode(await response.readAsString()) as Json,
    );
  }

  List<Json> items(Json body) => (body['items']! as List<Object?>).cast<Json>();

  String errorCode(Json body) => (body['error']! as Json)['code']! as String;

  Future<(int, Json)> book(String rid, String slotId, ConsultMode mode) {
    return call('POST', '/api/v1/care-recipients/$rid/appointments', {
      'slotId': slotId,
      'mode': mode.name,
      'bookedBy': '李俊',
    });
  }

  const liuNowSlot = 'shift-doctor-liu-20261116-0#4';
  const wangNowSlot = 'shift-doctor-wang-20261116-0#4';

  test('按科室列出医生，可立即咨询的排在前面', () async {
    final (_, departments) = await call('GET', '/api/v1/departments');
    expect(items(departments), hasLength(5));

    final (_, body) = await call(
      'GET',
      '/api/v1/consult/doctors?departmentId=dept-cardio',
    );
    final cards = items(body).map(DoctorCard.fromJson).toList();
    expect(cards.map((c) => c.doctor.name), ['王医生', '孙医生']);
    expect(cards.first.status, DoctorStatus.consulting);
    expect(cards.first.waitingCount, 3);
    expect(cards.last.status, DoctorStatus.away);
  });

  test('管理员看板显示接诊、排队和离线情况，普通医生无权查看', () async {
    final (status, body) = await call(
      'GET',
      '/api/v1/doctors/doctor-zhang/admin/board',
    );
    expect(status, 200);
    final board = AdminBoard.fromJson(body);
    final rows = {for (final r in board.rows) r.doctor.id: r};
    expect(rows, hasLength(6));
    expect(rows['doctor-wang']!.current, isNotNull);
    expect(rows['doctor-wang']!.waiting, hasLength(3));
    expect(rows['doctor-wang']!.laterToday, 2);
    expect(rows['doctor-liu']!.status, DoctorStatus.idle);
    expect(rows['doctor-chen']!.status, DoctorStatus.offline);
    expect(rows['doctor-zhao']!.status, DoctorStatus.offShift);

    final (forbidden, error) = await call(
      'GET',
      '/api/v1/doctors/doctor-wang/admin/board',
    );
    expect(forbidden, 403);
    expect(errorCode(error), 'FORBIDDEN');
  });

  test('预约当前时段后马上排队，同一天不能重复预约同一位医生，可以取消', () async {
    final (status, body) = await book(
      demoRecipientId,
      liuNowSlot,
      ConsultMode.text,
    );
    expect(status, 201);
    final booked = MyAppointment.fromJson(body);
    expect(booked.peopleAhead, 0);
    expect(booked.appointment.patientName, '妈妈');

    final (again, error) = await book(
      demoRecipientId,
      'shift-doctor-liu-20261116-0#6',
      ConsultMode.text,
    );
    expect(again, 409);
    expect(errorCode(error), 'APPOINTMENT_EXISTS');

    final (_, mine) = await call(
      'GET',
      '/api/v1/care-recipients/$demoRecipientId/appointments',
    );
    expect(items(mine), hasLength(1));

    final (cancelStatus, cancelled) = await call(
      'POST',
      '/api/v1/care-recipients/$demoRecipientId/appointments/${booked.appointment.id}/cancel',
    );
    expect(cancelStatus, 200);
    expect(
      MyAppointment.fromJson(cancelled).appointment.status,
      AppointmentStatus.cancelled,
    );
  });

  test('排队位置包含正在接诊的人，约满后返回 SLOT_FULL', () async {
    final (status, body) = await book(
      demoRecipientId,
      wangNowSlot,
      ConsultMode.video,
    );
    expect(status, 201);
    // Three already waiting plus one in consultation.
    expect(MyAppointment.fromJson(body).peopleAhead, 4);

    final (full, error) = await book('p2', wangNowSlot, ConsultMode.video);
    expect(full, 409);
    expect(errorCode(error), 'SLOT_FULL');
  });

  test('不提供的咨询方式和已结束的时段不能预约', () async {
    final (mode, modeError) = await book(
      demoRecipientId,
      liuNowSlot,
      ConsultMode.video,
    );
    expect(mode, 409);
    expect(errorCode(modeError), 'MODE_UNAVAILABLE');

    final (past, pastError) = await book(
      demoRecipientId,
      'shift-doctor-liu-20261116-0#0',
      ConsultMode.text,
    );
    expect(past, 409);
    expect(errorCode(pastError), 'SLOT_EXPIRED');
  });

  test('可预约时段只返回未结束的时段', () async {
    final (_, body) = await call(
      'GET',
      '/api/v1/consult/doctors/doctor-liu/slots?days=1',
    );
    final slots = (body['slots']! as List<Object?>)
        .map((s) => ConsultSlot.fromJson(s! as Json))
        .toList();
    expect(slots.first.id, liuNowSlot);
    expect(slots.every((s) => s.endsAt.isAfter(now)), isTrue);
  });

  test('医生切换为暂离后，家属端显示暂离', () async {
    final (status, body) = await call(
      'PUT',
      '/api/v1/doctors/doctor-zhang/presence',
      {'presence': 'away'},
    );
    expect(status, 200);
    expect(body['status'], 'away');

    final (_, cards) = await call(
      'GET',
      '/api/v1/consult/doctors?departmentId=dept-general',
    );
    expect(DoctorCard.fromJson(items(cards).single).status, DoctorStatus.away);
  });
}
