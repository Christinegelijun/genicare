import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venicare_app/src/app.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';

void main() {
  test('告警可以完成认领和处置状态转换', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialAlert = container
        .read(appControllerProvider)
        .alerts
        .firstWhere((alert) => alert.id == 'alert-fall-001');
    expect(initialAlert.status, AlertStatus.pending);

    expect(
      container
          .read(appControllerProvider.notifier)
          .claimAlert(initialAlert.id),
      isTrue,
    );
    expect(
      container
          .read(appControllerProvider)
          .alerts
          .firstWhere((alert) => alert.id == initialAlert.id)
          .status,
      AlertStatus.claimed,
    );

    expect(
      container
          .read(appControllerProvider.notifier)
          .resolveAlert(initialAlert.id),
      isTrue,
    );
    expect(
      container
          .read(appControllerProvider)
          .alerts
          .firstWhere((alert) => alert.id == initialAlert.id)
          .status,
      AlertStatus.resolved,
    );
    expect(
      container.read(appControllerProvider).recipient.protectionLevel,
      ProtectionLevel.normal,
    );
  });

  test('误报、解除认领和用药确认会写入状态', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);

    expect(
      controller.resolveAlert(
        'alert-fall-001',
        resultTitle: '已标记为误报',
        resultDetail: '现场无风险',
      ),
      isTrue,
    );
    expect(
      container.read(appControllerProvider).recipient.protectionLevel,
      ProtectionLevel.normal,
    );

    controller.resetDemo();
    expect(controller.claimAlert('alert-fall-001'), isTrue);
    expect(controller.releaseAlert('alert-fall-001'), isTrue);
    expect(
      container
          .read(appControllerProvider)
          .alerts
          .firstWhere((alert) => alert.id == 'alert-fall-001')
          .status,
      AlertStatus.pending,
    );

    controller.setMedicationCompleted('medication-evening', completed: true);
    expect(
      container
          .read(appControllerProvider)
          .medicationTasks
          .firstWhere((task) => task.id == 'medication-evening')
          .completed,
      isTrue,
    );
  });

  testWidgets('首页可以进入告警详情并认领事件', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeniCareApp()));
    await tester.pumpAndSettle();

    expect(find.text('紧急事件待处理'), findsOneWidget);
    await tester.tap(find.text('疑似跌倒').hitTestable().first);
    await tester.pumpAndSettle();

    expect(find.text('我来处理'), findsOneWidget);
    await tester.tap(find.text('我来处理'));
    await tester.pumpAndSettle();

    expect(find.text('老人安全，结束事件'), findsOneWidget);
  });

  testWidgets('设备页和我的页可以打开主要入口', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeniCareApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('设备'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('一键自检'), findsOneWidget);
    expect(find.text('家庭中枢'), findsOneWidget);

    await tester.tap(find.text('我的'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('家庭成员'), findsOneWidget);
    expect(find.text('告警策略'), findsOneWidget);
  });
}
