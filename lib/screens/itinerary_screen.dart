import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/itinerary_service.dart';
import '../models/trip.dart';
import '../services/routing_service.dart';
import '../services/geocoding_service.dart';
import 'map_screen.dart';

class ItineraryScreen extends StatefulWidget {
  final Trip trip;

  const ItineraryScreen({
    super.key,
    required this.trip,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {
  final Set<String> selectedInterests = {};

  final ItineraryService itineraryService = ItineraryService();
  final RoutingService routingService = RoutingService();
  final GeocodingService geocodingService = GeocodingService();

  Map<String, dynamic>? routingData;
  Map<String, dynamic>? itineraryData;
  List<ItineraryPlace> itineraryMapPlaces = [];
  bool isLoading = false;

  final List<String> interests = [
    "Beaches",
    "History",
    "Food",
    "Nature",
    "Adventure",
    "Shopping",
  ];

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742 * math.asin(math.sqrt(a));
  }

  // Optimize places BY DAY strictly so days never mix up their colors
  List<ItineraryPlace> _optimizePlacesByProximity(List<ItineraryPlace> places) {
    if (places.isEmpty) return places;

    // Group places by day number
    Map<int, List<ItineraryPlace>> groupedByDay = {};
    for (var place in places) {
      groupedByDay.putIfAbsent(place.dayNumber, () => []).add(place);
    }

    List<ItineraryPlace> finalOptimizedList = [];

    // Optimize route order within each day individually
    groupedByDay.forEach((dayNum, dayPlaces) {
      if (dayPlaces.length <= 2) {
        finalOptimizedList.addAll(dayPlaces);
      } else {
        List<ItineraryPlace> unvisited = List.from(dayPlaces);
        List<ItineraryPlace> sortedDay = [unvisited.removeAt(0)];

        while (unvisited.isNotEmpty) {
          final current = sortedDay.last;
          int nearestIndex = 0;
          double minDistance = double.infinity;

          for (int i = 0; i < unvisited.length; i++) {
            final dist = _calculateDistance(
              current.latitude,
              current.longitude,
              unvisited[i].latitude,
              unvisited[i].longitude,
            );
            if (dist < minDistance) {
              minDistance = dist;
              nearestIndex = i;
            }
          }
          sortedDay.add(unvisited.removeAt(nearestIndex));
        }

        finalOptimizedList.addAll(sortedDay);
      }
    });

    return finalOptimizedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.trip.location} Itinerary"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    "Plan Your ${widget.trip.location} Trip",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Select your interests to generate a personalized itinerary.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              "Choose Interests",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: interests.map((interest) {
                return FilterChip(
                  label: Text(
                    interest,
                    style: TextStyle(
                      color: selectedInterests.contains(interest)
                          ? Colors.white
                          : Colors.black87,
                    ),
                  ),
                  selected: selectedInterests.contains(interest),
                  selectedColor: Colors.deepPurple,
                  backgroundColor: Colors.grey.shade200,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        selectedInterests.add(interest);
                      } else {
                        selectedInterests.remove(interest);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                  setState(() {
                    isLoading = true;
                  });

                  try {
                    debugPrint("Generating itinerary...");

                    final result = await itineraryService.generateItinerary(
                      destination: widget.trip.location,
                      days: widget.trip.days,
                      interests: selectedInterests.toList(),
                    );

                    List<String> places = [];
                    List<ItineraryPlace> rawMapPlaces = [];
                    final seen = <String>{};

                    if (result != null && result["itinerary"] != null) {
                      for (var dayData in result["itinerary"]) {
                        int dayNum = dayData["day"] is int
                            ? dayData["day"]
                            : int.tryParse(dayData["day"].toString()) ?? 1;

                        String dayTitle = "Day $dayNum";

                        if (dayData["attractions"] != null) {
                          for (var place in dayData["attractions"]) {
                            String name = place["name"]?.toString().trim() ?? "";
                            if (name.isEmpty) continue;

                            name = name.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

                            if (name.isNotEmpty && !seen.contains(name)) {
                              seen.add(name);
                              places.add(name);

                              double? lat = place["lat"] != null ? (place["lat"] as num).toDouble() : null;
                              double? lon = place["lon"] != null ? (place["lon"] as num).toDouble() : null;

                              if (lat == null || lon == null) {
                                final searchQuery = "$name, ${widget.trip.location}";
                                final coords = await geocodingService.getCoordinates(searchQuery);
                                if (coords != null) {
                                  lat = coords["lat"];
                                  lon = coords["lon"];
                                }
                              }

                              if (lat != null && lon != null) {
                                rawMapPlaces.add(
                                  ItineraryPlace(
                                    name: name,
                                    latitude: lat,
                                    longitude: lon,
                                    day: dayTitle,
                                    dayNumber: dayNum, // Strictly binding the day number here
                                  ),
                                );
                              }
                            }
                          }
                        }
                      }
                    }

                    // Sort places geographically strictly inside each Day boundary
                    List<ItineraryPlace> optimizedPlaces = _optimizePlacesByProximity(rawMapPlaces);

                    Map<String, dynamic>? route;
                    if (places.isNotEmpty) {
                      try {
                        route = await routingService.optimizeRoute(
                          widget.trip.location,
                          places,
                        );
                      } catch (routingError) {
                        debugPrint("Routing Service Error: $routingError");
                      }
                    }

                    setState(() {
                      itineraryData = result;
                      routingData = route;
                      itineraryMapPlaces = optimizedPlaces;
                    });
                  } catch (e) {
                    debugPrint("ERROR DETAILS: $e");

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red,
                          content: Text(
                            "Failed: ${e.toString().replaceAll('Exception: ', '')}",
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        isLoading = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Generate Itinerary",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 🗺️ View Route On Map Action Button
            if (itineraryMapPlaces.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: Text("View Route Map (${itineraryMapPlaces.length} Stops)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          title: "${widget.trip.location} Route Map",
                          places: itineraryMapPlaces,
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Optimized Routes List
            if (routingData != null &&
                routingData!["routes"] != null &&
                (routingData!["routes"] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Optimized Route",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...List.generate(
                    routingData!["routes"].length,
                        (index) {
                      final route = routingData!["routes"][index];
                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(
                            Icons.route,
                            color: Colors.deepPurple,
                          ),
                          title: Text("${route["from"]} → ${route["to"]}"),
                          subtitle: Text(
                            "Distance: ${route["distance"] ?? "N/A"}\nTime: ${route["time"] ?? "N/A"}",
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                ],
              ),

            // Generated Itinerary Display
            if (itineraryData != null &&
                itineraryData!["itinerary"] != null &&
                (itineraryData!["itinerary"] as List).isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Your Itinerary",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  ...List.generate(
                    itineraryData!["itinerary"].length,
                        (index) {
                      final day = itineraryData!["itinerary"][index];

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 15),
                        child: Padding(
                          padding: const EdgeInsets.all(15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Day ${day["day"]}",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (day["attractions"] != null)
                                ...List.generate(
                                  day["attractions"].length,
                                      (i) {
                                    final place = day["attractions"][i];

                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: Colors.deepPurple,
                                        foregroundColor: Colors.white,
                                        child: Text("${i + 1}"),
                                      ),
                                      title: Text(
                                        place["name"] ?? "",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        place["description"] ?? "",
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}