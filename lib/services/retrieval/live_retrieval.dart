import 'package:intl/intl.dart';
import 'serp_client.dart';
import 'snippet_ranker.dart';
import '/config/env.dart';

/// Represents the result of a live information retrieval search.
///
/// This class holds the original query, the time the search was performed,
/// the ranked and trimmed list of results, and the full list of all results.
class LiveRetrievalResult {
  /// The original search query.
  final String query;
  /// The local time when the search results were fetched.
  final DateTime fetchedAt; // local time
  /// The list of search results, ranked and trimmed to the most relevant items.
  final List<SerpResult> results; // already ranked & trimmed
  /// The complete, raw list of deduplicated search results before ranking and trimming.
  final List<SerpResult> all;     // raw (deduped) list before trim

  /// Creates a [LiveRetrievalResult].
  LiveRetrievalResult({
    required this.query,
    required this.fetchedAt,
    required this.results,
    required this.all,
  });

  /// Generates a formatted timestamp string, e.g., "As of 27 Sep 2025, 04:12 PKT".
  String asOfLabel() {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return 'As of ${fmt.format(fetchedAt)} PKT';
  }

  /// A boolean that is `true` if there are no ranked results.
  bool get isEmpty => results.isEmpty;
}

/// A class for performing live information retrieval from the web.
///
/// This class orchestrates the process of fetching search results using a
/// [SerpClient], ranking them with a [SnippetRanker], and returning the
/// most relevant results.
class LiveRetrieval {
  final SerpClient _client;
  final SnippetRanker _ranker;

  /// Creates a [LiveRetrieval] instance.
  ///
  /// Allows for custom [SerpClient] and [SnippetRanker] instances to be provided,
  /// otherwise uses default instances.
  LiveRetrieval({SerpClient? client, SnippetRanker? ranker})
      : _client = client ?? const SerpClient(),
        _ranker = ranker ?? const SnippetRanker();

  /// Performs a web search, ranks the results, and returns the top N results.
  ///
  /// [query] The search query.
  /// [topN] The number of top results to return. Defaults to 3.
  ///
  /// Returns a [LiveRetrievalResult] containing the search results.
  Future<LiveRetrievalResult> search(String query, {int topN = 3}) async {
    final items = await _client.fetch(
      query,
      maxResults: Env.serpMaxResults,
    );

    final freshBias = _looksFreshQuery(query);
    final rankedTop = _ranker.topN(items, query: query, n: topN, freshBias: freshBias);

    return LiveRetrievalResult(
      query: query,
      fetchedAt: DateTime.now(),
      results: rankedTop,
      all: items,
    );
  }

  /// crude heuristic; you can later swap for your intent model’s signal.
  static bool _looksFreshQuery(String q) {
    final s = q.toLowerCase();
    const hints = [
  // News & Events
  'today','now','latest','live','breaking','headline','update',
  'happening','ongoing','trending','viral','alert','emergency',

  // Weather & Natural Events
  'weather','forecast','temperature','rain','storm','flood','earthquake',
  'cyclone','heatwave','humidity','wind','snow','sunrise','sunset',

  // Sports & Entertainment
  'match','game','score','result','fixtures','tournament','league','final',
  'standings','highlights','live stream','odds',

  // Finance, Economy & Markets
  'price','rate','exchange','stock','crypto','bitcoin','ethereum','gold',
  'silver','oil','petrol','diesel','inflation','currency','usd','eur','pkr',
  'inr','market','bond','mutual fund',

  // Politics & Public Affairs
  'election','results','polling','vote','votes','rally','press conference','government',

  // Travel, Traffic & Mobility
  'traffic','jam','accident','flight','arrivals','departures','train','bus','ferry',
  'open','closed','delayed','cancelled','schedule','status',

  // Media & Pop Culture
  'release','launched','premiere','episode','trailer','leaks','spoilers',
  'box office','concert','festival',

  // Tech & Product Launches
  'release date','rollout','update','patch','version','beta','firmware',
  'announcement','event','keynote',

  // Sales & Commerce
  'discount','sale','deal','offer','coupon','promotion',
  'black friday','cyber monday','prime day',

  // Health & Safety
  'outbreak','epidemic','pandemic','cases','deaths','recovered','vaccine',
  'symptoms','infection','virus',

  // System & Service Status
  'outage','down','offline','maintenance','restore','fix','issue',
  'service status','server'
];

    return hints.any(s.contains);
  }
}
