enum ProtectionLevel { normal, attention, incomplete, urgent, unknown }

enum AlertSeverity { info, warning, critical }

enum AlertStatus { pending, claimed, resolved }

enum DeviceStatus { online, warning, offline }

enum FamilyRole { owner, admin, contact, viewer }

enum AppThemePreference { system, light, dark }

enum MedicationPhase { upcoming, due, done }

class CareRecipient {
  const CareRecipient({
    required this.id,
    required this.name,
    required this.relationship,
    required this.protectionLevel,
    required this.statusText,
    required this.presenceText,
    required this.phoneMasked,
    required this.lastUpdatedAt,
  });

  final String id;
  final String name;
  final String relationship;
  final ProtectionLevel protectionLevel;
  final String statusText;
  final String presenceText;
  final String phoneMasked;
  final DateTime lastUpdatedAt;

  CareRecipient copyWith({
    ProtectionLevel? protectionLevel,
    String? statusText,
    String? presenceText,
    DateTime? lastUpdatedAt,
  }) {
    return CareRecipient(
      id: id,
      name: name,
      relationship: relationship,
      protectionLevel: protectionLevel ?? this.protectionLevel,
      statusText: statusText ?? this.statusText,
      presenceText: presenceText ?? this.presenceText,
      phoneMasked: phoneMasked,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
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
    bool clearClaimedBy = false,
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
      claimedBy: clearClaimedBy ? null : (claimedBy ?? this.claimedBy),
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
    required this.firmware,
    required this.powerLabel,
    required this.criticalForProtection,
    this.batteryPercent,
    this.fault,
  });

  final String id;
  final String name;
  final String location;
  final String icon;
  final DeviceStatus status;
  final String statusText;
  final DateTime lastSeenAt;
  final String firmware;
  final String powerLabel;
  final bool criticalForProtection;
  final int? batteryPercent;
  final String? fault;

  CareDevice copyWith({DateTime? lastSeenAt, String? statusText}) {
    return CareDevice(
      id: id,
      name: name,
      location: location,
      icon: icon,
      status: status,
      statusText: statusText ?? this.statusText,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      firmware: firmware,
      powerLabel: powerLabel,
      criticalForProtection: criticalForProtection,
      batteryPercent: batteryPercent,
      fault: fault,
    );
  }
}

