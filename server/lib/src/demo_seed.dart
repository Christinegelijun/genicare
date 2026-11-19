import 'package:venicare_server/src/care_store.dart';
import 'package:venicare_server/src/consult_seed.dart';
import 'package:venicare_shared/venicare_shared.dart';

const demoRecipientId = 'recipient-mother';
const demoDoctorId = 'doctor-zhang';

/// Matches the mobile app's demo family so both ends show the same person.
void seedDemoData(InMemoryCareStore store, DateTime now) {
  store
    ..addPatient(
      const ReportPatient(
        id: demoRecipientId,
        name: '妈妈',
        gender: '女',
        birthYear: 1952,
        conditions: ['高血压', '2 型糖尿病'],
        currentMedications: ['苯磺酸氨氯地平片 5mg 每日一次', '二甲双胍 0.5g 每日两次'],
      ),
    )
    ..addDoctor(
      const DoctorProfile(
        id: demoDoctorId,
        name: '张医生',
        organization: '社区卫生服务中心',
        department: '全科',
        departmentId: 'dept-general',
        title: '主治医师',
        specialties: '慢病随访、老年人用药管理',
        // Demo only: the same account doubles as the scheduling admin.
        isAdmin: true,
      ),
    )
    ..bind(recipientId: demoRecipientId, doctorId: demoDoctorId);
  seedConsultData(store, now);

  final today = DateTime(now.year, now.month, now.day);
  final readings = <VitalReading>[];
  final doses = <MedicationDose>[];
  for (var day = 13; day >= 0; day--) {
    final date = today.subtract(Duration(days: day));
    if (day % 4 != 3) {
      final systolic = 126 + (day * 7) % 19;
      final diastolic = 78 + (day * 5) % 13;
      readings.add(
        VitalReading(
          id: 'seed-bp-$day',
          kind: ReadingKind.bloodPressure,
          measuredAt: date.add(const Duration(hours: 7, minutes: 40)),
          source: day.isEven ? ReadingSource.voice : ReadingSource.typed,
          recordedBy: '妈妈',
          systolic: systolic,
          diastolic: diastolic,
          heartRate: 66 + (day * 3) % 14,
          transcript: day.isEven ? '血压$systolic，$diastolic' : null,
        ),
      );
    }
    if (day % 3 == 0) {
      readings.add(
        VitalReading(
          id: 'seed-bs-$day',
          kind: ReadingKind.bloodSugar,
          measuredAt: date.add(const Duration(hours: 7)),
          source: ReadingSource.voice,
          recordedBy: '妈妈',
          bloodSugar: 5.8 + (day % 5) * 0.4,
          transcript: '血糖${(5.8 + (day % 5) * 0.4).toStringAsFixed(1)}',
        ),
      );
    }
    for (final (slot, hour) in [('早间用药', 8), ('晚间用药', 20)]) {
      final scheduledAt = date.add(Duration(hours: hour));
      if (!scheduledAt.isBefore(now)) continue;
      final missed = day == 5 && hour == 20;
      doses.add(
        MedicationDose(
          id: 'seed-dose-$day-$hour',
          planName: slot,
          scheduledAt: scheduledAt,
          status: missed ? DoseStatus.missed : DoseStatus.confirmed,
          confirmedAt: missed
              ? null
              : scheduledAt.add(const Duration(minutes: 6)),
          evidence: missed ? null : DoseEvidence.selfReported,
        ),
      );
    }
  }

  store.upsertCareData(
    demoRecipientId,
    readings: readings,
    doses: doses,
    events: [
      CareEvent(
        id: 'seed-event-fall',
        title: '疑似跌倒',
        severity: EventSeverity.critical,
        occurredAt: today
            .subtract(const Duration(days: 4))
            .add(const Duration(hours: 15)),
        location: '客厅',
        resolution: '家属 3 分钟内认领，电话确认老人已自行起身，无明显外伤',
      ),
      CareEvent(
        id: 'seed-event-night',
        title: '夜间长时间未活动',
        severity: EventSeverity.info,
        occurredAt: today.subtract(const Duration(days: 1, hours: 1)),
        location: '卧室',
        resolution: '次日清晨检测到正常起身',
      ),
    ],
  );

  final report = buildHealthReport(
    id: 'seed-report-1',
    patient: store.patient(demoRecipientId)!,
    periodStart: today.subtract(const Duration(days: 13)),
    periodEnd: today.add(const Duration(days: 1)),
    generatedAt: now.subtract(const Duration(minutes: 30)),
    requestedBy: '李俊',
    familyNote: '妈妈最近说早上起床有点头晕，麻烦张医生看看血压是否需要调药。',
    readings: store.readings(demoRecipientId),
    doses: store.doses(demoRecipientId),
    events: store.events(demoRecipientId),
  );
  store.saveDelivery(
    ReportDelivery(
      id: 'seed-delivery-1',
      report: report,
      doctorId: demoDoctorId,
      doctorName: '张医生',
      status: DeliveryStatus.sent,
      sentAt: report.generatedAt,
    ),
  );
}
