import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/care_widgets.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(appControllerProvider).members;
    final colors = context.care;
    return Scaffold(
      appBar: AppBar(title: const Text('家庭成员')),
      body: ListView(
        padding: kPagePadding,
        children: [
          InfoBanner(
            icon: Icons.low_priority_rounded,
            title: '上面的人先收到升级通知',
            message: '所有者固定在第一位。其他成员可以调整顺序，告警会按这个顺序升级。',
            color: context.care.primary,
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < members.length; index++) ...[
            _MemberCard(member: members[index], index: index),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: members.length >= 6 ? null : () => _add(context, ref),
            icon: const Icon(Icons.person_add_alt_rounded),
            label: Text(members.length >= 6 ? '最多 6 位成员' : '邀请成员'),
          ),
          const SizedBox(height: 12),
          Text(
            '所有者可管理全部配置。管理员可改设备和计划。联系人可接收告警并处置事件。只读成员只能查看。',
            style: TextStyle(color: colors.muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final saved = await showModalBottomSheet<_NewMember>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _AddMemberSheet(),
    );
    if (saved == null || !context.mounted) {
      return;
    }
    final ok = ref.read(appControllerProvider.notifier).addMember(
      name: saved.name,
      phoneMasked: maskPhone(saved.phone),
      relation: saved.relation,
      role: saved.role,
    );
    if (!context.mounted) {
      return;
    }
    showCareToast(context, ok ? '已加入${saved.name}' : '暂时无法添加');
  }
}

class _MemberCard extends ConsumerWidget {
  const _MemberCard({required this.member, required this.index});

  final FamilyMember member;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.care;
    final palette = [
      colors.primary,
      colors.info,
      colors.warning,
      const Color(0xFF7A5B8A),
    ];
    final color = palette[index % palette.length];
    return CareCard(
      onTap: () => _open(context, ref),
      child: Row(
        children: [
          InitialAvatar(
            name: member.name,
            background: color.withValues(alpha: 0.14),
            foreground: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isSelf ? '${member.name}（我）' : member.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                const SizedBox(height: 3),
                Text(
                  '${familyRoleLabel(member.role)} · ${member.relation} · ${member.phoneMasked}',
                  style: TextStyle(color: colors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${index + 1}',
            style: TextStyle(color: colors.muted, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (member.role == FamilyRole.owner) {
      await showCareConfirm(
        context,
        title: member.name,
        message: '所有者固定为第一联系人，不能移除，也不能排到其他人后面。',
        confirmLabel: '知道了',
        cancelLabel: '关闭',
      );
      return;
    }
    final action = await showChoiceSheet(
      context,
      title: member.name,
      message: '调整通知顺序，或把这位成员移出家庭。',
      options: const ['上移', '下移', '移除成员'],
    );
    if (action == null || !context.mounted) {
      return;
    }
    final controller = ref.read(appControllerProvider.notifier);
    if (action == '上移') {
      final ok = controller.moveMember(member.id, -1);
      if (context.mounted && !ok) {
        showCareToast(context, '已经不能再上移');
      }
      return;
    }
    if (action == '下移') {
      final ok = controller.moveMember(member.id, 1);
      if (context.mounted && !ok) {
        showCareToast(context, '已经不能再下移');
      }
      return;
    }
    final confirmed = await showCareConfirm(
      context,
      title: '移除${member.name}？',
      message: '移除后，对方不再接收这个家庭的告警。演示数据可以在“关于”里恢复。',
      confirmLabel: '确认移除',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    controller.removeMember(member.id);
    if (context.mounted) {
      showCareToast(context, '已移除${member.name}');
    }
  }
}

class _NewMember {
  const _NewMember({
    required this.name,
    required this.phone,
    required this.relation,
    required this.role,
  });

  final String name;
  final String phone;
  final String relation;
  final FamilyRole role;
}

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet();

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relation = TextEditingController(text: '家人');
  var _role = FamilyRole.contact;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final valid = _name.text.trim().isNotEmpty && isMainlandMobile(_phone.text.trim());
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('邀请成员', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '姓名'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: '手机号'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _relation,
            decoration: const InputDecoration(labelText: '关系'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final role in [FamilyRole.admin, FamilyRole.contact, FamilyRole.viewer])
                ChoiceChip(
                  label: Text(familyRoleLabel(role)),
                  selected: _role == role,
                  onSelected: (_) => setState(() => _role = role),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            valid ? '邀请后立即出现在联系顺序末尾。' : '请填写姓名，以及 11 位手机号。',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: valid
                ? () => Navigator.pop(
                    context,
                    _NewMember(
                      name: _name.text.trim(),
                      phone: _phone.text.trim(),
                      relation: _relation.text.trim(),
                      role: _role,
                    ),
                  )
                : null,
            child: const Text('加入家庭'),
          ),
        ],
        ),
      ),
    );
  }
}
