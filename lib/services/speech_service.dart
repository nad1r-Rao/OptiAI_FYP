import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:audio_session/audio_session.dart';

class SpeechService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  Future<bool> initializeSpeech() async {
    // Configure audio session for Bluetooth support (Mobile only)
    if (!kIsWeb) {
      try {
        final session = await AudioSession.instance;
        await session.configure(AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.allowBluetooth | 
                                         AVAudioSessionCategoryOptions.defaultToSpeaker,
          avAudioSessionMode: AVAudioSessionMode.voiceChat,
          avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.voiceCommunication,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
          androidWillPauseWhenDucked: true,
        ));
      } catch (e) {

      }
    }

    _isAvailable = await _speechToText.initialize();
    return _isAvailable;
  }

  void startListening(Function(String) onResult) {
    if (!_isAvailable) return;

    if (_speechToText.isListening) {
      _speechToText.stop(); // Ensure it's stopped before restarting or just return
      // For now, let's just return to prevent the crash, or stop and wait.
      // The error "recognition has already started" suggests we shouldn't call listen again.
      return; 
    }

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
