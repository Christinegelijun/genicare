import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:venicare_app/src/domain/models.dart';
import 'package:venicare_app/src/domain/voice_parser.dart';
import 'package:venicare_app/src/state/app_controller.dart';
import 'package:venicare_app/src/state/voice_input.dart';
import 'package:venicare_app/src/theme/care_theme.dart';
import 'package:venicare_app/src/ui/sheets.dart';
import 'package:venicare_app/src/ui/ui_helpers.dart';

enum _Stage { idle, listening, confirm, saved, problem }

class ElderHomePage extends ConsumerStatefulWidget {
  const ElderHomePage({super.key});

  @override
  ConsumerState<ElderHomePage> createState() => _ElderHomePageState();
}

class _ElderHomePageState extends ConsumerState<ElderHomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final VoiceInput _voice = ref.read(voiceInputProvider);

  _Stage _stage = _Stage.idle;
  String _transcript = '';
  RecordSource _source = RecordSource.voice;
  List<VoiceEntry> _draft = const [];
  String? _note;
  ElderSaveResult? _lastSave;

  @override
  void dispose() {
    if (_stage == _Stage.listening) {
      _voice.cancel();
    }
    _pulse.dispose();
    super.dispose();
  }

  void _setStage(_Stage stage) {
    if (stage == _Stage.listening) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
    setState(() => _stage = stage);
  }

  Future<void> _toggleListening() async {
    if (_stage == _Stage.listening) {
      await _voice.stop();
      return;
    }
    _transcript = '';
    _source = RecordSource.voice;
    _setStage(_Stage.listening);
    final started = await _voice.start(
      onResult: (text, {required isFinal}) {
        if (mounted && _stage == _Stage.listening) {
          setState(() => _transcript = text);
        }
      },
      onDone: _onListeningDone,
    );
    if (!started && mounted) {
      _note = '这台手机现在用不了语音。\n请点下面的「打字记录」，或者请家人打开麦克风权限。';
      _setStage(_Stage.problem);
    }
  }

  Future<void> _onListeningDone({required bool failed}) async {
    // The final transcript can land a moment after the recognizer reports done.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || _stage != _Stage.listening) {
      return;
    }
    if (failed && _transcript.trim().isEmpty) {
      _note = '语音暂时用不了（可能没联网，或没给麦克风权限）。\n请点下面的「打字记录」。';
      _setStage(_Stage.problem);
      return;
    }
    _handleText(_transcript, RecordSource.voice);
  }

  void _handleText(String text, RecordSource source) {
    _transcript = text.trim();
    _source = source;
    if (_transcript.isEmpty) {
      _note = '没听到声音。\n请靠近手机，再点一下说话。';
      _setStage(_Stage.problem);
      return;
    }
    final parsed = parseHealthSpeech(_transcript);
    final (entries, medicationNote) = resolveMedication(
      parsed.entries,
      ref.read(appControllerProvider).medicationTasks,
      DateTime.now(),
    );
    _draft = entries;
    _note = medicationNote ?? parsed.problem;
    _setStage(entries.isEmpty ? _Stage.problem : _Stage.confirm);
  }

  void _saveDraft() {
    final result = ref
        .read(appControllerProvider.notifier)
        .saveElderEntries(_draft, source: _source, transcript: _transcript);
    if (result.isEmpty) {
      _note = '这些已经记过了，不用再记。';
      _setStage(_Stage.problem);
      return;
    }
    _lastSave = result;
    _setStage(_Stage.saved);
  }

  void _undoLastSave() {
    final result = _lastSave;
    if (result == null) {
      return;
    }
    ref.read(appControllerProvider.notifier).undoElderSave(result);
    _lastSave = null;
    _setStage(_Stage.idle);
    _toast('已经撤销，刚才那条不算了');
  }

  void _reset() => _setStage(_Stage.idle);

  Future<void> _typeInstead() async {
    if (_stage == _Stage.listening) {
      await _voice.cancel();
      _setStage(_Stage.idle);
    }
    if (!mounted) {
      return;
    }
    final text = await showDialog<String>(
      context: context,
      builder: (context) => const _TypeDialog(),
    );
    if (text == null || !mounted) {
      return;
    }
    _handleText(text, RecordSource.typed);
  }

  void _takeMedicine(MedicationTask task) {
    final controller = ref.read(appControllerProvider.notifier);
    final result = controller.saveElderEntries([
      MedicationEntry(task: task),
    ], source: RecordSource.tap);
    if (result.isEmpty) {
      return;
    }
    _toast(
      '记好了：${_medicationTime(task)}的药已吃',
      undo: () => controller.undoElderSave(result),
    );
  }

  Future<void> _exitElderMode() async {
    final confirmed = await showCareConfirm(
      context,
      title: '切回子女模式？',
      message: '切回后会显示完整的家属功能。',
      confirmLabel: '切回',
    );
    if (!confirmed || !mounted) {
      return;
    }
    ref.read(appControllerProvider.notifier).setAppMode(AppMode.family);
  }

  void _toast(String message, {VoidCallback? undo}) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(
          message,
          style: const TextStyle(fontSize: 22, height: 1.4),
        ),
        action: undo == null
            ? null
            : SnackBarAction(
                label: '撤销',
                textColor: Colors.amberAccent,
                onPressed: undo,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final colors = context.care;
    final now = DateTime.now();
    final tasks = [...state.medicationTasks]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final pressure =
        ([...state.healthRecords]
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)))
            .where((record) => record.kind == HealthRecordKind.bloodPressure)
            .firstOrNull;

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${state.recipient.name}，${greetingFor(now)}',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: colors.ink,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weekdayLabel(now),
                        style: TextStyle(
                          fontSize: 22,
                          color: colors.ink.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: '家人长按这里，切回子女模式',
                  child: OutlinedButton.icon(
                    onPressed: () => _toast('请家人长按这个按钮，切回子女模式'),
                    onLongPress: _exitElderMode,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(88, 52),
                      foregroundColor: colors.muted,
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    icon: const Icon(Icons.family_restroom_rounded),
                    label: const Text('家人'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ElderPanel(
              child: Column(
                children: [
                  _MicButton(
                    listening: _stage == _Stage.listening,
                    pulse: _pulse,
                    onTap: _toggleListening,
                  ),
                  const SizedBox(height: 16),
                  ..._stageBody(colors),
                ],
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _typeInstead,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                side: BorderSide(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.keyboard_alt_outlined, size: 28),
              label: const Text('不方便说话？打字记录'),
            ),
            const SizedBox(height: 32),
            _SectionTitle('今天的药'),
            const SizedBox(height: 12),
            if (tasks.isEmpty)
              _ElderPanel(child: _BigText('今天没有要吃的药', color: colors.muted))
            else
              for (final task in tasks) ...[
                _MedicineCard(task: task, onTake: () => _takeMedicine(task)),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 20),
            _SectionTitle('最近一次血压'),
            const SizedBox(height: 12),
            _ElderPanel(
              child: pressure == null
                  ? _BigText('还没有记过。\n量完说一句「血压 130 85」就行', color: colors.muted)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${pressure.systolic} / ${pressure.diastolic}',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _BigText(
                          '${friendlyDateTime(pressure.recordedAt)}'
                          '${pressure.heartRate == null ? '' : '  心跳 ${pressure.heartRate}'}',
                          color: colors.muted,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => _showCallFamily(context, state),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(76),
                backgroundColor: const Color(0xFF1E9E5A),
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.phone_in_talk_rounded, size: 32),
              label: const Text('打电话给家人'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _stageBody(CareColors colors) {
    switch (_stage) {
      case _Stage.idle:
        return [
          _BigText('点一下，开始说话', weight: FontWeight.w700),
          const SizedBox(height: 10),
          _BigText(
            '可以这样说：\n$kVoiceExamples',
            color: colors.muted,
            size: 20,
            center: true,
          ),
        ];
      case _Stage.listening:
        return [
          _BigText(
            '正在听…说完了再点一下',
            color: colors.urgent,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 12),
          _BigText(
            _transcript.isEmpty ? '请说' : _transcript,
            color: _transcript.isEmpty ? colors.muted : colors.ink,
            size: 28,
            center: true,
          ),
        ];
      case _Stage.confirm:
        return [
          _BigText('我听到的是：', color: colors.muted, size: 20),
          const SizedBox(height: 4),
          _BigText(
            '“$_transcript”',
            color: colors.muted,
            size: 20,
            center: true,
          ),
          const SizedBox(height: 14),
          for (final entry in _draft) ...[
            _EntryLine(text: _describeEntry(entry)),
            const SizedBox(height: 8),
          ],
          if (_note != null) ...[
            const SizedBox(height: 4),
            _BigText(_note!, color: colors.warning, size: 20, center: true),
          ],
          const SizedBox(height: 16),
          _BigButton(
            label: '对，记下来',
            icon: Icons.check_rounded,
            onPressed: _saveDraft,
          ),
          const SizedBox(height: 10),
          _BigButton(
            label: '不对，重新说',
            icon: Icons.refresh_rounded,
            outlined: true,
            onPressed: _reset,
          ),
        ];
      case _Stage.saved:
        final high = _draft.whereType<BloodPressureEntry>().any(
          (entry) => entry.systolic >= 140 || entry.diastolic >= 90,
        );
        return [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF1E9E5A),
            size: 64,
          ),
          const SizedBox(height: 8),
          _BigText('记好了！家人也能看到', size: 30, weight: FontWeight.w700),
          const SizedBox(height: 12),
          for (final entry in _draft) ...[
            _EntryLine(text: _describeEntry(entry)),
            const SizedBox(height: 8),
          ],
          if (high) ...[
            const SizedBox(height: 4),
            _BigText(
              '这次血压高于 140/90。\n如果头晕、胸口不舒服，请马上打电话给家人。',
              color: colors.warning,
              size: 22,
              center: true,
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: _undoLastSave,
            style: TextButton.styleFrom(
              minimumSize: const Size(160, 56),
              textStyle: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('记错了，撤销'),
          ),
        ];
      case _Stage.problem:
        return [
          Icon(Icons.hearing_rounded, color: colors.warning, size: 56),
          const SizedBox(height: 8),
          _BigText(_note ?? '没听明白', size: 24, center: true),
          const SizedBox(height: 16),
          _BigButton(
            label: '再说一次',
            icon: Icons.mic_rounded,
            onPressed: _toggleListening,
          ),
        ];
    }
  }

  Future<void> _showCallFamily(BuildContext context, AppState state) async {
    final member = await showModalBottomSheet<FamilyMember>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = sheetContext.care;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              _BigText('打给谁？', size: 28, weight: FontWeight.w700),
              const SizedBox(height: 12),
              for (final member in state.members) ...[
                Material(
                  color: colors.primarySoft,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(sheetContext, member),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            color: colors.primary,
                            size: 34,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              '${member.relation}  ${member.name}',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
    if (member == null || !context.mounted) {
      return;
    }
    _toast('演示版不会真的拨号。正式版会直接打给${member.relation}${member.name}');
  }
}

String _medicationTime(MedicationTask task) {
  final time = task.scheduledAt;
  final hour = time.hour > 12 ? time.hour - 12 : time.hour;
  final minute = time.minute == 0 ? '' : ' ${time.minute} 分';
  return '${medicationPeriodLabel(medicationPeriodOf(time))} $hour 点$minute';
}

String _describeEntry(VoiceEntry entry) {
  return switch (entry) {
    BloodPressureEntry(:final heartRate) =>
      '血压 ${entry.systolic} / ${entry.diastolic}${heartRate == null ? '' : '\n心跳 $heartRate'}',
    HeartRateEntry() => '心跳 ${entry.bpm}',
    BloodSugarEntry() => '血糖 ${entry.value}',
    MedicationEntry(:final task) =>
      task == null ? '吃过药了' : '${_medicationTime(task)}的药 已吃',
  };
}

class _ElderPanel extends StatelessWidget {
  const _ElderPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line, width: 1.5),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: context.care.ink,
      ),
    );
  }
}

class _BigText extends StatelessWidget {
  const _BigText(
    this.text, {
    this.color,
    this.size = 24,
    this.weight = FontWeight.w500,
    this.center = false,
  });

  final String text;
  final Color? color;
  final double size;
  final FontWeight weight;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: center ? TextAlign.center : null,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: 1.45,
        color: color ?? context.care.ink,
      ),
    );
  }
}

