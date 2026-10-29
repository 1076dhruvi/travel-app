import 'dart:async';
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

/// Available free basemap tile styles (100% zero-cost, no subscription required)
enum MapStyleOption {
  voyager(
    name: 'Streets (Voyager)',
    url: 'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json',
    icon: Icons.map_outlined,
  ),
  liberty(
    name: 'OSM Liberty',
    url: 'https://tiles.openfreemap.org/styles/liberty',
    icon: Icons.public_outlined,
  ),
  positron(
    name: 'Light Minimal',
    url: 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
    icon: Icons.wb_sunny_outlined,
  ),
  darkMatter(
    name: 'Dark Mode',
    url: 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json',
    icon: Icons.nightlight_outlined,
  );

  final String name;
  final String url;
  final IconData icon;

  const MapStyleOption({
    required this.name,
    required this.url,
    required this.icon,
  });
}

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
  bool loadingLocation = false;
  bool isMapReady = false;
  bool _hasStyleLoadError = false;
  Timer? _styleLoadTimer;

  MapStyleOption _selectedStyle = MapStyleOption.voyager;

  late int _selectedDay;
  ItineraryPlace? _selectedPlace;

  double _currentZoom = 11.5;
  Geographic? _currentCenter;

  final ScrollController _carouselController = ScrollController();
  final Set<String> _injectedRouteIds = {};
  final Set<String> _injectedSourceIds = {};

  // Sequential update queue and generation counter:
  // Ensures rapid day/style changes cancel superseded async network work and
  // never permanently drop a requested update or race to modify the style.
  int _routeUpdateGeneration = 0;
  bool _isUpdatingRoutes = false;
  int? _queuedDay;

  // In-memory cache for OSRM routes to avoid repeated network requests
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

  // ── Place Sanitization & Deduplication ────────────────────

  List<ItineraryPlace> get _sanitizedPlaces {
    final seen = <String>{};
    final valid = <ItineraryPlace>[];

    for (final p in widget.places) {
      if (p.latitude.isNaN || p.longitude.isNaN) continue;
      if (p.latitude == 0.0 && p.longitude == 0.0) continue;
      if (p.latitude < -90.0 || p.latitude > 90.0) continue;
      if (p.longitude < -180.0 || p.longitude > 180.0) continue;

      final key =
          '${p.name.trim().toLowerCase()}_${p.latitude.toStringAsFixed(4)}_${p.longitude.toStringAsFixed(4)}';
      if (!seen.contains(key)) {
        seen.add(key);
        valid.add(p);
      }
    }
    return valid;
  }

  List<int> get _availableDays {
    final days = _sanitizedPlaces.map((p) => p.dayNumber).toSet().toList();
    days.sort();
    return days;
  }

  List<ItineraryPlace> get _filteredPlaces {
    final places = _sanitizedPlaces;
    if (_selectedDay == 0) return places;
    return places.where((p) => p.dayNumber == _selectedDay).toList();
  }

  List<ItineraryLeg> get _filteredLegs {
    if (widget.legs == null || widget.legs!.isEmpty) return [];
    if (_selectedDay == 0) return widget.legs!;
    final dayPlaceNames = _filteredPlaces
        .map((p) => p.name.trim().toLowerCase())
        .toSet();
    final startName = widget.startPoint?.name.trim().toLowerCase();

    return widget.legs!.where((l) {
      final fromLower = l.from.trim().toLowerCase();
      final toLower = l.to.trim().toLowerCase();
      final hasFrom = dayPlaceNames.contains(fromLower);
      final hasTo = dayPlaceNames.contains(toLower);

      if (hasFrom && hasTo) return true;
      if (startName != null && startName.isNotEmpty) {
        if ((fromLower == startName && hasTo) ||
            (toLower == startName && hasFrom)) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? 0;
    _startStyleTimer();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    _carouselController.dispose();
    _routeUpdateGeneration++;
    super.dispose();
  }

  void _startStyleTimer() {
    _styleLoadTimer?.cancel();
    _hasStyleLoadError = false;
    _styleLoadTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !isMapReady) {
        setState(() {
          _hasStyleLoadError = true;
        });
      }
    });
  }

  // ── User Current Location (GPS) ───────────────────────────

  Future<void> _getCurrentLocation({bool centerOnUser = false}) async {
    setState(() => loadingLocation = true);

    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => loadingLocation = false);
          if (centerOnUser) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location services (GPS) are disabled on your phone.',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
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
          if (centerOnUser) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission denied. Enable it in phone Settings to view your position.',
                ),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        return;
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        setState(() {
          currentLat = position.latitude;
          currentLon = position.longitude;
          loadingLocation = false;
        });

        if (centerOnUser && _mapController != null) {
          await _mapController!.animateCamera(
            center: Geographic(lat: position.latitude, lon: position.longitude),
            zoom: 15.0,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Centered on your current location'),
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Location lookup error: $e');
      if (mounted) {
        setState(() => loadingLocation = false);
        if (centerOnUser) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not get GPS fix: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // ── Camera Positioning & Bounding ─────────────────────────

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a =
        0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) *
            math.cos(lat2 * p) *
            (1 - math.cos((lon2 - lon1) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a));
  }

  double _dynamicZoom(double distanceKm) {
    if (distanceKm > 1000) return 4.0;
    if (distanceKm > 500) return 5.0;
    if (distanceKm > 200) return 6.5;
    if (distanceKm > 100) return 7.5;
    if (distanceKm > 50) return 8.5;
    if (distanceKm > 20) return 9.5;
    if (distanceKm > 10) return 11.0;
    if (distanceKm > 5) return 12.0;
    return 13.5;
  }

  Future<void> fitPoints(List<ItineraryPlace> places) async {
    if (_mapController == null || !isMapReady) return;

    final allLats = <double>[];
    final allLons = <double>[];

    for (final p in places) {
      allLats.add(p.latitude);
      allLons.add(p.longitude);
    }

    if (widget.startPoint != null &&
        !widget.startPoint!.latitude.isNaN &&
        !widget.startPoint!.longitude.isNaN &&
        widget.startPoint!.latitude != 0.0) {
      allLats.add(widget.startPoint!.latitude);
      allLons.add(widget.startPoint!.longitude);
    }

    for (final leg in _filteredLegs) {
      for (final pt in leg.polyline) {
        if (pt.length >= 2 && !pt[0].isNaN && !pt[1].isNaN) {
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

    if ((maxLat - minLat).abs() < 0.0001 && (maxLon - minLon).abs() < 0.0001) {
      _currentCenter = Geographic(lat: minLat, lon: minLon);
      _currentZoom = 14.5;
      await _mapController!.animateCamera(
        center: _currentCenter,
        zoom: _currentZoom,
      );
      return;
    }

    try {
      await _mapController!.fitBounds(
        bounds: LngLatBounds(
          longitudeWest: minLon,
          longitudeEast: maxLon,
          latitudeSouth: minLat,
          latitudeNorth: maxLat,
        ),
        padding: const EdgeInsets.only(
          top: 80,
          left: 40,
          right: 40,
          bottom: 150,
        ),
      );
    } catch (_) {
      final centerLat = (minLat + maxLat) / 2;
      final centerLon = (minLon + maxLon) / 2;
      final distKm = _haversineKm(minLat, minLon, maxLat, maxLon);

      final targetZoom = _dynamicZoom(distKm);
      _currentZoom = targetZoom;
      _currentCenter = Geographic(lat: centerLat, lon: centerLon);

      await _mapController!.animateCamera(
        center: _currentCenter,
        zoom: targetZoom,
      );
    }
  }

  Future<void> goToLocation(
    double lat,
    double lon, [
    ItineraryPlace? place,
  ]) async {
    if (_mapController == null) return;

    setState(() {
      _selectedPlace = place;
    });

    if (place != null) {
      final index = _filteredPlaces.indexWhere((p) => p.name == place.name);
      if (index >= 0 && _carouselController.hasClients) {
        _carouselController.animateTo(
          index * 240.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }

    _currentZoom = 14.8;
    _currentCenter = Geographic(lat: lat, lon: lon);

    await _mapController!.animateCamera(
      center: _currentCenter,
      zoom: _currentZoom,
    );

    if (place != null && mounted) {
      _showPlaceDetailsSheet(place);
    }
  }

  Future<void> _zoomBy(double delta) async {
    if (_mapController == null || !isMapReady) return;
    _currentZoom = (_currentZoom + delta).clamp(1.5, 19.0);
    await _mapController!.animateCamera(
      center: _currentCenter,
      zoom: _currentZoom,
    );
  }

  // ── OSRM Road Routing Engine ───────────────────────────────

  Future<List<List<double>>?> _fetchOsrmRoute(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) async {
    final cacheKey =
        '${lat1.toStringAsFixed(4)},${lon1.toStringAsFixed(4)}->${lat2.toStringAsFixed(4)},${lon2.toStringAsFixed(4)}';
    if (_osrmCache.containsKey(cacheKey)) {
      return _osrmCache[cacheKey]!.map((pt) => List<double>.from(pt)).toList();
    }

    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '$lon1,$lat1;$lon2,$lat2'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final coords = routes[0]['geometry']['coordinates'] as List<dynamic>;
      final result = coords
          .map(
            (c) => [
              (c[0] as num).toDouble(), // lon
              (c[1] as num).toDouble(), // lat
            ],
          )
          .toList();

      _osrmCache[cacheKey] = result;
      return result.map((pt) => List<double>.from(pt)).toList();
    } catch (e) {
      debugPrint('OSRM routing fetch exception: $e');
      return null;
    }
  }

  Future<void> _updateRoutesForDay(int day) async {
    _queuedDay = day;
    // Invalidate any currently running asynchronous network calls
    _routeUpdateGeneration++;

    if (_isUpdatingRoutes) {
      // The running worker loop will pick up _queuedDay on completion
      return;
    }

    _isUpdatingRoutes = true;
    try {
      while (_queuedDay != null && mounted) {
        final targetDay = _queuedDay!;
        _queuedDay = null;
        final currentGen = _routeUpdateGeneration;
        await _doUpdateRoutesForDay(targetDay, currentGen);
      }
    } finally {
      _isUpdatingRoutes = false;
    }
  }

  Future<void> _doUpdateRoutesForDay(int day, int currentGen) async {
    final style = _styleController;
    if (style == null || !mounted || currentGen != _routeUpdateGeneration) {
      debugPrint(
        'MapScreen: _doUpdateRoutesForDay[$day] skipped (gen $currentGen stale or style null)',
      );
      return;
    }

    // ── Clean up previously added layers & sources ──────────
    // First, inspect the live style to remove any route layers
    try {
      // ignore: invalid_use_of_visible_for_testing_member
      final currentLayerIds = style.getLayerIds();
      for (final layerId in currentLayerIds) {
        if (layerId.startsWith('leg-layer-') ||
            layerId.startsWith('route-layer-')) {
          try {
            await style.removeLayer(layerId);
          } catch (e) {
            debugPrint('MapScreen: removeLayer($layerId) failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('MapScreen: getLayerIds / layer cleanup error: $e');
    }
    _injectedRouteIds.clear();

    // Now remove sources since no layers reference them
    for (final sourceId in Set<String>.of(_injectedSourceIds)) {
      try {
        await style.removeSource(sourceId);
      } catch (e) {
        debugPrint('MapScreen: removeSource($sourceId) failed: $e');
      }
    }
    _injectedSourceIds.clear();

    if (!mounted ||
        currentGen != _routeUpdateGeneration ||
        _styleController != style) {
      return;
    }

    // ── Helper: add one GeoJSON source + LineLayer safely ───
    Future<void> addRouteLayer({
      required String sourceId,
      required String layerId,
      required List<List<double>> geoJsonCoords, // [[lon,lat], ...]
      required String hexColor,
      required double lineWidth,
      required double lineOpacity,
    }) async {
      if (geoJsonCoords.length < 2) {
        debugPrint(
          'MapScreen: addRouteLayer($layerId) skipped — fewer than 2 coords',
        );
        return;
      }

      if (!mounted ||
          currentGen != _routeUpdateGeneration ||
          _styleController != style) {
        return;
      }

      final geoJson = jsonEncode({
        'type': 'Feature',
        'geometry': {'type': 'LineString', 'coordinates': geoJsonCoords},
        'properties': {},
      });

      try {
        await style.addSource(GeoJsonSource(id: sourceId, data: geoJson));
        _injectedSourceIds.add(sourceId);
      } catch (e) {
        debugPrint('MapScreen: addSource($sourceId) notice: $e, recovering');
        try {
          await style.removeSource(sourceId);
          await style.addSource(GeoJsonSource(id: sourceId, data: geoJson));
          _injectedSourceIds.add(sourceId);
        } catch (_) {
          try {
            await style.updateGeoJsonSource(id: sourceId, data: geoJson);
            _injectedSourceIds.add(sourceId);
          } catch (e2) {
            debugPrint(
              'MapScreen: updateGeoJsonSource($sourceId) also failed: $e2',
            );
            return;
          }
        }
      }

      if (!mounted ||
          currentGen != _routeUpdateGeneration ||
          _styleController != style) {
        return;
      }

      try {
        await style.addLayer(
          LineStyleLayer(
            id: layerId,
            sourceId: sourceId,
            layout: const {'line-cap': 'round', 'line-join': 'round'},
            paint: {
              'line-color': hexColor,
              'line-width': lineWidth,
              'line-opacity': lineOpacity,
            },
          ),
        );
        _injectedRouteIds.add(layerId);
        debugPrint(
          'MapScreen: added layer $layerId (${geoJsonCoords.length} pts, color=$hexColor)',
        );
      } catch (e) {
        debugPrint(
          'MapScreen: addLayer($layerId) with layout failed ($e), retrying without layout',
        );
        try {
          await style.addLayer(
            LineStyleLayer(
              id: layerId,
              sourceId: sourceId,
              paint: {
                'line-color': hexColor,
                'line-width': lineWidth,
                'line-opacity': lineOpacity,
              },
            ),
          );
          _injectedRouteIds.add(layerId);
        } catch (e2) {
          debugPrint('MapScreen: addLayer($layerId) failed: $e2');
          try {
            await style.removeSource(sourceId);
          } catch (_) {}
          _injectedSourceIds.remove(sourceId);
        }
      }
    }

    // ── 1. Rich per-leg polylines from backend Routes API ───
    final availableLegs = _filteredLegs;
    debugPrint(
      'MapScreen: _doUpdateRoutesForDay[$day] (gen $currentGen) — ${availableLegs.length} legs, ${_filteredPlaces.length} places',
    );

    if (availableLegs.isNotEmpty) {
      for (int i = 0; i < availableLegs.length; i++) {
        if (!mounted ||
            currentGen != _routeUpdateGeneration ||
            _styleController != style) {
          return;
        }
        final leg = availableLegs[i];
        final sourceId = 'leg-src-$day-$i';
        final layerId = 'leg-layer-$day-$i';

        // Backend stores polyline as [[lat, lon], ...].
        // GeoJSON (MapLibre) requires [[lon, lat], ...].
        List<List<double>> geoJsonCoords = [];

        // Check if leg already has real road polyline (> 2 points)
        if (leg.polyline.length > 2) {
          geoJsonCoords = leg.polyline
              .where((pt) => pt.length >= 2 && !pt[0].isNaN && !pt[1].isNaN)
              .map((pt) => [pt[1], pt[0]])
              .toList();
          debugPrint(
            'MapScreen: leg[$i] using stored rich polyline (${geoJsonCoords.length} pts)',
          );
        } else {
          // Empty or 2-point straight line fallback — fetch actual road geometry from OSRM
          double fromLat = 0.0;
          double fromLon = 0.0;
          double toLat = 0.0;
          double toLon = 0.0;

          if (leg.polyline.length == 2 &&
              leg.polyline[0].length >= 2 &&
              leg.polyline[1].length >= 2) {
            fromLat = leg.polyline[0][0];
            fromLon = leg.polyline[0][1];
            toLat = leg.polyline[1][0];
            toLon = leg.polyline[1][1];
          }

          if (fromLat == 0.0 || toLat == 0.0) {
            final fromPlace = widget.places.firstWhere(
              (p) =>
                  p.name.trim().toLowerCase() == leg.from.trim().toLowerCase(),
              orElse: () => ItineraryPlace(
                name: leg.from,
                latitude: widget.startPoint?.latitude ?? 0.0,
                longitude: widget.startPoint?.longitude ?? 0.0,
              ),
            );
            final toPlace = widget.places.firstWhere(
              (p) => p.name.trim().toLowerCase() == leg.to.trim().toLowerCase(),
              orElse: () =>
                  ItineraryPlace(name: leg.to, latitude: 0.0, longitude: 0.0),
            );
            if (fromLat == 0.0) {
              fromLat = fromPlace.latitude;
              fromLon = fromPlace.longitude;
            }
            if (toLat == 0.0) {
              toLat = toPlace.latitude;
              toLon = toPlace.longitude;
            }
          }

          if (fromLat != 0.0 && toLat != 0.0) {
            debugPrint(
              'MapScreen: leg[$i] (${leg.from} → ${leg.to}) fetching OSRM road geometry',
            );
            final osrmCoords = await _fetchOsrmRoute(
              fromLat,
              fromLon,
              toLat,
              toLon,
            );
            if (!mounted ||
                currentGen != _routeUpdateGeneration ||
                _styleController != style) {
              return;
            }

            if (osrmCoords != null && osrmCoords.length > 2) {
              geoJsonCoords = osrmCoords;
              debugPrint(
                'MapScreen: leg[$i] received OSRM road route (${geoJsonCoords.length} pts)',
              );
            } else if (leg.polyline.length >= 2) {
              geoJsonCoords = leg.polyline.map((pt) => [pt[1], pt[0]]).toList();
            } else {
              geoJsonCoords = [
                [fromLon, fromLat],
                [toLon, toLat],
              ];
            }
          }
        }

        if (geoJsonCoords.length < 2) continue;

        final modeLower = leg.mode.toLowerCase();
        final modeHexColor = _getModeHexColor(leg.mode);
        final double lineWidth = modeLower.contains('walk')
            ? 3.8
            : (modeLower.contains('bus') ||
                      modeLower.contains('train') ||
                      modeLower.contains('transit') ||
                      modeLower.contains('metro')
                  ? 5.5
                  : 4.8);
        final double lineOpacity = modeLower.contains('walk') ? 0.90 : 0.95;

        await addRouteLayer(
          sourceId: sourceId,
          layerId: layerId,
          geoJsonCoords: geoJsonCoords,
          hexColor: modeHexColor,
          lineWidth: lineWidth,
          lineOpacity: lineOpacity,
        );
      }
      return;
    }

    // ── 2. Fallback: consecutive OSRM segments between places ─
    final places = _filteredPlaces;
    if (places.isEmpty || (places.length < 2 && widget.startPoint == null)) {
      debugPrint('MapScreen: fallback skipped — insufficient stops');
      return;
    }

    final effectiveDay = day == 0 ? 1 : day;
    final color = _getDayColor(effectiveDay);
    final hexColor = _colorToHex(color);
    final List<List<double>> allCoords = [];

    // Route from start point to first stop (if start point available)
    if (widget.startPoint != null &&
        widget.startPoint!.latitude != 0.0 &&
        !widget.startPoint!.latitude.isNaN &&
        places.isNotEmpty) {
      final startCoords = await _fetchOsrmRoute(
        widget.startPoint!.latitude,
        widget.startPoint!.longitude,
        places.first.latitude,
        places.first.longitude,
      );
      if (!mounted ||
          currentGen != _routeUpdateGeneration ||
          _styleController != style) {
        return;
      }

      if (startCoords != null && startCoords.isNotEmpty) {
        allCoords.addAll(startCoords);
      } else {
        allCoords
          ..add([widget.startPoint!.longitude, widget.startPoint!.latitude])
          ..add([places.first.longitude, places.first.latitude]);
      }
    }

    for (int i = 0; i < places.length - 1; i++) {
      if (!mounted ||
          currentGen != _routeUpdateGeneration ||
          _styleController != style) {
        return;
      }
      final from = places[i];
      final to = places[i + 1];

      final coords = await _fetchOsrmRoute(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
      if (!mounted ||
          currentGen != _routeUpdateGeneration ||
          _styleController != style) {
        return;
      }

      if (coords != null && coords.isNotEmpty) {
        // Drop duplicate first point when stitching segments (without mutating cache)
        final slice = (allCoords.isNotEmpty && coords.length > 1)
            ? coords.sublist(1)
            : coords;
        allCoords.addAll(slice);
      } else {
        if (allCoords.isEmpty) allCoords.add([from.longitude, from.latitude]);
        allCoords.add([to.longitude, to.latitude]);
      }
    }

    if (allCoords.length >= 2) {
      await addRouteLayer(
        sourceId: 'route-source-fallback-$day',
        layerId: 'route-layer-fallback-$day',
        geoJsonCoords: allCoords,
        hexColor: hexColor,
        lineWidth: 4.8,
        lineOpacity: 0.92,
      );
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

  // ── Open in Google Maps ───────────────────────────────────

  Future<void> _openInGoogleMaps() async {
    try {
      final filtered = _filteredPlaces;
      if (filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No stops found for selected day.')),
        );
        return;
      }

      final startLat = widget.startPoint?.latitude ?? filtered.first.latitude;
      final startLng = widget.startPoint?.longitude ?? filtered.first.longitude;
      final origin = '$startLat,$startLng';

      final dest = filtered.last;
      final destination = '${dest.latitude},${dest.longitude}';

      final intermediates = filtered.length > 1
          ? filtered.sublist(0, filtered.length - 1)
          : <ItineraryPlace>[];
      final waypointList = intermediates
          .take(9)
          .map((p) => '${p.latitude},${p.longitude}')
          .toList();

      final selectedLeg = _filteredLegs.isNotEmpty ? _filteredLegs.first : null;
      String travelMode = 'driving';
      if (selectedLeg != null) {
        final m = selectedLeg.mode.toLowerCase();
        if (m.contains('walk')) {
          travelMode = 'walking';
        } else if (m.contains('transit') ||
            m.contains('bus') ||
            m.contains('train') ||
            m.contains('metro')) {
          travelMode = 'transit';
        } else if (m.contains('bike') || m.contains('cycle')) {
          travelMode = 'bicycling';
        }
      }

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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open external Google Maps: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Place & Leg Details Bottom Sheets ─────────────────────

  void _showPlaceDetailsSheet(ItineraryPlace place) {
    final color = _getDayColor(place.dayNumber);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.place, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                place.day ?? "Day ${place.dayNumber}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (place.stopNumber > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Stop #${place.stopNumber}",
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (place.description != null &&
                  place.description!.isNotEmpty) ...[
                Text(
                  place.description!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (place.arrivalTime != null &&
                      place.arrivalTime!.isNotEmpty)
                    Chip(
                      avatar: const Icon(
                        Icons.schedule,
                        size: 16,
                        color: Colors.blue,
                      ),
                      label: Text(
                        "${place.arrivalTime}${place.leaveTime != null ? " - ${place.leaveTime}" : ""}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.blue.shade50,
                      side: BorderSide(color: Colors.blue.shade200),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    avatar: const Icon(
                      Icons.storefront,
                      size: 16,
                      color: Colors.teal,
                    ),
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
                      avatar: const Icon(
                        Icons.wb_twilight,
                        size: 16,
                        color: Colors.orange,
                      ),
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
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.directions,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text('Navigate in Google Maps'),
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
                      final uri = Uri.https('www.google.com', '/maps/search/', {
                        'api': '1',
                        'query': '${place.latitude},${place.longitude}',
                      });
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
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
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                  Icon(
                    _getTransportIcon(leg.mode),
                    color: AppTheme.primaryTeal,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${leg.from} → ${leg.to}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatBadge(Icons.straighten, 'Distance', leg.distance),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    Icons.timer_outlined,
                    'Duration',
                    leg.duration,
                  ),
                  const SizedBox(width: 8),
                  _buildStatBadge(
                    Icons.payments_outlined,
                    'Fare',
                    leg.cost ?? 'check locally',
                  ),
                ],
              ),
              if (leg.steps.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Route Directions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: leg.steps.length,
                    separatorBuilder: (_, i) => const Divider(height: 10),
                    itemBuilder: (ctx, idx) {
                      final step = leg.steps[idx];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            step.type == 'transit'
                                ? Icons.directions_bus
                                : Icons.arrow_forward,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step.instruction,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    },
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
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
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
    if (m.contains('train') ||
        m.contains('rail') ||
        m.contains('subway') ||
        m.contains('metro')) {
      return Icons.train;
    }
    if (m.contains('bus')) return Icons.directions_bus;
    return Icons.local_taxi;
  }

  // ── Style Selection Dialog ────────────────────────────────

  void _showStylePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Map Theme',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...MapStyleOption.values.map((opt) {
                  final isSelected = _selectedStyle == opt;
                  return ListTile(
                    leading: Icon(
                      opt.icon,
                      color: isSelected
                          ? AppTheme.primaryTeal
                          : Colors.grey.shade700,
                    ),
                    title: Text(
                      opt.name,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? AppTheme.primaryTeal
                            : Colors.black87,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.primaryTeal,
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_selectedStyle != opt) {
                        setState(() {
                          _selectedStyle = opt;
                          isMapReady = false;
                          _styleController = null;
                          _injectedRouteIds.clear();
                          _injectedSourceIds.clear();
                          _routeUpdateGeneration++;
                        });
                        _startStyleTimer();
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Build Method ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlaces;
    final initialGeographic = _sanitizedPlaces.isNotEmpty
        ? Geographic(
            lat: _sanitizedPlaces.first.latitude,
            lon: _sanitizedPlaces.first.longitude,
          )
        : (widget.startPoint != null &&
                  widget.startPoint!.latitude != 0.0 &&
                  !widget.startPoint!.latitude.isNaN
              ? Geographic(
                  lat: widget.startPoint!.latitude,
                  lon: widget.startPoint!.longitude,
                )
              : (currentLat != null && currentLon != null
                    ? Geographic(lat: currentLat!, lon: currentLon!)
                    : Geographic(lat: 20.5937, lon: 78.9629)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.layers_outlined),
            tooltip: 'Change Map Style',
            onPressed: _showStylePicker,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Fit Bounds',
            onPressed: () => fitPoints(filtered),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── MapLibre Map ──────────────────────────────────
          MapLibreMap(
            key: ValueKey(_selectedStyle.url),
            options: MapOptions(
              initCenter: initialGeographic,
              initZoom: _currentZoom,
              initStyle: _selectedStyle.url,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onStyleLoaded: (style) async {
              _styleLoadTimer?.cancel();
              _styleController = style;
              if (mounted) {
                setState(() {
                  isMapReady = true;
                  _hasStyleLoadError = false;
                });
              }

              await fitPoints(filtered);
              await _updateRoutesForDay(_selectedDay);
            },
            children: [
              WidgetLayer(
                markers: [
                  // Start point marker
                  if (widget.startPoint != null &&
                      widget.startPoint!.latitude != 0.0 &&
                      !widget.startPoint!.latitude.isNaN)
                    Marker(
                      point: Geographic(
                        lat: widget.startPoint!.latitude,
                        lon: widget.startPoint!.longitude,
                      ),
                      size: const Size(50, 60),
                      child: GestureDetector(
                        onTap: () async {
                          if (_mapController != null) {
                            await _mapController!.animateCamera(
                              center: Geographic(
                                lat: widget.startPoint!.latitude,
                                lon: widget.startPoint!.longitude,
                              ),
                              zoom: 15.0,
                            );
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Start Location: ${widget.startPoint!.name} (Leaves at ${widget.startPoint!.departureTime})",
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade800,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
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
                            Icon(
                              Icons.home_filled,
                              color: Colors.green.shade800,
                              size: 28,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Sequenced Attraction Markers
                  ...filtered.asMap().entries.map((entry) {
                    final index = entry.key;
                    final place = entry.value;
                    final color = _getDayColor(place.dayNumber);
                    final isSelected = _selectedPlace?.name == place.name;
                    final displayNum = place.stopNumber > 0
                        ? place.stopNumber
                        : (index + 1);

                    return Marker(
                      point: Geographic(
                        lat: place.latitude,
                        lon: place.longitude,
                      ),
                      size: isSelected
                          ? const Size(56, 74)
                          : const Size(46, 62),
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
                                index == 0
                                    ? Icons.stars_rounded
                                    : Icons.location_on,
                                color: isSelected
                                    ? Colors.black87
                                    : (index == 0
                                          ? Colors.amber.shade800
                                          : color),
                                size: isSelected ? 38 : 30,
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
                      size: const Size(32, 32),
                      child: GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "Your Current Position: ${currentLat!.toStringAsFixed(4)}, ${currentLon!.toStringAsFixed(4)}",
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.my_location,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ── Top Day Filter Chips ──────────────────────────
          if (_availableDays.isNotEmpty)
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
                        'All Days (${_sanitizedPlaces.length})',
                        style: TextStyle(
                          color: _selectedDay == 0
                              ? Colors.white
                              : Colors.black87,
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
                      final count = _sanitizedPlaces
                          .where((p) => p.dayNumber == d)
                          .length;

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

          // ── Style Load Error / Slow Network Banner ────────
          if (_hasStyleLoadError)
            Positioned(
              top: 60,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade400),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Map tiles are taking long to load.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedStyle = MapStyleOption.liberty;
                          isMapReady = false;
                        });
                        _startStyleTimer();
                      },
                      child: const Text('Try OSM'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Loading Overlay ───────────────────────────────
          if (!isMapReady)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Loading map & road routes...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── Empty State ───────────────────────────────────
          if (filtered.isEmpty && widget.startPoint == null)
            Center(
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        size: 44,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Locations Available',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'No coordinates found for this selection.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Return to Trip'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ── On-Map Floating Camera & Control Buttons ──────
          Positioned(
            right: 14,
            bottom: filtered.isNotEmpty ? 130 : 30,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Zoom In
                _buildMapControlFab(
                  heroTag: 'zoom_in',
                  icon: Icons.add,
                  tooltip: 'Zoom In',
                  onPressed: () => _zoomBy(1.0),
                ),
                const SizedBox(height: 6),

                // Zoom Out
                _buildMapControlFab(
                  heroTag: 'zoom_out',
                  icon: Icons.remove,
                  tooltip: 'Zoom Out',
                  onPressed: () => _zoomBy(-1.0),
                ),
                const SizedBox(height: 6),

                // My Location GPS
                _buildMapControlFab(
                  heroTag: 'my_location',
                  icon: Icons.my_location,
                  tooltip: 'My Location',
                  color: Colors.blueAccent,
                  isLoading: loadingLocation,
                  onPressed: () => _getCurrentLocation(centerOnUser: true),
                ),
                const SizedBox(height: 6),

                // Map Theme Switcher
                _buildMapControlFab(
                  heroTag: 'map_layers',
                  icon: Icons.layers_outlined,
                  tooltip: 'Map Theme',
                  onPressed: _showStylePicker,
                ),
                const SizedBox(height: 6),

                // Leg Details (if legs exist)
                if (_filteredLegs.isNotEmpty)
                  _buildMapControlFab(
                    heroTag: 'legs_info',
                    icon: Icons.alt_route,
                    tooltip: 'Transit & Leg Details',
                    color: AppTheme.primaryTeal,
                    onPressed: () {
                      if (_filteredLegs.isNotEmpty) {
                        _showLegDetailsSheet(_filteredLegs.first);
                      }
                    },
                  ),
                if (_filteredLegs.isNotEmpty) const SizedBox(height: 6),

                // Open in Google Maps
                _buildMapControlFab(
                  heroTag: 'open_gmaps',
                  icon: Icons.directions,
                  tooltip: 'Open in Google Maps',
                  color: Colors.green.shade700,
                  onPressed: _openInGoogleMaps,
                ),
                const SizedBox(height: 6),

                // Fit Bounds
                _buildMapControlFab(
                  heroTag: 'fit_bounds',
                  icon: Icons.aspect_ratio,
                  tooltip: 'Fit Bounds',
                  backgroundColor: Colors.grey.shade900,
                  color: Colors.white,
                  onPressed: () => fitPoints(filtered),
                ),
              ],
            ),
          ),

          // ── Bottom Place Cards Carousel ───────────────────
          if (filtered.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
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
                  final displayNum = place.stopNumber > 0
                      ? place.stopNumber
                      : (index + 1);

                  return GestureDetector(
                    onTap: () =>
                        goToLocation(place.latitude, place.longitude, place),
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
    );
  }

  Widget _buildMapControlFab({
    required String heroTag,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
    Color? backgroundColor,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: backgroundColor ?? Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isLoading ? null : onPressed,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(icon, size: 20, color: color ?? Colors.grey.shade800),
            ),
          ),
        ),
      ),
    );
  }
}
