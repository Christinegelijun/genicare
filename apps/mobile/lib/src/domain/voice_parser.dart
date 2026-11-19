import 'package:venicare_app/src/domain/models.dart';

enum MedicationPeriod { morning, noon, evening }

sealed class VoiceEntry {
  const VoiceEntry();
}

class BloodPressureEntry extends VoiceEntry {
  const BloodPressureEntry({
    required this.systolic,
    required this.diastolic,
    this.heartRate,
  });

  final int systolic;
  final int diastolic;
  final int? heartRate;
}

class HeartRateEntry extends VoiceEntry {
  const HeartRateEntry(this.bpm);

  final int bpm;
}

class BloodSugarEntry extends VoiceEntry {
  const BloodSugarEntry(this.value);

  final double value;
}

class MedicationEntry extends VoiceEntry {
  const MedicationEntry({this.period, this.task});

  final MedicationPeriod? period;
  final MedicationTask? task;
}

class VoiceParseResult {
  const VoiceParseResult({
    required this.text,
    required this.entries,
    this.problem,
  });

  final String text;
  final List<VoiceEntry> entries;
  final String? problem;
}

const kVoiceExamples = '血压 130 85\n晚上的药吃了\n血糖 6.5';

const _digitValues = {
  '零': 0,
  '〇': 0,
  '一': 1,
  '幺': 1,
  '二': 2,
  '两': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '七': 7,
  '八': 8,
  '九': 9,
};

final _chineseNumber = RegExp(r'[零〇一幺二两三四五六七八九十百]+(?:点[零〇一幺二两三四五六七八九]+)?');
final _number = RegExp(r'\d+(?:\.\d+)?');

String normalizeSpeech(String raw) {
  var text = raw.trim();
  const fullWidth = '０１２３４５６７８９';
  for (var i = 0; i < fullWidth.length; i++) {
    text = text.replaceAll(fullWidth[i], '$i');
  }
  text = text.replaceAll('／', '/').replaceAll('．', '.');
  text = text.replaceAllMapped(_chineseNumber, (match) {
    final parts = match[0]!.split('点');
    final integers = _chineseIntegers(parts.first);
    if (integers.isEmpty) {
      return match[0]!;
    }
    final head = integers.take(integers.length - 1).map((n) => '$n ').join();
    final fraction = parts.length > 1
        ? '.${parts[1].split('').map((c) => _digitValues[c]).join()}'
        : '';
    return ' $head${integers.last}$fraction ';
  });
  return text.replaceAllMapped(
    RegExp(r'(\d+)\s*点\s*(\d+)'),
    (match) => '${match[1]}.${match[2]}',
  );
}

/// "一百三八十五" is how people read a blood-pressure pair aloud, so one run
/// of Chinese numerals can hold several numbers.
List<int> _chineseIntegers(String run) {
  if (!run.contains('十') && !run.contains('百')) {
    final digits = run.split('').map((c) => _digitValues[c]).join();
    final value = int.tryParse(digits);
    return value == null ? const [] : [value];
  }

  final out = <int>[];
  var total = 0;
  var current = 0;
  var lastUnit = 1000;
  var zero = false;
  var started = false;

  void flush() {
    if (!started) {
      return;
    }
    var value = total;
    if (current > 0) {
      value += lastUnit == 100 && !zero ? current * 10 : current;
    }
    out.add(value);
    total = 0;
    current = 0;
    lastUnit = 1000;
    zero = false;
    started = false;
  }

  for (final char in run.split('')) {
    final unit = switch (char) {
      '百' => 100,
      '十' => 10,
      _ => null,
    };
    if (unit != null) {
      if (unit >= lastUnit) {
        final carry = current;
        current = 0;
        flush();
        current = carry;
      }
      total += (current == 0 ? 1 : current) * unit;
      current = 0;
      lastUnit = unit;
      zero = false;
      started = true;
      continue;
    }
    final digit = _digitValues[char]!;
    if (digit == 0) {
      zero = true;
      started = true;
      continue;
    }
    if (current != 0) {
      flush();
    }
    current = digit;
    started = true;
  }
  flush();
  return out;
}

