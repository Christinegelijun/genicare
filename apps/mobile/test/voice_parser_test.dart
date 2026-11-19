import 'package:flutter_test/flutter_test.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/domain/voice_parser.dart';

BloodPressureEntry? _pressure(String text) {
  return parseHealthSpeech(
    text,
  ).entries.whereType<BloodPressureEntry>().firstOrNull;
}

void main() {
  group('中文数字', () {
    test('读法转换', () {
      expect(normalizeSpeech('一百三十五').trim(), '135');
      expect(normalizeSpeech('一百三').trim(), '130');
      expect(normalizeSpeech('一百零五').trim(), '105');
      expect(normalizeSpeech('八十五').trim(), '85');
      expect(normalizeSpeech('十五').trim(), '15');
      expect(normalizeSpeech('两百').trim(), '200');
      expect(normalizeSpeech('一三零').trim(), '130');
      expect(normalizeSpeech('六点五').trim(), '6.5');
      expect(normalizeSpeech('６点２').trim(), '6.2');
    });

    test('连着读的两个数会拆开', () {
      expect(normalizeSpeech('一百三八十五').trim(), '130 85');
      expect(normalizeSpeech('一百三十八十五').trim(), '130 85');
    });
  });

  group('血压', () {
    test('各种说法', () {
      for (final text in [
        '血压130 85',
        '血压 130/85',
        '高压130低压85',
        '高压一百三十，低压八十五',
        '血压一百三八十五',
        '130比85',
        '一百三 八十五',
        '低压85高压130',
      ]) {
        final entry = _pressure(text);
        expect(entry, isNotNull, reason: text);
        expect((entry!.systolic, entry.diastolic), (130, 85), reason: text);
      }
    });

    test('第三个数当作心跳', () {
      final entry = _pressure('血压128 82 72')!;
      expect(entry.heartRate, 72);
      expect(_pressure('高压128，低压82，心跳七十二')!.heartRate, 72);
    });

    test('只说一个数会提示', () {
      final result = parseHealthSpeech('血压130');
      expect(result.entries, isEmpty);
      expect(result.problem, contains('两个数'));
    });

    test('不合理的数字不记录', () {
      final result = parseHealthSpeech('血压 30 20');
      expect(result.entries, isEmpty);
      expect(result.problem, contains('不对'));
    });

    test('早上八点这种时间不会当成血压', () {
      final entry = _pressure('早上八点量的血压一百二十，八十')!;
      expect((entry.systolic, entry.diastolic), (120, 80));
    });
  });

  group('其他指标', () {
    test('心跳和血糖', () {
      expect(parseHealthSpeech('心跳72').entries.single, isA<HeartRateEntry>());
      final sugar =
          parseHealthSpeech('血糖六点五').entries.single as BloodSugarEntry;
      expect(sugar.value, 6.5);
    });

    test('一句话里说多项', () {
      final entries = parseHealthSpeech('血压130 85，血糖6.1，晚上的药吃了').entries;
      expect(entries.whereType<BloodPressureEntry>(), hasLength(1));
      expect(entries.whereType<BloodSugarEntry>().single.value, 6.1);
      expect(
        entries.whereType<MedicationEntry>().single.period,
        MedicationPeriod.evening,
      );
    });
  });

  group('用药', () {
    test('吃药的说法和时段', () {
      MedicationEntry? med(String text) => parseHealthSpeech(
        text,
      ).entries.whereType<MedicationEntry>().firstOrNull;

      expect(med('我吃过药了'), isNotNull);
      expect(med('吃药了')!.period, isNull);
      expect(med('早上的药吃了')!.period, MedicationPeriod.morning);
      expect(med('晚上的药已经吃了')!.period, MedicationPeriod.evening);
      expect(med('吃了降压药'), isNotNull);
      expect(parseHealthSpeech('高血压的药吃了').problem, isNull);
    });

    test('没吃不会记录', () {
      final result = parseHealthSpeech('我还没吃药');
      expect(result.entries, isEmpty);
      expect(result.problem, contains('先不记'));
    });

    test('匹配今天的药', () {
      final today = DateTime(2026, 11, 15);
      MedicationTask task(String id, int hour, {bool completed = false}) =>
          MedicationTask(
            id: id,
            name: id,
            dosage: '1 次',
            compartment: '1 号药仓',
            scheduleText: '',
            periodLabel: '',
            remindRule: '',
            scheduledAt: today.add(Duration(hours: hour)),
            completed: completed,
            notifyFamilyIfMissed: true,
            createdBy: '李俊',
            updatedAt: today,
          );
      final tasks = [task('morning', 8, completed: true), task('evening', 20)];

      final noon = today.add(const Duration(hours: 12));
      expect(matchMedicationTask(tasks, null, noon)?.id, 'evening');
      expect(
        matchMedicationTask(tasks, MedicationPeriod.morning, noon),
        isNull,
      );

      final (entries, message) = resolveMedication(
        const [MedicationEntry(period: MedicationPeriod.morning)],
        tasks,
        noon,
      );
      expect(entries, isEmpty);
      expect(message, '早上的药今天已经记过了');
    });
  });

  test('听不懂时给出示例', () {
    final result = parseHealthSpeech('今天天气不错');
    expect(result.entries, isEmpty);
    expect(result.problem, contains('血压 130 85'));
  });
}
