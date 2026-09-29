import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre/maplibre.dart';
import 'package:geolocator/geolocator.dart' as geo;

// ─────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────

class ItineraryPlace {
  final String name;
  final double latitude;
  final double longitude;
  final String? day;
  final int dayNumber;

  ItineraryPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.day,
    this.dayNumber = 1,
  });
}

// ─────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────

class MapScreen extends StatefulWidget {
  final String title;
  final List<ItineraryPlace> places;

  const MapScreen({
    super.key,
    required this.title,
    required this.places,
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

  final Set<String> _injectedRouteIds = {};

  // ── Day colour palette ────────────────────────────────────

  final List<Color> dayColors = [
    Colors.deepPurple,
    Colors.deepOrange,
    Colors.teal,
    Colors.pinkAccent,
    Colors.indigo,
    Colors.amber,
  ];

  Color _getDayColor(int dayNum) {
    var effectiveDay = dayNum;
    if (effectiveDay < 1) {
      effectiveDay = 1;
    }
    return dayColors[(effectiveDay - 1) % dayColors.length];
  }

  /// Returns a CSS hex string like `"#7C3AED"` for use in MapLibre style specs.
  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

  // ── Lifecycle ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ── Location ──────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
      return;
    }

    geo.LocationPermission permission =
    await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
      return;
    }

    try {
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
      if (mounted) {
        setState(() => loadingLocation = false);
      }
    }
  }

  // ── Camera helpers ────────────────────────────────────────

  double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
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

  Future<void> fitAllPoints() async {
    if (_mapController == null ||
        !isMapReady ||
        widget.places.isEmpty) {
      return;
    }

    final lats = widget.places.map((p) => p.latitude).toList();
    final lons = widget.places.map((p) => p.longitude).toList();

    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min);
    final maxLon = lons.reduce(math.max);

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final distKm = _haversineKm(minLat, minLon, maxLat, maxLon);

    await _mapController!.animateCamera(
      center: Geographic(lat: centerLat, lon: centerLon),
      zoom: _dynamicZoom(distKm),
    );
  }

  Future<void> goToLocation(double lat, double lon) async {
    if (_mapController == null) return;
    await _mapController!.animateCamera(
      center: Geographic(lat: lat, lon: lon),
      zoom: 15,
    );
  }

  // ── OSRM route fetching & injection ──────────────────────

  Map<int, List<ItineraryPlace>> _groupByDay() {
    final Map<int, List<ItineraryPlace>> grouped = {};
    for (final place in widget.places) {
      grouped.putIfAbsent(place.dayNumber, () => []).add(place);
    }
    return grouped;
  }

  Future<List<List<double>>?> _fetchOsrmRoute(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
          '$lon1,$lat1;$lon2,$lat2'
          '?overview=full&geometries=geojson',
    );

    try {
      final response =
      await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final coords = routes[0]['geometry']['coordinates'] as List<dynamic>;
      return coords
          .map((c) => [
        (c[0] as num).toDouble(), // lon
        (c[1] as num).toDouble(), // lat
      ])
          .toList();
    } catch (e) {
      debugPrint('OSRM fetch error ($lat1,$lon1 → $lat2,$lon2): $e');
      return null;
    }
  }

  Future<void> _injectAllRoutes(StyleController style) async {
    _styleController = style;
    _injectedRouteIds.clear();
    final grouped = _groupByDay();

    for (final entry in grouped.entries) {
      final dayNum = entry.key;
      final dayPlaces = entry.value;

      if (dayPlaces.length < 2) continue;

      final color = _getDayColor(dayNum);
      final hexColor = _colorToHex(color);

      final List<List<double>> allCoords = [];

      for (int i = 0; i < dayPlaces.length - 1; i++) {
        final from = dayPlaces[i];
        final to = dayPlaces[i + 1];

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

      if (allCoords.length < 2) continue;

      final sourceId = 'route-source-day$dayNum';
      final layerId = 'route-layer-day$dayNum';

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

        await style.addLayer(LineStyleLayer(
          id: layerId,
          sourceId: sourceId,
          paint: {
            'line-color': hexColor,
            'line-width': 5.0,
            'line-opacity': 0.85,
          },
        ));

        _injectedRouteIds.add(layerId);
      } catch (e) {
        debugPrint('Layer injection error for day $dayNum: $e');
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapLibreMap(
            options: MapOptions(
              initCenter: widget.places.isNotEmpty
                  ? Geographic(
                lat: widget.places.first.latitude,
                lon: widget.places.first.longitude,
              )
                  : Geographic(lat: 28.6139, lon: 77.2090),
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

              await fitAllPoints();
              await _injectAllRoutes(style);
            },
            children: [
              WidgetLayer(
                markers: [
                  ...widget.places.asMap().entries.map((entry) {
                    final index = entry.key;
                    final place = entry.value;
                    final color = _getDayColor(place.dayNumber);

                    return Marker(
                      point: Geographic(
                        lat: place.latitude,
                        lon: place.longitude,
                      ),
                      size: const Size(48, 64),
                      child: GestureDetector(
                        onTap: () =>
                            goToLocation(place.latitude, place.longitude),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              index == 0
                                  ? Icons.stars_rounded
                                  : Icons.location_on,
                              color:
                              index == 0 ? Colors.amber : color,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (currentLat != null && currentLon != null)
                    Marker(
                      point: Geographic(
                          lat: currentLat!, lon: currentLon!),
                      size: const Size(30, 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black38, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (loadingLocation)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.places.length,
              itemBuilder: (context, index) {
                final place = widget.places[index];
                final color = _getDayColor(place.dayNumber);

                return GestureDetector(
                  onTap: () =>
                      goToLocation(place.latitude, place.longitude),
                  child: Card(
                    margin: const EdgeInsets.only(right: 12),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                              if (place.day != null)
                                Text(
                                  place.day!,
                                  style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          heroTag: 'fit_all',
          backgroundColor: Colors.grey.shade900,
          onPressed: fitAllPoints,
          child: const Icon(Icons.aspect_ratio, color: Colors.white),
        ),
      ),
    );
  }
}