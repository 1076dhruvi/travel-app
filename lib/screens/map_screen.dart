import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import 'package:geolocator/geolocator.dart' as geo;

class MapScreen extends StatefulWidget {
  final String location;
  final double latitude;
  final double longitude;

  const MapScreen({
    super.key,
    required this.location,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapController? mapController;

  double? currentLat;
  double? currentLon;

  bool loadingLocation = true;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    bool serviceEnabled =
    await geo.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      setState(() => loadingLocation = false);
      return;
    }

    geo.LocationPermission permission =
    await geo.Geolocator.checkPermission();

    if (permission == geo.LocationPermission.denied) {
      permission =
      await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.denied ||
        permission ==
            geo.LocationPermission.deniedForever) {
      setState(() => loadingLocation = false);
      return;
    }

    geo.Position position =
    await geo.Geolocator.getCurrentPosition(
      desiredAccuracy:
      geo.LocationAccuracy.bestForNavigation,
    );

    debugPrint(
        "Latitude: ${position.latitude}");
    debugPrint(
        "Longitude: ${position.longitude}");

    setState(() {
      currentLat = position.latitude;
      currentLon = position.longitude;
      loadingLocation = false;
    });
  }

  Future<void> goToCurrentLocation() async {
    if (mapController == null ||
        currentLat == null ||
        currentLon == null) return;

    await mapController!.animateCamera(
      center: Geographic(
        lat: currentLat!,
        lon: currentLon!,
      ),
      zoom: 15,
    );
  }

  Future<void> goToDestination() async {
    if (mapController == null) return;

    await mapController!.animateCamera(
      center: Geographic(
        lat: widget.latitude,
        lon: widget.longitude,
      ),
      zoom: 14,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.location),
        backgroundColor: Colors.deepPurple,
      ),

      body: Stack(
        children: [
          MapLibreMap(
            options: MapOptions(
              initCenter: Geographic(
                lat: widget.latitude,
                lon: widget.longitude,
              ),
              initZoom: 12,
              initStyle:
              "https://api.maptiler.com/maps/streets-v2/style.json?key=nzRnCgH9OEgYFqjDaIoO",
            ),

            onMapCreated: (controller) {
              mapController = controller;
            },

            children: [
              WidgetLayer(
                markers: [

                  // Destination Marker
                  Marker(
                    point: Geographic(
                      lat: widget.latitude,
                      lon: widget.longitude,
                    ),

                    size: const Size(40, 40),

                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),

                  // User Marker
                  if (currentLat != null &&
                      currentLon != null)
                    Marker(
                      point: Geographic(
                        lat: currentLat!,
                        lon: currentLon!,
                      ),

                      size: const Size(28, 28),

                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        width: 18,
                        height: 18,
                      ),
                    ),
                ],
              ),
            ],
          ),

          if (loadingLocation)
            const Center(
              child: CircularProgressIndicator(),
            ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.place,
                  color: Colors.red,
                ),
                title: Text(widget.location),
                subtitle:
                const Text("Trip Destination"),
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          FloatingActionButton(
            heroTag: "destination",
            backgroundColor: Colors.red,
            onPressed: goToDestination,
            child: const Icon(Icons.place),
          ),

          const SizedBox(height: 12),

          FloatingActionButton(
            heroTag: "location",
            backgroundColor: Colors.deepPurple,
            onPressed: goToCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}