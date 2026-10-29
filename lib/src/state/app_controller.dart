import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/data/demo_repository.dart';
import 'package:venicare_app/src/domain/models.dart';

final demoRepositoryProvider = Provider<DemoRepository>(
  (ref) => DemoRepository(),
);

final appControllerProvider = NotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends Notifier<AppState> {
  @override
  AppState build() {
    return ref.read(demoRepositoryProvider).loadInitialState();
  }

  void selectTab(int index) {
    state = state.copyWith(selectedTab: index);
  }

  void setThemePreference(AppThemePreference preference) {
    state = state.copyWith(themePreference: preference);
  }

  void markSynced() {
    final now = DateTime.now();
    state = state.copyWith(
      lastSyncedAt: now,
      recipient: state.recipient.copyWith(lastUpdatedAt: now),
    );
  }

  void resetDemo() {
    final tab = state.selectedTab;
    final theme = state.themePreference;
    state = ref
        .read(demoRepositoryProvider)
        .loadInitialState()
        .copyWith(selectedTab: tab, themePreference: theme);
  }

  bool claimAlert(String alertId) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status != AlertStatus.pending) {
      return false;
    }

    _replaceAlert(
      alert.copyWith(
        status: AlertStatus.claimed,
        claimedBy: '我',
        timeline: [
          ...alert.timeline,
          AlertTimelineEntry(
            title: '我已开始处理',
            detail: '其他联系人会同步看到当前认领状态。',
            occurredAt: DateTime.now(),
          ),
        ],
      ),
    );
    state = state.copyWith(
      recipient: state.recipient.copyWith(
        statusText: '我正在处理这起紧急事件',
        lastUpdatedAt: DateTime.now(),
      ),
    );
    _addLog('认领了「${alert.title}」');
    return true;
  }

  bool releaseAlert(String alertId) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status != AlertStatus.claimed) {
      return false;
    }
    if (alert.claimedBy != null && alert.claimedBy != '我') {
      return false;
    }

    _replaceAlert(
      alert.copyWith(
        status: AlertStatus.pending,
        clearClaimedBy: true,
        timeline: [
          ...alert.timeline,
          AlertTimelineEntry(
            title: '已解除认领',
            detail: '事件重新开放，其他联系人可以继续处理。',
            occurredAt: DateTime.now(),
          ),
        ],
      ),
    );
    final criticalCount = state.activeAlerts
        .where((item) => item.severity == AlertSeverity.critical)
        .length;
    state = state.copyWith(
      recipient: state.recipient.copyWith(
        protectionLevel: criticalCount > 0
            ? ProtectionLevel.urgent
            : state.recipient.protectionLevel,
        statusText: criticalCount > 0
            ? '存在 $criticalCount 个待处理紧急事件'
            : state.recipient.statusText,
        presenceText: '语音询问后暂无回应',
        lastUpdatedAt: DateTime.now(),
      ),
    );
    _addLog('解除了「${alert.title}」的认领');
    return true;
  }

  bool resolveAlert(
    String alertId, {
    String resultTitle = '事件已结束',
    String resultDetail = '家属确认老人安全，本次事件已完成处置。',
  }) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status == AlertStatus.resolved) {
      return false;
    }

    _replaceAlert(
      alert.copyWith(
        status: AlertStatus.resolved,
        claimedBy: alert.claimedBy ?? '我',
        timeline: [
          ...alert.timeline,
          AlertTimelineEntry(
            title: resultTitle,
            detail: resultDetail,
            occurredAt: DateTime.now(),
          ),
        ],
      ),
    );

    if (state.activeAlerts.isEmpty) {
      state = state.copyWith(
        recipient: state.recipient.copyWith(
          protectionLevel: ProtectionLevel.normal,
          statusText: '当前无待处理事件',
          presenceText: '家中状态平稳',
          lastUpdatedAt: DateTime.now(),
        ),
      );
    }
    _addLog('结束了「${alert.title}」');
    return true;
  }

  bool recordOnAlert({
    String? alertId,
    required String title,
    required String detail,
    String? presenceText,
  }) {
    final id =
        alertId ??
        (state.activeAlerts.isEmpty ? null : state.activeAlerts.first.id);
    var recorded = id == null;
    if (id != null) {
      recorded = appendTimeline(id, title: title, detail: detail);
    }
    if (presenceText != null) {
      state = state.copyWith(
        recipient: state.recipient.copyWith(
          presenceText: presenceText,
          lastUpdatedAt: DateTime.now(),
        ),
      );
    }
    if (recorded) {
      _addLog(title);
    }
    return recorded;
  }

  bool appendTimeline(
    String alertId, {
    required String title,
    required String detail,
  }) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status == AlertStatus.resolved) {
      return false;
    }
    _replaceAlert(
      alert.copyWith(
        timeline: [
          ...alert.timeline,
          AlertTimelineEntry(
            title: title,
            detail: detail,
            occurredAt: DateTime.now(),
          ),
        ],
      ),
    );
    return true;
  }

  void setMedicationCompleted(String id, {required bool completed}) {
    final index = state.medicationTasks.indexWhere((task) => task.id == id);
    if (index < 0) {
      return;
    }
    final task = state.medicationTasks[index];
    if (task.completed == completed) {
      return;
    }
    final now = DateTime.now();
    final tasks = [
      for (final item in state.medicationTasks)
        if (item.id == id)
          item.copyWith(completed: completed, updatedAt: now)
        else
          item,
    ];
    final alertId = 'alert-med-done-$id';
    final hasRecord = state.alerts.any((alert) => alert.id == alertId);
    final alerts = [
      if (completed && !hasRecord)
        CareAlert(
          id: alertId,
          title: '${task.name}已确认',
          description: '家属确认本次用药操作已完成。本记录不是处方或服药建议。',
          location: '卧室',
          occurredAt: now,
          severity: AlertSeverity.info,
          status: AlertStatus.resolved,
          claimedBy: '我',
          timeline: [
            AlertTimelineEntry(
              title: '家属确认',
              detail: '${task.compartment} · ${task.dosage}',
              occurredAt: now,
            ),
          ],
        ),
      ...state.alerts,
    ];
    state = state.copyWith(medicationTasks: tasks, alerts: alerts);
    _addLog(completed ? '确认了${task.name}' : '撤销了${task.name}的确认');
  }

  void toggleMedicationNotify(String id) {
    state = state.copyWith(
      medicationTasks: [
        for (final task in state.medicationTasks)
          if (task.id == id)
            task.copyWith(
              notifyFamilyIfMissed: !task.notifyFamilyIfMissed,
              updatedAt: DateTime.now(),
            )
          else
            task,
      ],
    );
  }

  void touchDevice(String id) {
    CareDevice? matched;
    final devices = [
      for (final device in state.devices)
        if (device.id == id)
          matched = device.copyWith(lastSeenAt: DateTime.now())
        else
          device,
    ];
    if (matched == null) {
      return;
    }
    state = state.copyWith(devices: devices);
    _addLog('向${matched.name}发送了测试');
  }

  void addDevice(CareDevice device) {
    state = state.copyWith(
      devices: [...state.devices, device],
      clearProtectionNote: device.criticalForProtection,
    );
    _addLog('添加了${device.name}');
  }

  bool removeDevice(String id) {
    final device = _findDevice(id);
    if (device == null) {
      return false;
    }
    state = state.copyWith(
      devices: state.devices.where((item) => item.id != id).toList(),
      protectionNote: device.criticalForProtection
          ? '已解绑${device.location}的${device.name}，该区域暂时失去对应保护。'
          : state.protectionNote,
    );
    _addLog('解绑了${device.name}');
    return true;
  }

  void saveSelfCheck(SelfCheckReport report) {
    state = state.copyWith(selfCheck: report, lastSyncedAt: report.checkedAt);
  }

  bool addMember({
    required String name,
    required String phoneMasked,
    required String relation,
    required FamilyRole role,
  }) {
    if (state.members.length >= 6 || name.trim().isEmpty) {
      return false;
    }
    final member = FamilyMember(
      id: 'member-${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      role: role,
      phoneMasked: phoneMasked,
      relation: relation.trim().isEmpty ? '家人' : relation.trim(),
    );
    state = state.copyWith(members: [...state.members, member]);
    _addLog('邀请了${member.name}');
    return true;
  }

  bool removeMember(String id) {
    FamilyMember? member;
    for (final item in state.members) {
      if (item.id == id) {
        member = item;
      }
    }
    if (member == null || member.role == FamilyRole.owner) {
      return false;
    }
    state = state.copyWith(
      members: state.members.where((item) => item.id != id).toList(),
    );
    _addLog('移除了${member.name}');
    return true;
  }

  bool moveMember(String id, int delta) {
    final index = state.members.indexWhere((member) => member.id == id);
    if (index < 0 || state.members[index].role == FamilyRole.owner) {
      return false;
    }
    final target = index + delta;
    if (target <= 0 || target >= state.members.length) {
      return false;
    }
    final next = [...state.members];
    final item = next.removeAt(index);
    next.insert(target, item);
    state = state.copyWith(members: next);
    return true;
  }

  void renameMember(String id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return;
    }
    state = state.copyWith(
      members: [
        for (final member in state.members)
          if (member.id == id) member.copyWith(name: trimmed) else member,
      ],
    );
  }

  bool toggleEscalation(String id, {required bool enabled}) {
    EscalationStep? step;
    for (final item in state.escalation) {
      if (item.id == id) {
        step = item;
      }
    }
    if (step == null || step.locked) {
      return false;
    }
    state = state.copyWith(
      escalation: [
        for (final item in state.escalation)
          if (item.id == id) item.copyWith(enabled: enabled) else item,
      ],
    );
    _addLog(enabled ? '开启了${step.channel}升级' : '关闭了${step.channel}升级');
    return true;
  }

  void updatePrivacy({
    bool? shareRoom,
    bool? shareMedication,
    bool? shareDeviceHealth,
  }) {
    state = state.copyWith(
      privacy: state.privacy.copyWith(
        shareRoom: shareRoom,
        shareMedication: shareMedication,
        shareDeviceHealth: shareDeviceHealth,
      ),
    );
    _addLog('更新了数据共享设置');
  }

  CareAlert? _findAlert(String alertId) {
    for (final alert in state.alerts) {
      if (alert.id == alertId) {
        return alert;
      }
    }
    return null;
  }

  CareDevice? _findDevice(String id) {
    for (final device in state.devices) {
      if (device.id == id) {
        return device;
      }
    }
    return null;
  }

  void _replaceAlert(CareAlert updated) {
    state = state.copyWith(
      alerts: [
        for (final alert in state.alerts)
          if (alert.id == updated.id) updated else alert,
      ],
    );
  }

  void _addLog(String action) {
    final actor = state.members
        .where((member) => member.isSelf)
        .map((member) => member.name)
        .firstOrNull;
    final logs = [
      AccessRecord(
        id: 'log-${DateTime.now().microsecondsSinceEpoch}',
        actor: actor ?? '我',
        action: action,
        occurredAt: DateTime.now(),
      ),
      ...state.accessLogs,
    ];
    state = state.copyWith(
      accessLogs: logs.length > 30 ? logs.sublist(0, 30) : logs,
    );
  }
}
