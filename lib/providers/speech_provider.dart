import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/speech_service.dart';
import 'chat_provider.dart';

class SpeechProvider extends ChangeNotifier {
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  String _recognizedText = '';
  
  // Wake Word & Auto-Sleep State
  bool _isAwake = false;
  Timer? _sleepTimer;
  
  bool get isListening => _isListening;
  bool get isAwake => _isAwake;
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

      // 1. SLEEP MODE: Only listen for "Opti"
      if (!_isAwake) {
        if (lower.contains('opti')) {
          _wakeUp();
          // Fall through to process the command immediately!
        } else {
          return; // Ignore other text if not waking up
        }
      }

      // 2. AWAKE MODE: Process commands & Reset Timer
      _resetSleepTimer();
      
      // Delegate all logic to ChatProvider.sendText
      chatProvider.sendText(text);
    });
  }

  void _wakeUp() {
    _isAwake = true;
    notifyListeners();
    _resetSleepTimer();

  }

  void _goToSleep() {
    _isAwake = false;
    _sleepTimer?.cancel();
    notifyListeners();

  }

  void _resetSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(seconds: 30), _goToSleep);
  }


  void stopListening() {
    _speechService.stopListening();
    _isListening = false;
    _sleepTimer?.cancel(); // Cancel timer when manually stopped
    notifyListeners();
  }

  void resetText() {
    _recognizedText = '';
    notifyListeners();
  }
}

