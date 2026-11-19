import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/router/app_paths.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  static const _sectionStyle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final self = state.members.firstWhere((member) => member.isSelf);
    final pendingMeds = state.medicationTasks
        .where((task) => medicationPhase(task) != MedicationPhase.done)
        .length;

    return ListView(
      padding: kPagePadding,
      children: [
        const TabHeading(title: '我的'),
        const SizedBox(height: 16),
        CareCard(
          onTap: () => context.push(AppPaths.account),
          child: Row(
            children: [
              InitialAvatar(
                name: self.name,
                background: colors.primarySoft,
                foreground: colors.primary,
                radius: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      self.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${familyRoleLabel(self.role)} · ${state.familyName}',
                      style: TextStyle(color: colors.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      self.phoneMasked,
                      style: TextStyle(color: colors.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.muted),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('使用模式', style: _sectionStyle),
        const SizedBox(height: 8),
        CareSegmented(
          labels: const ['子女模式', '老人模式'],
          index: state.appMode.index,
          onChanged: (index) {
            if (AppMode.values[index] == AppMode.elder) {
              _enterElderMode(context, ref);
            }
          },
        ),
        const SizedBox(height: 6),
        Text(
          '老人模式只有一页，字更大，说一句话就能记血压和用药。适合装在老人自己的手机上。',
          style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 18),
        Text('外观', style: _sectionStyle),
        const SizedBox(height: 8),
        CareSegmented(
          labels: const ['跟随系统', '浅色', '深色'],
          index: state.themePreference.index,
          onChanged: (index) {
            ref
                .read(appControllerProvider.notifier)
                .setThemePreference(AppThemePreference.values[index]);
          },
        ),
        const SizedBox(height: 22),
        Text('家庭与照护', style: _sectionStyle),
        const SizedBox(height: 8),
        CareCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.group_outlined,
                title: '家庭成员',
                subtitle: '${state.members.length} 位联系人',
                onTap: () => context.push(AppPaths.family),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.add_alert_outlined,
                title: '告警策略',
                subtitle: escalationSummary(state.escalation),
                onTap: () => context.push(AppPaths.policy),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.medication_outlined,
                title: '用药计划',
                subtitle: pendingMeds == 0
                    ? '今日计划都已确认'
                    : '还有 $pendingMeds 项未确认',
                onTap: () => context.push(AppPaths.medication),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.favorite_border_rounded,
                title: '健康记录',
                subtitle: '${state.recipient.name}自己记录的血压、血糖和用药',
                onTap: () => context.push(AppPaths.health),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.medical_services_outlined,
                title: '咨询预约',
                subtitle: '按科室查看医生空闲与排队，预约图文/电话/视频',
                onTap: () => context.push(AppPaths.consult),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.admin_panel_settings_outlined,
                title: '数据与权限',
                subtitle: '共享范围和访问记录',
                onTap: () => context.push(AppPaths.privacy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text('支持', style: _sectionStyle),
        const SizedBox(height: 8),
        CareCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: '通知能力检查',
                subtitle: '当前状态正常',
                onTap: () => context.push(AppPaths.notifications),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: '帮助与反馈',
                onTap: () => context.push(AppPaths.help),
              ),
              Divider(height: 1, indent: 72, color: colors.line),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: '关于安心守护',
                subtitle: '演示版 $kAppVersion',
                onTap: () => context.push(AppPaths.about),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '本产品用于居家生活照护辅助，不能替代专业医疗、人工护理或紧急救援服务。',
          style: TextStyle(color: colors.muted, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Future<void> _enterElderMode(BuildContext context, WidgetRef ref) async {
    final confirmed = await showCareConfirm(
      context,
      title: '切换到老人模式？',
      message:
          '这台手机会只显示一个大字页面，重新打开 App 也会保持老人模式。\n\n'
          '要切回来时，长按页面右上角的「家人」按钮。',
      confirmLabel: '切换',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).setAppMode(AppMode.elder);
  }
}

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final self = state.members.firstWhere((member) => member.isSelf);
    final order =
        state.members.indexWhere((member) => member.id == self.id) + 1;
    return Scaffold(
      appBar: AppBar(title: const Text('账号')),
      body: ListView(
        padding: kPagePadding,
        children: [
          CareCard(
            child: Column(
              children: [
                SpecRow(label: '姓名', value: self.name),
                SpecRow(label: '手机号', value: self.phoneMasked),
                SpecRow(
                  label: '身份',
                  value: '${familyRoleLabel(self.role)} · ${self.relation}',
                ),
                SpecRow(label: '家庭', value: state.familyName),
                SpecRow(label: '通知顺序', value: '第 $order 位'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InfoBanner(
            icon: Icons.lock_outline_rounded,
            title: '演示账号',
            message: '当前没有登录服务器。姓名只保存在这次打开的页面里，刷新浏览器后会回到示例数据。',
            color: context.care.info,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => _rename(context, ref, self),
            child: const Text('修改显示姓名'),
          ),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    FamilyMember self,
  ) async {
    final controller = TextEditingController(text: self.name);
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('显示姓名'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: '怎么称呼你'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null || saved.isEmpty || !context.mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).renameMember(self.id, saved);
  }
}
