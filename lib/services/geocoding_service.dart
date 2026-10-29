import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String apiKey = "70101d58fc2d4441a91d29558f9157bb";

  Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final encodedQuery = Uri.encodeQueryComponent(query.trim());

    final url = Uri.parse(
      "https://api.geoapify.com/v1/geocode/autocomplete"
      "?text=$encodedQuery"
      "&limit=10"
      "&apiKey=$apiKey",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        print("Geoapify search error: ${response.statusCode}");
        print(response.body);
        return [];
      }

      final data = jsonDecode(response.body);
      final features = data["features"] as List? ?? [];

      final List<Map<String, dynamic>> results = [];

      for (final feature in features) {
        final properties = feature["properties"];

        if (properties == null) continue;

        final lat = properties["lat"];
        final lon = properties["lon"];

        if (lat == null || lon == null) continue;

        final cleanName = _createCleanName(properties);

        if (cleanName.isEmpty) continue;

        results.add({
          "name": cleanName,
          "lat": double.tryParse(lat.toString()),
          "lon": double.tryParse(lon.toString()),
        });
      }

      return results;
    } catch (e) {
      print("Geoapify search exception: $e");
      return [];
    }
  }

  String _createCleanName(Map<String, dynamic> properties) {
    final name = properties["name"]?.toString().trim() ?? "";
    final city = properties["city"]?.toString().trim() ?? "";
    final state = properties["state"]?.toString().trim() ?? "";
    final country = properties["country"]?.toString().trim() ?? "";

    final parts = <String>[];

    // Priority 1: Include specific location/attraction name
    if (name.isNotEmpty) {
      parts.add(name);
    }

    // Priority 2: Add city if it's different from the place name
    if (city.isNotEmpty && city.toLowerCase() != name.toLowerCase()) {
      parts.add(city);
    }

    // Priority 3: Add state
    if (state.isNotEmpty &&
        state.toLowerCase() != name.toLowerCase() &&
        state.toLowerCase() != city.toLowerCase()) {
      parts.add(state);
    }

    // Priority 4: Add country
    if (country.isNotEmpty) {
      parts.add(country);
    }

    return parts.join(", ");
  }

  // Used across the app for fallback coordinates lookup
  Future<Map<String, double>?> getCoordinates(String location) async {
    final encodedLocation = Uri.encodeQueryComponent(location);

    final url = Uri.parse(
      "https://api.geoapify.com/v1/geocode/search"
      "?text=$encodedLocation"
      "&limit=1"
      "&apiKey=$apiKey",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data["features"] as List? ?? [];

        if (features.isNotEmpty) {
          final properties = features[0]["properties"];

          return {
            "lat": double.parse(properties["lat"].toString()),
            "lon": double.parse(properties["lon"].toString()),
          };
        }
      }

      // Fallback: OpenStreetMap Nominatim (Free, worldwide, zero API key)
      final nominatimUrl = Uri.parse(
        "https://nominatim.openstreetmap.org/search?q=$encodedLocation&format=json&limit=1",
      );
      final nomRes = await http
          .get(nominatimUrl, headers: {'User-Agent': 'TravelCompanionApp/1.0'})
          .timeout(const Duration(seconds: 4));

      if (nomRes.statusCode == 200) {
        final nomData = jsonDecode(nomRes.body);
        if (nomData is List && nomData.isNotEmpty) {
          final item = nomData[0];
          return {
            "lat": double.parse(item["lat"].toString()),
            "lon": double.parse(item["lon"].toString()),
          };
        }
      }

      return null;
    } catch (e) {
      // Secondary attempt with Nominatim if Geoapify threw network exception
      try {
        final nominatimUrl = Uri.parse(
          "https://nominatim.openstreetmap.org/search?q=$encodedLocation&format=json&limit=1",
        );
        final nomRes = await http
            .get(
              nominatimUrl,
              headers: {'User-Agent': 'TravelCompanionApp/1.0'},
            )
            .timeout(const Duration(seconds: 4));

        if (nomRes.statusCode == 200) {
          final nomData = jsonDecode(nomRes.body);
          if (nomData is List && nomData.isNotEmpty) {
            final item = nomData[0];
            return {
              "lat": double.parse(item["lat"].toString()),
              "lon": double.parse(item["lon"].toString()),
            };
          }
        }
      } catch (_) {}

      return null;
    }
  }
}
