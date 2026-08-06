import 'dart:convert';
import 'package:http/http.dart' as http;

class EmergencyPlace {
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distance;
  final String category;
  final String? phone;

  EmergencyPlace({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.distance,
    required this.category,
    this.phone,
  });
  factory EmergencyPlace.fromJson(
      Map<String, dynamic> json,
      String category,
      ) {
    final datasource = json['datasource'];

    String? extractedPhone;

    if (datasource is Map<String, dynamic>) {
      final raw = datasource['raw'];

      if (raw is Map<String, dynamic>) {
        extractedPhone = raw['phone']?.toString();
      }
    }

    return EmergencyPlace(
      name: (json['name'] ?? 'Unnamed Facility').toString(),
      address: (json['formatted'] ?? 'Address unavailable').toString(),
      latitude: (json['lat'] as num?)?.toDouble() ?? 0,
      longitude: (json['lon'] as num?)?.toDouble() ?? 0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      category: category,
      phone: extractedPhone,
    );
  }
}

class EmergencyPlacesService {
  // ============================================================
  // REPLACE THIS WITH YOUR FRIEND'S GEOAPIFY API KEY
  // ============================================================

  static const String _apiKey = '70101d58fc2d4441a91d29558f9157bb';

  // ============================================================
  // GENERIC NEARBY PLACE SEARCH
  // ============================================================

  Future<List<EmergencyPlace>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    required String category,
    int radius = 5000,
    int limit = 10,
  }) async {
    if (_apiKey == 'YOUR_GEOAPIFY_API_KEY') {
      throw Exception('Geoapify API key has not been added yet.');
    }

    final uri = Uri.https(
      'api.geoapify.com',
      '/v2/places',
      {
        'categories': category,
        'filter': 'circle:$longitude,$latitude,$radius',
        'bias': 'proximity:$longitude,$latitude',
        'limit': limit.toString(),
        'apiKey': _apiKey,
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Geoapify request failed: ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response received from Geoapify.');
    }

    final features = data['features'];

    if (features is! List) {
      return [];
    }

    return features
        .whereType<Map<String, dynamic>>()
        .map((feature) {
      final properties = feature['properties'];

      if (properties is! Map<String, dynamic>) {
        return null;
      }

      return EmergencyPlace.fromJson(
        properties,
        category,
      );
    })
        .whereType<EmergencyPlace>()
        .where(
          (place) =>
      place.latitude != 0 &&
          place.longitude != 0,
    )
        .toList();
  }

  // ============================================================
  // HOSPITALS
  // ============================================================

  Future<List<EmergencyPlace>> getNearbyHospitals({
    required double latitude,
    required double longitude,
  }) {
    return getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      category: 'healthcare.hospital',
    );
  }

  // ============================================================
  // POLICE
  // ============================================================

  Future<List<EmergencyPlace>> getNearbyPoliceStations({
    required double latitude,
    required double longitude,
  }) {
    return getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      category: 'service.police',
    );
  }

  // ============================================================
  // FIRE STATIONS
  // ============================================================

  Future<List<EmergencyPlace>> getNearbyFireStations({
    required double latitude,
    required double longitude,
  }) {
    return getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      category: 'service.fire_station',
    );
  }
}