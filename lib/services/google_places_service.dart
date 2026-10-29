import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

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
      primaryText:
          map['primaryText']?.toString() ??
          map['structured_formatting']?['main_text']?.toString() ??
          map['description']?.toString() ??
          '',
      secondaryText:
          map['secondaryText']?.toString() ??
          map['structured_formatting']?['secondary_text']?.toString() ??
          '',
      fullText:
          map['fullText']?.toString() ??
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
  static String? _cachedApiKey;

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3000';
    } catch (_) {}

    return 'http://localhost:3000';
  }

  /// Retrieves the Google API key from the environment or backend.
  Future<String?> getApiKey() async {
    const envKey = String.fromEnvironment(
      'GOOGLE_PLACES_API_KEY',
      defaultValue: String.fromEnvironment('GOOGLE_API_KEY'),
    );

    if (envKey.isNotEmpty) return envKey;

    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }

    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/api/places/key'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['apiKey'] != null &&
            data['apiKey'].toString().isNotEmpty) {
          _cachedApiKey = data['apiKey'].toString();
          return _cachedApiKey;
        }
      }
    } catch (e) {
      debugPrint('[Google Places API Key Error]: $e');
    }

    return null;
  }

  /// Autocomplete using Google Places API (New).
  Future<List<PlacePrediction>> getAutocomplete(
    String query, {
    String? sessionToken,
    void Function(int status, String userMessage, String bodySnippet)?
        onError,
  }) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) return [];

    final cacheKey = cleanQuery.toLowerCase();

    if (_autocompleteCache.containsKey(cacheKey)) {
      return _autocompleteCache[cacheKey]!;
    }

    final apiKey = await getApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      const msg =
          'Google Places API key is missing. Ensure GOOGLE_PLACES_API_KEY is configured.';

      debugPrint('[Google Places Autocomplete Error] $msg');
      onError?.call(401, msg, msg);

      return [];
    }

    try {
      final url = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );

      final bodyPayload = <String, dynamic>{
        'input': cleanQuery,
        'includedRegionCodes': ['in'],
        'languageCode': 'en',
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        'locationBias': {
          'circle': {
            'center': {
              'latitude': 19.076,
              'longitude': 72.8777,
            },
            'radius': 50000.0,
          },
        },
      };
      final response = await http
          .post(
            url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': apiKey,
          'X-Goog-FieldMask':
          'suggestions.placePrediction.placeId,'
              'suggestions.placePrediction.text,'
              'suggestions.placePrediction.structuredFormat',
        },
            body: jsonEncode(bodyPayload),
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) {
        final status = response.statusCode;
        final bodySnippet = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;

        debugPrint(
          '[Places API Autocomplete Error] '
          'Status: $status, Body: $bodySnippet',
        );

        String userMessage =
            'Places autocomplete returned status $status.';

        final lower = response.body.toLowerCase();

        if (status == 403 ||
            lower.contains('api_not_enabled') ||
            lower.contains('servicedisabled') ||
            lower.contains('not enabled')) {
          userMessage =
              "Google Cloud Places API (New) is not enabled for your project. "
              "Please enable 'Places API (New)' in Google Cloud Console.";
        }

        onError?.call(status, userMessage, bodySnippet);

        return [];
      }

      final data = jsonDecode(response.body);
      final suggestions = data['suggestions'] as List? ?? [];
      final List<PlacePrediction> results = [];

      for (final s in suggestions) {
        final pred =
            s['placePrediction'] as Map<String, dynamic>? ?? {};

        final rawPlace = pred['place']?.toString() ?? '';

        final rawId = pred['placeId']?.toString() ??
            (rawPlace.startsWith('places/')
                ? rawPlace.substring(7)
                : rawPlace);

        final structured =
            pred['structuredFormat'] as Map<String, dynamic>? ?? {};

        final mainText =
            structured['mainText']?['text']?.toString() ??
            pred['text']?['text']?.toString() ??
            '';

        final secText =
            structured['secondaryText']?['text']?.toString() ?? '';

        final full = pred['text']?['text']?.toString() ?? mainText;

        results.add(
          PlacePrediction(
            placeId: rawId.isNotEmpty ? rawId : rawPlace,
            primaryText: mainText.isNotEmpty ? mainText : full,
            secondaryText: secText,
            fullText: full,
          ),
        );
      }

      _autocompleteCache[cacheKey] = results;

      return results;
    } catch (e) {
      debugPrint('[Google Places Autocomplete Exception]: $e');

      onError?.call(
        500,
        'Failed to connect to Google Places API: $e',
        e.toString(),
      );

      return [];
    }
  }

  /// Retrieves place details using Google Places API (New).
  Future<Map<String, dynamic>?> getPlaceDetails(
    String placeId, {
    void Function(int status, String userMessage, String bodySnippet)?
        onError,
  }) async {
    if (placeId.isEmpty) return null;

    if (_detailsCache.containsKey(placeId)) {
      return _detailsCache[placeId];
    }

    final apiKey = await getApiKey();

    if (apiKey == null || apiKey.isEmpty) {
      const msg =
          'Google Places API key is missing. Ensure GOOGLE_PLACES_API_KEY is configured.';

      debugPrint('[Google Place Details Error] $msg');
      onError?.call(401, msg, msg);

      return null;
    }

    try {
      final normalizedId = placeId.startsWith('places/')
          ? placeId.substring(7)
          : placeId;

      final url = Uri.parse(
        'https://places.googleapis.com/v1/places/$normalizedId',
      );

      final response = await http
          .get(
            url,
            headers: {
              'X-Goog-Api-Key': apiKey,
              'X-Goog-FieldMask': 'location,displayName',
            },
          )
          .timeout(const Duration(seconds: 7));

      if (response.statusCode != 200) {
        final status = response.statusCode;
        final bodySnippet = response.body.length > 300
            ? response.body.substring(0, 300)
            : response.body;

        debugPrint(
          '[Places API Details Error] '
          'Status: $status, Body: $bodySnippet',
        );

        String userMessage =
            'Place details returned status $status.';

        final lower = response.body.toLowerCase();

        if (status == 403 ||
            lower.contains('api_not_enabled') ||
            lower.contains('servicedisabled') ||
            lower.contains('not enabled')) {
          userMessage =
              "Google Cloud Places API (New) is not enabled for your project. "
              "Please enable 'Places API (New)' in Google Cloud Console.";
        }

        onError?.call(status, userMessage, bodySnippet);

        return null;
      }

      final data = jsonDecode(response.body);
      final loc = data['location'] as Map<String, dynamic>?;

      if (loc != null &&
          loc['latitude'] != null &&
          loc['longitude'] != null) {
        final lat = (loc['latitude'] as num).toDouble();
        final lon = (loc['longitude'] as num).toDouble();
        final name = data['displayName']?['text']?.toString();

        final result = {
          'lat': lat,
          'lon': lon,
          'name': name,
        };

        _detailsCache[placeId] = result;

        return result;
      }
    } catch (e) {
      debugPrint('[Google Place Details Exception]: $e');

      onError?.call(
        500,
        'Failed to connect to Google Places Details API: $e',
        e.toString(),
      );
    }

    return null;
  }

  /// Reverse geocodes coordinates to a place or neighbourhood name.
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse('$_baseUrl/api/places/reverse-geocode');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'lat': lat,
              'lon': lon,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['name'] != null) {
          return data['name'].toString();
        }
      }
    } catch (e) {
      debugPrint('[Google Places Reverse Geocode Error]: $e');
    }

    return 'Location (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})';
  }
}
