import 'package:flutter/material.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/theme/care_theme.dart';

const kAppVersion = '0.1.0';

String greetingFor(DateTime value) {
  final hour = value.hour;
  if (hour < 5) {
    return '夜深了';
  }
  if (hour < 11) {
    return '早上好';
  }
  if (hour < 14) {
    return '中午好';
  }
  if (hour < 18) {
    return '下午好';
  }
  return '晚上好';
}

String relativeTime(DateTime value) {
  final now = DateTime.now();
  if (value.isAfter(now)) {
    final ahead = value.difference(now);
    if (ahead.inMinutes < 1) {
      return '即将';
    }
    if (ahead.inHours < 1) {
      return '${ahead.inMinutes} 分钟后';
    }
    if (ahead.inDays < 1) {
      return '${ahead.inHours} 小时后';
    }
    return '${ahead.inDays} 天后';
  }

  final difference = now.difference(value);
  if (difference.inMinutes < 1) {
    return '刚刚';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} 分钟前';
  }
  if (difference.inDays < 1) {
    return '${difference.inHours} 小时前';
  }
  return '${difference.inDays} 天前';
}

String clockTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String friendlyDateTime(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final time = clockTime(value);
  final delta = today.difference(day).inDays;
  if (delta == 0) {
    return '今天 $time';
  }
  if (delta == 1) {
    return '昨天 $time';
  }
  if (delta == -1) {
    return '明天 $time';
  }
  return '${value.month}月${value.day}日 $time';
}

String weekdayLabel(DateTime value) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  return '${value.month}月${value.day}日 星期${labels[value.weekday - 1]}';
}

String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 7) {
    return digits;
  }
  return '${digits.substring(0, 3)}****${digits.substring(digits.length - 4)}';
}

bool isMainlandMobile(String phone) {
  return RegExp(r'^1\d{10}$').hasMatch(phone);
}

MedicationPhase medicationPhase(MedicationTask task, [DateTime? now]) {
  if (task.completed) {
    return MedicationPhase.done;
  }
  final clock = now ?? DateTime.now();
  if (task.scheduledAt.isAfter(clock)) {
    return MedicationPhase.upcoming;
  }
  return MedicationPhase.due;
}

String medicationStatusText(MedicationTask task) {
  return switch (medicationPhase(task)) {
    MedicationPhase.done => '已确认',
    MedicationPhase.upcoming => '未到时间',
    MedicationPhase.due => '待确认',
  };
}

String alertStatusText(AlertStatus status) {
  return switch (status) {
    AlertStatus.pending => '待处理',
    AlertStatus.claimed => '处理中',
    AlertStatus.resolved => '已结束',
  };
}

String severityLabel(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical => '紧急',
    AlertSeverity.warning => '提醒',
    AlertSeverity.info => '记录',
  };
}

String deviceStatusLabel(DeviceStatus status) {
  return switch (status) {
    DeviceStatus.online => '在线',
    DeviceStatus.warning => '注意',
    DeviceStatus.offline => '离线',
  };
}

String familyRoleLabel(FamilyRole role) {
  return switch (role) {
    FamilyRole.owner => '所有者',
    FamilyRole.admin => '管理员',
    FamilyRole.contact => '联系人',
    FamilyRole.viewer => '只读成员',
  };
}

String protectionLabel(ProtectionLevel level) {
  return switch (level) {
    ProtectionLevel.normal => '守护正常',
    ProtectionLevel.attention => '需要留意',
    ProtectionLevel.incomplete => '保护不完整',
    ProtectionLevel.urgent => '紧急',
    ProtectionLevel.unknown => '状态未知',
  };
}

String deviceBlurb(String icon) {
  return switch (icon) {
    'hub' => '负责本地询问、设备汇聚和告警上报。',
    'radar' => '辅助发现姿态异常。App 不读取雷达点云。',
    'medication' => '记录药仓开合与确认，不判断药物是否正确。',
    'button' => '按下后向家属发送求助，适合卫生间等位置。',
    _ => '家庭照护设备。',
  };
}

String protectionImpact(CareDevice device) {
  if (device.criticalForProtection && device.status == DeviceStatus.offline) {
    return '${device.location}的自动监测已中断。';
  }
  if (device.criticalForProtection && device.status == DeviceStatus.warning) {
    return '设备异常期间，${device.location}的保护可能不完整。';
  }
  if (device.criticalForProtection) {
    return '正在覆盖${device.location}的姿态与跌倒辅助监测。';
  }
  if (device.status == DeviceStatus.warning) {
    return '不影响跌倒监测，相关照护提醒可能延迟。';
  }
  return '不承担自动跌倒监测。';
}

String escalationSummary(List<EscalationStep> steps) {
  final names = steps.where((step) => step.enabled).map((step) => step.channel);
  if (names.isEmpty) {
    return '未开启升级';
  }
  return names.join(' → ');
}

IconData deviceIcon(String name) {
  return switch (name) {
    'hub' => Icons.hub_outlined,
    'radar' => Icons.radar_outlined,
    'medication' => Icons.medication_outlined,
    'button' => Icons.sos_outlined,
    _ => Icons.sensors_outlined,
  };
}

Color severityColor(CareColors colors, AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical => colors.urgent,
    AlertSeverity.warning => colors.warning,
    AlertSeverity.info => colors.info,
  };
}

Color deviceTone(CareColors colors, DeviceStatus status) {
  return switch (status) {
    DeviceStatus.online => colors.primary,
    DeviceStatus.warning => colors.warning,
    DeviceStatus.offline => colors.urgent,
  };
}

Color medicationTone(CareColors colors, MedicationPhase phase) {
  return switch (phase) {
    MedicationPhase.done => colors.primary,
    MedicationPhase.due => colors.warning,
    MedicationPhase.upcoming => colors.muted,
  };
}

IconData alertIcon(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical => Icons.crisis_alert_rounded,
    AlertSeverity.warning => Icons.warning_amber_rounded,
    AlertSeverity.info => Icons.check_circle_outline_rounded,
  };
}
