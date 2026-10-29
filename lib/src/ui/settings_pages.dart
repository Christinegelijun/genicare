import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class PolicyPage extends ConsumerWidget {
  const PolicyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final order = state.members.map((member) => member.name).join(' → ');
    return Scaffold(
      appBar: AppBar(title: const Text('告警策略')),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.notifications_active_outlined,
            title: '无人认领时按顺序升级',
            message: '演示环境不会真正发送短信或拨打电话，只保存你选中的升级方式。',
            color: context.care.info,
          ),
          const SizedBox(height: 14),
          CareCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final step in state.escalation)
                  SwitchListTile.adaptive(
                    title: Text(
                      step.channel,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(step.description),
                    value: step.enabled,
                    onChanged: step.locked
                        ? null
                        : (value) {
                            ref.read(appControllerProvider.notifier).toggleEscalation(
                              step.id,
                              enabled: value,
                            );
                          },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'App 推送是紧急事件的第一通道，不能关闭。短信和电话是备用。',
            style: TextStyle(color: colors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          CareCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前联系顺序', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(order, style: const TextStyle(height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final privacy = state.privacy;
    final controller = ref.read(appControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('数据与权限')),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.visibility_outlined,
            title: '你自己始终看得到',
            message: '下面的开关决定其他成员能看到什么。关闭后不会从你的首页藏起这些信息。',
            color: context.care.primary,
          ),
          const SizedBox(height: 14),
          CareCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: const Text('共享事件房间', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('告警里显示客厅、卧室等房间，不提供精确坐标'),
                  value: privacy.shareRoom,
                  onChanged: (value) => controller.updatePrivacy(shareRoom: value),
                ),
                SwitchListTile.adaptive(
                  title: const Text('共享用药确认', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('其他成员可以看到是否确认，不包含用药建议'),
                  value: privacy.shareMedication,
                  onChanged: (value) => controller.updatePrivacy(shareMedication: value),
                ),
                SwitchListTile.adaptive(
                  title: const Text('共享设备健康', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('其他成员可以看到在线、电量和故障'),
                  value: privacy.shareDeviceHealth,
                  onChanged: (value) => controller.updatePrivacy(shareDeviceHealth: value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const SectionHeader(title: '最近访问'),
          const SizedBox(height: 10),
          if (state.accessLogs.isEmpty)
            const EmptyHint(
              icon: Icons.history_rounded,
              title: '还没有访问记录',
              message: '认领事件、修改策略和添加设备后会出现在这里。',
            )
          else
            CareCard(
              child: Column(
                children: [
                  for (var index = 0; index < state.accessLogs.length; index++) ...[
                    _LogRow(record: state.accessLogs[index]),
                    if (index != state.accessLogs.length - 1)
                      Divider(height: 18, color: context.care.line),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.record});

  final AccessRecord record;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${record.actor} ${record.action}',
                style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 3),
              Text(
                friendlyDateTime(record.occurredAt),
                style: TextStyle(color: colors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class NotificationCheckPage extends ConsumerStatefulWidget {
  const NotificationCheckPage({super.key});

  @override
  ConsumerState<NotificationCheckPage> createState() => _NotificationCheckPageState();
}

class _NotificationCheckPageState extends ConsumerState<NotificationCheckPage> {
  var _checking = false;
  var _checkedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final phone = ref.watch(appControllerProvider).recipient.phoneMasked;
    final colors = context.care;
    final items = [
      ('系统通知', '演示环境默认允许应用内提醒'),
      ('紧急通道', '待处理事件会显示在首页和事件页'),
      ('备用手机号', '$phone 已作为老人联系电话'),
      ('短信备用', '按告警策略中的短信开关显示'),
      ('电话备用', '按告警策略中的电话开关显示'),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('通知能力')),
      body: ListView(
        padding: kPagePadding,
        children: [
          Text(
            _checking ? '正在核对' : '通知能力正常',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '最近检查 ${friendlyDateTime(_checkedAt)}。这里不会向系统申请真实权限。',
            style: TextStyle(color: colors.muted, height: 1.45),
          ),
          const SizedBox(height: 16),
          for (final item in items) ...[
            CareCard(
              child: Row(
                children: [
                  Icon(
                    _checking ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                    color: _checking ? colors.warning : colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(item.$2, style: TextStyle(color: colors.muted, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          FilledButton(
            onPressed: _checking ? null : _recheck,
            child: Text(_checking ? '检查中' : '重新检查'),
          ),
        ],
      ),
    );
  }

  Future<void> _recheck() async {
    setState(() => _checking = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      _checkedAt = DateTime.now();
    });
    showCareToast(context, '通知能力正常');
  }
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  final _feedback = TextEditingController();

  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Scaffold(
      appBar: AppBar(title: const Text('帮助与反馈')),
      body: ListView(
        padding: kPagePadding,
        children: [
          for (final item in _faqs) ...[
            CareCard(
              padding: EdgeInsets.zero,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    Text(item.$2, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          Text('反馈', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _feedback,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '哪一步不好找，或哪句文案看不懂',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '演示环境不会上传这段内容。',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              final text = _feedback.text.trim();
              if (text.isEmpty) {
                showCareToast(context, '先写一点想反馈的内容');
                return;
              }
              _feedback.clear();
              showCareToast(context, '已留在本机，演示不会上传');
            },
            child: const Text('提交反馈'),
          ),
        ],
      ),
    );
  }
}

const _faqs = [
  (
    '紧急事件要怎么处理？',
    '先打开事件。需要时联系老人，或让中枢再次询问。确认由自己跟进时点「我来处理」，确认安全后再结束。',
  ),
  (
    '看到了就算处理完吗？',
    '不算。请使用「我来处理」或「老人安全，结束事件」。单独打开页面不会被记成老人已经安全。',
  ),
  (
    '误报怎么处理？',
    '确认现场没有风险后可以标记误报。事件会结束，并留下误报记录。',
  ),
  (
    '设备离线会怎样？',
    '中枢或雷达离线时，对应房间的自动监测会中断。药盒和求助按钮异常不会被显示成老人安全。',
  ),
  (
    '用药计划是处方吗？',
    '不是。计划由家属录入和确认，本产品不提供诊断、处方或剂量建议。',
  ),
  (
    '为什么没有真正打电话？',
    '当前是本地演示，不会拨打真实电话、发送短信或连接硬件。操作会记入事件进展，用来预览流程。',
  ),
];

class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: kPagePadding,
        children: [
          CareCard(
            child: Row(
              children: [
                IconBadge(
                  icon: Icons.favorite_rounded,
                  color: colors.primary,
                  size: 56,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('安心守护', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        '演示版 $kAppVersion',
                        style: TextStyle(color: colors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '用于预览居家照护里的状态、事件、设备和用药确认。不能替代专业医疗、人工护理或紧急救援。',
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => showCareToast(context, '当前已是最新演示版本'),
            child: const Text('检查更新'),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () => _reset(context, ref),
            child: const Text('恢复初始演示'),
          ),
        ],
      ),
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCareConfirm(
      context,
      title: '恢复初始演示？',
      message: '会清除这次演示里的认领、用药确认、成员和设备改动。外观选择会保留。',
      confirmLabel: '恢复',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).resetDemo();
    if (!context.mounted) {
      return;
    }
    showCareToast(context, '已恢复初始演示数据');
  }
}
