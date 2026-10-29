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

  bool claimAlert(String alertId) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status != AlertStatus.pending) {
      return false;
    }

    final updated = alert.copyWith(
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
    );
    _replaceAlert(updated);
    return true;
  }

  bool resolveAlert(String alertId) {
    final alert = _findAlert(alertId);
    if (alert == null || alert.status != AlertStatus.claimed) {
      return false;
    }

    final updated = alert.copyWith(
      status: AlertStatus.resolved,
      timeline: [
        ...alert.timeline,
        AlertTimelineEntry(
          title: '事件已结束',
          detail: '家属确认老人安全，本次事件已完成处置。',
          occurredAt: DateTime.now(),
        ),
      ],
    );
    _replaceAlert(updated);

    if (state.activeAlerts.isEmpty) {
      state = state.copyWith(
        recipient: CareRecipient(
          id: state.recipient.id,
          name: state.recipient.name,
          relationship: state.recipient.relationship,
          protectionLevel: ProtectionLevel.normal,
          statusText: '当前无待处理事件',
          lastUpdatedAt: DateTime.now(),
        ),
      );
    }
    return true;
  }

  CareAlert? _findAlert(String alertId) {
    for (final alert in state.alerts) {
      if (alert.id == alertId) {
        return alert;
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
}
