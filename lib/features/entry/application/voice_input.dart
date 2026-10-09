import 'package:speech_to_text/speech_to_text.dart';

/// Turns speech into text. A small interface so screens can be tested
/// without a microphone.
abstract class VoiceInput {
  /// True while the microphone is open.
  bool get isListening;

  /// Starts listening. [onText] gets the words so far, and `true` when the
  /// phrase is complete. Returns false when speech is not available (no
  /// permission, or the phone cannot do it).
  Future<bool> start(
    void Function(String text, bool isFinal) onText, {
    String? localeId,
  });

  Future<void> stop();
}

class SpeechVoiceInput implements VoiceInput {
  final _speech = SpeechToText();
  var _ready = false;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> start(
    void Function(String text, bool isFinal) onText, {
    String? localeId,
  }) async {
    if (!_ready) {
      try {
        _ready = await _speech.initialize();
      } catch (_) {
        _ready = false;
      }
    }
    if (!_ready) return false;
    await _speech.listen(
      onResult: (r) => onText(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        localeId: localeId,
      ),
    );
    return true;
  }

  @override
  Future<void> stop() => _speech.stop();
}
