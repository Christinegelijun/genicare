import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class DevicesPage extends ConsumerWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final attention = state.devices.where((device) => device.status != DeviceStatus.online).length;
    final report = state.selfCheck;

    return RefreshIndicator(
      onRefresh: () async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        ref.read(appControllerProvider.notifier).markSynced();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: kPagePadding,
        children: [
          const TabHeading(title: '设备', subtitle: '中枢、雷达、药盒和求助按钮'),
          const SizedBox(height: 16),
          InfoBanner(
            icon: attention == 0 ? Icons.shield_outlined : Icons.warning_amber_rounded,
            title: attention == 0 ? '家庭保护在线' : '$attention 台设备需要注意',
            message: report == null
                ? '还没有自检记录'
                : '上次自检 ${relativeTime(report.checkedAt)}，${report.attentionCount == 0 ? '未发现异常' : '${report.attentionCount} 项需要注意'}',
            color: attention == 0 ? colors.primary : colors.warning,
            onTap: () => context.push(AppPaths.selfCheck),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => context.push(AppPaths.selfCheck),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('一键自检'),
          ),
          if (state.protectionNote != null) ...[
            const SizedBox(height: 12),
            InfoBanner(
              icon: Icons.shield_outlined,
              title: '保护范围有变化',
              message: state.protectionNote!,
              color: colors.warning,
            ),
          ],
          const SizedBox(height: 18),
          for (final device in state.devices) ...[
            _DeviceCard(device: device),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => context.push(AppPaths.addDevice),
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加设备'),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final CareDevice device;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final color = deviceTone(colors, device.status);
    return CareCard(
      onTap: () => context.push(AppPaths.device(device.id)),
      child: Row(
        children: [
          IconBadge(icon: deviceIcon(device.icon), color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${device.location} · ${deviceStatusLabel(device.status)} · ${device.statusText}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '最近通信 ${relativeTime(device.lastSeenAt)}'
                  '${device.batteryPercent == null ? '' : ' · 电量 ${device.batteryPercent}%'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (device.batteryPercent != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: device.batteryPercent! / 100,
                      minHeight: 6,
                      color: device.batteryPercent! < 20 ? colors.warning : colors.primary,
                      backgroundColor: colors.line,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.muted),
        ],
      ),
    );
  }
}

class CheckItem {
  const CheckItem({required this.title, required this.detail, required this.ok});

  final String title;
  final String detail;
  final bool ok;
}

List<CheckItem> buildSelfChecks(AppState state) {
  return [
    for (final device in state.devices)
      CheckItem(
        title: device.name,
        detail: device.fault ?? '${device.location} · ${device.statusText}',
        ok: device.status == DeviceStatus.online,
      ),
    const CheckItem(
      title: '告警通知',
      detail: 'App、短信和电话备用通道按当前策略可用',
      ok: true,
    ),
  ];
}

class SelfCheckPage extends ConsumerStatefulWidget {
  const SelfCheckPage({super.key});

  @override
  ConsumerState<SelfCheckPage> createState() => _SelfCheckPageState();
}

class _SelfCheckPageState extends ConsumerState<SelfCheckPage> {
  late final List<CheckItem> _items;
  Timer? _timer;
  int _revealed = 0;
  var _saved = false;

  @override
  void initState() {
    super.initState();
    _items = buildSelfChecks(ref.read(appControllerProvider));
    _schedule();
  }

  void _schedule() {
    _timer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted) {
        return;
      }
      setState(() => _revealed += 1);
      if (_revealed < _items.length) {
        _schedule();
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    if (_saved) {
      return;
    }
    _saved = true;
    final attention = _items.where((item) => !item.ok).length;
    ref.read(appControllerProvider.notifier).saveSelfCheck(
      SelfCheckReport(
        checkedAt: DateTime.now(),
        attentionCount: attention,
        lines: [for (final item in _items) '${item.title}：${item.detail}'],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final done = _revealed >= _items.length;
    final attention = _items.where((item) => !item.ok).length;
    return Scaffold(
      appBar: AppBar(title: const Text('一键自检')),
      body: ListView(
        padding: kPagePadding,
        children: [
          Text(
            done ? '自检完成' : '正在检查家庭保护',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            done
                ? (attention == 0 ? '关键项都正常。' : '$attention 项需要注意，跌倒监测不受药盒电量影响。')
                : '演示环境只核对当前设备状态，不会向硬件发送指令。',
            style: TextStyle(color: colors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _items.isEmpty ? 1 : _revealed / _items.length,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < _items.length; index++) ...[
            _CheckRow(
              item: _items[index],
              phase: index < _revealed
                  ? _CheckPhase.done
                  : index == _revealed
                  ? _CheckPhase.running
                  : _CheckPhase.waiting,
            ),
            const SizedBox(height: 10),
          ],
          if (done) ...[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('完成'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _CheckPhase { waiting, running, done }

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.item, required this.phase});

  final CheckItem item;
  final _CheckPhase phase;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final color = phase == _CheckPhase.done
        ? (item.ok ? colors.primary : colors.warning)
        : colors.muted;
    return CareCard(
      child: Row(
        children: [
          if (phase == _CheckPhase.running)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          else
            Icon(
              phase == _CheckPhase.waiting
                  ? Icons.circle_outlined
                  : item.ok
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              color: color,
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (phase == _CheckPhase.done) ...[
                  const SizedBox(height: 3),
                  Text(item.detail, style: TextStyle(color: colors.muted, height: 1.4)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftType {
  const _DraftType({
    required this.name,
    required this.icon,
    required this.blurb,
    required this.critical,
    required this.powerLabel,
    required this.battery,
  });

  final String name;
  final String icon;
  final String blurb;
  final bool critical;
  final String powerLabel;
  final int? battery;
}

const _draftTypes = [
  _DraftType(
    name: '毫米波雷达',
    icon: 'radar',
    blurb: '辅助发现姿态异常，不上传原始点云。',
    critical: true,
    powerLabel: '市电',
    battery: null,
  ),
  _DraftType(
    name: '智能药盒',
    icon: 'medication',
    blurb: '记录开合与确认，不判断药物是否正确。',
    critical: false,
    powerLabel: '电池',
    battery: 100,
  ),
  _DraftType(
    name: '紧急求助按钮',
    icon: 'button',
    blurb: '按下后向家属发送求助。',
    critical: false,
    powerLabel: '电池',
    battery: 100,
  ),
];

const _rooms = ['客厅', '卧室', '卫生间', '厨房', '阳台'];

class AddDevicePage extends ConsumerStatefulWidget {
  const AddDevicePage({super.key});

  @override
  ConsumerState<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends ConsumerState<AddDevicePage> {
  final _name = TextEditingController(text: _draftTypes.first.name);
  var _typeIndex = 0;
  var _room = _rooms.first;
  var _nameTouched = false;
  var _pairing = false;
  var _done = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final draft = _draftTypes[_typeIndex];
    return Scaffold(
      appBar: AppBar(title: const Text('添加设备')),
      body: ListView(
        padding: kPagePadding,
        children: [
          if (_done) ...[
            const EmptyHint(
              icon: Icons.check_circle_outline_rounded,
              title: '已加入这个家庭',
              message: '演示绑定只写在本机，没有搜索蓝牙，也没有改动网络。',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('返回设备'),
            ),
          ] else if (_pairing) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              '正在模拟绑定',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '不会连接蓝牙或家庭中枢。',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.muted),
            ),
          ] else ...[
            Text('选择设备', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            for (var index = 0; index < _draftTypes.length; index++) ...[
              CareCard(
                onTap: () => _selectType(index),
                borderColor: index == _typeIndex ? colors.primary : colors.line,
                child: Row(
                  children: [
                    IconBadge(
                      icon: deviceIcon(_draftTypes[index].icon),
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _draftTypes[index].name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _draftTypes[index].blurb,
                            style: TextStyle(color: colors.muted, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      index == _typeIndex
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: index == _typeIndex ? colors.primary : colors.muted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
            Text('安装房间', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final room in _rooms)
                  ChoiceChip(
                    label: Text(room),
                    selected: _room == room,
                    onSelected: (_) => setState(() => _room = room),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: '设备名称'),
              onChanged: (_) => setState(() => _nameTouched = true),
            ),
            const SizedBox(height: 8),
            Text(
              '一个家庭保持一台中枢。雷达、药盒和按钮可以按房间继续添加。',
              style: TextStyle(color: colors.muted, height: 1.45),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : () => _start(draft),
              child: const Text('开始绑定'),
            ),
          ],
        ],
      ),
    );
  }

  void _selectType(int index) {
    setState(() {
      _typeIndex = index;
      if (!_nameTouched) {
        _name.text = _draftTypes[index].name;
      }
    });
  }

  void _start(_DraftType draft) {
    final name = _name.text.trim();
    if (name.isEmpty || _pairing) {
      return;
    }
    setState(() => _pairing = true);
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) {
        return;
      }
      ref.read(appControllerProvider.notifier).addDevice(
        CareDevice(
          id: 'device-${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          location: _room,
          icon: draft.icon,
          status: DeviceStatus.online,
          statusText: '刚刚绑定',
          lastSeenAt: DateTime.now(),
          firmware: '1.0.0',
          powerLabel: draft.powerLabel,
          criticalForProtection: draft.critical,
          batteryPercent: draft.battery,
        ),
      );
      setState(() {
        _pairing = false;
        _done = true;
      });
    });
  }
}
