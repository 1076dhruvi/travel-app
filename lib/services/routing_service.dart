import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class RoutingService {
  Future<Map<String, dynamic>> optimizeRoute(
    String city,
    List<dynamic> places, {
    Map<String, dynamic>? startPoint,
  }) async {
    final url = Uri.parse(AppConfig.routingOptimizeUrl);

    final Map<String, dynamic> payload = {"city": city, "places": places};

    if (startPoint != null) {
      payload["startPoint"] = startPoint;
    }

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }
}
