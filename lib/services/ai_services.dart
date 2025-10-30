// 📁 lib/services/ai_services.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'retrieval/live_retrieval.dart';

/// Represents a single search result item from a live retrieval.
class LiveAnswerItem {
  /// The title of the search result.
  final String title;
  /// The URL of the search result.
  final String url;
  /// The domain of the search result.
  final String domain;
  /// The date the search result was seen or published.
  final DateTime? date;

  /// Creates a [LiveAnswerItem].
  LiveAnswerItem({
    required this.title,
    required this.url,
    required this.domain,
    required this.date,
  });
}

/// Represents the complete answer from a live retrieval, including synthesized text and sources.
class LiveAnswer {
  /// The original query that was sent.
  final String query;
  /// A timestamp label for when the information was retrieved.
  final String asOf;           // e.g., "As of 27 Sep 2025, 11:35 PKT"
  /// The formatted plain text response, suitable for display or text-to-speech.
  final String plainText;      // formatted for UI/TTS
  /// A list of [LiveAnswerItem]s that were used as sources.
  final List<LiveAnswerItem> items;

  /// Creates a [LiveAnswer].
  LiveAnswer({
    required this.query,
    required this.asOf,
    required this.plainText,
    required this.items,
  });
}

/// An extension on nullable [DateTime] to format it as a string.
extension _Fmt on DateTime? {
  /// Formats the [DateTime] as `YYYY-MM-DD HH:MM`. Returns an empty string if null.
  String fmt() {
    final d = this;
    if (d == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}

/// A service class for handling all AI-related functionalities.
///
/// This includes communicating with the Gemini API for text and image analysis,
/// capturing images from an ESP32 camera, classifying user queries, and
/// performing live information retrieval from the web.
class AiService {
  /// Sends a text-only query to the Gemini API.
  Future<String> sendTextToGemini(String query) => _sendTextToGemini(query);
  /// Sends a text query and an image to the Gemini API.
  Future<String> sendTextWithImageToGemini(String q, Uint8List img) =>
      _sendTextWithImageToGemini(q, img);
  /// Captures an image from the configured ESP32 camera.
  Future<Uint8List?> captureImageFromESP32() => _captureImageFromESP32();

  /// The API key for the Gemini service.
  final String geminiApiKey;
  /// The URL for the ESP32 camera's capture endpoint.
  final String esp32Url; // e.g., http://192.168.4.1/capture
  /// The URL for the custom model API used for query classification.
  final String modelApiUrl; // e.g., https://api.example.com

  /// Creates an instance of [AiService].
  AiService({
    required this.geminiApiKey,
    required this.esp32Url,
    required this.modelApiUrl,
    
  });

  // ---- Types ----
  static const _timeout = Duration(seconds: 10);

  // =========================
  // 1) GEMINI HELPERS (updated)
  // =========================

  // Try both API versions (some projects/keys are provisioned on v1, others on v1beta)
  static const List<String> _geminiBases = [
    'https://generativelanguage.googleapis.com/v1/models',
    'https://generativelanguage.googleapis.com/v1beta/models',
  ];

  // Try these model IDs in order; different projects expose different aliases
  static const List<String> _textModels = [
    // v1 (available for your key)
  'gemini-2.5-flash',
  'gemini-2.5-pro',
  'gemini-2.0-flash',
  'gemini-2.0-flash-001',
  'gemini-2.5-flash-lite',

  // v1beta fallbacks (also visible for your key)
  'gemini-2.5-flash-preview-05-20',
  'gemini-2.5-flash-lite-preview-06-17',
  'gemini-2.5-pro-preview-06-05',
  'gemini-2.5-pro-preview-05-06',
  'gemini-2.5-pro-preview-03-25',

  ];

  static Uri _geminiUri(String base, String model) =>
      Uri.parse('$base/$model:generateContent');

  static bool _isNotFound(http.Response r) =>
      r.statusCode == 404 && r.body.contains('NOT_FOUND');

  // =========================

  /// Classifies a user's query to determine if it requires an image.
  ///
  /// This method sends the query to a custom model API. The model returns a
  /// probability, a boolean trigger indicating if an image is needed, and the
  /// model version.
  ///
  /// [query] The user's text query.
  ///
  /// Returns a record containing the probability, trigger status, and version.
  Future<({double prob, bool trigger, String version})> classify(
      String query) async {
    final uri = Uri.parse('$modelApiUrl/predict');
    final resp = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'query': query}),
        )
        .timeout(_timeout);

    if (resp.statusCode != 200) {
      throw Exception('Model API ${resp.statusCode}: ${resp.body}');
    }
    final m = jsonDecode(resp.body) as Map<String, dynamic>;
    final prob = (m['prob'] as num?)?.toDouble();
    final trigger = m['trigger'] as bool?;
    final version = (m['version'] as String?) ?? 'unknown';

