import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import 'package:geolocator/geolocator.dart' as geo;

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
  MapController? mapController;
  double? currentLat;
  double? currentLon;
  bool loadingLocation = true;
  bool isMapReady = false;

  final List<Color> dayColors = [
    Colors.deepPurple,
    Colors.deepOrange,
    Colors.teal,
    Colors.pinkAccent,
    Colors.indigo,
    Colors.amber,
  ];

  Color _getDayColor(int dayNum) {
    if (dayNum < 1) dayNum = 1;
    return dayColors[(dayNum - 1) % dayColors.length];
  }

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
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

    try {
      geo.Position position = await geo.Geolocator.getCurrentPosition(
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
      debugPrint("Location Error: $e");
      if (mounted) setState(() => loadingLocation = false);
    }
  }

  double _calculateDistanceInKm(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  double _getDynamicZoom(double distanceKm) {
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

  void fitAllPoints() async {
    if (mapController == null || !isMapReady || widget.places.isEmpty) return;

    // Use only itinerary place coordinates so distant user location doesn't break zoom
    List<double> lats = widget.places.map((p) => p.latitude).toList();
    List<double> lons = widget.places.map((p) => p.longitude).toList();

    double minLat = lats.reduce(math.min);
    double maxLat = lats.reduce(math.max);
    double minLon = lons.reduce(math.min);
    double maxLon = lons.reduce(math.max);

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final maxDistKm = _calculateDistanceInKm(minLat, minLon, maxLat, maxLon);

    await mapController!.animateCamera(
      center: Geographic(lat: centerLat, lon: centerLon),
      zoom: _getDynamicZoom(maxDistKm),
    );
  }

  Future<void> goToLocation(double lat, double lon) async {
    if (mapController == null) return;
    await mapController!.animateCamera(
      center: Geographic(lat: lat, lon: lon),
      zoom: 15,
    );
  }

  Map<int, List<ItineraryPlace>> _groupPlacesByDay() {
    Map<int, List<ItineraryPlace>> grouped = {};
    for (var place in widget.places) {
      grouped.putIfAbsent(place.dayNumber, () => []).add(place);
    }
    return grouped;
  }

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
              initStyle: "https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json",
            ),
            onMapCreated: (controller) {
              mapController = controller;
            },
            onStyleLoaded: (style) {
              if (mounted) {
                setState(() => isMapReady = true);
                fitAllPoints();
              }
            },
            children: [
              WidgetLayer(
                markers: [
                  // Location stop markers
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
                        onTap: () => goToLocation(place.latitude, place.longitude),
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
                                "${index + 1}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Icon(
                              index == 0 ? Icons.stars_rounded : Icons.location_on,
                              color: index == 0 ? Colors.amber : color,
                              size: 32,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // User current position marker (only shown if detected)
                  if (currentLat != null && currentLon != null)
                    Marker(
                      point: Geographic(lat: currentLat!, lon: currentLon!),
                      size: const Size(30, 30),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Colors.black38, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (loadingLocation) const Center(child: CircularProgressIndicator()),

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
                  onTap: () => goToLocation(place.latitude, place.longitude),
                  child: Card(
                    margin: const EdgeInsets.only(right: 12),
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: color,
                            radius: 16,
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                place.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              if (place.day != null)
                                Text(
                                  place.day!,
                                  style: TextStyle(
                                      color: Colors.grey.shade600, fontSize: 12),
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
          heroTag: "fit_all",
          backgroundColor: Colors.grey.shade900,
          onPressed: fitAllPoints,
          child: const Icon(Icons.aspect_ratio, color: Colors.white),
        ),
      ),
    );
  }
}