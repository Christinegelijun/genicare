import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

final voiceInputProvider = Provider<VoiceInput>((ref) {
  final input = SpeechVoiceInput();
  ref.onDispose(input.cancel);
  return input;
});

typedef VoiceResultCallback =
    void Function(String text, {required bool isFinal});

/// [failed] is true when recognition broke (network, permission, audio
/// device), as opposed to simply hearing nothing.
typedef VoiceDoneCallback = void Function({required bool failed});

abstract class VoiceInput {
  /// Returns false when the device has no recognizer or the microphone
  /// permission was refused. [onDone] fires once per session, including
  /// after errors.
  Future<bool> start({
    required VoiceResultCallback onResult,
    required VoiceDoneCallback onDone,
  });

  Future<void> stop();

  Future<void> cancel();
}

class SpeechVoiceInput implements VoiceInput {
  static const _noSpeechErrors = {
    'error_no_match',
    'error_speech_timeout',
    'no-speech',
  };

  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  String? _localeId;
  VoiceDoneCallback? _onDone;

  @override
  Future<bool> start({
    required VoiceResultCallback onResult,
    required VoiceDoneCallback onDone,
  }) async {
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onStatus: (status) {
            if (status == SpeechToText.doneStatus ||
                status == SpeechToText.notListeningStatus) {
              _finish(failed: false);
            }
          },
          onError: (error) {
            _finish(failed: !_noSpeechErrors.contains(error.errorMsg));
          },
        );
        if (!_initialized) {
          return false;
        }
        _localeId = await _chineseLocale();
      }
      _onDone = onDone;
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, isFinal: result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 40),
          pauseFor: const Duration(seconds: 4),
        ),
      );
      return true;
    } on Object {
      _onDone = null;
      return false;
    }
  }

  Future<String?> _chineseLocale() async {
    final locales = await _speech.locales();
    for (final preferred in ['zh_CN', 'zh-CN', 'cmn-Hans-CN']) {
      for (final locale in locales) {
        if (locale.localeId == preferred) {
          return locale.localeId;
        }
      }
    }
    for (final locale in locales) {
      if (locale.localeId.startsWith('zh') ||
          locale.localeId.startsWith('cmn')) {
        return locale.localeId;
      }
    }
    return 'zh_CN';
  }

  void _finish({required bool failed}) {
    final done = _onDone;
    _onDone = null;
    done?.call(failed: failed);
  }

  @override
  Future<void> stop() async {
    if (_initialized) {
      await _speech.stop();
    }
  }

  @override
  Future<void> cancel() async {
    _onDone = null;
    if (_initialized) {
      await _speech.cancel();
    }
  }
}
