import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> initializeSpeech() async {
    _isAvailable = await _speechToText.initialize();
    return _isAvailable;
  }

  void startListening(Function(String) onResult) {
    if (!_isAvailable) return;

    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          _isListening = false;
          onResult(result.recognizedWords);
          stopListening();
        }
      },
      // listenMode: ListenMode.confirmation,
      // cancelOnError: true,
    );
    _isListening = true;
  }

  void stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _isListening = false;
  }
}
