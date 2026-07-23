import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';
import '../services/geocoding_service.dart';

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

  final GeocodingService geocodingService = GeocodingService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Map"),
      ),

      body: MapLibreMap(
        options: MapOptions(
          initCenter: Geographic(
            lat: widget.latitude,
            lon: widget.longitude,
          ),
          initZoom: 10,
          initStyle:
          "https://api.maptiler.com/maps/streets-v2/style.json?key=nzRnCgH9OEgYFqjDaIoO",
        ),

        onMapCreated: (controller) {
          mapController = controller;
        },

        onStyleLoaded: (style) {
          debugPrint("Map Loaded Successfully!");
        },
      ),
    );
  }
}