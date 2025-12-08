import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

/// A drop-in replacement for GenerativeModel that bypasses the "Unhandled format" crash
/// by using raw HTTP and ignoring unknown fields in the Gemini 2.5 response.
class GeminiQuickFix {
  final String apiKey;
  final String model;
  final double? temperature;
  final int? maxOutputTokens;

  GeminiQuickFix({
    required this.apiKey,
    required this.model,
    this.temperature,
    this.maxOutputTokens,
  });

  /// Start a chat session with optional history
  SimpleChatSession startChat({List<Content>? history}) {
    return SimpleChatSession(
      apiKey: apiKey,
      model: model,
      history: history ?? [],
      temperature: temperature,
      maxOutputTokens: maxOutputTokens,
    );
  }

  Future<SimpleResponse> generateContent(Iterable<Content> prompt) async {
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

    // Manually map the SDK Content object to JSON to avoid SDK internal checks
    final contents = prompt.map((c) => {
      'role': c.role ?? 'user',
      'parts': c.parts.map((p) => _mapPart(p)).toList()
    }).toList();

    // Build request body with optional generation config
    final body = <String, dynamic>{'contents': contents};
    if (temperature != null || maxOutputTokens != null) {
      body['generationConfig'] = {
        if (temperature != null) 'temperature': temperature,
        if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        // CRITICAL FIX: We manually extract the text and IGNORE the "role" field 
        // or any other new fields that are crashing the official SDK.
        if (json['candidates'] != null && 
            (json['candidates'] as List).isNotEmpty &&
            json['candidates'][0]['content'] != null &&
            json['candidates'][0]['content']['parts'] != null) {
              
          final parts = json['candidates'][0]['content']['parts'] as List;
          final textBuffer = StringBuffer();
          for (var part in parts) {
            if (part['text'] != null) {
              textBuffer.write(part['text']);
            }
          }
          return SimpleResponse(textBuffer.toString());
        }
        return SimpleResponse(''); // Empty response if structure differs but no error
      } else {
        throw Exception('Gemini API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send request: $e');
    }
  }

  Map<String, dynamic> _mapPart(Part p) {
    if (p is TextPart) {
      return {'text': p.text};
    } else if (p is DataPart) {
      // Handles your ESP32 Images
      return {
        'inline_data': {
          'mime_type': p.mimeType,
          'data': base64Encode(p.bytes)
        }
      };
    }
    // Fallback for simple text parts if type matching fails
    return {'text': p.toString()};
  }
}

/// Chat session that maintains conversation history
class SimpleChatSession {
  final String apiKey;
  final String model;
  final List<Content> _history;
  final double? temperature;
  final int? maxOutputTokens;

  SimpleChatSession({
    required this.apiKey,
    required this.model,
    required List<Content> history,
    this.temperature,
    this.maxOutputTokens,
  }) : _history = List.from(history);

  Future<SimpleResponse> sendMessage(Content message) async {
    // Add user message to history
    _history.add(message);
    
    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');

    // Convert history to JSON
    final contents = _history.map((c) => {
      'role': c.role ?? 'user',
      'parts': c.parts.map((p) => _mapPart(p)).toList()
    }).toList();

    final body = <String, dynamic>{'contents': contents};
    if (temperature != null || maxOutputTokens != null) {
      body['generationConfig'] = {
        if (temperature != null) 'temperature': temperature,
        if (maxOutputTokens != null) 'maxOutputTokens': maxOutputTokens,
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        if (json['candidates'] != null && 
            (json['candidates'] as List).isNotEmpty &&
            json['candidates'][0]['content'] != null &&
            json['candidates'][0]['content']['parts'] != null) {
              
          final parts = json['candidates'][0]['content']['parts'] as List;
          final textBuffer = StringBuffer();
          for (var part in parts) {
            if (part['text'] != null) {
              textBuffer.write(part['text']);
            }
          }
          final responseText = textBuffer.toString();
          
          // Add assistant response to history
          _history.add(Content('model', [TextPart(responseText)]));
          
          return SimpleResponse(responseText);
        }
        return SimpleResponse('');
      } else {
        throw Exception('Gemini API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Map<String, dynamic> _mapPart(Part p) {
    if (p is TextPart) {
      return {'text': p.text};
    } else if (p is DataPart) {
      return {
        'inline_data': {
          'mime_type': p.mimeType,
          'data': base64Encode(p.bytes)
        }
      };
    }
    return {'text': p.toString()};
  }
}

/// A simple wrapper to match the response.text style
class SimpleResponse {
  final String? text;
  SimpleResponse(this.text);
}

