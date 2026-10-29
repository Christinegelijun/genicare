import 'package:flutter/material.dart';
import 'package:venicare_app/src/domain/models.dart';

String relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value);
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

Color alertColor(AlertSeverity severity) {
  return switch (severity) {
    AlertSeverity.critical => const Color(0xFFD43D3D),
    AlertSeverity.warning => const Color(0xFFD9822B),
    AlertSeverity.info => const Color(0xFF2878B5),
  };
}

Color deviceColor(DeviceStatus status) {
  return switch (status) {
    DeviceStatus.online => const Color(0xFF218765),
    DeviceStatus.warning => const Color(0xFFD9822B),
    DeviceStatus.offline => const Color(0xFF9B3B3B),
  };
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

String alertStatusText(AlertStatus status) {
  return switch (status) {
    AlertStatus.pending => '待处理',
    AlertStatus.claimed => '处理中',
    AlertStatus.resolved => '已结束',
  };
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        ?action,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
