import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'gemini_fix.dart';
import 'retrieval/live_retrieval.dart';
import 'retrieval/serp_client.dart'; 

class LiveAnswerItem {
  final String title;
  final String url;
  final String domain;
  final DateTime? date;

  LiveAnswerItem({
    required this.title,
    required this.url,
    required this.domain,
    required this.date,
  });
}

class LiveAnswer {
  final String query;
  final String asOf;
  final String plainText;
  final List<LiveAnswerItem> items;
  final List<SerpResult> searchContext;

  LiveAnswer({
    required this.query,
    required this.asOf,
    required this.plainText,
    required this.items,
    this.searchContext = const [],
  });
}

extension _Fmt on DateTime? {
  String fmt() {
    final d = this;
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

enum QueryType {
  image,
  realtime,
  text,
  memory_store,
  calendar_read,
  calendar_write,
  calendar_delete,
  phone_call,
  whatsapp_msg,
}

class AiService {
  final String geminiApiKey;
  final String esp32Url;
  final String modelApiUrl;

  late final GeminiQuickFix _model;
  late final GeminiQuickFix _visionModel;
  late final GeminiQuickFix _routerModel;

  AiService({
    required this.geminiApiKey,
    required this.esp32Url,
    required this.modelApiUrl,
  }) {
    _model = GeminiQuickFix(
      model: 'gemini-2.5-flash-lite',
      apiKey: geminiApiKey,
    );
    _visionModel = GeminiQuickFix(
      model: 'gemini-2.5-flash-lite',
      apiKey: geminiApiKey,
    );
    _routerModel = GeminiQuickFix(
      model: 'gemini-2.5-flash-lite',
      apiKey: geminiApiKey,
      temperature: 0.0,
      maxOutputTokens: 10,
    );
  }

  // --- ROUTER ---
  Future<QueryType> routeQuery(String query, {String? localContext}) async {
    String prompt = """
You are a router for smart glasses. Classify the user's query into one of these types:
1. IMAGE: The user wants to capture, see, look at, or analyze something visual (e.g., "What is this?", "Read this text", "Look at the view", "Take a picture", "Take a photo", "Check this out", "See this", "What do you see?", "Describe what's in front of me", "I'm seeing a beautiful scenery", "Analyze this").
2. REALTIME: The user asks for live/changing info (e.g., "Weather?", "Stock price?", "Who won the game?", "Current time").
3. MEMORY_STORE: The user explicitly asks you to remember a fact (e.g., "Remember that my keys are in the bowl", "Note that I like sushi").
4. CALENDAR_READ: The user asks about their schedule (e.g., "What is my schedule?", "When is my next meeting?", "Do I have any events today?").
5. CALENDAR_WRITE: The user wants to create/schedule a NEW event (e.g., "Schedule a meeting with Bob", "Remind me to call mom", "Add dinner to calendar").
6. CALENDAR_DELETE: The user wants to REMOVE/CANCEL an existing event (e.g., "Delete the meeting with Bob", "Cancel my 2pm appointment", "Remove the lunch event", "Delete dinner with Mahnoor").
7. PHONE_CALL: The user wants to make a phone call (e.g., "Call John", "Dial Mom", "Phone Alice").
8. WHATSAPP_MSG: The user wants to send a WhatsApp message (e.g., "Send hi to John on WhatsApp", "WhatsApp Mom saying I'll be late", "Message Ali on WhatsApp").
9. TEXT: General chat, knowledge, or logic (e.g., "Tell me a joke", "Summarize this", "Who is Einstein?").

Query: "$query"
""";

    if (localContext != null && localContext.isNotEmpty) {
      prompt += "\nLocal Model Prediction: $localContext\n(Use this prediction to help you decide, but trust your own judgment if it seems wrong.)\n";
    }

    prompt += '\nReply ONLY with one word: IMAGE, REALTIME, MEMORY_STORE, CALENDAR_READ, CALENDAR_WRITE, CALENDAR_DELETE, PHONE_CALL, WHATSAPP_MSG, or TEXT.';

    debugPrint('ROUTER: Classifying query: "$query"');
    
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final content = [Content.text(prompt)];
        final response = await _routerModel.generateContent(content);
        final text = response.text?.trim().toUpperCase() ?? 'TEXT';
        debugPrint('ROUTER: Query="$query" → Response="$text"');

        if (text.contains('IMAGE')) return QueryType.image;
        if (text.contains('REALTIME')) return QueryType.realtime;
        if (text.contains('MEMORY')) return QueryType.memory_store;
        if (text.contains('CALENDAR_READ')) return QueryType.calendar_read;
        if (text.contains('CALENDAR_WRITE')) return QueryType.calendar_write;
        if (text.contains('CALENDAR_DELETE')) return QueryType.calendar_delete;
        if (text.contains('PHONE_CALL')) return QueryType.phone_call;
        if (text.contains('WHATSAPP')) return QueryType.whatsapp_msg;
        
        return QueryType.text;
      } catch (e) {
        debugPrint('ROUTER ERROR (attempt ${attempt + 1}): $e');
        if (attempt == 2) {
          debugPrint('ROUTER: All attempts failed, falling back to TEXT');
        }
      }
    }
    return QueryType.text; // Fallback after retries
  }