class MedicationTask {
  const MedicationTask({
    required this.id,
    required this.name,
    required this.dosage,
    required this.compartment,
    required this.scheduleText,
    required this.periodLabel,
    required this.remindRule,
    required this.scheduledAt,
    required this.completed,
    required this.notifyFamilyIfMissed,
    required this.createdBy,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String dosage;
  final String compartment;
  final String scheduleText;
  final String periodLabel;
  final String remindRule;
  final DateTime scheduledAt;
  final bool completed;
  final bool notifyFamilyIfMissed;
  final String createdBy;
  final DateTime updatedAt;

  MedicationTask copyWith({
    bool? completed,
    bool? notifyFamilyIfMissed,
    DateTime? updatedAt,
  }) {
    return MedicationTask(
      id: id,
      name: name,
      dosage: dosage,
      compartment: compartment,
      scheduleText: scheduleText,
      periodLabel: periodLabel,
      remindRule: remindRule,
      scheduledAt: scheduledAt,
      completed: completed ?? this.completed,
      notifyFamilyIfMissed: notifyFamilyIfMissed ?? this.notifyFamilyIfMissed,
      createdBy: createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.phoneMasked,
    required this.relation,
    this.isSelf = false,
  });

  final String id;
  final String name;
  final FamilyRole role;
  final String phoneMasked;
  final String relation;
  final bool isSelf;

  FamilyMember copyWith({String? name, String? relation, String? phoneMasked}) {
    return FamilyMember(
      id: id,
      name: name ?? this.name,
      role: role,
      phoneMasked: phoneMasked ?? this.phoneMasked,
      relation: relation ?? this.relation,
      isSelf: isSelf,
    );
  }
}

class EscalationStep {
  const EscalationStep({
    required this.id,
    required this.channel,
    required this.description,
    required this.delayMinutes,
    required this.enabled,
    this.locked = false,
  });

  final String id;
  final String channel;
  final String description;
  final int delayMinutes;
  final bool enabled;
  final bool locked;

  EscalationStep copyWith({bool? enabled}) {
    return EscalationStep(
      id: id,
      channel: channel,
      description: description,
      delayMinutes: delayMinutes,
      enabled: enabled ?? this.enabled,
      locked: locked,
    );
  }
}

class AccessRecord {
  const AccessRecord({
    required this.id,
    required this.actor,
    required this.action,
    required this.occurredAt,
  });

  final String id;
  final String actor;
  final String action;
  final DateTime occurredAt;
}

class PrivacySettings {
  const PrivacySettings({
    required this.shareRoom,
    required this.shareMedication,
    required this.shareDeviceHealth,
  });

  final bool shareRoom;
  final bool shareMedication;
  final bool shareDeviceHealth;

  PrivacySettings copyWith({
    bool? shareRoom,
    bool? shareMedication,
    bool? shareDeviceHealth,
  }) {
    return PrivacySettings(
      shareRoom: shareRoom ?? this.shareRoom,
      shareMedication: shareMedication ?? this.shareMedication,
      shareDeviceHealth: shareDeviceHealth ?? this.shareDeviceHealth,
    );
  }
}

class SelfCheckReport {
  const SelfCheckReport({
    required this.checkedAt,
    required this.lines,
    required this.attentionCount,
  });

  final DateTime checkedAt;
  final List<String> lines;
  final int attentionCount;
}

class AppState {
  const AppState({
    required this.familyName,
    required this.recipient,
    required this.alerts,
    required this.devices,
    required this.medicationTasks,
    required this.members,
    required this.escalation,
    required this.accessLogs,
    required this.privacy,
    required this.lastSyncedAt,
    required this.themePreference,
    this.selfCheck,
    this.protectionNote,
    this.selectedTab = 0,
  });

  final String familyName;
  final CareRecipient recipient;
  final List<CareAlert> alerts;
  final List<CareDevice> devices;
  final List<MedicationTask> medicationTasks;
  final List<FamilyMember> members;
  final List<EscalationStep> escalation;
  final List<AccessRecord> accessLogs;
  final PrivacySettings privacy;
  final DateTime lastSyncedAt;
  final AppThemePreference themePreference;
  final SelfCheckReport? selfCheck;
  final String? protectionNote;
  final int selectedTab;

  List<CareAlert> get activeAlerts =>
      alerts.where((alert) => alert.status != AlertStatus.resolved).toList();

  AppState copyWith({
    CareRecipient? recipient,
    List<CareAlert>? alerts,
    List<CareDevice>? devices,
    List<MedicationTask>? medicationTasks,
    List<FamilyMember>? members,
    List<EscalationStep>? escalation,
    List<AccessRecord>? accessLogs,
    PrivacySettings? privacy,
    DateTime? lastSyncedAt,
    AppThemePreference? themePreference,
    SelfCheckReport? selfCheck,
    bool clearSelfCheck = false,
    String? protectionNote,
    bool clearProtectionNote = false,
    int? selectedTab,
  }) {
    return AppState(
      familyName: familyName,
      recipient: recipient ?? this.recipient,
      alerts: alerts ?? this.alerts,
      devices: devices ?? this.devices,
      medicationTasks: medicationTasks ?? this.medicationTasks,
      members: members ?? this.members,
      escalation: escalation ?? this.escalation,
      accessLogs: accessLogs ?? this.accessLogs,
      privacy: privacy ?? this.privacy,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      themePreference: themePreference ?? this.themePreference,
      selfCheck: clearSelfCheck ? null : (selfCheck ?? this.selfCheck),
      protectionNote: clearProtectionNote
          ? null
          : (protectionNote ?? this.protectionNote),
      selectedTab: selectedTab ?? this.selectedTab,
    );
  }
}
