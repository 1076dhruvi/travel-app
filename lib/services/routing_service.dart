import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class RoutingService {
  String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    try {
      if (Platform.isAndroid) return "http://10.0.2.2:3000";
    } catch (_) {}
    return "http://localhost:3000";
  }

  Future<Map<String, dynamic>> optimizeRoute(
    String city,
    List<dynamic> places, {
    Map<String, dynamic>? startPoint,
  }) async {
    final url = Uri.parse("$_baseUrl/api/routing/optimize");

    final Map<String, dynamic> payload = {
      "city": city,
      "places": places,
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
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }
}