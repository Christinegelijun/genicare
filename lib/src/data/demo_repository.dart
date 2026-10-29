import 'package:venicare_app/src/domain/models.dart';

class DemoRepository {
  AppState loadInitialState() {
    final now = DateTime.now();

    return AppState(
      recipient: CareRecipient(
        id: 'recipient-mother',
        name: '妈妈',
        relationship: '我的母亲',
        protectionLevel: ProtectionLevel.urgent,
        statusText: '存在 1 个待处理紧急事件',
        lastUpdatedAt: now.subtract(const Duration(minutes: 1)),
      ),
      alerts: [
        CareAlert(
          id: 'alert-fall-001',
          title: '疑似跌倒',
          description: '客厅雷达检测到快速下降并持续倒地，语音询问后暂未收到回应。',
          location: '客厅',
          occurredAt: now.subtract(const Duration(minutes: 4)),
          severity: AlertSeverity.critical,
          status: AlertStatus.pending,
          timeline: [
            AlertTimelineEntry(
              title: '检测到异常姿态',
              detail: '身体高度快速下降，倒地状态持续 18 秒。',
              occurredAt: now.subtract(const Duration(minutes: 4)),
            ),
            AlertTimelineEntry(
              title: '本地语音询问',
              detail: '家庭中枢已询问“您还好吗？”，暂未收到回应。',
              occurredAt: now.subtract(const Duration(minutes: 3, seconds: 50)),
            ),
            AlertTimelineEntry(
              title: '已通知家属',
              detail: '已向第一联系人发送 App 紧急通知。',
              occurredAt: now.subtract(const Duration(minutes: 3, seconds: 35)),
            ),
          ],
        ),
        CareAlert(
          id: 'alert-medication-001',
          title: '晚间用药已确认',
          description: '药盒已打开，用户通过按键完成操作确认。',
          location: '卧室',
          occurredAt: now.subtract(const Duration(hours: 14)),
          severity: AlertSeverity.info,
          status: AlertStatus.resolved,
          claimedBy: '系统',
          timeline: [
            AlertTimelineEntry(
              title: '用药提醒',
              detail: '家庭中枢播放晚间用药提醒。',
              occurredAt: now.subtract(const Duration(hours: 14, minutes: 2)),
            ),
            AlertTimelineEntry(
              title: '操作已确认',
              detail: '药盒打开并通过实体按键确认。',
              occurredAt: now.subtract(const Duration(hours: 14)),
            ),
          ],
        ),
        CareAlert(
          id: 'alert-device-001',
          title: '药盒电量偏低',
          description: '预计剩余电量可使用约 3 天，请安排充电。',
          location: '卧室',
          occurredAt: now.subtract(const Duration(days: 1, hours: 2)),
          severity: AlertSeverity.warning,
          status: AlertStatus.resolved,
          claimedBy: '李俊',
          timeline: [
            AlertTimelineEntry(
              title: '检测到低电量',
              detail: '药盒剩余电量 18%。',
              occurredAt: now.subtract(const Duration(days: 1, hours: 2)),
            ),
            AlertTimelineEntry(
              title: '家属已处理',
              detail: '李俊已安排上门充电。',
              occurredAt: now.subtract(const Duration(days: 1)),
            ),
          ],
        ),
      ],
      devices: [
        CareDevice(
          id: 'hub-001',
          name: '家庭中枢',
          location: '客厅',
          icon: 'hub',
          status: DeviceStatus.online,
          statusText: '运行正常',
          lastSeenAt: now.subtract(const Duration(seconds: 18)),
        ),
        CareDevice(
          id: 'radar-001',
          name: '毫米波雷达',
          location: '客厅',
          icon: 'radar',
          status: DeviceStatus.online,
          statusText: '监测中',
          lastSeenAt: now.subtract(const Duration(seconds: 22)),
        ),
        CareDevice(
          id: 'pillbox-001',
          name: '智能药盒',
          location: '卧室',
          icon: 'medication',
          status: DeviceStatus.warning,
          statusText: '电量偏低',
          lastSeenAt: now.subtract(const Duration(minutes: 2)),
          batteryPercent: 18,
        ),
        CareDevice(
          id: 'button-001',
          name: '紧急求助按钮',
          location: '卫生间',
          icon: 'button',
          status: DeviceStatus.online,
          statusText: '运行正常',
          lastSeenAt: now.subtract(const Duration(minutes: 1)),
          batteryPercent: 86,
        ),
      ],
      medicationTasks: [
        MedicationTask(
          id: 'medication-morning',
          name: '早间用药',
          dosage: '1 号药仓 · 1 次',
          scheduledAt: DateTime(now.year, now.month, now.day, 8),
          completed: true,
        ),
        MedicationTask(
          id: 'medication-evening',
          name: '晚间用药',
          dosage: '2 号药仓 · 1 次',
          scheduledAt: DateTime(now.year, now.month, now.day, 20),
          completed: false,
        ),
      ],
    );
  }
}
