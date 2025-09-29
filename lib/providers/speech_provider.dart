import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import 'chat_provider.dart';

class SpeechProvider extends ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  String _recognizedText = '';

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;

  Future<bool> initialize() async {
    return await _speechService.initializeSpeech();
  }

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

  void stopListening() {
    _speechService.stopListening();
    _isListening = false;
    notifyListeners();
  }

  void resetText() {
    _recognizedText = '';
    notifyListeners();
  }
}
