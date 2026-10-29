import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
  final double? lat;
  final double? lon;

  PlacePrediction({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
    this.lat,
    this.lon,
  });

  factory PlacePrediction.fromMap(Map<String, dynamic> map) {
    return PlacePrediction(
      placeId: map['placeId']?.toString() ?? '',
      primaryText: map['primaryText']?.toString() ??
          map['structured_formatting']?['main_text']?.toString() ??
          map['description']?.toString() ??
          '',
      secondaryText: map['secondaryText']?.toString() ??
          map['structured_formatting']?['secondary_text']?.toString() ??
          '',
      fullText: map['fullText']?.toString() ??
          map['description']?.toString() ??
          '',
      lat: (map['lat'] as num?)?.toDouble(),
      lon: (map['lon'] as num?)?.toDouble(),
    );
  }
}

class GooglePlacesService {
  static final Map<String, List<PlacePrediction>> _autocompleteCache = {};
  static final Map<String, Map<String, dynamic>> _detailsCache = {};

  String get _baseUrl {
    if (kIsWeb) return "http://localhost:3000";
    try {
      if (Platform.isAndroid) return "http://10.0.2.2:3000";
    } catch (_) {}
    return "http://localhost:3000";
  }

  /// Autocomplete suggestions with 300ms debounce support, session token, India-biased
  Future<List<PlacePrediction>> getAutocomplete(
    String query, {
    String? sessionToken,
    String? destination,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final cacheKey = "${cleanQuery.toLowerCase()}_${destination ?? ''}";
    if (_autocompleteCache.containsKey(cacheKey)) {
      return _autocompleteCache[cacheKey]!;
    }

    try {
      final url = Uri.parse("$_baseUrl/api/places/autocomplete");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "input": cleanQuery,
          "sessionToken": sessionToken,
          "destination": destination,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predictionsJson = data["predictions"] as List? ?? [];
        final results = predictionsJson
            .map((p) => PlacePrediction.fromMap(Map<String, dynamic>.from(p)))
            .toList();
        _autocompleteCache[cacheKey] = results;
        return results;
      }
    } catch (e) {
      // Return empty list on failure
    }

    return [];
  }

  /// Place details to fetch exact latitude and longitude
  Future<Map<String, dynamic>?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    if (placeId.isEmpty) return null;

    if (_detailsCache.containsKey(placeId)) {
      return _detailsCache[placeId];
    }

    try {
      final url = Uri.parse("$_baseUrl/api/places/details");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "placeId": placeId,
          "sessionToken": sessionToken,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["place"] != null) {
          final place = Map<String, dynamic>.from(data["place"]);
          _detailsCache[placeId] = place;
          return place;
        }
      }
    } catch (e) {
      // Fallback handled below
    }

    return null;
  }

  /// Reverse geocode coordinates to a place / neighbourhood name
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse("$_baseUrl/api/places/reverse-geocode");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "lat": lat,
          "lon": lon,
        }),
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["name"] != null) {
          return data["name"].toString();
        }
      }
    } catch (_) {}

    return "Location (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})";
  }
}
