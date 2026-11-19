import 'package:venicare_shared/src/report/reference_ranges.dart';
import 'package:venicare_shared/src/report/report_models.dart';

/// Builds an immutable report from everything recorded inside
/// [periodStart, periodEnd). Callers pass all data they hold; filtering and
/// ordering happen here so every side produces the same report.
HealthReport buildHealthReport({
  required String id,
  required ReportPatient patient,
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime generatedAt,
  required String requestedBy,
  required Iterable<VitalReading> readings,
  Iterable<MedicationDose> doses = const [],
  Iterable<CareEvent> events = const [],
  String? familyNote,
}) {
  if (!periodEnd.isAfter(periodStart)) {
    throw ArgumentError('报告结束时间必须晚于开始时间');
  }
  bool inPeriod(DateTime at) =>
      !at.isBefore(periodStart) && at.isBefore(periodEnd);

  final periodReadings = readings.where((r) => inPeriod(r.measuredAt)).toList()
    ..sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
  final periodDoses = doses.where((d) => inPeriod(d.scheduledAt)).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  final periodEvents = events.where((e) => inPeriod(e.occurredAt)).toList()
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  final pressure = periodReadings
      .where((r) => r.systolic != null && r.diastolic != null)
      .toList();
  final heartRates = [for (final r in periodReadings) ?r.heartRate];
  final sugars = [for (final r in periodReadings) ?r.bloodSugar];

  final days = {
    for (final r in periodReadings)
      DateTime(r.measuredAt.year, r.measuredAt.month, r.measuredAt.day),
  };

  return HealthReport(
    id: id,
    patient: patient,
    periodStart: periodStart,
    periodEnd: periodEnd,
    generatedAt: generatedAt,
    requestedBy: requestedBy,
    familyNote: familyNote,
    daysWithReadings: days.length,
    totalDays: (periodEnd.difference(periodStart).inHours / 24).ceil(),
    bloodPressure: pressure.isEmpty
        ? null
        : BloodPressureSummary(
            systolic: _summarize(
              pressure.map((r) => r.systolic!),
              (v) => v >= ReferenceRanges.systolicHigh,
            ),
            diastolic: _summarize(
              pressure.map((r) => r.diastolic!),
              (v) => v >= ReferenceRanges.diastolicHigh,
            ),
            aboveReferenceCount: pressure
                .where(
                  (r) => isPressureAboveReference(r.systolic!, r.diastolic!),
                )
                .length,
          ),
    heartRate: heartRates.isEmpty
        ? null
        : _summarize(heartRates, (v) => isHeartRateOutOfRange(v.toInt())),
    bloodSugar: sugars.isEmpty
        ? null
        : _summarize(sugars, (v) => isBloodSugarOutOfRange(v.toDouble())),
    medication: MedicationSummary(
      scheduled: periodDoses.length,
      confirmed: periodDoses
          .where((d) => d.status == DoseStatus.confirmed)
          .length,
    ),
    readings: List.unmodifiable(periodReadings),
    doses: List.unmodifiable(periodDoses),
    events: List.unmodifiable(periodEvents),
  );
}

NumericSummary _summarize(Iterable<num> values, bool Function(num) flagged) {
  final list = values.toList();
  var sum = 0.0;
  var min = double.infinity;
  var max = double.negativeInfinity;
  var flaggedCount = 0;
  for (final value in list) {
    final v = value.toDouble();
    sum += v;
    if (v < min) min = v;
    if (v > max) max = v;
    if (flagged(value)) flaggedCount++;
  }
  return NumericSummary(
    count: list.length,
    average: (sum / list.length * 10).roundToDouble() / 10,
    min: min,
    max: max,
    flaggedCount: flaggedCount,
  );
}
