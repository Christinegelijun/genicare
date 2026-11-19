import 'package:intl/intl.dart';
import 'package:venicare_shared/venicare_shared.dart';

final _dateTime = DateFormat('MM-dd HH:mm');
final _date = DateFormat('yyyy-MM-dd');

String formatDateTime(DateTime value) => _dateTime.format(value.toLocal());

String formatDate(DateTime value) => _date.format(value.toLocal());

/// Period end is exclusive, so the last covered day is the day before it.
String formatPeriod(DateTime start, DateTime end) {
  final lastDay = end.subtract(const Duration(milliseconds: 1));
  return '${formatDate(start)} 至 ${formatDate(lastDay)}';
}

String deliveryStatusText(DeliveryStatus status) {
  return switch (status) {
    DeliveryStatus.sent => '未读',
    DeliveryStatus.read => '已读',
    DeliveryStatus.replied => '已回复',
    DeliveryStatus.revoked => '已撤回',
  };
}

String readingKindText(ReadingKind kind) {
  return switch (kind) {
    ReadingKind.bloodPressure => '血压',
    ReadingKind.heartRate => '心率',
    ReadingKind.bloodSugar => '血糖',
  };
}

String readingValueText(VitalReading reading) {
  final parts = <String>[
    if (reading.systolic != null && reading.diastolic != null)
      '${reading.systolic}/${reading.diastolic} mmHg',
    if (reading.heartRate case final hr?) '心率 $hr 次/分',
    if (reading.bloodSugar case final sugar?)
      '${sugar.toStringAsFixed(1)} mmol/L',
  ];
  return parts.join(' · ');
}

String readingSourceText(ReadingSource source) {
  return switch (source) {
    ReadingSource.voice => '语音',
    ReadingSource.typed => '手动输入',
    ReadingSource.tap => '点按',
    ReadingSource.device => '设备上传',
  };
}

String doseEvidenceText(DoseEvidence? evidence) {
  return switch (evidence) {
    DoseEvidence.selfReported => '本人确认',
    DoseEvidence.familyReported => '家属代确认',
    DoseEvidence.pillboxOpened => '药仓已打开（不代表已服药）',
    null => '—',
  };
}

String severityText(EventSeverity severity) {
  return switch (severity) {
    EventSeverity.info => '提示',
    EventSeverity.warning => '注意',
    EventSeverity.critical => '紧急',
  };
}

String doctorStatusText(DoctorStatus status) {
  return switch (status) {
    DoctorStatus.idle => '空闲',
    DoctorStatus.consulting => '接诊中',
    DoctorStatus.offShift => '不在班',
    DoctorStatus.away => '暂离',
    DoctorStatus.offline => '离线',
  };
}

String presenceText(DoctorPresence presence) {
  return switch (presence) {
    DoctorPresence.online => '在线接诊',
    DoctorPresence.away => '暂时离开',
    DoctorPresence.offline => '下线',
  };
}

String consultModeText(ConsultMode mode) {
  return switch (mode) {
    ConsultMode.text => '图文',
    ConsultMode.phone => '电话',
    ConsultMode.video => '视频',
  };
}

final _clock = DateFormat('HH:mm');

String formatClock(DateTime value) => _clock.format(value.toLocal());

String formatSpan(DateTime start, DateTime end) =>
    '${formatClock(start)}–${formatClock(end)}';

String weekdayText(DateTime value) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return '周${labels[value.toLocal().weekday - 1]}';
}

String ageText(int? birthYear, DateTime now) {
  return birthYear == null ? '年龄未填' : '${now.year - birthYear} 岁';
}

String trimNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}
