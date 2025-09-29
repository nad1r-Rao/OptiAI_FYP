import 'package:intl/intl.dart';
import 'serp_client.dart';
import 'snippet_ranker.dart';
import '/config/env.dart';

class LiveRetrievalResult {
  final String query;
  final DateTime fetchedAt; // local time
  final List<SerpResult> results; // already ranked & trimmed
  final List<SerpResult> all;     // raw (deduped) list before trim

  LiveRetrievalResult({
    required this.query,
    required this.fetchedAt,
    required this.results,
    required this.all,
  });

  /// "As of 27 Sep 2025, 04:12 PKT"
  String asOfLabel() {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return 'As of ${fmt.format(fetchedAt)} PKT';
  }

  bool get isEmpty => results.isEmpty;
}

class LiveRetrieval {
  final SerpClient _client;
  final SnippetRanker _ranker;

  LiveRetrieval({SerpClient? client, SnippetRanker? ranker})
      : _client = client ?? const SerpClient(),
        _ranker = ranker ?? const SnippetRanker();

  /// Main entry: fetch -> rank -> return top N (default 3).
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