class _Numbers {
  _Numbers(this.text) : matches = _number.allMatches(text).toList();

  final String text;
  final List<RegExpMatch> matches;
  final Set<int> used = {};

  num? takeAfter(RegExp keyword, {int maxGap = 6}) {
    for (final hit in keyword.allMatches(text)) {
      for (var i = 0; i < matches.length; i++) {
        final match = matches[i];
        if (used.contains(i) || match.start < hit.end) {
          continue;
        }
        if (match.start - hit.end > maxGap) {
          break;
        }
        used.add(i);
        return num.parse(match[0]!);
      }
    }
    return null;
  }

  List<int> unusedIntegersFrom(int offset) {
    return [
      for (var i = 0; i < matches.length; i++)
        if (!used.contains(i) &&
            matches[i].start >= offset &&
            !matches[i][0]!.contains('.'))
          i,
    ];
  }

  int take(int index) {
    used.add(index);
    return int.parse(matches[index][0]!);
  }
}

final _systolicWord = RegExp('高压|收缩压|上压');
final _diastolicWord = RegExp('低压|舒张压|下压');
final _pressureWord = RegExp(r'(?:(?<!高)血压|高压|低压|收缩压|舒张压)(?!的?药)');
final _pulseWord = RegExp('心率|心跳|脉搏|脉');
final _sugarWord = RegExp('血糖');
final _tookMedicine = RegExp(
  r'(吃|服|喝|用)[了过完好]?[^，。,.!！?？]{0,4}药|药[^，。,.!！?？]{0,4}(吃|服|喝|用)[了过完好]',
);
final _missedMedicine = RegExp(r'(没|未|忘了|忘记)[^，。,.]{0,3}(吃|服|喝)');

VoiceParseResult parseHealthSpeech(String raw) {
  final text = normalizeSpeech(raw);
  final numbers = _Numbers(text);
  final entries = <VoiceEntry>[];
  String? problem;

  var systolic = numbers.takeAfter(_systolicWord)?.round();
  var diastolic = numbers.takeAfter(_diastolicWord)?.round();
  var pulse = numbers.takeAfter(_pulseWord)?.round();
  final sugar = numbers.takeAfter(_sugarWord);

  final slash = RegExp(r'(\d{2,3})\s*[/比]\s*(\d{2,3})').firstMatch(text);
  final pressureHit = _pressureWord.firstMatch(text);
  final hasOtherKeyword =
      _pulseWord.hasMatch(text) || _sugarWord.hasMatch(text);

  var pool = <int>[];
  if (pressureHit != null || slash != null) {
    pool = numbers.unusedIntegersFrom(pressureHit?.start ?? 0);
  } else if (!hasOtherKeyword) {
    final candidates = numbers.unusedIntegersFrom(0);
    if (candidates.length == 2 || candidates.length == 3) {
      final first = int.parse(numbers.matches[candidates[0]][0]!);
      final second = int.parse(numbers.matches[candidates[1]][0]!);
      if (_isSystolic(first) && _isDiastolic(second)) {
        pool = candidates;
      }
    }
  }
  if (pool.isNotEmpty && systolic == null) {
    systolic = numbers.take(pool.removeAt(0));
  }
  if (pool.isNotEmpty && diastolic == null) {
    diastolic = numbers.take(pool.removeAt(0));
  }
  if (pool.isNotEmpty && pulse == null) {
    final candidate = int.parse(numbers.matches[pool.first][0]!);
    if (_isPulse(candidate)) {
      pulse = numbers.take(pool.removeAt(0));
    }
  }

  final mentionedPressure = pressureHit != null || slash != null;
  if (systolic != null && diastolic != null) {
    if (systolic < diastolic) {
      (systolic, diastolic) = (diastolic, systolic);
    }
    if (_isSystolic(systolic) &&
        _isDiastolic(diastolic) &&
        systolic - diastolic >= 10) {
      entries.add(
        BloodPressureEntry(
          systolic: systolic,
          diastolic: diastolic,
          heartRate: pulse != null && _isPulse(pulse) ? pulse : null,
        ),
      );
      pulse = null;
    } else {
      problem = '血压的数字好像不对，请再说一次，比如：血压 130 85';
    }
  } else if (mentionedPressure || systolic != null || diastolic != null) {
    problem = '血压要说两个数，比如：高压 130，低压 85';
  }

  if (pulse != null) {
    if (_isPulse(pulse)) {
      entries.add(HeartRateEntry(pulse));
    } else {
      problem ??= '心跳的数字好像不对，请再说一次';
    }
  } else if (_pulseWord.hasMatch(text) &&
      entries.whereType<BloodPressureEntry>().isEmpty) {
    problem ??= '心跳要说一个数，比如：心跳 72';
  }

  if (sugar != null && sugar >= 1 && sugar <= 35) {
    entries.add(BloodSugarEntry(sugar.toDouble()));
  } else if (_sugarWord.hasMatch(text)) {
    problem ??= '血糖要说一个数，比如：血糖 6.5';
  }

  final took = _tookMedicine.firstMatch(text);
  if (took != null) {
    if (_missedMedicine.hasMatch(text)) {
      problem ??= '好的，先不记。吃完药再告诉我';
    } else {
      final window = text.substring(
        (took.start - 8).clamp(0, text.length),
        (took.end + 2).clamp(0, text.length),
      );
      entries.add(MedicationEntry(period: _periodIn(window)));
    }
  }

  if (entries.isEmpty) {
    problem ??= '没听明白。可以这样说：\n$kVoiceExamples';
  }
  return VoiceParseResult(text: raw.trim(), entries: entries, problem: problem);
}

