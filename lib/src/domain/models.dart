enum ProtectionLevel { normal, attention, incomplete, urgent, unknown }

enum AlertSeverity { info, warning, critical }

enum AlertStatus { pending, claimed, resolved }

enum DeviceStatus { online, warning, offline }

class CareRecipient {
  const CareRecipient({
    required this.id,
    required this.name,
    required this.relationship,
    required this.protectionLevel,
    required this.statusText,
    required this.lastUpdatedAt,
  });

  final String id;
  final String name;
  final String relationship;
  final ProtectionLevel protectionLevel;
  final String statusText;
  final DateTime lastUpdatedAt;
}

class CareAlert {
  const CareAlert({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.occurredAt,
    required this.severity,
    required this.status,
    required this.timeline,
    this.claimedBy,
  });

  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime occurredAt;
  final AlertSeverity severity;
  final AlertStatus status;
  final String? claimedBy;
  final List<AlertTimelineEntry> timeline;

  CareAlert copyWith({
    AlertStatus? status,
    String? claimedBy,
    List<AlertTimelineEntry>? timeline,
  }) {
    return CareAlert(
      id: id,
      title: title,
      description: description,
      location: location,
      occurredAt: occurredAt,
      severity: severity,
      status: status ?? this.status,
      claimedBy: claimedBy ?? this.claimedBy,
      timeline: timeline ?? this.timeline,
    );
  }
}

class AlertTimelineEntry {
  const AlertTimelineEntry({
    required this.title,
    required this.detail,
    required this.occurredAt,
  });

  final String title;
  final String detail;
  final DateTime occurredAt;
}

class CareDevice {
  const CareDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.icon,
    required this.status,
    required this.statusText,
    required this.lastSeenAt,
    this.batteryPercent,
  });

  final String id;
  final String name;
  final String location;
  final String icon;
  final DeviceStatus status;
  final String statusText;
  final DateTime lastSeenAt;
  final int? batteryPercent;
}

class MedicationTask {
  const MedicationTask({
    required this.id,
    required this.name,
    required this.dosage,
    required this.scheduledAt,
    required this.completed,
  });

  final String id;
  final String name;
  final String dosage;
  final DateTime scheduledAt;
  final bool completed;
}

class AppState {
  const AppState({
    required this.recipient,
    required this.alerts,
    required this.devices,
    required this.medicationTasks,
    this.selectedTab = 0,
  });

  final CareRecipient recipient;
  final List<CareAlert> alerts;
  final List<CareDevice> devices;
  final List<MedicationTask> medicationTasks;
  final int selectedTab;

  List<CareAlert> get activeAlerts =>
      alerts.where((alert) => alert.status != AlertStatus.resolved).toList();

  AppState copyWith({
    CareRecipient? recipient,
    List<CareAlert>? alerts,
    List<CareDevice>? devices,
    List<MedicationTask>? medicationTasks,
    int? selectedTab,
  }) {
    return AppState(
      recipient: recipient ?? this.recipient,
      alerts: alerts ?? this.alerts,
      devices: devices ?? this.devices,
      medicationTasks: medicationTasks ?? this.medicationTasks,
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}
