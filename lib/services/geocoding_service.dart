import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  Future<Map<String, double>?> getCoordinates(String location) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$location&format=json&limit=1",
    );

    final response = await http.get(
      url,
      headers: {
        "User-Agent": "Travel Companion App",
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        return {
          "lat": double.parse(data[0]["lat"]),
          "lon": double.parse(data[0]["lon"]),
        };
      }
    }

    return null;
  }
}