bool _isSystolic(int value) => value >= 60 && value <= 260;

bool _isDiastolic(int value) => value >= 30 && value <= 160;

bool _isPulse(int value) => value >= 30 && value <= 220;

MedicationPeriod? _periodIn(String text) {
  if (RegExp('早|上午').hasMatch(text)) {
    return MedicationPeriod.morning;
  }
  if (RegExp('中午|午饭|下午').hasMatch(text)) {
    return MedicationPeriod.noon;
  }
  if (RegExp('晚|夜|睡前').hasMatch(text)) {
    return MedicationPeriod.evening;
  }
  return null;
}

MedicationPeriod medicationPeriodOf(DateTime value) {
  if (value.hour < 11) {
    return MedicationPeriod.morning;
  }
  if (value.hour < 17) {
    return MedicationPeriod.noon;
  }
  return MedicationPeriod.evening;
}

String medicationPeriodLabel(MedicationPeriod period) {
  return switch (period) {
    MedicationPeriod.morning => '早上',
    MedicationPeriod.noon => '中午',
    MedicationPeriod.evening => '晚上',
  };
}

/// Without a spoken period, the most recent overdue task wins, then the next
/// upcoming one.
MedicationTask? matchMedicationTask(
  List<MedicationTask> tasks,
  MedicationPeriod? period,
  DateTime now,
) {
  final pending = tasks.where((task) => !task.completed).toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (period != null) {
    return pending
        .where((task) => medicationPeriodOf(task.scheduledAt) == period)
        .firstOrNull;
  }
  final due = pending.where((task) => !task.scheduledAt.isAfter(now));
  return due.isNotEmpty ? due.last : pending.firstOrNull;
}

/// Attaches the matching task to each medication entry. Entries that match
/// nothing are dropped and explained in the returned message.
(List<VoiceEntry>, String?) resolveMedication(
  List<VoiceEntry> entries,
  List<MedicationTask> tasks,
  DateTime now,
) {
  String? message;
  final resolved = <VoiceEntry>[];
  for (final entry in entries) {
    if (entry is! MedicationEntry) {
      resolved.add(entry);
      continue;
    }
    final task = matchMedicationTask(tasks, entry.period, now);
    if (task != null) {
      resolved.add(MedicationEntry(period: entry.period, task: task));
      continue;
    }
    final period = entry.period;
    if (period == null) {
      message = '今天的药都已经记过了';
    } else {
      final exists = tasks.any(
        (t) => medicationPeriodOf(t.scheduledAt) == period,
      );
      final label = medicationPeriodLabel(period);
      message = exists ? '$label的药今天已经记过了' : '今天没有$label的药';
    }
  }
  return (resolved, message);
}
