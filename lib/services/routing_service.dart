import 'dart:convert';
import 'package:http/http.dart' as http;

class RoutingService {

  Future<Map<String, dynamic>> optimizeRoute(
      String city,
      List<String> places,
      ) async {

    final url = Uri.parse(
      "http://192.168.1.10:3000/api/routing/optimize",
    );

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "city": city,
        "places": places,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(response.body);
    }
  }

}