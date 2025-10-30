import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_services.dart';
import '../models/chat_message.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// A provider class for managing the chat interface, state, and interactions.
///
/// This class handles the application's core chat functionalities, including:
/// - Managing a list of chat messages.
/// - Interacting with the [AiService] to process user queries and get AI responses.
/// - Handling text-to-speech (TTS) for AI messages.
/// - Persisting chat history to Firestore.
/// - Managing the "thinking" state of the AI.
class ChatProvider with ChangeNotifier {
  /// The service responsible for handling AI-related tasks.
  final AiService aiService;
  final List<ChatMessage> _messages = [];
  final FlutterTts _tts = FlutterTts();
  bool _isThinking = false;
  bool _hasLoadedHistory = false;

  /// A list of [ChatMessage] objects representing the conversation history.
  List<ChatMessage> get messages => _messages;

  /// A boolean indicating whether the AI is currently processing a request.
  bool get isThinking => _isThinking;

  /// Creates a new instance of [ChatProvider].
  ///
  /// Requires an [AiService] to be provided for handling AI interactions.
  ChatProvider({required this.aiService});

  /// Sets the thinking status of the AI and notifies listeners.
  ///
  /// [value] is `true` if the AI is processing, `false` otherwise.
  void _setThinking(bool value) {
    _isThinking = value;
    notifyListeners();
  }

