import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venicare_app/src/app.dart';
import 'package:venicare_app/src/data/demo_consult_repository.dart';
import 'package:venicare_app/src/state/consult_controller.dart';
import 'package:venicare_shared/venicare_shared.dart';

void main() {
  final now = DateTime(2026, 11, 16, 10, 10);

  test('本地咨询仓库可按科室列出医生并预约', () {
    final repo = DemoConsultRepository(now: now);
    final cardio = repo.doctors(departmentId: 'dept-cardio');
    expect(cardio.map((c) => c.doctor.name), ['王医生', '孙医生']);
    expect(cardio.first.status, DoctorStatus.consulting);
    expect(cardio.first.waitingCount, 2);

    final open = repo
        .slots('doctor-wang')
        .where((s) => s.remaining > 0)
        .first;
    final booked = repo.book(
      careRecipientId: 'recipient-mother',
      patientName: '妈妈',
      slotId: open.id,
      mode: ConsultMode.text,
      bookedBy: '李俊',
    );
    expect(booked.appointment.doctorName, '王医生');
    expect(
      repo.myAppointments('recipient-mother').where((m) => m.appointment.active),
      hasLength(1),
    );

    final cancelled = repo.cancel('recipient-mother', booked.appointment.id);
    expect(cancelled.appointment.status, AppointmentStatus.cancelled);
  });

  testWidgets('子女可按科室打开医生预约页', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = DemoConsultRepository(now: now);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [consultRepositoryProvider.overrideWithValue(repo)],
        child: const VeniCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('预约医生'));
    await tester.pumpAndSettle();
    expect(find.text('按科室预约咨询'), findsOneWidget);

    await tester.tap(find.text('心血管内科'));
    await tester.pumpAndSettle();
    expect(find.text('接诊中'), findsOneWidget);
    expect(find.textContaining('排队 2 人'), findsOneWidget);

    await tester.tap(find.text('王医生  副主任医师'));
    await tester.pumpAndSettle();
    expect(find.text('预约 王医生'), findsOneWidget);
    expect(find.text('可选时段'), findsOneWidget);
    expect(find.textContaining('10:00'), findsWidgets);
  });
}
