import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ItineraryService {
  // In-memory cache for itinerary responses
  static final Map<String, dynamic> _responseCache = {};

  String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    try {
      if (Platform.isAndroid) return "http://10.0.2.2:3000";
    } catch (_) {}
    return "http://localhost:3000";
  }

  Future<dynamic> generateItinerary({
    required String destination,
    required int days,
    required List<String> interests,
    Map<String, dynamic>? startPoint,
  }) async {
    final cacheKey = "${destination.toLowerCase()}_${days}_${interests.join(',')}_${startPoint?['lat']},${startPoint?['lon']}";
    if (_responseCache.containsKey(cacheKey)) {
      return _responseCache[cacheKey];
    }

    final url = Uri.parse("$_baseUrl/api/itinerary/generate");

    final Map<String, dynamic> payload = {
      "destination": destination,
      "days": days,
      "interests": interests,
    };

    if (startPoint != null) {
      payload["startPoint"] = startPoint;
    }

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _responseCache[cacheKey] = data;
      return data;
    } else {
      String errorMessage = "Failed to generate itinerary";
      try {
        final errJson = jsonDecode(response.body);
        if (errJson["error"] != null) {
          errorMessage = errJson["error"].toString();
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}