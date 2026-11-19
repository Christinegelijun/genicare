import 'package:venicare_shared/src/report/reference_ranges.dart';

typedef Json = Map<String, Object?>;

enum ReadingKind { bloodPressure, heartRate, bloodSugar }

enum ReadingSource { voice, typed, tap, device }

enum DoseStatus { confirmed, missed }

/// How a dose was confirmed. An opened pillbox compartment is only evidence of
/// an action, so reports must not present it as "taken".
enum DoseEvidence { selfReported, familyReported, pillboxOpened }

enum EventSeverity { info, warning, critical }

T _enumByName<T extends Enum>(List<T> values, Object? name) {
  return values.byName(name! as String);
}

DateTime _date(Object? value) => DateTime.parse(value! as String);

DateTime? _dateOrNull(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<T> _list<T>(Object? value, T Function(Json) fromJson) {
  return (value as List<Object?>? ?? const [])
      .map((item) => fromJson(item! as Json))
      .toList();
}

class VitalReading {
  const VitalReading({
    required this.id,
    required this.kind,
    required this.measuredAt,
    required this.source,
    required this.recordedBy,
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.bloodSugar,
    this.transcript,
  });

  factory VitalReading.fromJson(Json json) {
    return VitalReading(
      id: json['id']! as String,
      kind: _enumByName(ReadingKind.values, json['kind']),
      measuredAt: _date(json['measuredAt']),
      source: _enumByName(ReadingSource.values, json['source']),
      recordedBy: json['recordedBy']! as String,
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      heartRate: json['heartRate'] as int?,
      bloodSugar: (json['bloodSugar'] as num?)?.toDouble(),
      transcript: json['transcript'] as String?,
    );
  }

  final String id;
  final ReadingKind kind;
  final DateTime measuredAt;
  final ReadingSource source;
  final String recordedBy;
  final int? systolic;
  final int? diastolic;

  /// Also present on blood-pressure readings when the cuff reported a pulse.
  final int? heartRate;
  final double? bloodSugar;

  /// Original spoken or typed text, kept so the doctor can see what the elder
  /// actually said when a parsed value looks wrong.
  final String? transcript;

  bool get flagged {
    final sys = systolic;
    final dia = diastolic;
    final hr = heartRate;
    final sugar = bloodSugar;
    return (sys != null && dia != null && isPressureAboveReference(sys, dia)) ||
        (hr != null && isHeartRateOutOfRange(hr)) ||
        (sugar != null && isBloodSugarOutOfRange(sugar));
  }

  Json toJson() => {
    'id': id,
    'kind': kind.name,
    'measuredAt': measuredAt.toUtc().toIso8601String(),
    'source': source.name,
    'recordedBy': recordedBy,
    'systolic': systolic,
    'diastolic': diastolic,
    'heartRate': heartRate,
    'bloodSugar': bloodSugar,
    'transcript': transcript,
  };
}

class MedicationDose {
  const MedicationDose({
    required this.id,
    required this.planName,
    required this.scheduledAt,
    required this.status,
    this.confirmedAt,
    this.evidence,
  });

  factory MedicationDose.fromJson(Json json) {
    final evidence = json['evidence'];
    return MedicationDose(
      id: json['id']! as String,
      planName: json['planName']! as String,
      scheduledAt: _date(json['scheduledAt']),
      status: _enumByName(DoseStatus.values, json['status']),
      confirmedAt: _dateOrNull(json['confirmedAt']),
      evidence: evidence == null
          ? null
          : _enumByName(DoseEvidence.values, evidence),
    );
  }

  final String id;
  final String planName;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime? confirmedAt;
  final DoseEvidence? evidence;

  Json toJson() => {
    'id': id,
    'planName': planName,
    'scheduledAt': scheduledAt.toUtc().toIso8601String(),
    'status': status.name,
    'confirmedAt': confirmedAt?.toUtc().toIso8601String(),
    'evidence': evidence?.name,
  };
}

class CareEvent {
  const CareEvent({
    required this.id,
    required this.title,
    required this.severity,
    required this.occurredAt,
    required this.location,
    this.resolution,
  });

  factory CareEvent.fromJson(Json json) {
    return CareEvent(
      id: json['id']! as String,
      title: json['title']! as String,
      severity: _enumByName(EventSeverity.values, json['severity']),
      occurredAt: _date(json['occurredAt']),
      location: json['location']! as String,
      resolution: json['resolution'] as String?,
    );
  }

  final String id;
  final String title;
  final EventSeverity severity;
  final DateTime occurredAt;
  final String location;
  final String? resolution;

  Json toJson() => {
    'id': id,
    'title': title,
    'severity': severity.name,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'location': location,
    'resolution': resolution,
  };
}

class ReportPatient {
  const ReportPatient({
    required this.id,
    required this.name,
    this.gender,
    this.birthYear,
    this.conditions = const [],
    this.currentMedications = const [],
  });

  factory ReportPatient.fromJson(Json json) {
    return ReportPatient(
      id: json['id']! as String,
      name: json['name']! as String,
      gender: json['gender'] as String?,
      birthYear: json['birthYear'] as int?,
      conditions: (json['conditions'] as List<Object?>? ?? const [])
          .cast<String>(),
      currentMedications:
          (json['currentMedications'] as List<Object?>? ?? const [])
              .cast<String>(),
    );
  }

  final String id;
  final String name;
  final String? gender;
  final int? birthYear;

  /// Self-reported by the family; not verified medical history.
  final List<String> conditions;
  final List<String> currentMedications;

  Json toJson() => {
    'id': id,
    'name': name,
    'gender': gender,
    'birthYear': birthYear,
    'conditions': conditions,
    'currentMedications': currentMedications,
  };
}

class NumericSummary {
  const NumericSummary({
    required this.count,
    required this.average,
    required this.min,
    required this.max,
    required this.flaggedCount,
  });

  factory NumericSummary.fromJson(Json json) {
    return NumericSummary(
      count: json['count']! as int,
      average: (json['average']! as num).toDouble(),
      min: (json['min']! as num).toDouble(),
      max: (json['max']! as num).toDouble(),
      flaggedCount: json['flaggedCount']! as int,
    );
  }

  final int count;
  final double average;
  final double min;
  final double max;
  final int flaggedCount;

  Json toJson() => {
    'count': count,
    'average': average,
    'min': min,
    'max': max,
    'flaggedCount': flaggedCount,
  };
}

class BloodPressureSummary {
  const BloodPressureSummary({
    required this.systolic,
    required this.diastolic,
    required this.aboveReferenceCount,
  });

  factory BloodPressureSummary.fromJson(Json json) {
    return BloodPressureSummary(
      systolic: NumericSummary.fromJson(json['systolic']! as Json),
      diastolic: NumericSummary.fromJson(json['diastolic']! as Json),
      aboveReferenceCount: json['aboveReferenceCount']! as int,
    );
  }

  final NumericSummary systolic;
  final NumericSummary diastolic;
  final int aboveReferenceCount;

  int get count => systolic.count;

  Json toJson() => {
    'systolic': systolic.toJson(),
    'diastolic': diastolic.toJson(),
    'aboveReferenceCount': aboveReferenceCount,
  };
}

class MedicationSummary {
  const MedicationSummary({required this.scheduled, required this.confirmed});

  factory MedicationSummary.fromJson(Json json) {
    return MedicationSummary(
      scheduled: json['scheduled']! as int,
      confirmed: json['confirmed']! as int,
    );
  }

  final int scheduled;
  final int confirmed;

  int get missed => scheduled - confirmed;

  double? get confirmationRate => scheduled == 0 ? null : confirmed / scheduled;

  Json toJson() => {'scheduled': scheduled, 'confirmed': confirmed};
}

/// Immutable snapshot sent to a doctor. Once generated it is never edited; a
/// correction produces a new report so what the doctor read stays auditable.
class HealthReport {
  const HealthReport({
    required this.id,
    required this.patient,
    required this.periodStart,
    required this.periodEnd,
    required this.generatedAt,
    required this.requestedBy,
    required this.daysWithReadings,
    required this.totalDays,
    required this.readings,
    required this.doses,
    required this.events,
    required this.medication,
    this.bloodPressure,
    this.heartRate,
    this.bloodSugar,
    this.familyNote,
    this.schemaVersion = currentSchemaVersion,
  });

  factory HealthReport.fromJson(Json json) {
    final schemaVersion = json['schemaVersion']! as int;
    if (schemaVersion > currentSchemaVersion) {
      throw FormatException('不支持的报告版本 $schemaVersion，请升级客户端');
    }
    final bloodPressure = json['bloodPressure'] as Json?;
    final heartRate = json['heartRate'] as Json?;
    final bloodSugar = json['bloodSugar'] as Json?;
    return HealthReport(
      schemaVersion: schemaVersion,
      id: json['id']! as String,
      patient: ReportPatient.fromJson(json['patient']! as Json),
      periodStart: _date(json['periodStart']),
      periodEnd: _date(json['periodEnd']),
      generatedAt: _date(json['generatedAt']),
      requestedBy: json['requestedBy']! as String,
      familyNote: json['familyNote'] as String?,
      daysWithReadings: json['daysWithReadings']! as int,
      totalDays: json['totalDays']! as int,
      bloodPressure: bloodPressure == null
          ? null
          : BloodPressureSummary.fromJson(bloodPressure),
      heartRate: heartRate == null ? null : NumericSummary.fromJson(heartRate),
      bloodSugar: bloodSugar == null
          ? null
          : NumericSummary.fromJson(bloodSugar),
      medication: MedicationSummary.fromJson(json['medication']! as Json),
      readings: _list(json['readings'], VitalReading.fromJson),
      doses: _list(json['doses'], MedicationDose.fromJson),
      events: _list(json['events'], CareEvent.fromJson),
    );
  }

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String id;
  final ReportPatient patient;

  /// Inclusive start and exclusive end of the covered period.
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final String requestedBy;
  final String? familyNote;
  final int daysWithReadings;
  final int totalDays;
  final BloodPressureSummary? bloodPressure;
  final NumericSummary? heartRate;
  final NumericSummary? bloodSugar;
  final MedicationSummary medication;
  final List<VitalReading> readings;
  final List<MedicationDose> doses;
  final List<CareEvent> events;

  int get flaggedReadingCount => readings.where((r) => r.flagged).length;

  Json toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'patient': patient.toJson(),
    'periodStart': periodStart.toUtc().toIso8601String(),
    'periodEnd': periodEnd.toUtc().toIso8601String(),
    'generatedAt': generatedAt.toUtc().toIso8601String(),
    'requestedBy': requestedBy,
    'familyNote': familyNote,
    'daysWithReadings': daysWithReadings,
    'totalDays': totalDays,
    'bloodPressure': bloodPressure?.toJson(),
    'heartRate': heartRate?.toJson(),
    'bloodSugar': bloodSugar?.toJson(),
    'medication': medication.toJson(),
    'readings': readings.map((r) => r.toJson()).toList(),
    'doses': doses.map((d) => d.toJson()).toList(),
    'events': events.map((e) => e.toJson()).toList(),
  };
}
