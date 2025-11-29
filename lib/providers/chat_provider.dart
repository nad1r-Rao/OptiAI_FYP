import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Added import
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/ai_services.dart';
import 'memory_provider.dart';

class ChatProvider extends ChangeNotifier {
  final AiService aiService;
  final MemoryProvider memoryProvider;
  final FlutterTts _flutterTts = FlutterTts();

  final List<ChatMessage> _messages = [];
  bool _isThinking = false;
  bool _hasLoadedHistory = false;

  List<ChatMessage> get messages => _messages;
  bool get isThinking => _isThinking;

  final List<Conversation> _conversations = [];
  String? _currentConversationId;

  List<Conversation> get conversations => _conversations;
  String? get currentConversationId => _currentConversationId;

  ChatProvider({
    required this.aiService,
    required this.memoryProvider,
  }) {
    _initTts();
    memoryProvider.loadMemories();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _setThinking(bool value) {
    _isThinking = value;
    notifyListeners();
  }

  Future<void> _speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _appendToFirestore({
    required String text,
    required String sender, // 'user' | 'ai'
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // 1. Create conversation if not exists
    if (_currentConversationId == null) {
      final ref = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('conversations')
          .add({
        'title': text, // Use first message as title initially
        'lastMessage': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _currentConversationId = ref.id;
    } else {
      // Update existing conversation preview
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('conversations')
          .doc(_currentConversationId)
          .update({
        'lastMessage': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 2. Add message to subcollection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .doc(_currentConversationId)
        .collection('messages')
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

  // Public method to add system/status messages
  void addMessage({required String message, required bool isUser}) {
    _messages.add(ChatMessage(isUser: isUser, message: message));
    notifyListeners();
    if (!isUser) {
       _speak(message);
    }
  }

  // Start a fresh session
  void startNewChat() {
    _messages.clear();
    _currentConversationId = null;
    notifyListeners();
  }

  // Alias for clearChat to satisfy existing calls
  void clearChat() {
    startNewChat();
  }

  // Load list of conversations
  Future<void> loadConversations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .orderBy('timestamp', descending: true)
        .get();

    _conversations.clear();
    for (var doc in snapshot.docs) {
      _conversations.add(Conversation.fromMap(doc.id, doc.data()));
    }
    notifyListeners();
  }

  // Load a specific chat session
  Future<void> loadChat(String conversationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _currentConversationId = conversationId;
    _messages.clear(); // Clear current view first
    notifyListeners();

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      _messages.add(ChatMessage(
        message: data['text'],
        isUser: data['sender'] == 'user',
        imageBytes: null, // Images not stored in FS yet for simplicity
      ));
    }
    notifyListeners();
  }

  Future<void> deleteConversation(String conversationId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .doc(conversationId)
        .delete();

    _conversations.removeWhere((c) => c.id == conversationId);
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
      _messages.clear();
    }
    notifyListeners();
  }

  Future<void> clearAllConversations() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('conversations')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    _conversations.clear();
    _messages.clear();
    _currentConversationId = null;
    notifyListeners();
  }

  /// Load chat history from Firestore (Legacy method kept for compatibility if needed, but updated to use loadConversations logic or just ignored)
  Future<void> loadChatHistory({bool show = true, bool force = false}) async {
    // For now, we'll just load conversations instead of the old flat history
    await loadConversations();
  }
  
  Future<void> clearChatHistoryFromFirestore() async {
      await clearAllConversations();
  }

  /// Send plain text message (routes through the model → text or image)
  Future<void> sendText(String text) async {

    if (text.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {

      return;
    }

    // Show user message
    final userMsg = ChatMessage(isUser: true, message: text);
    _messages.add(userMsg);
    notifyListeners();
    await _appendToFirestore(text: text, sender: 'user');

    // Model-driven flow
    _setThinking(true);
    try {
      // 1. Local Model Classification (The "First Pass")
      String? localPrediction;
      try {
        localPrediction = await aiService.classify(text); 
      } catch (e) {
        // Ignore local model errors
      }

      // 2. Gemini Router (The "Brain") - with local context
      final queryType = await aiService.routeQuery(text, localContext: localPrediction);

      if (queryType == QueryType.realtime) {
        // --- REALTIME FLOW ---
        try {
          final answer = await aiService.getLiveAnswerSynth(text);
          await _addAiMessage(answer.plainText, speak: false);

          // Speak only the concise synthesized line
          final lines = answer.plainText.split('\n');
          final idx = lines.indexWhere((l) => l.startsWith('As of '));
          String synthForSpeech;
          if (idx != -1 && idx + 1 < lines.length) {
            synthForSpeech = (lines
                    .skip(idx + 1)
                    .firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''))
                .trim();
          } else {
            synthForSpeech = lines
                .firstWhere((l) => l.trim().isNotEmpty, orElse: () => '')
                .trim();
  Future<void> sendTextWithImageToGemini(String text, Uint8List imageBytes) async {
    final userMsg = ChatMessage(isUser: true, message: text, imageBytes: imageBytes);
    _messages.add(userMsg);
    notifyListeners();
    await _appendToFirestore(text: text, sender: 'user'); // Note: not saving image to FS yet

    _setThinking(true);
    try {
      final reply = await aiService.sendTextWithImageToGemini(text, imageBytes);
      await _addAiMessage(reply);
    } catch (e) {
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
    }
  }
}
