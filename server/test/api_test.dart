import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:venicare_server/venicare_server.dart';
import 'package:venicare_shared/venicare_shared.dart';

void main() {
  final now = DateTime.utc(2026, 11, 15, 12);
  late InMemoryCareStore store;
  late Handler handler;

  setUp(() {
    store = InMemoryCareStore();
    seedDemoData(store, now);
    store.addDoctor(
      const DoctorProfile(
        id: 'doctor-other',
        name: '王医生',
        organization: '市人民医院',
        department: '心内科',
        title: '副主任医师',
      ),
    );
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

  test('家属同步数据并发送报告后，医生收件箱可以看到', () async {
    final (syncStatus, _) = await call(
      'POST',
      '/api/v1/care-recipients/$demoRecipientId/sync',
      {
        'readings': [
          VitalReading(
            id: 'app-1',
            kind: ReadingKind.bloodPressure,
            measuredAt: DateTime.utc(2026, 11, 15, 8),
            source: ReadingSource.voice,
            recordedBy: '妈妈',
            systolic: 152,
            diastolic: 96,
          ).toJson(),
        ],
      },
    );
    expect(syncStatus, 200);

    final (status, body) = await call(
      'POST',
      '/api/v1/care-recipients/$demoRecipientId/reports',
      {
        'doctorIds': [demoDoctorId],
        'periodStart': '2026-11-15T00:00:00Z',
        'periodEnd': '2026-11-16T00:00:00Z',
        'requestedBy': '李俊',
      },
    );
    expect(status, 201);
    final delivery = ReportDelivery.fromJson(
      (body['items']! as List<Object?>).single! as Json,
    );
    expect(delivery.report.readings.map((r) => r.id), contains('app-1'));
    expect(delivery.report.bloodPressure!.aboveReferenceCount, 1);

    final (_, inbox) = await call(
      'GET',
      '/api/v1/doctors/$demoDoctorId/reports',
    );
    final ids = (inbox['items']! as List<Object?>).map(
      (item) => ReportInboxItem.fromJson(item! as Json).deliveryId,
    );
    expect(ids, contains(delivery.id));
  });

  test('未授权的医生不能被选为接收人', () async {
    final (status, body) = await call(
      'POST',
      '/api/v1/care-recipients/$demoRecipientId/reports',
      {
        'doctorIds': ['doctor-other'],
        'periodStart': '2026-11-01T00:00:00Z',
        'periodEnd': '2026-11-16T00:00:00Z',
        'requestedBy': '李俊',
      },
    );
    expect(status, 403);
    expect((body['error']! as Json)['code'], 'DOCTOR_NOT_AUTHORIZED');
  });

  test('医生已读和回复会更新状态，其他医生看不到这份报告', () async {
    const path = '/api/v1/doctors/$demoDoctorId/reports/seed-delivery-1';

    final (_, read) = await call('POST', '$path/read');
    expect(read['status'], 'read');

    final (replyStatus, replied) = await call('POST', '$path/replies', {
      'content': '晨起血压偏高，建议连续测量一周后复诊。',
    });
    expect(replyStatus, 201);
    expect(replied['status'], 'replied');

    final (_, familyView) = await call(
      'GET',
      '/api/v1/care-recipients/$demoRecipientId/reports',
    );
    final first = ReportDelivery.fromJson(
      (familyView['items']! as List<Object?>).first! as Json,
    );
    expect(first.replies.single.content, contains('复诊'));

    final (otherStatus, _) = await call(
      'GET',
      '/api/v1/doctors/doctor-other/reports/seed-delivery-1',
    );
    expect(otherStatus, 404);
  });

  test('请求体错误返回统一错误格式', () async {
    final (status, body) = await call(
      'POST',
      '/api/v1/care-recipients/$demoRecipientId/reports',
      {'doctorIds': <String>[]},
    );
    expect(status, 400);
    expect((body['error']! as Json)['code'], 'INVALID_REQUEST');
  });
}
