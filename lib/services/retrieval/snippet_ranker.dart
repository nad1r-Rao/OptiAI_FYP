// import 'dart:math';
import 'serp_client.dart';

/// A class for ranking SERP (Search Engine Results Page) results.
///
/// This ranker uses a blended scoring approach to sort search results based on
/// several factors, including relevance to the query, the trustworthiness of the
/// domain, and the freshness of the content.
class SnippetRanker {
  /// Creates a const [SnippetRanker].
  const SnippetRanker();

  /// Ranks a list of [SerpResult]s based on a blended scoring model.
  ///
  /// The scoring considers:
  /// - **Relevance**: Keyword overlap between the query and the result's title/snippet.
  /// - **Domain Trust**: A preference for official and high-quality domains.
  /// - **Freshness**: Higher scores for more recent content, especially for queries
  ///   where freshness is important.
  ///
  /// [input] The list of [SerpResult]s to rank.
  /// [query] The original search query.
  /// [freshBias] A boolean to indicate if freshness should be weighted more heavily.
  /// [diversifyDomains] If `true`, the ranked list will prefer to show results
  ///   from different domains first.
  ///
  /// Returns a new list of [SerpResult]s sorted by the calculated rank.
  List<SerpResult> rank(
    List<SerpResult> input, {
    required String query,
    bool freshBias = false,
    bool diversifyDomains = true,
  }) {
    if (input.isEmpty) return const [];

    final qTokens = _tokens(query);
    final now = DateTime.now();

    List<_Scored> scored = input.map((r) {
      final rel = _relevance(r, qTokens);
      final trust = _domainTrust(r.domain);
      final fresh = _freshness(now, r.date, freshBias: freshBias);
      final weightRel   = freshBias ? 0.30 : 0.50;
      final weightTrust = freshBias ? 0.30 : 0.30;
      final weightFresh = freshBias ? 0.40 : 0.20;

      final score = (weightRel * rel) + (weightTrust * trust) + (weightFresh * fresh);
      return _Scored(r, score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));

    if (!diversifyDomains) {
      return scored.map((s) => s.item).toList();
    }

    // Encourage diversity: prefer first appearance of a domain, then fill gaps.
    final seen = <String>{};
    final diverse = <SerpResult>[];
    for (final s in scored) {
      final d = s.item.domain;
      if (!seen.contains(d)) {
        seen.add(d);
        diverse.add(s.item);
      }
    }
    // If we filtered too hard, append the rest to fill.
    for (final s in scored) {
      if (!diverse.contains(s.item)) diverse.add(s.item);
    }

    return diverse;
  }

  /// Ranks the input list and returns the top N results.
  ///
  /// A convenience method that first calls [rank] and then takes the first [n]
  /// results from the sorted list.
  ///
  /// [input] The list of [SerpResult]s to rank.
  /// [query] The original search query.
  /// [n] The number of top results to return.
  /// [freshBias] A boolean to indicate if freshness should be weighted more heavily.
  ///
  /// Returns a list containing the top [n] ranked [SerpResult]s.
  List<SerpResult> topN(
    List<SerpResult> input, {
    required String query,
    int n = 3,
    bool freshBias = false,
  }) {
    final ranked = rank(input, query: query, freshBias: freshBias);
    if (ranked.length <= n) return ranked;
    return ranked.take(n).toList();
  }

  // ----------------- helpers -----------------

  static Set<String> _tokens(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 3) // ignore very short tokens
        .toSet();
  }

  static double _relevance(SerpResult r, Set<String> qTokens) {
    if (qTokens.isEmpty) return 0;
    final hay = '${r.title} ${r.snippet}'.toLowerCase();
    int hits = 0;
    for (final t in qTokens) {
      if (hay.contains(t)) hits++;
    }
    return hits / qTokens.length; // 0..1
  }

  static double _freshness(DateTime now, DateTime? date, {required bool freshBias}) {
    if (date == null) return freshBias ? 0.3 : 0.0; // small baseline when fresh is important

    // Score newer items higher. Map age to [0..1].
    final age = now.difference(date).inMinutes.abs();
    // Short horizon if freshBias (e.g., live scores/news), longer otherwise.
    final horizonMinutes = freshBias ? 720 /*12h*/ : 4320 /*3d*/;
    final freshness = 1.0 - (age / horizonMinutes);
    return freshness.clamp(0.0, 1.0);
  }

  static double _domainTrust(String domain) {
    if (domain.isEmpty) return 0.3; // neutral-ish

    // Lightweight trust hints. Tune as you like.
    const boosts = {
      // Officials / reference
      'who.int': 0.95, 'nih.gov': 0.95, 'bmj.com': 0.9, 'gov.pk': 0.9, 'edu': 0.85,
      // Major reputable publishers
      'bbc.com': 0.85, 'reuters.com': 0.9, 'apnews.com': 0.9, 'aljazeera.com': 0.8,
      'dawn.com': 0.85, 'theguardian.com': 0.82, 'nytimes.com': 0.85, 'wsj.com': 0.85,
      // Sports
      'espncricinfo.com': 0.9, 'espn.com': 0.85,
      // Weather
      'weather.com': 0.85, 'accuweather.com': 0.8, 'metoffice.gov.uk': 0.9,
      // Finance
      'investing.com': 0.75, 'bloomberg.com': 0.88, 'marketwatch.com': 0.8,
    };

    // Exact domain match boost
    if (boosts.containsKey(domain)) return boosts[domain]!;

    // Heuristics
    if (domain.endsWith('.gov') || domain.endsWith('.gov.pk')) return 0.9;
    if (domain.endsWith('.edu')) return 0.85;

    // Default mild trust
    return 0.6;
  }
}

class _Scored {
  final SerpResult item;
  final double score;
  _Scored(this.item, this.score);
}
