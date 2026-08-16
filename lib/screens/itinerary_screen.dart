import 'package:flutter/material.dart';
import '../services/itinerary_service.dart';
import '../models/trip.dart';
import '../services/routing_service.dart';

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

  Map<String, dynamic>? routingData;
  Map<String, dynamic>? itineraryData;
  bool isLoading = false;

  final List<String> interests = [
    "Beaches",
    "History",
    "Food",
    "Nature",
    "Adventure",
    "Shopping",
  ];

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
                    print("Generating itinerary...");

                    // 1. Call Gemini via backend service
                    final result =
                    await itineraryService.generateItinerary(
                      destination: widget.trip.location,
                      days: widget.trip.days,
                      interests: selectedInterests.toList(),
                    );

                    print("Itinerary Result: $result");

                    // 2. Extract and sanitize places for routing
                    List<String> places = [];
                    final seen = <String>{};

                    if (result != null && result["itinerary"] != null) {
                      for (var day in result["itinerary"]) {
                        if (day["attractions"] != null) {
                          for (var place in day["attractions"]) {
                            String name =
                                place["name"]?.toString().trim() ?? "";

                            if (name.isEmpty) continue;

                            // Strip parenthetical details like "(e.g., Cochin Cooking Class)"
                            name = name
                                .replaceAll(
                                RegExp(r'\s*\([^)]*\)'), '')
                                .trim();

                            // Ignore unwanted regional places outside scope
                            final lower = name.toLowerCase();
                            if (lower.contains(
                                "bannerghatta biological park") ||
                                lower.contains("mysore") ||
                                lower.contains("hampi") ||
                                lower.contains("coorg")) {
                              continue;
                            }

                            if (name.isNotEmpty && !seen.contains(name)) {
                              seen.add(name);
                              places.add(name);
                            }
                          }
                        }
                      }
                    }

                    print("Places sent to routing: $places");

                    // 3. Optimize route (Isolated so geocoding errors do NOT crash itinerary display)
                    Map<String, dynamic>? route;
                    if (places.isNotEmpty) {
                      try {
                        route = await routingService.optimizeRoute(
                          widget.trip.location,
                          places,
                        );
                      } catch (routingError) {
                        print(
                            "Routing Service Error (Non-Fatal): $routingError");
                      }
                    }

                    // 4. Update UI with itinerary (even if route optimization failed)
                    setState(() {
                      itineraryData = result;
                      routingData = route;
                    });
                  } catch (e) {
                    print("ERROR DETAILS: $e");

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
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.location_on,
                                        color: Colors.deepPurple,
                                      ),
                                      title: Text(
                                        place["name"] ?? "Unknown place",
                                      ),
                                      subtitle: Text(
                                        "${place["description"] != null ? "${place["description"]}\n" : ""}Best time: ${place["bestTime"] ?? "Anytime"}",
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