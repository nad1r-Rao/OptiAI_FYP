import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import 'chat_provider.dart';

/// A provider class for managing speech-to-text functionalities.
///
/// This class acts as a bridge between the UI and the [SpeechService]. It
/// handles the state for listening, the recognized text, and triggers
/// actions in the [ChatProvider] based on the speech input.
class SpeechProvider extends ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  String _recognizedText = '';

  /// A boolean indicating whether the speech recognition service is currently listening.
  bool get isListening => _isListening;

  /// The text that has been recognized by the speech service.
  String get recognizedText => _recognizedText;

  /// Initializes the speech recognition service.
  ///
  - It's recommended to call this once when the application starts.
  ///
  - Returns `true` if initialization is successful, `false` otherwise.
  Future<bool> initialize() async {
    return await _speechService.initializeSpeech();
  }

  /// Starts the speech recognition service.
  ///
  /// This method begins listening for speech and processes the recognized
  /// text. It determines whether the user's command is for image analysis
  /// or a standard text query and calls the appropriate method on the [chatProvider].
  ///
  /// [onResult] A callback function that is invoked with the recognized text.
  /// [chatProvider] The [ChatProvider] instance to send the final command to.
  void startListening({required Function(String) onResult, required ChatProvider chatProvider}) {
    _isListening = true;
    notifyListeners();

    _speechService.startListening((text) {
      _recognizedText = text;
      onResult(text);
      notifyListeners();

      final lower = text.toLowerCase();
      if (lower.contains("identify") || lower.contains("describe") || lower.contains("what's") || lower.contains("what is") || lower.contains("capture") || lower.contains("take picture")) {
        chatProvider.analyzeImageWithPrompt(text);
      } else {
        chatProvider.sendText(text);
      }
    });
  }

  /// Stops the speech recognition service.
  void stopListening() {
    _speechService.stopListening();
    _isListening = false;
    notifyListeners();
  }

  /// Resets the recognized text to an empty string.
  void resetText() {
    _recognizedText = '';
    notifyListeners();
  }
}
