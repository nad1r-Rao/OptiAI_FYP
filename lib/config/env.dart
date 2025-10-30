// lib/config/env.dart
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// Build-time overrides (optional):
/// flutter run --dart-define=MODEL_API_BASE=http://192.168.1.23:8080
/// flutter run --dart-define=ESP32_URL=http://192.168.192.78/capture

/// A class to manage environment-specific configurations.
///
/// This class provides static methods and constants to handle different
/// configurations for API URLs, keys, and other settings based on the
/// build environment and target platform.
class Env {
  static const String _modelApiOverride =
      String.fromEnvironment('MODEL_API_BASE', defaultValue: '');
  static const String _esp32Override =
      String.fromEnvironment('ESP32_URL', defaultValue: '');

  /// Determines the base URL for the FastAPI model.
  ///
  /// This method returns the appropriate base URL by checking for build-time
  /// overrides first. If no override is present, it provides default URLs
  /// based on the platform (web, Android, or desktop).
  ///
  /// Returns the model API base URL as a [String].
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

  /// Constructs the URL for the ESP32 camera image.
  ///
  /// This method handles the logic for accessing the ESP32 camera, which
  /// differs between web and native platforms. For web, it proxies the request
  /// through the FastAPI backend to avoid CORS issues. For native platforms,
  /// it uses the local ESP32 URL directly.
  ///
  /// [localEsp32Url] is the direct local network URL of the ESP32 camera.
  ///
  /// Returns the final ESP32 URL as a [String].
  static String esp32Url({required String localEsp32Url}) {
    if (_esp32Override.isNotEmpty) return _esp32Override;

    if (kIsWeb) {
      final encoded = Uri.encodeComponent(localEsp32Url);
      return '${modelApiBase()}/esp32?url=$encoded'; // proxy via backend
    }
    return localEsp32Url; // native apps don’t need CORS
  }

  // === Live Retrieval (SERP) ===

  /// API key for the SERP API service.
  /// Note: This should not be hardcoded. Use environment variables or a secrets management solution.
  static const String serpApiKey = '<YOUR_API_KEY_HERE>'; // Replace with your actual key

  /// Base URL for the SERP API.
  static const String serpBaseUrl = 'https://serpapi.com/search.json';

  /// Proxy URL for SERP API to bypass potential CORS or client-side restrictions.
  static const String serpProxyUrl = 'https://serp-proxy.serp-proxy.workers.dev';

  /// The maximum number of search results to fetch from the SERP API.
  static const int serpMaxResults = 8;   // fetch up to 8

  /// The timeout in milliseconds for SERP API requests.
  static const int serpTimeoutMs  = 7000;

  // Caching TTLs (ms)

  /// Cache Time-To-Live for weather data in milliseconds (45 minutes).
  static const int ttlWeatherMs   = 45 * 60 * 1000; // 45 min

  /// Cache Time-To-Live for news data in milliseconds (20 minutes).
  static const int ttlNewsMs      = 20 * 60 * 1000; // 20 min

  /// Cache Time-To-Live for sports scores in milliseconds (2 minutes).
  static const int ttlScoresMs    = 2  * 60 * 1000; // 2 min

  /// Cache Time-To-Live for stock prices in milliseconds (8 minutes).
  static const int ttlPricesMs    = 8  * 60 * 1000; // 8 min
}
