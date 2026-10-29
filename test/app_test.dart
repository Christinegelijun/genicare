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

  testWidgets('首页可以进入告警详情并认领事件', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VeniCareApp()));
    await tester.pumpAndSettle();

    expect(find.text('紧急事件待处理'), findsOneWidget);
    await tester.tap(find.text('疑似跌倒').first);
    await tester.pumpAndSettle();

    expect(find.text('我来处理'), findsOneWidget);
    await tester.tap(find.text('我来处理'));
    await tester.pumpAndSettle();

    expect(find.text('老人安全，结束事件'), findsOneWidget);
  });
}
