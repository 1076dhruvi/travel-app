import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _definedBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
  );

  /// Detects whether the app is currently running on an Android emulator.
  /// Returns `false` on a physical device (such as Motorola Edge 70).
  static bool get isAndroidEmulator {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
    } catch (_) {
      return false;
    }

    // Explicit override via --dart-define=USE_EMULATOR=true / false if specified
    const definedEmulator = String.fromEnvironment('USE_EMULATOR');
    if (definedEmulator.toLowerCase() == 'true') return true;
    if (definedEmulator.toLowerCase() == 'false') return false;

    // Detect standard Android emulator pipes / files
    try {
      if (File('/dev/qemu_pipe').existsSync() ||
          File('/dev/socket/qemud').existsSync() ||
          File('/system/bin/qemu-props').existsSync()) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Centralized backend host URL.
  /// Priority:
  /// 1. Explicit override passed via `--dart-define=BACKEND_URL=...`
  /// 2. If running on an Android emulator: `http://10.0.2.2:3000`
  /// 3. Physical Android phone (USB debugging with `adb reverse tcp:3000 tcp:3000`)
  ///    or desktop/web: `http://127.0.0.1:3000`
  static String get backendUrl {
    if (_definedBackendUrl.isNotEmpty) {
      final trimmed = _definedBackendUrl.trim();
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }

    if (isAndroidEmulator) {
      return 'http://10.0.2.2:3000';
    }

    // Physical Android device (forwarded via adb reverse) or desktop/web:
    return 'http://192.168.1.37:3000';
  }

  /// Base URL for API endpoints:
  /// - Physical device: `http://192.168.1.37:3000/api`
  /// - Android emulator: `http://10.0.2.2:3000/api`
  static String get apiBaseUrl => '$backendUrl/api';

  /// Helper for health check URL
  static String get healthUrl => '$backendUrl/api/health';

  /// Helper for itinerary endpoint:
  /// - Physical device: `http://192.168.1.37:3000/api/itinerary/generate`
  /// - Android emulator: `http://10.0.2.2:3000/api/itinerary/generate`
  static String get itineraryGenerateUrl => '$apiBaseUrl/itinerary/generate';

  /// Helper for routing endpoint:
  /// - Physical device: `http://192.168.1.37:3000/api/routing/optimize`
  /// - Android emulator: `http://10.0.2.2:3000/api/routing/optimize`
  static String get routingOptimizeUrl => '$apiBaseUrl/routing/optimize';
}
