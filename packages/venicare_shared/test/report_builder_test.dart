import 'package:test/test.dart';
import 'package:venicare_shared/venicare_shared.dart';

void main() {
  final start = DateTime.utc(2026, 11, 1);
  final end = DateTime.utc(2026, 11, 8);
  const patient = ReportPatient(id: 'p1', name: '妈妈', conditions: ['高血压']);

  VitalReading pressure(String id, DateTime at, int sys, int dia, {int? hr}) {
    return VitalReading(
      id: id,
      kind: ReadingKind.bloodPressure,
      measuredAt: at,
      source: ReadingSource.voice,
      recordedBy: '妈妈',
      systolic: sys,
      diastolic: dia,
      heartRate: hr,
    );
  }

  HealthReport build({
    List<VitalReading> readings = const [],
    List<MedicationDose> doses = const [],
  }) {
    return buildHealthReport(
      id: 'r1',
      patient: patient,
      periodStart: start,
      periodEnd: end,
      generatedAt: end,
      requestedBy: '李俊',
      readings: readings,
      doses: doses,
    );
  }

  test('只统计报告周期内的数据并按时间排序', () {
    final report = build(
      readings: [
        pressure('late', DateTime.utc(2026, 11, 3, 8), 142, 88, hr: 72),
        pressure('early', DateTime.utc(2026, 11, 2, 8), 128, 82),
        pressure('before', DateTime.utc(2026, 10, 31, 8), 150, 95),
        pressure('at-end', end, 150, 95),
      ],
    );

    expect(report.readings.map((r) => r.id), ['early', 'late']);
    expect(report.bloodPressure!.count, 2);
    expect(report.bloodPressure!.systolic.average, 135);
    expect(report.bloodPressure!.aboveReferenceCount, 1);
    expect(report.heartRate!.count, 1);
    expect(report.bloodSugar, isNull);
    expect(report.daysWithReadings, 2);
    expect(report.totalDays, 7);
    expect(report.flaggedReadingCount, 1);
  });

  test('用药确认率只按周期内计划剂次计算', () {
    final report = build(
      doses: [
        MedicationDose(
          id: 'd1',
          planName: '早间用药',
          scheduledAt: DateTime.utc(2026, 11, 2, 0),
          status: DoseStatus.confirmed,
          evidence: DoseEvidence.selfReported,
        ),
        MedicationDose(
          id: 'd2',
          planName: '晚间用药',
          scheduledAt: DateTime.utc(2026, 11, 2, 12),
          status: DoseStatus.missed,
        ),
      ],
    );

    expect(report.medication.scheduled, 2);
    expect(report.medication.missed, 1);
    expect(report.medication.confirmationRate, 0.5);
  });

  test('报告 JSON 往返后内容不变', () {
    final report = build(
      readings: [pressure('a', DateTime.utc(2026, 11, 2, 8), 128, 82)],
    );
    final delivery = ReportDelivery(
      id: 'dl1',
      report: report,
      doctorId: 'doc1',
      doctorName: '张医生',
      status: DeliveryStatus.sent,
      sentAt: end,
    );

    final decoded = ReportDelivery.fromJson(delivery.toJson());

    expect(decoded.toJson(), delivery.toJson());
    expect(decoded.report.patient.conditions, ['高血压']);
  });

  test('拒绝解析更高版本的报告', () {
    final json = build().toJson()..['schemaVersion'] = 99;
    expect(() => HealthReport.fromJson(json), throwsFormatException);
  });
}
