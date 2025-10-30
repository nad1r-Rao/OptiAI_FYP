import 'package:speech_to_text/speech_to_text.dart';

/// A service class for managing speech-to-text functionality using the `speech_to_text` package.
///
/// This class encapsulates the logic for initializing the speech recognizer,
/// starting and stopping listening sessions, and handling the recognized text.
class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  /// A boolean indicating whether the speech recognition service is currently listening.
  bool get isListening => _isListening;
  /// A boolean indicating whether the speech recognition service is available on the device.
  bool get isAvailable => _isAvailable;

  /// Initializes the speech-to-text service.
  ///
  /// This must be called before any other methods.
  ///
  /// Returns `true` if the service is available, `false` otherwise.
  Future<bool> initializeSpeech() async {
    _isAvailable = await _speechToText.initialize();
    return _isAvailable;
  }

  /// Starts a listening session for speech recognition.
  ///
  /// When a final result is recognized, it invokes the [onResult] callback
  /// and automatically stops the listening session.
  ///
  /// [onResult] A callback function that receives the recognized text as a string.
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

  /// Stops the current listening session.
  void stopListening() {
    if (_speechToText.isListening) {
      _speechToText.stop();
    }
    _isListening = false;
  }
}
