import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/ai_services.dart';
import '../models/chat_message.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ChatProvider with ChangeNotifier {
  final AiService aiService;
  final List<ChatMessage> _messages = [];
  final FlutterTts _tts = FlutterTts();
  bool _isThinking = false;
  bool _hasLoadedHistory = false;

  List<ChatMessage> get messages => _messages;
  bool get isThinking => _isThinking;

  ChatProvider({required this.aiService});

  void _setThinking(bool value) {
    _isThinking = value;
    notifyListeners();
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.9);
    await _tts.speak(text);
  }

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

  Future<void> _addAiMessage(String text, {bool speak = true}) async {
    final replyMsg = ChatMessage(isUser: false, message: text);
    _messages.add(replyMsg);
    notifyListeners();
    if (speak) await _speak(text);
    await _appendToFirestore(text: text, sender: 'ai');
  }

  /// Load chat history from Firestore
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

  /// Send plain text message (routes through the model → text or image)
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

  /// Send image + prompt (kept for your explicit image flow)
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

  /// ESP32 image capture (kept for your explicit capture command)
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

  /// Analyze ESP32 image with prompt (kept for your explicit analyze command)
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

  /// Clear only local chat (UI)
  Future<void> clearChat() async {
    _messages.clear();
    notifyListeners();
  }

  /// Clear chat history from Firestore and UI
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
