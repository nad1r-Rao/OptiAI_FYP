import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../services/ai_services.dart';
import '../services/calendar_service.dart';
import '../services/contact_service.dart';
import 'memory_provider.dart';

class ChatProvider extends ChangeNotifier {
  final AiService aiService;
  final MemoryProvider memoryProvider;
  final CalendarService calendarService;
  final ContactService contactService = ContactService();
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
    required this.calendarService,
  }) {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> setVoiceSpeed(double speed) async {
    await _flutterTts.setSpeechRate(speed);
    notifyListeners();
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

  Future<void> loadChatHistory({bool show = true, bool force = false}) async {
    await loadConversations();
  }

  Future<void> clearChatHistoryFromFirestore() async {
    await clearAllConversations();
  }

  /// Send plain text message (routes through the model → text or image)
  Future<void> sendText(String text) async {
    print("DEBUG: sendText called with: $text");
    if (text.trim().isEmpty) {
      print("DEBUG: Text is empty");
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    print("DEBUG: Current UID: $uid");
    if (uid == null) {
      print("DEBUG: User not logged in!");
      return;
    }

    // Load settings
    final prefs = await SharedPreferences.getInstance();
    final autoCapture = prefs.getBool('auto_capture') ?? true;
    final personality = prefs.getString('ai_personality') ?? 'Friendly';
    print("DEBUG: Settings loaded. AutoCapture: $autoCapture, Personality: $personality");

    // Show user message
    final userMsg = ChatMessage(isUser: true, message: text);
    _messages.add(userMsg);
    notifyListeners();
    print("DEBUG: User message added to local state");
    
    try {
      await _appendToFirestore(text: text, sender: 'user');
      print("DEBUG: User message saved to Firestore");
    } catch (e) {
      print("DEBUG: Failed to save to Firestore: $e");
    }

    // Model-driven flow
    _setThinking(true);
    print("DEBUG: Thinking state set to true");
    try {
      // 1. Local Model Classification
      String? localPrediction;
      try {
        print("DEBUG: Calling aiService.classify");
        localPrediction = await aiService.classify(text);
        print("DEBUG: Local prediction: $localPrediction");
      } catch (e) {
        print("DEBUG: Local classify failed: $e");
        // Ignore local model errors
      }

      // 2. Gemini Router
      print("DEBUG: Calling aiService.routeQuery");
      final queryType =
          await aiService.routeQuery(text, localContext: localPrediction);
      print("DEBUG: Query routed to: $queryType");

      if (queryType == QueryType.realtime) {
        // --- REALTIME FLOW ---
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
        }
        await _speak(synthForSpeech);

      } else if (queryType == QueryType.image) {
        // --- VISUAL FLOW (Auto-Capture) ---
        if (!autoCapture) {
          // Fallback to text if auto-capture is disabled
          final response = await aiService.sendTextToGemini(
              text, memories: memoryProvider.memories, personality: personality);
          await _addAiMessage(response);
        } else {
          await _addAiMessage("Capturing image...", speak: false);
          
          final imageBytes = await aiService.captureImageFromESP32();
          
          if (imageBytes != null) {
            _messages.add(ChatMessage(
              isUser: true, 
              message: "Captured Image", 
              imageBytes: imageBytes
            ));
            notifyListeners();

            final reply = await aiService.sendTextWithImageToGemini(text, imageBytes);
            await _addAiMessage(reply);
          } else {
            await _addAiMessage(
              "I couldn't connect to the camera. Please check the connection.",
              speak: true
            );
          }
        }

      } else if (queryType == QueryType.memory_store) {
        // --- MEMORY FLOW ---
        final fact = await aiService.extractFact(text);
        await memoryProvider.addMemory(fact);
        await _addAiMessage("I'll remember that.");

      } else if (queryType == QueryType.calendar_read) {
        // --- CALENDAR READ FLOW ---
        await _addAiMessage("Checking your calendar...", speak: false);
        final events = await calendarService.getEventsForDay(DateTime.now());
        
        if (events.isEmpty) {
          await _addAiMessage("You have no events scheduled for today.");
        } else {
          String eventSummary = "Here are your events for today:\n";
          for (var e in events) {
            eventSummary += "- ${e.title} at ${e.start}\n";
          }
          // Ask AI to summarize nicely
          final summary = await aiService.sendTextToGemini(
            "Summarize these calendar events for the user naturally: $eventSummary",
            personality: personality
          );
          await _addAiMessage(summary);
        }

      } else if (queryType == QueryType.calendar_write) {
        // --- CALENDAR WRITE FLOW ---
        await _addAiMessage("Scheduling that for you...", speak: false);
        final details = await aiService.extractCalendarEvent(text);
        
        if (details.isNotEmpty && details.containsKey('title') && details.containsKey('startTime')) {
          final title = details['title'];
          final start = DateTime.parse(details['startTime']);
          final end = details.containsKey('endTime') 
              ? DateTime.parse(details['endTime']) 
              : start.add(const Duration(hours: 1));
          final desc = details['description'];

          final result = await calendarService.createEvent(
            title: title,
            startTime: start,
            endTime: end,
            description: desc,
          );
          await _addAiMessage(result);
        } else {
          await _addAiMessage("I couldn't understand the event details. Please try again.");
        }

      } else if (queryType == QueryType.calendar_delete) {
        // --- CALENDAR DELETE FLOW ---
        await _addAiMessage("Searching for that event...", speak: false);
        
        // Use AI to extract the title cleanly
        String targetTitle = await aiService.extractCalendarDeletion(text);
        
        print("DEBUG: Target title for deletion (AI extracted): '$targetTitle'");
            
        if (targetTitle.isEmpty) {
           await _addAiMessage("I'm not sure which event to delete. Please specify the title.");
        } else {
           final result = await calendarService.deleteEvent(targetTitle);
           print("DEBUG: Delete result: $result");
           await _addAiMessage(result);
           
           // Fallback: If not found, explain why
           if (result.startsWith("Could not find")) {
             final explanation = await aiService.sendTextToGemini(
               "The user asked to delete '$text', but I couldn't find an event matching '$targetTitle'. Explain this briefly and ask for the exact title.",
               personality: personality
             );
             await _addAiMessage(explanation);
           }
        }

      } else if (queryType == QueryType.phone_call) {
        // --- PHONE CALL FLOW ---
        await _addAiMessage("Looking up contact...", speak: false);
        
        final name = await aiService.extractContactName(text);
        if (name.isEmpty) {
          await _addAiMessage("Who would you like to call?");
        } else {
          final result = await contactService.findAndCallContact(name);
          await _addAiMessage(result);
        }

      } else {
        // --- GENERAL CHAT FLOW ---
        print("DEBUG: General chat flow");
        final response = await aiService.sendTextToGemini(
            text, memories: memoryProvider.memories, personality: personality);
        print("DEBUG: Gemini response: $response");
        await _addAiMessage(response);
      }

    } catch (e, stack) {
      print("DEBUG: Error in sendText: $e");
      print("DEBUG: Stack trace: $stack");
      await _addAiMessage('Error: $e', speak: false);
    } finally {
      _setThinking(false);
      print("DEBUG: Thinking state set to false");
    }
  }

  /// Send Image + Text to Gemini
  Future<void> sendTextWithImageToGemini(
      String text, Uint8List imageBytes) async {
    final userMsg =
        ChatMessage(isUser: true, message: text, imageBytes: imageBytes);
    _messages.add(userMsg);
    notifyListeners();
    await _appendToFirestore(
        text: text, sender: 'user'); // Note: not saving image to FS yet

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