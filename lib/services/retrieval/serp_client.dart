import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '/config/env.dart';

/// Represents a single search result from a SERP (Search Engine Results Page) API.
class SerpResult {
  /// The title of the search result.
  final String title;
  /// The URL of the search result.
  final String url;
  /// A brief snippet or description of the search result.
  final String snippet;
  /// The publication or last updated date of the result, if available.
  final DateTime? date;

  /// Creates a [SerpResult].
  SerpResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.date,
  });

  /// Extracts and returns the domain name from the URL.
  String get domain {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return '';
    }
  }

  @override
  String toString() => 'SerpResult(title: $title, url: $url)';
}

/// A client for interacting with a SERP API to fetch search results.
///
/// This class handles the logic for making requests to the search API,
/// including dynamically choosing between a direct and a proxied route
/// to avoid issues like CORS on the web. It also parses the JSON response
/// into a list of [SerpResult] objects.
class SerpClient {
  /// Creates a const [SerpClient].
  const SerpClient();

  /// Fetches search results for a given query.
  ///
  /// This method dynamically chooses the best route for the request. On the web,
  /// it prefers a proxy to avoid CORS issues. On mobile and desktop, it tries a
  /// direct request first and falls back to the proxy if the direct request fails.
  ///
  /// [query] The search query.
  /// [maxResults] The maximum number of results to return.
  /// [hl] The host language for the search.
  /// [gl] The geographic location for the search.
  /// [forceProxy] If `true`, forces the use of the proxy.
  ///
  /// Returns a list of [SerpResult]s.
  Future<List<SerpResult>> fetch(
    String query, {
    int? maxResults,
    String hl = 'en',
    String gl = 'pk',
    bool? forceProxy, // optional manual override if you ever need it
  }) async {
    final max = maxResults ?? Env.serpMaxResults;

    // Decide path
    final bool preferProxyOnWeb = kIsWeb;
    final bool proxyAvailable = (Env.serpProxyUrl.isNotEmpty);
    final bool useProxyFirst = (forceProxy == true) || (preferProxyOnWeb && proxyAvailable);

    // Try primary path
    try {
      final uri = useProxyFirst
          ? _proxyUri(query, max, hl, gl)
          : _directUri(query, max, hl, gl);

      final data = await _getJson(uri);
      final list = _parseResults(data, max);
      if (list.isNotEmpty) return list;

      // If empty and we have another route to try, fall through to retry
      if (!useProxyFirst && proxyAvailable) {
        // Direct returned empty—retry via proxy
        final data2 = await _getJson(_proxyUri(query, max, hl, gl));
        return _parseResults(data2, max);
      }
      return list;
    } catch (e) {
      // If the first route fails and we have a fallback, try it
      if (!useProxyFirst && proxyAvailable) {
        final data2 = await _getJson(_proxyUri(query, max, hl, gl));
        return _parseResults(data2, max);
      }
      rethrow;
    }
  }

  // ---------------- internals ----------------

  Uri _directUri(String query, int max, String hl, String gl) {
    return Uri.parse(Env.serpBaseUrl).replace(queryParameters: {
      'engine': 'google',
      'q': query,
      'api_key': Env.serpApiKey,
      'num': '$max',
      'hl': hl,
      'gl': gl,
    });
  }

  Uri _proxyUri(String query, int max, String hl, String gl) {
    if (Env.serpProxyUrl.isEmpty) {
      throw Exception('SERP proxy URL not configured in Env.serpProxyUrl');
    }
    return Uri.parse(Env.serpProxyUrl).replace(queryParameters: {
      'q': query,
      'num': '$max',
      'hl': hl,
      'gl': gl,
    });
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final resp = await http
        .get(uri, headers: {
          'Accept': 'application/json',
          'User-Agent': 'OptiAI-Glasses/1.0 (+flutter; serp-client)'
        })
        .timeout(Duration(milliseconds: Env.serpTimeoutMs));

    if (resp.statusCode != 200) {
      throw Exception('SERP HTTP ${resp.statusCode}: ${resp.body}');
    }
    return json.decode(resp.body) as Map<String, dynamic>;
    }

  List<SerpResult> _parseResults(Map<String, dynamic> data, int max) {
    final results = <SerpResult>[];

    // Organic
    if (data['organic_results'] is List) {
      for (final item in (data['organic_results'] as List)) {
        final map = (item as Map).cast<String, dynamic>();
        final title = _asString(map['title']);
        final link = _asString(map['link']);
        final snippet = _asString(map['snippet']);
        final dateStr = _asString(map['date']);
        if (title.isEmpty || link.isEmpty) continue;
        results.add(SerpResult(
          title: title,
          url: link,
          snippet: snippet,
          date: _parseDate(dateStr),
        ));
        if (results.length >= max) break;
      }
    }

    // News (often with dates)
    if (results.length < max && data['news_results'] is List) {
      for (final item in (data['news_results'] as List)) {
        final map = (item as Map).cast<String, dynamic>();
        final title = _asString(map['title']);
        final link = _asString(map['link']);
        final snippet = _asString(map['snippet']);
        final dateStr = _asString(map['date']);
        if (title.isEmpty || link.isEmpty) continue;
        results.add(SerpResult(
          title: title,
          url: link,
          snippet: snippet,
          date: _parseDate(dateStr),
        ));
        if (results.length >= max) break;
      }
    }

    // Dedup by URL
    final seen = <String>{};
    final deduped = <SerpResult>[];
    for (final r in results) {
      final key = r.url.trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      deduped.add(r);
      if (deduped.length >= max) break;
    }

    return deduped;
  }

  static String _asString(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static DateTime? _parseDate(String s) {
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {
      final lower = s.toLowerCase();
      final now = DateTime.now();
      int numOrZero(String t) => int.tryParse(t) ?? 0;
      if (lower.contains('hour')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return now.subtract(Duration(hours: n));
      }
      if (lower.contains('min')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return now.subtract(Duration(minutes: n));
      }
      if (lower.contains('day')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: n));
      }
      if (lower.contains('week')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return now.subtract(Duration(days: 7 * n));
      }
      if (lower.contains('month')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return DateTime(now.year, now.month - n, now.day);
      }
      if (lower.contains('year')) {
        final n = numOrZero(RegExp(r'(\d+)').firstMatch(lower)?.group(1) ?? '0');
        return DateTime(now.year - n, now.month, now.day);
      }
      return null;
    }
  }
}
