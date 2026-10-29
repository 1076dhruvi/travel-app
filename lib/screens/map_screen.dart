import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre/maplibre.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:url_launcher/url_launcher.dart';
import '../models/itinerary.dart';
import '../theme/app_theme.dart';

export '../models/itinerary.dart';

class MapScreen extends StatefulWidget {
  final String title;
  final List<ItineraryPlace> places;
  final List<ItineraryLeg>? legs;
  final StartPoint? startPoint;
  final int? initialDay;

  const MapScreen({
    super.key,
    required this.title,
    required this.places,
    this.legs,
    this.startPoint,
    this.initialDay,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? _mapController;
  StyleController? _styleController;

  double? currentLat;
  double? currentLon;
  bool loadingLocation = true;
  bool isMapReady = false;

  late int _selectedDay;
  ItineraryPlace? _selectedPlace;

  final ScrollController _carouselController = ScrollController();
  final Set<String> _injectedRouteIds = {};
  final Set<String> _injectedSourceIds = {};

  // In-memory cache for OSRM routes to avoid repeating requests
  static final Map<String, List<List<double>>> _osrmCache = {};

  // ── Coordinated Day colour palette (AppTheme) ─────────────
  List<Color> get dayColors => AppTheme.dayColors;

  Color _getDayColor(int dayNum) {
    return AppTheme.getDayColor(dayNum);
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  String _getModeHexColor(String mode) {
    return AppTheme.getModeHexColor(mode);
  }

  // ── Open full day route in Google Maps (Maps URLs API) ────
  Future<void> _openInGoogleMaps() async {
    try {
      final filtered = _filteredPlaces;
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No stops for selected day.')),
        );
        return;
      }

      // Origin: day start point or first stop
      final startLat = widget.startPoint?.latitude ?? filtered.first.latitude;
      final startLng = widget.startPoint?.longitude ?? filtered.first.longitude;
      final origin = '$startLat,$startLng';

      // Destination: last stop
      final dest = filtered.last;
      final destination = '${dest.latitude},${dest.longitude}';

      // Waypoints: up to 9 intermediate stops (Maps URLs max)
      final intermediates = filtered.length > 1
          ? filtered.sublist(0, filtered.length - 1)
          : <ItineraryPlace>[];
      final waypointList = intermediates
          .take(9)
          .map((p) => '${p.latitude},${p.longitude}')
          .toList();

      // Determine travel mode for URL
      final selectedLeg = _filteredLegs.isNotEmpty ? _filteredLegs.first : null;
      String travelMode = 'driving';
      if (selectedLeg != null) {
        final m = selectedLeg.mode.toLowerCase();
        if (m.contains('walk')) {
          travelMode = 'walking';
        } else if (m.contains('transit') || m.contains('bus') || m.contains('train') || m.contains('metro')) {
          travelMode = 'transit';
        } else if (m.contains('bike') || m.contains('cycle')) {
          travelMode = 'bicycling';
        }
      }

      // Build Maps URL using Uri.https for proper encoding
      final params = <String, String>{
        'api': '1',
        'origin': origin,
        'destination': destination,
        'travelmode': travelMode,
      };
      if (waypointList.isNotEmpty) {
        params['waypoints'] = waypointList.join('|');
      }
      final uri = Uri.https('www.google.com', '/maps/dir/', params);

      // Use LaunchMode.externalApplication — do NOT gate on canLaunchUrl
      // (canLaunchUrl returns false on Android 11+ without <queries> entries)
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Maps: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  List<int> get _availableDays {
    final days = widget.places.map((p) => p.dayNumber).toSet().toList();
    days.sort();
    return days;
  }

  List<ItineraryPlace> get _filteredPlaces {
    if (_selectedDay == 0) return widget.places;
    return widget.places.where((p) => p.dayNumber == _selectedDay).toList();
  }

  List<ItineraryLeg> get _filteredLegs {
    if (widget.legs == null || widget.legs!.isEmpty) return [];
    if (_selectedDay == 0) return widget.legs!;
    final filteredPlacesNames = _filteredPlaces.map((p) => p.name).toSet();
    if (widget.startPoint != null) {
      filteredPlacesNames.add(widget.startPoint!.name);
    }
    return widget.legs!.where((l) {
      return filteredPlacesNames.contains(l.from) ||
          filteredPlacesNames.contains(l.to);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? 0;
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _carouselController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => loadingLocation = false);
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        if (mounted) setState(() => loadingLocation = false);
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          currentLat = position.latitude;
          currentLon = position.longitude;
          loadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Location error: $e');
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  double _dynamicZoom(double distanceKm) {
    if (distanceKm > 1000) return 4.5;
    if (distanceKm > 500) return 5.5;
    if (distanceKm > 200) return 6.5;
    if (distanceKm > 100) return 7.5;
    if (distanceKm > 50) return 8.5;
    if (distanceKm > 20) return 9.5;
    if (distanceKm > 10) return 11.0;
    if (distanceKm > 5) return 12.0;
    return 13.0;
  }

  Future<void> fitPoints(List<ItineraryPlace> places) async {
    if (_mapController == null || !isMapReady) return;

    final allLats = <double>[];
    final allLons = <double>[];

    for (final p in places) {
      allLats.add(p.latitude);
      allLons.add(p.longitude);
    }

    if (widget.startPoint != null) {
      allLats.add(widget.startPoint!.latitude);
      allLons.add(widget.startPoint!.longitude);
    }

    for (final leg in _filteredLegs) {
      for (final pt in leg.polyline) {
        if (pt.length >= 2) {
          allLats.add(pt[0]);
          allLons.add(pt[1]);
        }
      }
    }

    if (allLats.isEmpty) {
      if (currentLat != null && currentLon != null) {
        allLats.add(currentLat!);
        allLons.add(currentLon!);
      } else {
        return;
      }
    }

    final minLat = allLats.reduce(math.min);
    final maxLat = allLats.reduce(math.max);
    final minLon = allLons.reduce(math.min);
    final maxLon = allLons.reduce(math.max);

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final distKm = _haversineKm(minLat, minLon, maxLat, maxLon);

    await _mapController!.animateCamera(
      center: Geographic(lat: centerLat, lon: centerLon),
      zoom: _dynamicZoom(distKm),
    );
  }

  Future<void> goToLocation(double lat, double lon, [ItineraryPlace? place]) async {
    if (_mapController == null) return;
    setState(() {
      _selectedPlace = place;
    });

    if (place != null) {
      final index = _filteredPlaces.indexWhere((p) => p.name == place.name);
      if (index >= 0 && _carouselController.hasClients) {
        _carouselController.animateTo(
          index * 220.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    await _mapController!.animateCamera(
      center: Geographic(lat: lat, lon: lon),
      zoom: 14.5,
    );

    if (place != null && mounted) {
      _showPlaceDetailsSheet(place);
    }
  }

  Future<List<List<double>>?> _fetchOsrmRoute(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    final cacheKey =
        '${lat1.toStringAsFixed(4)},${lon1.toStringAsFixed(4)}->${lat2.toStringAsFixed(4)},${lon2.toStringAsFixed(4)}';
    if (_osrmCache.containsKey(cacheKey)) {
      return _osrmCache[cacheKey];
    }

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$lon1,$lat1;$lon2,$lat2'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final coords = routes[0]['geometry']['coordinates'] as List<dynamic>;
      final result = coords
          .map((c) => [
                (c[0] as num).toDouble(), // lon
                (c[1] as num).toDouble(), // lat
              ])
          .toList();

      _osrmCache[cacheKey] = result;
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateRoutesForDay(int day) async {
    final style = _styleController;
    if (style == null) return;

    // Clean up previously added layers & sources
    for (final layerId in _injectedRouteIds) {
      try {
        await style.removeLayer(layerId);
      } catch (_) {}
    }
    for (final sourceId in _injectedSourceIds) {
      try {
        await style.removeSource(sourceId);
      } catch (_) {}
    }
    _injectedRouteIds.clear();
    _injectedSourceIds.clear();

    // 1. If we have rich decoded legs from Google Routes API, render per-leg polylines
    final availableLegs = _filteredLegs;
    if (availableLegs.isNotEmpty) {
      for (int i = 0; i < availableLegs.length; i++) {
        final leg = availableLegs[i];
        final sourceId = 'leg-src-$day-$i';
        final layerId = 'leg-layer-$day-$i';


        // Prepare GeoJSON coordinates: MapLibre requires [lon, lat]
        List<List<double>> geoJsonCoords = [];
        if (leg.polyline.isNotEmpty) {
          geoJsonCoords = leg.polyline.map((pt) => [pt[1], pt[0]]).toList();
        } else {
          // Fallback to start and end points via OSRM
          final fromPlace = widget.places.firstWhere(
            (p) => p.name == leg.from,
            orElse: () => ItineraryPlace(
              name: leg.from,
              latitude: widget.startPoint?.latitude ?? 0.0,
              longitude: widget.startPoint?.longitude ?? 0.0,
            ),
          );
          final toPlace = widget.places.firstWhere(
            (p) => p.name == leg.to,
            orElse: () => ItineraryPlace(
              name: leg.to,
              latitude: 0.0,
              longitude: 0.0,
            ),
          );

          final osrmCoords = await _fetchOsrmRoute(
            fromPlace.latitude,
            fromPlace.longitude,
            toPlace.latitude,
            toPlace.longitude,
          );
          if (osrmCoords != null && osrmCoords.isNotEmpty) {
            geoJsonCoords = osrmCoords;
          } else {
            geoJsonCoords = [
              [fromPlace.longitude, fromPlace.latitude],
              [toPlace.longitude, toPlace.latitude],
            ];
          }
        }

        if (geoJsonCoords.length < 2) continue;

        final geoJsonString = jsonEncode({
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': geoJsonCoords,
          },
          'properties': {
            'mode': leg.mode,
            'duration': leg.duration,
            'distance': leg.distance,
          },
        });

        // Styling based on mode:
        // solid drive/cab, dashed walk, distinct pattern for transit
        final modeLower = leg.mode.toLowerCase();
        final modeHexColor = _getModeHexColor(leg.mode);
        final Map<String, Object> paintProps;

        if (modeLower.contains('walk')) {
          paintProps = {
            'line-color': modeHexColor,
            'line-width': 4.0,
            'line-opacity': 0.95,
            'line-dasharray': [2.0, 2.0], // Dashed walk
          };
        } else if (modeLower.contains('bus') ||
            modeLower.contains('train') ||
            modeLower.contains('transit') ||
            modeLower.contains('metro')) {
          paintProps = {
            'line-color': modeHexColor,
            'line-width': 5.5,
            'line-opacity': 0.95,
            'line-dasharray': [1.0, 1.2], // Distinct transit pattern
          };
        } else {
          // Solid drive / cab
          paintProps = {
            'line-color': modeHexColor,
            'line-width': 5.0,
            'line-opacity': 0.95,
          };
        }

        try {
          await style.addSource(GeoJsonSource(
            id: sourceId,
            data: geoJsonString,
          ));
          _injectedSourceIds.add(sourceId);

          await style.addLayer(LineStyleLayer(
            id: layerId,
            sourceId: sourceId,
            paint: paintProps,
          ));
          _injectedRouteIds.add(layerId);
        } catch (e) {
          debugPrint('Leg layer injection error ($i): $e');
        }
      }
      return;
    }

    // 2. Fallback: Draw consecutive places with OSRM
    final places = _filteredPlaces;
    if (places.length < 2) return;

    final effectiveDay = day == 0 ? 1 : day;
    final color = _getDayColor(effectiveDay);
    final hexColor = _colorToHex(color);
    final List<List<double>> allCoords = [];

    for (int i = 0; i < places.length - 1; i++) {
      final from = places[i];
      final to = places[i + 1];

      final coords = await _fetchOsrmRoute(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );

      if (coords != null && coords.isNotEmpty) {
        if (allCoords.isNotEmpty) coords.removeAt(0);
        allCoords.addAll(coords);
      } else {
        if (allCoords.isEmpty) {
          allCoords.add([from.longitude, from.latitude]);
        }
        allCoords.add([to.longitude, to.latitude]);
      }
    }

    if (allCoords.length < 2) return;

    final sourceId = 'route-source-fallback-$day';
    final layerId = 'route-layer-fallback-$day';

    final geoJsonString = jsonEncode({
      'type': 'Feature',
      'geometry': {
        'type': 'LineString',
        'coordinates': allCoords,
      },
      'properties': {},
    });

    try {
      await style.addSource(GeoJsonSource(
        id: sourceId,
        data: geoJsonString,
      ));
      _injectedSourceIds.add(sourceId);

      await style.addLayer(LineStyleLayer(
        id: layerId,
        sourceId: sourceId,
        paint: {
          'line-color': hexColor,
          'line-width': 4.5,
          'line-opacity': 0.9,
        },
      ));
      _injectedRouteIds.add(layerId);
    } catch (e) {
      debugPrint('Fallback route layer injection error: $e');
    }
  }

  void _onDaySelected(int day) {
    setState(() {
      _selectedDay = day;
      _selectedPlace = null;
    });
    fitPoints(_filteredPlaces);
    _updateRoutesForDay(day);
  }

  void _showPlaceDetailsSheet(ItineraryPlace place) {
    final color = _getDayColor(place.dayNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Stop #${place.stopNumber} • ${place.day ?? "Day ${place.dayNumber}"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (place.arrivalTime != null && place.arrivalTime!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Colors.black87),
                          const SizedBox(width: 4),
                          Text(
                            "${place.arrivalTime}${place.leaveTime != null ? " - ${place.leaveTime}" : ""}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                place.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (place.duration != null && place.duration!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Planned Duration: ${place.duration}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (place.description != null && place.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  place.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.schedule, size: 16, color: Colors.teal),
                    label: Text(
                      'Hours: ${place.openingHours ?? "check locally"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: Colors.teal.shade50,
                    side: BorderSide(color: Colors.teal.shade200),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (place.bestTime != null && place.bestTime!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                      label: Text(
                        'Best: ${place.bestTime}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.orange.shade50,
                      side: BorderSide(color: Colors.orange.shade200),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.directions, color: Colors.white, size: 18),
                  label: const Text('Open in Google Maps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () async {
                    try {
                      // Single place — open in Maps search (no canLaunchUrl gate)
                      final uri = Uri.https(
                        'www.google.com',
                        '/maps/search/',
                        {'api': '1', 'query': '${place.latitude},${place.longitude}'},
                      );
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('Could not open Google Maps: $e'),
                            backgroundColor: Colors.red.shade700,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLegDetailsSheet(ItineraryLeg leg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(_getTransportIcon(leg.mode), color: AppTheme.getModeColor(leg.mode), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Travel Leg Details',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '${leg.from}  ➔  ${leg.to}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildStatBadge(Icons.straighten, 'Distance', leg.distance),
                  const SizedBox(width: 10),
                  _buildStatBadge(Icons.timer_outlined, 'Duration', leg.duration),
                  const SizedBox(width: 10),
                  _buildStatBadge(
                    _getTransportIcon(leg.mode),
                    'Mode',
                    leg.mode.toUpperCase(),
                  ),
                ],
              ),
              if (leg.transitLine != null && leg.transitLine!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.modeTransitLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.modeTransitBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_bus, size: 18, color: AppTheme.modeTransit),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Transit Line: ${leg.transitLine}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.modeTransit,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBadge(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTransportIcon(String mode) {
    final m = mode.toLowerCase();
    if (m.contains('walk')) return Icons.directions_walk;
    if (m.contains('train') || m.contains('rail') || m.contains('subway') || m.contains('metro')) {
      return Icons.train;
    }
    if (m.contains('bus')) return Icons.directions_bus;
    return Icons.local_taxi;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlaces;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fit Selected Day',
            onPressed: () => fitPoints(filtered),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MapLibre Map ──────────────────────────────────
          MapLibreMap(
            options: MapOptions(
              initCenter: widget.startPoint != null
                  ? Geographic(
                      lat: widget.startPoint!.latitude,
                      lon: widget.startPoint!.longitude,
                    )
                  : (widget.places.isNotEmpty
                      ? Geographic(
                          lat: widget.places.first.latitude,
                          lon: widget.places.first.longitude,
                        )
                      : Geographic(lat: 19.076, lon: 72.8777)),
              initZoom: 11,
              initStyle:
                  'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onStyleLoaded: (style) async {
              _styleController = style;
              if (mounted) setState(() => isMapReady = true);

              await fitPoints(filtered);
              await _updateRoutesForDay(_selectedDay);
            },
            children: [
              WidgetLayer(
                markers: [
                  // Start point marker
                  if (widget.startPoint != null)
                    Marker(
                      point: Geographic(
                        lat: widget.startPoint!.latitude,
                        lon: widget.startPoint!.longitude,
                      ),
                      size: const Size(48, 58),
                      child: GestureDetector(
                        onTap: () async {
                          if (_mapController != null) {
                            await _mapController!.animateCamera(
                              center: Geographic(
                                lat: widget.startPoint!.latitude,
                                lon: widget.startPoint!.longitude,
                              ),
                              zoom: 14.5,
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Start Point: ${widget.startPoint!.name} (Leaves at ${widget.startPoint!.departureTime})"),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade800,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Text(
                                "START",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(Icons.home_filled, color: Colors.green.shade800, size: 28),
                          ],
                        ),
                      ),
                    ),

                  // Stop markers numbered matching the list
                  ...filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final place = entry.value;
                    final color = _getDayColor(place.dayNumber);
                    final isSelected = _selectedPlace?.name == place.name;
                    final displayNum = place.stopNumber > 0 ? place.stopNumber : (index + 1);

                    return Marker(
                      point: Geographic(
                        lat: place.latitude,
                        lon: place.longitude,
                      ),
                      size: isSelected ? const Size(54, 72) : const Size(46, 62),
                      child: GestureDetector(
                        onTap: () => goToLocation(
                          place.latitude,
                          place.longitude,
                          place,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black87 : color,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black38,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$displayNum',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Icon(
                                index == 0 ? Icons.stars_rounded : Icons.location_on,
                                color: isSelected
                                    ? Colors.black87
                                    : (index == 0 ? Colors.amber.shade800 : color),
                                size: isSelected ? 36 : 30,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  // Current GPS position marker
                  if (currentLat != null && currentLon != null)
                    Marker(
                      point: Geographic(lat: currentLat!, lon: currentLon!),
                      size: const Size(28, 28),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Top Day Filter Chips ──────────────────────────
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(
                      'All Days (${widget.places.length})',
                      style: TextStyle(
                        color: _selectedDay == 0 ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    selected: _selectedDay == 0,
                    selectedColor: AppTheme.primaryTeal,
                    backgroundColor: Colors.white.withValues(alpha: 0.95),
                    elevation: 3,
                    onSelected: (selected) {
                      if (selected) _onDaySelected(0);
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._availableDays.map((d) {
                    final color = _getDayColor(d);
                    final isSel = _selectedDay == d;
                    final count =
                        widget.places.where((p) => p.dayNumber == d).length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: CircleAvatar(
                          backgroundColor: isSel ? Colors.white : color,
                          radius: 5,
                        ),
                        label: Text(
                          'Day $d ($count)',
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        selected: isSel,
                        selectedColor: color,
                        backgroundColor: Colors.white.withValues(alpha: 0.95),
                        elevation: 3,
                        onSelected: (selected) {
                          if (selected) _onDaySelected(d);
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Loading indicator ─────────────────────────────
          if (loadingLocation)
            const Center(child: CircularProgressIndicator()),

          // ── Bottom Place Cards Carousel ───────────────────
          if (filtered.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              height: 104,
              child: ListView.builder(
                controller: _carouselController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final place = filtered[index];
                  final color = _getDayColor(place.dayNumber);
                  final isSelected = _selectedPlace?.name == place.name;
                  final displayNum = place.stopNumber > 0 ? place.stopNumber : (index + 1);

                  return GestureDetector(
                    onTap: () => goToLocation(
                      place.latitude,
                      place.longitude,
                      place,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? color : Colors.grey.shade300,
                          width: isSelected ? 2.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected
                                ? color.withValues(alpha: 0.35)
                                : Colors.black12,
                            blurRadius: isSelected ? 8 : 4,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            radius: 16,
                            child: Text(
                              '$displayNum',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    if (place.arrivalTime != null &&
                                        place.arrivalTime!.isNotEmpty) ...[
                                      Icon(
                                        Icons.access_time,
                                        size: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        "${place.arrivalTime}${place.leaveTime != null ? " - ${place.leaveTime}" : ""}",
                                        style: TextStyle(
                                          color: Colors.grey.shade800,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Hours: ${place.openingHours ?? "check locally"}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 115),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_filteredLegs.isNotEmpty)
              FloatingActionButton.small(
                heroTag: 'legs_info',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryTeal,
                onPressed: () {
                  if (_filteredLegs.isNotEmpty) {
                    _showLegDetailsSheet(_filteredLegs.first);
                  }
                },
                tooltip: 'Leg Details',
                child: const Icon(Icons.alt_route),
              ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'open_gmaps',
              backgroundColor: Colors.white,
              foregroundColor: Colors.green.shade700,
              onPressed: _openInGoogleMaps,
              tooltip: 'Open full route in Google Maps',
              child: const Icon(Icons.directions),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: 'fit_all',
              backgroundColor: Colors.grey.shade900,
              onPressed: () => fitPoints(filtered),
              tooltip: 'Fit Bounds',
              child: const Icon(Icons.aspect_ratio, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}