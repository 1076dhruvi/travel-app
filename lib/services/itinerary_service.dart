import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ItineraryService {
  // In-memory cache for itinerary responses
  static final Map<String, dynamic> _responseCache = {};

  Future<dynamic> generateItinerary({
    required String destination,
    required int days,
    required List<String> interests,
    Map<String, dynamic>? startPoint,
  }) async {
    final cacheKey =
        "${destination.toLowerCase()}_${days}_${interests.join(',')}_${startPoint?['lat']},${startPoint?['lon']}";
    if (_responseCache.containsKey(cacheKey)) {
      return _responseCache[cacheKey];
    }

    final url = Uri.parse(AppConfig.itineraryGenerateUrl);

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
      headers: {"Content-Type": "application/json"},
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
