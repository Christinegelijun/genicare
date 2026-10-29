import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/theme/care_theme.dart';

void showCareToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> showCareConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = '取消',
  bool destructive = false,
}) async {
  final colors = context.care;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(88, 44),
              backgroundColor: destructive ? colors.urgent : null,
              foregroundColor: destructive ? Colors.white : null,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return confirmed == true;
}

Future<String?> showChoiceSheet(
  BuildContext context, {
  required String title,
  required String message,
  required List<String> options,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = sheetContext.care;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(message, style: TextStyle(color: colors.muted, height: 1.45)),
              const SizedBox(height: 8),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.muted,
                  ),
                  onTap: () => Navigator.pop(sheetContext, option),
                ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showCallSheet(
  BuildContext context,
  WidgetRef ref, {
  String? alertId,
}) async {
  final recipient = ref.read(appControllerProvider).recipient;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final colors = sheetContext.care;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('联系${recipient.name}', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                recipient.phoneMasked,
                style: Theme.of(sheetContext).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '演示环境不会拨出真实电话，只会把这次联系记入事件进展。',
                style: TextStyle(color: colors.muted, height: 1.45),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('记录联系尝试'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (confirmed != true || !context.mounted) {
    return;
  }
  final ok = ref.read(appControllerProvider.notifier).recordOnAlert(
    alertId: alertId,
    title: '已尝试联系老人',
    detail: '演示环境未拨出真实电话，已记录本次联系。',
    presenceText: '家属已尝试电话联系',
  );
  if (!context.mounted) {
    return;
  }
  showCareToast(
    context,
    ok ? '已记录联系尝试，演示不会拨出真实电话' : '事件已结束，未能追加记录',
  );
}

Future<void> showVoiceSheet(
  BuildContext context,
  WidgetRef ref, {
  String? alertId,
}) async {
  final confirmed = await showCareConfirm(
    context,
    title: '让中枢再次询问？',
    message: '正式版本会让家庭中枢在现场播放“您还好吗？”。当前演示只把询问记入进展，不会连接设备。',
    confirmLabel: '记录询问',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final ok = ref.read(appControllerProvider.notifier).recordOnAlert(
    alertId: alertId,
    title: '再次发起询问',
    detail: '已记录询问请求。演示环境不会让中枢实际播放语音。',
    presenceText: '已再次发起本地询问',
  );
  if (!context.mounted) {
    return;
  }
  showCareToast(
    context,
    ok ? '已记录询问，演示不会连接家庭中枢' : '事件已结束，未能追加记录',
  );
}
