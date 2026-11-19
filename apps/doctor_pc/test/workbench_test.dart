import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venicare_doctor/src/api/doctor_api.dart';
import 'package:venicare_doctor/src/app.dart';
import 'package:venicare_doctor/src/state/workbench_controller.dart';
import 'package:venicare_doctor/src/ui/report_detail.dart';
import 'package:venicare_shared/venicare_shared.dart';

class _FakeDoctorApi implements DoctorApi {
  _FakeDoctorApi(this._delivery);

  ReportDelivery _delivery;
  int markReadCalls = 0;

  @override
  Future<DoctorProfile> profile() async => const DoctorProfile(
    id: 'doctor-zhang',
    name: '张医生',
    organization: '社区卫生服务中心',
    department: '全科',
    departmentId: 'dept-general',
    title: '主治医师',
    isAdmin: true,
  );

  @override
  Future<List<ReportInboxItem>> inbox({DeliveryStatus? status}) async => [
    if (status == null || status == _delivery.status) _delivery.toInboxItem(),
  ];

  @override
  Future<ReportDelivery> delivery(String deliveryId) async => _delivery;

  @override
  Future<ReportDelivery> markRead(String deliveryId) async {
    markReadCalls++;
    return _delivery = _delivery.copyWith(
      status: DeliveryStatus.read,
      readAt: DateTime.utc(2026, 11, 15, 10),
    );
  }

  @override
  Future<ReportDelivery> reply(String deliveryId, String content) async {
    return _delivery = _delivery.copyWith(
      status: DeliveryStatus.replied,
      replies: [
        DoctorReply(
          id: 'r1',
          doctorId: 'doctor-zhang',
          doctorName: '张医生',
          content: content,
          createdAt: DateTime.utc(2026, 11, 15, 11),
        ),
      ],
    );
  }

  DoctorPresence _presence = DoctorPresence.online;

  @override
  Future<DoctorPresence> presence() async => _presence;

  @override
  Future<DoctorPresence> setPresence(DoctorPresence presence) async =>
      _presence = presence;

  @override
  Future<AdminBoard> adminBoard() async => AdminBoard(
    generatedAt: DateTime.utc(2026, 11, 15, 12),
    departments: const [
      Department(id: 'dept-general', name: '全科'),
    ],
    rows: const [],
  );

  @override
  Future<WeekSchedule> weekSchedule(DateTime from) async => WeekSchedule(
    from: from,
    days: 7,
    departments: const [],
    doctors: const [],
    shifts: const [],
  );
}

ReportDelivery _sampleDelivery() {
  VitalReading bp(int day, int sys, int dia) => VitalReading(
    id: 'bp-$day',
    kind: ReadingKind.bloodPressure,
    measuredAt: DateTime.utc(2026, 11, day, 0, 30),
    source: ReadingSource.voice,
    recordedBy: '妈妈',
    systolic: sys,
    diastolic: dia,
    transcript: '血压$sys，$dia',
  );
  final report = buildHealthReport(
    id: 'rpt-1',
    patient: const ReportPatient(
      id: 'recipient-mother',
      name: '妈妈',
      gender: '女',
      birthYear: 1952,
      conditions: ['高血压'],
    ),
    periodStart: DateTime.utc(2026, 11, 1),
    periodEnd: DateTime.utc(2026, 11, 15),
    generatedAt: DateTime.utc(2026, 11, 15, 9),
    requestedBy: '李俊',
    familyNote: '最近早上头晕',
    readings: [bp(3, 128, 82), bp(6, 146, 92), bp(9, 132, 84)],
  );
  return ReportDelivery(
    id: 'dlv-1',
    report: report,
    doctorId: 'doctor-zhang',
    doctorName: '张医生',
    status: DeliveryStatus.sent,
    sentAt: DateTime.utc(2026, 11, 15, 9),
  );
}

void main() {
  testWidgets('打开未读报告会标记已读，并可以回复家属', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = _FakeDoctorApi(_sampleDelivery());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [doctorApiProvider.overrideWithValue(api)],
        child: const DoctorApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('张医生'), findsOneWidget);
    expect(find.text('未读'), findsWidgets);
    expect(find.text('1 条读数超参考线'), findsOneWidget);

    await tester.tap(find.text('妈妈'));
    await tester.pumpAndSettle();

    expect(api.markReadCalls, 1);
    expect(find.text('最近早上头晕'), findsOneWidget);
    expect(find.text('1 次高于 140/90'), findsOneWidget);
    expect(find.text('全部测量记录（3 条）'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(TextField),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ReportDetail),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(find.byType(TextField), '建议连续测量一周后复诊');
    await tester.tap(find.text('发送回复'));
    await tester.pumpAndSettle();

    expect(find.text('建议连续测量一周后复诊'), findsOneWidget);
    expect(find.text('已回复'), findsWidgets);
  });
}