  // --- CALENDAR EXTRACTION ---
  Future<Map<String, dynamic>> extractCalendarEvent(String text) async {
    final now = DateTime.now();
    final prompt = """
Extract event details from this text.
Current Time: $now
User: "$text"

Return JSON with:
- title: String
- startTime: ISO8601 String (approximate if needed)
- endTime: ISO8601 String (default to 1 hour after start if not specified)
- description: String (optional)

Example JSON:
{"title": "Meeting with Bob", "startTime": "2024-12-02T14:00:00", "endTime": "2024-12-02T15:00:00", "description": ""}
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      return jsonDecode(jsonStr);
    } catch (e) {
      return {};
    }
  }

  Future<String> extractCalendarDeletion(String text) async {
    final prompt = """
Extract the title of the event the user wants to delete.
User: "$text"

Return ONLY the title string. Do not include "delete" or "cancel" in the title unless it's part of the event name.
If the user says "Delete the meeting with Bob", return "Meeting with Bob".
If the user says "Cancel dinner", return "Dinner".
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text?.trim() ?? text;
    } catch (e) {
      return text;
    }
  }

  Future<String> extractContactName(String text) async {
    final prompt = """
Extract the name of the person the user wants to call.
User: "$text"

Return ONLY the name.
If the user says "Call John", return "John".
If the user says "Call Mom", return "Mom".
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text?.trim() ?? "";
    } catch (e) {
      return "";
    }
  }
  
//--- WHATSAPP MESSAGE EXTRACTION ---

  Future<Map<String, String>> extractWhatsAppDetails(String text) async {
    final prompt = """
Extract the contact name and message from this WhatsApp request.
User: "$text"

Return JSON with:
- contactName: The name of the person to message
- message: The message to send

Examples:
- "Send hi to John on WhatsApp" → {"contactName": "John", "message": "hi"}
- "WhatsApp Mom saying I'll be late" → {"contactName": "Mom", "message": "I'll be late"}
- "Message Ali on WhatsApp hello" → {"contactName": "Ali", "message": "hello"}

Return ONLY valid JSON, no explanation.
""";

    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final jsonStr = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '{}';
      final Map<String, dynamic> parsed = jsonDecode(jsonStr);
      return {
        'contactName': parsed['contactName']?.toString() ?? '',
        'message': parsed['message']?.toString() ?? '',
      };
    } catch (e) {
      debugPrint('extractWhatsAppDetails error: $e');
      return {'contactName': '', 'message': ''};
    }
  }

  // --- LOCAL MODEL CLASSIFICATION ---
  Future<String?> classify(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$modelApiUrl/predict'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': text}),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (e) {
      // Ignore local model errors
    }
    return null;
  }

  // --- MEMORY EXTRACTION ---
  Future<String> extractFact(String text) async {
    final prompt = """
Extract the core fact from this user statement.
User: "$text"
Fact (concise, 3rd person if about user):
""";
    
    try {
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      return response.text?.trim() ?? text;
    } catch (e) {
      return text; // Fallback to raw text
    }
  }

  // --- TEXT ---
  Future<String> sendTextToGemini(String text, {
    List<String> memories = const [],
    List<Content> chatHistory = const [],
    String personality = 'Friendly',
  }) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        String systemContext = "You are OptiAI, a helpful assistant inside smart glasses. "
            "Your personality is $personality. "
            "Keep your answers VERY concise (1-2 sentences max). "
            "Do NOT use markdown, asterisks, or special formatting. Just plain text. "
            "Be helpful, friendly, and direct.\n\n";
            
        if (memories.isNotEmpty) {
          systemContext += "You have the following memories about the user:\n";
          for (var m in memories) {
            systemContext += "- $m\n";
          }
          systemContext += "Use these memories to personalize your answer if relevant.\n\n";
        }

        // Start a chat session with history
        final chat = _model.startChat(history: [
          Content.text(systemContext), // System instruction as first message
          ...chatHistory,
        ]);

        final response = await chat.sendMessage(Content.text(text));
        return response.text ?? "No response from AI";
      }catch (e) {
        return "Error connecting to Gemini: $e";
      }
    }
    return "I'm overloaded right now. Please try again later.";
  }

  // --- VISION ---
  Future<String> sendTextWithImageToGemini(String text, Uint8List imageBytes) async {
    try {
      final content = [
        Content.multi([
          TextPart(text),
          DataPart('image/jpeg', imageBytes),
        ])
      ];
      final response = await _visionModel.generateContent(content);
      return response.text ?? "I couldn't analyze the image.";
    } catch (e) {
      return "Error analyzing image: $e";
    }
  }

  // --- ESP32 ---
  // ESP32 configuration constants
  static const int _esp32TimeoutSeconds = 10;  // Increased from 5s for slow ESP32 responses
  static const int _esp32MaxRetries = 3;       // Retry attempts for unreliable connections
  static const int _esp32RetryDelayMs = 500;   // Delay between retries (increases exponentially)

  Future<Uint8List?> captureImageFromESP32() async {
    for (int attempt = 1; attempt <= _esp32MaxRetries; attempt++) {
      try {
        final response = await http.get(
          Uri.parse(esp32Url),
          headers: {
            'Connection': 'close',        // Free ESP32 memory immediately after sending
            'Cache-Control': 'no-cache',  // Always get fresh image
          },
        ).timeout(Duration(seconds: _esp32TimeoutSeconds));
        
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
        
        // Log non-200 responses for debugging
        debugPrint('ESP32 capture attempt $attempt: HTTP ${response.statusCode}');
        
      } on TimeoutException {
        debugPrint('ESP32 capture attempt $attempt: Timeout after ${_esp32TimeoutSeconds}s');
      } on http.ClientException catch (e) {
        debugPrint('ESP32 capture attempt $attempt: Network error - $e');
      } catch (e) {
        debugPrint('ESP32 capture attempt $attempt: Error - $e');
      }
      
      // Wait before retry (exponential backoff: 500ms, 1000ms, 2000ms)
      if (attempt < _esp32MaxRetries) {
        await Future.delayed(Duration(milliseconds: _esp32RetryDelayMs * attempt));
      }
    }
    
    debugPrint('ESP32 capture failed after $_esp32MaxRetries attempts');
    return null;
  }

  Future<bool> checkEsp32Connection() async {
    try {
      // Parse the original URL (e.g., http://192.168.1.5/capture)
      final originalUri = Uri.parse(esp32Url);
      
      // Create a lightweight "ping" URL using just the root path
      final statusUri = originalUri.replace(path: '/');
      
      // Use HEAD request - asks "are you there?" without downloading the body
      // This prevents triggering full camera capture and is much lighter
      final resp = await http.head(
        statusUri,
        headers: {'Connection': 'close'},  // Free socket immediately
      ).timeout(const Duration(seconds: 5)); // 5s is enough for a simple ping
      
      return resp.statusCode == 200;
    } on TimeoutException {
      debugPrint('ESP32 connection check: Timeout');
      return false;
    } on http.ClientException catch (e) {
      debugPrint('ESP32 connection check: Network error - $e');
      return false;
    } catch (e) {
      debugPrint('ESP32 connection check: Error - $e');
      return false;
    }
  }

  // --- REALTIME ---
  Future<LiveAnswer> getLiveAnswerSynth(String query) async {
    final lr = LiveRetrieval();
    final res = await lr.search(query, topN: 3);

    if (res.results.isEmpty) {
      return LiveAnswer(
        query: res.query,
        asOf: res.asOfLabel(),
        plainText: '${res.asOfLabel()}\nSorry, I couldn’t find reliable live info for that.',
        items: const [],
      );
    }

    final String sourcesBlock = [
      for (var i = 0; i < res.results.length; i++)
        '${i + 1}) ${res.results[i].domain} — ${res.results[i].title}\n'
            'Snippet: ${res.results[i].snippet}\n'
            'URL: ${res.results[i].url}\n'
            'DateSeen: ${res.results[i].date.fmt()}'
    ].join('\n\n');

    final prompt = '''
You are OptiAI's live synthesis. Answer ONLY using the SOURCES below.
If numbers disagree, briefly mention that and prefer the most recent/trustworthy source.
Be concise (1–2 sentences), no markdown, no bullets, no URLs in the sentence.
Do NOT invent data—if uncertain, say "ranges vary by source".

QUERY: $query
TIME: ${res.asOfLabel()}

SOURCES:
$sourcesBlock

Now produce ONE concise answer in plain text.
''';

    final synthesized = await sendTextToGemini(prompt);

    final items = res.results
        .map((r) => LiveAnswerItem(
              title: r.title,
              url: r.url,
              domain: r.domain,
              date: r.date,
            ))
        .toList();

    final plainText = StringBuffer()
      ..writeln(res.asOfLabel())
      ..writeln(synthesized.trim())
      ..writeln()
      ..writeln('Sources:')
      ..writeln(items
          .map((it) => '• ${it.title} (${it.domain})\n${it.url}')
          .join('\n\n'));

    return LiveAnswer(
      query: res.query,
      asOf: res.asOfLabel(),
      plainText: plainText.toString().trim(),
      items: items,
      searchContext: res.results,
    );
  }
}
