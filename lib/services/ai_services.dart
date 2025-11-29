import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
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
  final List<SerpResult> searchContext; // Changed SearchResult to SerpResult

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
}

class AiService {
  final String geminiApiKey;
  final String esp32Url;
  final String modelApiUrl;

  late final GenerativeModel _model;
  late final GenerativeModel _visionModel;
  late final GenerativeModel _routerModel;

  AiService({
    required this.geminiApiKey,
    required this.esp32Url,
    required this.modelApiUrl,
  }) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash', // User requested newer model
      apiKey: geminiApiKey,
    );
    _visionModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: geminiApiKey,
    );
    _routerModel = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.0,
        maxOutputTokens: 10,
      ),
    );
  }

  // --- ROUTER ---
  Future<QueryType> routeQuery(String query, {String? localContext}) async {
    String prompt = """
You are a router for smart glasses. Classify the user's query into one of these types:
1. IMAGE: The user wants to capture/analyze an image (e.g., "What is this?", "Read this text", "Look at the view").
2. REALTIME: The user asks for live/changing info (e.g., "Weather?", "Stock price?", "Who won the game?", "Current time").
3. MEMORY_STORE: The user explicitly asks you to remember a fact (e.g., "Remember that my keys are in the bowl", "Note that I like sushi").
4. TEXT: General chat, knowledge, or logic (e.g., "Tell me a joke", "Summarize this", "Who is Einstein?").

Query: "$query"
""";

    if (localContext != null && localContext.isNotEmpty) {
      prompt += "\nLocal Model Prediction: $localContext\n(Use this prediction to help you decide, but trust your own judgment if it seems wrong.)\n";
    }

    prompt += '\nReply ONLY with one word: IMAGE, REALTIME, MEMORY_STORE, or TEXT.';

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final content = [Content.text(prompt)];
        final response = await _routerModel.generateContent(content);
        final text = response.text?.trim().toUpperCase() ?? 'TEXT';

        if (text.contains('IMAGE')) return QueryType.image;
        if (text.contains('REALTIME')) return QueryType.realtime;
        if (text.contains('MEMORY')) return QueryType.memory_store;
        
        return QueryType.text;
      } catch (e) {
        return QueryType.text; // Fallback on non-retriable error
      }
    }
    return QueryType.text; // Fallback after retries
  }

  // --- LOCAL MODEL CLASSIFICATION ---
  Future<String?> classify(String text) async {
    try {
      final response = await http.post(
        Uri.parse('$modelApiUrl/predict'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': text}), // Changed 'text' to 'query'
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        // Return the raw body so the LLM can see prob/trigger/ver
        return response.body;
      }
    } catch (e) {
      // Ignore local model errors
    }
    return null;
  }

  // --- TEXT ---
  Future<String> sendTextToGemini(String text, {
    List<String> memories = const [],
    List<Content> chatHistory = const [],
  }) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        String systemContext = "You are OptiAI, a helpful assistant inside smart glasses. "
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
  Future<Uint8List?> captureImageFromESP32() async {
    try {
      final response = await http.get(Uri.parse(esp32Url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      // Ignore ESP32 errors
    }
    return null;
  }

  Future<bool> checkEsp32Connection() async {
    try {
      final resp = await http.get(Uri.parse(esp32Url)).timeout(const Duration(seconds: 5));
      return resp.statusCode == 200;
    } catch (_) {
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