  /// Speaks the given text using the text-to-speech engine.
  ///
  /// [text] The text to be spoken.
  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.speak(text);
  }

  /// Appends a message to the user's chat history in Firestore.
  ///
  /// [text] The content of the message.
  /// [sender] Who sent the message, either 'user' or 'ai'.
  Future<void> _appendToFirestore({
    required String text,
    required String sender, // 'user' | 'ai'
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .add({
      'text': text,
      'sender': sender,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Adds a message from the AI to the chat and optionally speaks it.
  ///
  /// [text] The AI's message content.
  /// [speak] Whether to speak the message using TTS. Defaults to `true`.
  Future<void> _addAiMessage(String text, {bool speak = true}) async {
    final replyMsg = ChatMessage(isUser: false, message: text);
    _messages.add(replyMsg);
    notifyListeners();
    if (speak) await _speak(text);
    await _appendToFirestore(text: text, sender: 'ai');
  }

  /// Loads the chat history for the current user from Firestore.
  ///
  /// [show] If `true`, clears the current messages and displays the loaded history.
  /// [force] If `true`, reloads the history even if it has been loaded before.
  Future<void> loadChatHistory({bool show = true, bool force = false}) async {
    if (_hasLoadedHistory && !force) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory')
        .orderBy('timestamp')
        .get();

    if (show) {
      _messages.clear();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _messages.add(ChatMessage(
          message: data['text'],
          isUser: data['sender'] == 'user',
          imageBytes: null,
        ));
      }
      notifyListeners();
    }

    _hasLoadedHistory = true;
  }

  /// Sends a text message from the user and processes it.
  ///
  /// This method handles various types of text inputs, including routing
  /// to specific functions based on keywords (e.g., "take picture") and
  /// detecting if a query requires real-time information. Otherwise, it
  /// sends the text to the AI for a general response.
  ///
  /// [text] The user's message.
  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Show user message
    final userMsg = ChatMessage(isUser: true, message: text);
    _messages.add(userMsg);
    notifyListeners();
    await _appendToFirestore(text: text, sender: 'user');

    final lower = text.toLowerCase();

    // Manual overrides (keep your shortcuts)
    if (lower.contains("take picture")) {
      await takePicture();
      return;
    }
    if (lower.contains("identify") ||
        lower.contains("describe") ||
        lower.contains("analyze")) {
      await analyzeImageWithPrompt(text);
      return;
    }

    // ---------- Realtime detector ----------
    final looksRealtime = [
      'today','now','latest','live','weather','forecast','score','result',
      'rate','price','usd','pkr','news','update','schedule','fixture'
    ].any(lower.contains);

    if (looksRealtime) {
      _setThinking(true);
      try {
        // 1) Get synthesized answer (SERP → rank → Gemini one-liner)
        final answer = await aiService.getLiveAnswerSynth(text);

        // 2) Show full formatted text (timestamp + one-line synthesis + sources) in UI,
        //    but DON'T speak this big block to avoid long TTS.
        await _addAiMessage(answer.plainText, speak: false);

        // 3) Speak only the concise synthesized line (after the "As of ..." line)
        final lines = answer.plainText.split('\n');
        final idx = lines.indexWhere((l) => l.startsWith('As of '));
        String synthForSpeech;
        if (idx != -1 && idx + 1 < lines.length) {
          // next non-empty line after As of
          synthForSpeech = (lines
                  .skip(idx + 1)
                  .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''))
              .trim();
        } else {
          synthForSpeech = lines
              .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
              .trim();
        }
        if (synthForSpeech.isNotEmpty) {
          await _speak('Here is the latest. $synthForSpeech');
        }

        // 4) (Optional) Also add a separate Sources-only message with tappable links
        // if (answer.items.isNotEmpty) {
        //   final buf = StringBuffer('Sources:\n');
        //   for (final it in answer.items) {
        //     buf.writeln('• ${it.title} (${it.domain})\n${it.url}');
        //   }
        //   await _addAiMessage(buf.toString(), speak: false);
        // }
      } catch (e) {
        await _addAiMessage("Couldn't fetch live info ($e).", speak: false);
      } finally {
        _setThinking(false);
      }
      return; // don't fall through to Gemini path
    }
    // ---------- End realtime block ----------

    // Model-driven flow (your existing Gemini path)
    _setThinking(true);
    try {
      final reply = await aiService.processUserQuery(text);
      await _addAiMessage(reply);
    } catch (e) {
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
    }
  }

  /// Sends a text prompt along with an image to the AI for analysis.
  ///
  /// [prompt] The text prompt to accompany the image.
  /// [imageBytes] The image data in bytes.
  Future<void> sendTextWithImageToGemini(String prompt, Uint8List imageBytes) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _setThinking(true);

    // show prompt + image in UI
    final promptMsg = ChatMessage(isUser: true, message: prompt);
    final imageMsg = ChatMessage(isUser: false, imageBytes: imageBytes);
    _messages.addAll([promptMsg, imageMsg]);
    notifyListeners();

    await _appendToFirestore(text: prompt, sender: 'user');

    try {
      final result = await aiService.sendTextWithImageToGemini(prompt, imageBytes);
      await _addAiMessage(result);
    } catch (e) {
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
    }
  }

  /// Captures an image from the ESP32 camera and displays it in the chat.
  Future<void> takePicture() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final capturingMsg = ChatMessage(isUser: false, message: 'Capturing image...');
    _messages.add(capturingMsg);
    notifyListeners();
    await _speak(capturingMsg.message!);

    _setThinking(true);

    try {
      final image = await aiService.captureImageFromESP32();
      if (image != null) {
        final imageMsg = ChatMessage(isUser: false, imageBytes: image);
        _messages.add(imageMsg);
      } else {
        await _addAiMessage('Failed to capture image from ESP32.', speak: true);
      }
    } catch (e) {
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
      notifyListeners();
    }
  }

  /// Captures an image from the ESP32 and sends it to the AI with a prompt for analysis.
  ///
  /// [prompt] The analysis prompt to send with the captured image.
  Future<void> analyzeImageWithPrompt(String prompt) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final analyzingMsg = ChatMessage(isUser: false, message: 'Analyzing image...');
    _messages.add(analyzingMsg);
    notifyListeners();
    await _speak(analyzingMsg.message!);

    _setThinking(true);

    try {
      final image = await aiService.captureImageFromESP32();
      if (image != null) {
        final result = await aiService.sendTextWithImageToGemini(prompt, image);
        final imageMsg = ChatMessage(isUser: false, imageBytes: image);
        _messages.add(imageMsg);
        await _addAiMessage(result);
      } else {
        await _addAiMessage('Failed to capture image for analysis.', speak: true);
      }
    } catch (e) {
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
      notifyListeners();
    }
  }

  /// Clears the chat messages from the local UI.
  ///
  /// This does not affect the chat history stored in Firestore.
  Future<void> clearChat() async {
    _messages.clear();
    notifyListeners();
  }

  /// Clears the entire chat history from both Firestore and the local UI.
  Future<void> clearChatHistoryFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatHistory');

    final snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    _messages.clear();
    _hasLoadedHistory = false;
    notifyListeners();
  }
}
