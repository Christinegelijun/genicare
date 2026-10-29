import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class DeviceDetailPage extends ConsumerWidget {
  const DeviceDetailPage({required this.deviceId, super.key});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = _find(ref.watch(appControllerProvider).devices);
    if (device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('设备详情')),
        body: const MissingBody(message: '设备不存在或已解绑'),
      );
    }
    final colors = context.care;
    final color = deviceTone(colors, device.status);
    return Scaffold(
      appBar: AppBar(title: Text(device.name)),
      body: ListView(
        padding: kPagePadding,
        children: [
          CareCard(
            child: Row(
              children: [
                IconBadge(icon: deviceIcon(device.icon), color: color, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${device.location} · ${deviceStatusLabel(device.status)}',
                        style: TextStyle(color: color, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(deviceBlurb(device.icon), style: TextStyle(color: colors.muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (device.fault != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.warning_amber_rounded,
              title: '当前异常',
              message: device.fault!,
              color: colors.warning,
            ),
          ],
          const SizedBox(height: 12),
          InfoBanner(
            icon: Icons.shield_outlined,
            title: device.criticalForProtection ? '影响保护范围' : '不影响跌倒监测',
            message: protectionImpact(device),
            color: device.criticalForProtection ? colors.primary : colors.info,
          ),
          const SizedBox(height: 12),
          CareCard(
            child: Column(
              children: [
                SpecRow(label: '状态说明', value: device.statusText),
                SpecRow(
                  label: '最近通信',
                  value: '${friendlyDateTime(device.lastSeenAt)} · ${relativeTime(device.lastSeenAt)}',
                ),
                SpecRow(label: '供电', value: device.powerLabel),
                SpecRow(label: '固件', value: device.firmware),
                if (device.batteryPercent != null)
                  SpecRow(label: '电量', value: '${device.batteryPercent}%'),
              ],
            ),
          ),
          if (device.batteryPercent != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: device.batteryPercent! / 100,
                minHeight: 8,
                color: device.batteryPercent! < 20 ? colors.warning : colors.primary,
                backgroundColor: colors.line,
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              ref.read(appControllerProvider.notifier).touchDevice(device.id);
              showCareToast(context, '已记录测试请求，演示不会触发真实告警');
            },
            icon: const Icon(Icons.wifi_tethering_rounded),
            label: const Text('发送测试'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _reconfigure(context),
            icon: const Icon(Icons.settings_input_antenna),
            label: const Text('重新配网'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => _unbind(context, ref, device),
            child: Text('解绑设备', style: TextStyle(color: colors.urgent)),
          ),
        ],
      ),
    );
  }

  CareDevice? _find(List<CareDevice> devices) {
    for (final device in devices) {
      if (device.id == deviceId) {
        return device;
      }
    }
    return null;
  }

  Future<void> _reconfigure(BuildContext context) async {
    await showCareConfirm(
      context,
      title: '重新配网',
      message: '正式版本会通过蓝牙把家庭网络交给设备。当前演示不会搜索设备，绑定关系保持不变。',
      confirmLabel: '我知道了',
      cancelLabel: '关闭',
    );
  }

  Future<void> _unbind(BuildContext context, WidgetRef ref, CareDevice device) async {
    final confirmed = await showCareConfirm(
      context,
      title: '解绑${device.name}？',
      message: device.criticalForProtection
          ? '解绑后，${device.location}会暂时失去这项保护。可以在“关于”里恢复演示数据。'
          : '解绑后，首页和设备页不再显示它。可以在“关于”里恢复演示数据。',
      confirmLabel: '确认解绑',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).removeDevice(device.id);
    if (!context.mounted) {
      return;
    }
    showCareToast(context, '已解绑${device.name}');
    context.pop();
  }
}