    if (prob == null || trigger == null) {
      throw Exception('Model API: missing fields in response');
    }
    return (prob: prob, trigger: trigger, version: version);
  }

  /// Processes a user's query by first classifying it and then responding accordingly.
  ///
  /// If the query is classified as not needing an image, it's sent to the
  /// Gemini text model. If it needs an image, this method attempts to capture
  /// one from the ESP32 and sends both the text and image to Gemini. It includes
  /// a graceful fallback to a text-only response if the camera is unavailable.
  ///
  /// [query] The user's text query.
  ///
  /// Returns the AI's response as a string.
  Future<String> processUserQuery(String query) async {
    try {
      final res = await classify(query);
      final needsImage = res.trigger;

      if (!needsImage) {
        return await _sendTextToGemini(query);
      }

      final img = await _captureImageFromESP32WithRetry();
      if (img == null) {
        // Graceful fallback
        return 'Camera not available right now. I can still answer as text:\n\n'
            '${await _sendTextToGemini(query)}';
      }
      return await _sendTextWithImageToGemini(query, img);
    } catch (e) {
      return 'Error: $e';
    }
  }

  // ==========================================
  // 2) _sendTextToGemini (REPLACED with retries)
  // ==========================================
  Future<String> _sendTextToGemini(String query) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': query}
          ]
        }
      ],
      'generationConfig': {'temperature': 0.4, 'topK': 32, 'topP': 0.95}
    });

    http.Response? last;
    for (final base in _geminiBases) {
      for (final model in _textModels) {
        final resp = await http
            .post(
              _geminiUri(base, model),
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': geminiApiKey,
              },
              body: body,
            )
            .timeout(_timeout);
        last = resp;

        if (resp.statusCode == 200) {
          final m = jsonDecode(resp.body) as Map<String, dynamic>;
          final candidates = (m['candidates'] as List?) ?? const [];
          if (candidates.isEmpty) return 'No response from AI';
          final text = (((candidates[0] as Map)['content'] as Map)['parts']
              as List?)?.first?['text'] as String?;
          return text ?? 'No response from AI';
        }

        if (_isNotFound(resp)) {
          // Try next model/base
          continue;
        }

        // Other errors (401/403/429/500…) – surface immediately
        throw Exception('Gemini text ${resp.statusCode}: ${resp.body}');
      }
    }
    throw Exception(
        'Gemini text 404: no compatible model found. Last: ${last?.body}');
  }

  // ======================================================
  // 3) _sendTextWithImageToGemini (REPLACED with retries)
  // ======================================================
  Future<String> _sendTextWithImageToGemini(
      String query, Uint8List imageBytes) async {
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': query},
            {
              'inlineData': {
                'mimeType': 'image/jpeg',
                'data': base64Encode(imageBytes),
              }
            }
          ]
        }
      ],
      'generationConfig': {'temperature': 0.3, 'topK': 32, 'topP': 0.95}
    });

    http.Response? last;
    for (final base in _geminiBases) {
      for (final model in _textModels) {
        final resp = await http
            .post(
              _geminiUri(base, model), // same multimodal method
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': geminiApiKey,
              },
              body: body,
            )
            .timeout(_timeout);
        last = resp;

        if (resp.statusCode == 200) {
          final m = jsonDecode(resp.body) as Map<String, dynamic>;
          final candidates = (m['candidates'] as List?) ?? const [];
          if (candidates.isEmpty) return 'No response from AI';
          final text = (((candidates[0] as Map)['content'] as Map)['parts']
              as List?)?.first?['text'] as String?;
          return text ?? 'No response from AI';
        }

        if (_isNotFound(resp)) {
          continue; // try next model/base
        }

        throw Exception('Gemini image ${resp.statusCode}: ${resp.body}');
      }
    }
    throw Exception(
        'Gemini image 404: no compatible model found. Last: ${last?.body}');
  }

  // ---------- ESP32 capture with retry ----------
  Future<Uint8List?> _captureImageFromESP32WithRetry({int attempts = 2}) async {
    for (int i = 0; i < attempts; i++) {
      final img = await _captureImageFromESP32();
      if (img != null && img.isNotEmpty) return img;
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return null;
  }

  Future<Uint8List?> _captureImageFromESP32() async {
    final url = '$esp32Url?t=${DateTime.now().millisecondsSinceEpoch}';
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode == 200) {
        return resp.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Performs a live web search and uses Gemini to synthesize an answer from the results.
  ///
  /// This method uses the [LiveRetrieval] service to search the web for a given
  /// query. It then constructs a prompt with the search results and sends it to
  /// Gemini to generate a concise, synthesized answer.
  ///
  /// [query] The user's query for the live search.
  ///
  /// Returns a [LiveAnswer] object containing the synthesized response and source links.
  Future<LiveAnswer> getLiveAnswerSynth(String query) async {
    final lr = LiveRetrieval();
    final res = await lr.search(query, topN: 3);

    if (res.results.isEmpty) {
      return LiveAnswer(
        query: res.query,
        asOf: res.asOfLabel(),
        plainText:
            '${res.asOfLabel()}\nSorry, I couldn’t find reliable live info for that.',
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

    final synthesized = await _sendTextToGemini(prompt);

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
    );
  }

  /// Performs a live web search and returns a formatted list of top sources.
  ///
  /// This method is a simpler alternative to [getLiveAnswerSynth]. It performs
  /// a web search and returns the top results as a formatted string, without
  /// synthesizing an answer.
  ///
  /// [query] The user's query for the live search.
  ///
  /// Returns a [LiveAnswer] object with the formatted list of sources.
  static Future<LiveAnswer> getLiveAnswer(String query) async {
    final lr = LiveRetrieval();
    final res = await lr.search(query, topN: 3);

    final buf = StringBuffer();
    buf.writeln(res.asOfLabel());
    if (res.results.isEmpty) {
      buf.writeln('Sorry, I couldn’t find reliable live info for that.');
    } else {
      buf.writeln('Top sources:');
      for (final r in res.results) {
        final title = _shorten(r.title, 90);
        buf.writeln('• $title (${r.domain})');
      }
    }

    final items = res.results
        .map((r) => LiveAnswerItem(
              title: r.title,
              url: r.url,
              domain: r.domain,
              date: r.date,
            ))
        .toList();

    return LiveAnswer(
      query: res.query,
      asOf: res.asOfLabel(),
      plainText: buf.toString().trim(),
      items: items,
    );
  }

  static String _shorten(String s, int max) {
    if (s.length <= max) return s;
    return '${s.substring(0, max - 1).trimRight()}…';
  }


}
