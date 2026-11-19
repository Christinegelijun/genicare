import 'package:venicare_shared/src/report/report_models.dart';

enum DeliveryStatus { sent, read, replied, revoked }

class DoctorReply {
  const DoctorReply({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.content,
    required this.createdAt,
  });

  factory DoctorReply.fromJson(Json json) {
    return DoctorReply(
      id: json['id']! as String,
      doctorId: json['doctorId']! as String,
      doctorName: json['doctorName']! as String,
      content: json['content']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  final String id;
  final String doctorId;
  final String doctorName;
  final String content;
  final DateTime createdAt;

  Json toJson() => {
    'id': id,
    'doctorId': doctorId,
    'doctorName': doctorName,
    'content': content,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// One report delivered to one doctor. The same [HealthReport] snapshot may be
/// delivered to several doctors; each delivery has its own status and replies.
class ReportDelivery {
  const ReportDelivery({
    required this.id,
    required this.report,
    required this.doctorId,
    required this.doctorName,
    required this.status,
    required this.sentAt,
    this.readAt,
    this.replies = const [],
  });

  factory ReportDelivery.fromJson(Json json) {
    final readAt = json['readAt'] as String?;
    return ReportDelivery(
      id: json['id']! as String,
      report: HealthReport.fromJson(json['report']! as Json),
      doctorId: json['doctorId']! as String,
      doctorName: json['doctorName']! as String,
      status: DeliveryStatus.values.byName(json['status']! as String),
      sentAt: DateTime.parse(json['sentAt']! as String),
      readAt: readAt == null ? null : DateTime.parse(readAt),
      replies: (json['replies'] as List<Object?>? ?? const [])
          .map((item) => DoctorReply.fromJson(item! as Json))
          .toList(),
    );
  }

  final String id;
  final HealthReport report;
  final String doctorId;
  final String doctorName;
  final DeliveryStatus status;
  final DateTime sentAt;
  final DateTime? readAt;
  final List<DoctorReply> replies;

  ReportDelivery copyWith({
    DeliveryStatus? status,
    DateTime? readAt,
    List<DoctorReply>? replies,
  }) {
    return ReportDelivery(
      id: id,
      report: report,
      doctorId: doctorId,
      doctorName: doctorName,
      status: status ?? this.status,
      sentAt: sentAt,
      readAt: readAt ?? this.readAt,
      replies: replies ?? this.replies,
    );
  }

  ReportInboxItem toInboxItem() {
    return ReportInboxItem(
      deliveryId: id,
      patientName: report.patient.name,
      periodStart: report.periodStart,
      periodEnd: report.periodEnd,
      sentAt: sentAt,
      status: status,
      flaggedReadingCount: report.flaggedReadingCount,
      criticalEventCount: report.events
          .where((e) => e.severity == EventSeverity.critical)
          .length,
    );
  }

  Json toJson() => {
    'id': id,
    'report': report.toJson(),
    'doctorId': doctorId,
    'doctorName': doctorName,
    'status': status.name,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'readAt': readAt?.toUtc().toIso8601String(),
    'replies': replies.map((r) => r.toJson()).toList(),
  };
}

/// Lightweight row for the doctor's inbox; avoids shipping every reading.
class ReportInboxItem {
  const ReportInboxItem({
    required this.deliveryId,
    required this.patientName,
    required this.periodStart,
    required this.periodEnd,
    required this.sentAt,
    required this.status,
    required this.flaggedReadingCount,
    required this.criticalEventCount,
  });

  factory ReportInboxItem.fromJson(Json json) {
    return ReportInboxItem(
      deliveryId: json['deliveryId']! as String,
      patientName: json['patientName']! as String,
      periodStart: DateTime.parse(json['periodStart']! as String),
      periodEnd: DateTime.parse(json['periodEnd']! as String),
      sentAt: DateTime.parse(json['sentAt']! as String),
      status: DeliveryStatus.values.byName(json['status']! as String),
      flaggedReadingCount: json['flaggedReadingCount']! as int,
      criticalEventCount: json['criticalEventCount']! as int,
    );
  }

  final String deliveryId;
  final String patientName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime sentAt;
  final DeliveryStatus status;
  final int flaggedReadingCount;
  final int criticalEventCount;

  Json toJson() => {
    'deliveryId': deliveryId,
    'patientName': patientName,
    'periodStart': periodStart.toUtc().toIso8601String(),
    'periodEnd': periodEnd.toUtc().toIso8601String(),
    'sentAt': sentAt.toUtc().toIso8601String(),
    'status': status.name,
    'flaggedReadingCount': flaggedReadingCount,
    'criticalEventCount': criticalEventCount,
  };
}
