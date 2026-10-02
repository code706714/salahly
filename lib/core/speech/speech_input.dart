import 'package:speech_to_text/speech_to_text.dart';

/// Dictation, so a technician can say the problem instead of typing it.
abstract interface class SpeechInput {
  /// Starts listening in Egyptian Arabic and reports the words heard so
  /// far as they change. Returns false when the phone cannot recognise
  /// speech or the microphone is not allowed.
  Future<bool> listen({required void Function(String words) onWords});

  /// Stops listening; the last words reported are final.
  Future<void> stop();
}

class DeviceSpeechInput implements SpeechInput {
  DeviceSpeechInput({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  static const _locale = 'ar_EG';

  final SpeechToText _speech;

  @override
  Future<bool> listen({required void Function(String words) onWords}) async {
    try {
      if (!_speech.isAvailable && !await _speech.initialize()) return false;
      await _speech.listen(
        onResult: (result) => onWords(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          localeId: _locale,
          listenMode: ListenMode.dictation,
          cancelOnError: true,
        ),
      );
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> stop() => _speech.stop();
}