class _EntryLine extends StatelessWidget {
  const _EntryLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: colors.ink,
          height: 1.3,
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        icon: Icon(icon, size: 28),
        label: Text(label),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 32),
      label: Text(label),
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.pulse,
    required this.onTap,
  });

  final bool listening;
  final Animation<double> pulse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final color = listening ? colors.urgent : colors.primary;
    return Semantics(
      button: true,
      label: listening ? '说完了，停止' : '开始说话',
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          return Container(
            width: 196,
            height: 196,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08 + pulse.value * 0.14),
            ),
            child: child,
          );
        },
        child: Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          shadowColor: color.withValues(alpha: 0.4),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 84,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.task, required this.onTake});

  final MedicationTask task;
  final VoidCallback onTake;

  @override
  Widget build(BuildContext context) {
    final colors = context.care;
    final phase = medicationPhase(task);
    final (status, statusColor) = switch (phase) {
      MedicationPhase.done => ('✓ 已经吃了', const Color(0xFF1E9E5A)),
      MedicationPhase.due => ('到时间了，还没吃', colors.warning),
      MedicationPhase.upcoming => ('还没到时间', colors.muted),
    };
    return _ElderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _medicationTime(task),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
          const SizedBox(height: 4),
          _BigText(task.compartment, color: colors.muted, size: 20),
          const SizedBox(height: 4),
          _BigText(status, color: statusColor, weight: FontWeight.w700),
          if (phase != MedicationPhase.done) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onTake,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(68),
                textStyle: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 32),
              label: const Text('我吃过了'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeDialog extends StatefulWidget {
  const _TypeDialog();

  @override
  State<_TypeDialog> createState() => _TypeDialogState();
}

class _TypeDialogState extends State<_TypeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '写下来也可以',
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 2,
        style: const TextStyle(fontSize: 26),
        decoration: const InputDecoration(
          hintText: '比如：血压 130 85',
          hintStyle: TextStyle(fontSize: 22),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(88, 56),
            textStyle: const TextStyle(fontSize: 22),
          ),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          style: FilledButton.styleFrom(
            minimumSize: const Size(120, 56),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: const Text('好了'),
        ),
      ],
    );
  }
}
