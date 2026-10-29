import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _definedBackendUrl = String.fromEnvironment('BACKEND_URL');

  /// Centralized backend URL configuration.
  /// Priority:
  /// 1. Passed via `--dart-define=BACKEND_URL=...`
  /// 2. If running on Android (emulator), default to `http://10.0.2.2:3000`
  /// 3. Otherwise (Windows/macOS/Linux/Web/iOS), default to `http://127.0.0.1:3000`
  static String get backendUrl {
    if (_definedBackendUrl.isNotEmpty) {
      return _definedBackendUrl.endsWith('/')
          ? _definedBackendUrl.substring(0, _definedBackendUrl.length - 1)
          : _definedBackendUrl;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }

    return 'http://127.0.0.1:3000';
  }

  /// Helper for health check URL
  static String get healthUrl => '$backendUrl/health';

  /// Helper for itinerary endpoint
  static String get itineraryGenerateUrl => '$backendUrl/api/itinerary/generate';

  /// Helper for routing endpoint
  static String get routingOptimizeUrl => '$backendUrl/api/routing/optimize';
}
