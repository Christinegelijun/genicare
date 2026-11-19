import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venicare_app/src/app.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/domain/voice_parser.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/state/voice_input.dart';

class _FakeVoiceInput implements VoiceInput {
  VoiceResultCallback? _onResult;
  VoiceDoneCallback? _onDone;

  void say(String text) {
    _onResult?.call(text, isFinal: true);
    final done = _onDone;
    _onDone = null;
    done?.call(failed: false);
  }

  @override
  Future<bool> start({
    required VoiceResultCallback onResult,
    required VoiceDoneCallback onDone,
  }) async {
    _onResult = onResult;
    _onDone = onDone;
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async => _onDone = null;
}

void main() {
  test('老人模式记录血压和用药，可以撤销', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(appControllerProvider.notifier);
    final before = container.read(appControllerProvider).healthRecords.length;
    final evening = container
        .read(appControllerProvider)
        .medicationTasks
        .firstWhere((task) => task.id == 'medication-evening');

    final result = controller.saveElderEntries(
      [
        const BloodPressureEntry(systolic: 135, diastolic: 86, heartRate: 70),
        MedicationEntry(task: evening),
      ],
      source: RecordSource.voice,
      transcript: '血压135 86 70，药吃了',
    );
    var state = container.read(appControllerProvider);
    expect(result.recordIds, hasLength(2));
    expect(state.healthRecords, hasLength(before + 2));
    expect(state.healthRecords.first.systolic, 135);
    expect(
      state.medicationTasks
          .firstWhere((task) => task.id == evening.id)
          .completed,
      isTrue,
    );

    final again = controller.saveElderEntries([
      MedicationEntry(task: evening),
    ], source: RecordSource.tap);
    expect(again.isEmpty, isTrue);

    controller.undoElderSave(result);
    state = container.read(appControllerProvider);
    expect(state.healthRecords, hasLength(before));
    expect(
      state.medicationTasks
          .firstWhere((task) => task.id == evening.id)
          .completed,
      isFalse,
    );
    expect(
      state.alerts.any((alert) => alert.id == 'alert-med-done-${evening.id}'),
      isFalse,
    );
  });

  testWidgets('切换到老人模式，用语音记录血压，再切回子女模式', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final voice = _FakeVoiceInput();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceInputProvider.overrideWithValue(voice)],
        child: const VeniCareApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('老人模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切换'));
    await tester.pumpAndSettle();

    expect(find.text('点一下，开始说话'), findsOneWidget);
    expect(find.text('今天的药'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    expect(find.text('正在听…说完了再点一下'), findsOneWidget);

    voice.say('血压一百三十八，八十八');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('血压 138 / 88'), findsOneWidget);

    await tester.tap(find.text('对，记下来'));
    await tester.pumpAndSettle();
    expect(find.text('记好了！家人也能看到'), findsOneWidget);
    expect(find.text('138 / 88'), findsOneWidget);

    await tester.longPress(find.text('家人'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('切回'));
    await tester.pumpAndSettle();
    expect(find.text('妈妈自己记录的'), findsOneWidget);
  });

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
