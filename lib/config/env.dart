// lib/config/env.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Build-time overrides (optional):
/// flutter run --dart-define=MODEL_API_BASE=http://192.168.1.23:8080
/// flutter run --dart-define=ESP32_URL=http://192.168.192.78/capture

class Env {
  static const String _modelApiOverride =
      String.fromEnvironment('MODEL_API_BASE', defaultValue: '');
  static const String _esp32Override =
      String.fromEnvironment('ESP32_URL', defaultValue: '');

  /// Base URL for your FastAPI model.
  static String modelApiBase() {
    if (_modelApiOverride.isNotEmpty) return _modelApiOverride;

    if (kIsWeb) {
      // Browser talking to backend on your machine
      return 'http://127.0.0.1:8080';
    }

    // Native platforms:
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator maps host loopback to 10.0.2.2
      return 'http://10.0.2.2:8080';
    }

    // Windows/macOS/Linux desktop
    return 'http://127.0.0.1:8080';
  }

  /// ESP32 image URL.
  /// For Web we proxy through FastAPI to avoid CORS; for native we hit ESP32 directly.
  static String esp32Url({required String localEsp32Url}) {
    if (_esp32Override.isNotEmpty) return _esp32Override;

    if (kIsWeb) {
      final encoded = Uri.encodeComponent(localEsp32Url);
      return '${modelApiBase()}/esp32?url=$encoded'; // proxy via backend
    }
    return localEsp32Url; // native apps don’t need CORS
  }

  // === Live Retrieval (SERP) ===
  static const String serpApiKey = '276e551e6c1ee590e3fa8cd661476c41df809c6fb28406276546af70125a53d1'; // keep empty in git
  static const String serpBaseUrl = 'https://serpapi.com/search.json';
  static const String serpProxyUrl = 'https://serp-proxy.serp-proxy.workers.dev';

  // Basic knobs
  static const int serpMaxResults = 8;   // fetch up to 8
  static const int serpTimeoutMs  = 7000;

  // Caching TTLs (ms)
  static const int ttlWeatherMs   = 45 * 60 * 1000; // 45 min
  static const int ttlNewsMs      = 20 * 60 * 1000; // 20 min
  static const int ttlScoresMs    = 2  * 60 * 1000; // 2 min
  static const int ttlPricesMs    = 8  * 60 * 1000; // 8 min
}
