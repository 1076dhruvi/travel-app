import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import '../services/itinerary_service.dart';
import '../services/routing_service.dart';
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
  final Set<String> expandedStopNames = {};

  final ItineraryService itineraryService = ItineraryService();
  final RoutingService routingService = RoutingService();
  final GeocodingService geocodingService = GeocodingService();
  final DatabaseService databaseService = DatabaseService();

  Map<String, dynamic>? routingData;
  Map<String, dynamic>? itineraryData;
  List<ItineraryPlace> itineraryMapPlaces = [];
  List<ItineraryLeg> itineraryLegs = [];
  StartPoint? itineraryStartPoint;

  bool isLoading = false;
  bool isPreferencesExpanded = false;

  // Start Point Detection & Manual Entry
  String startPointName = "Detecting start location...";
  double? startLat;
  double? startLon;
  bool isDetectingLocation = false;
  String? locationStatusMessage;

  // Selected Day Filter: 0 = All Days, 1 = Day 1, etc.
  int selectedDayTab = 0;

  final List<String> interests = [
    "Beaches",
    "History",
    "Food",
    "Nature",
    "Adventure",
    "Shopping",
    "Culture",
    "Relaxation",
    "Architecture",
    "Photography",
  ];

  final List<Color> dayColors = [
    const Color(0xFF673AB7), // Deep Purple
    const Color(0xFF00897B), // Teal
    const Color(0xFFE65100), // Deep Orange
    const Color(0xFFD81B60), // Pink
    const Color(0xFF1E88E5), // Blue
    const Color(0xFFF57F17), // Amber
  ];

  Color _getDayColor(int dayNum) {
    var effectiveDay = dayNum;
    if (effectiveDay < 1) effectiveDay = 1;
    return dayColors[(effectiveDay - 1) % dayColors.length];
  }

  IconData _getTransportIcon(String? mode) {
    final m = (mode ?? '').toLowerCase();
    if (m.contains('walk')) return Icons.directions_walk;
    if (m.contains('metro') || m.contains('subway') || m.contains('tube')) {
      return Icons.subway;
    }
    if (m.contains('bus')) return Icons.directions_bus;
    if (m.contains('train') || m.contains('rail')) return Icons.train;
    if (m.contains('boat') || m.contains('ferry')) return Icons.directions_boat;
    if (m.contains('auto') ||
        m.contains('rickshaw') ||
        m.contains('taxi') ||
        m.contains('cab')) {
      return Icons.local_taxi;
    }
    if (m.contains('car') || m.contains('drive')) return Icons.directions_car;
    return Icons.alt_route;
  }

  @override
  void initState() {
    super.initState();
    _detectUserLocation();
    _loadSavedItinerary();
  }

  // ── Start Point & Location Handling ────────────────────────

  Future<void> _detectUserLocation() async {
    setState(() {
      isDetectingLocation = true;
      locationStatusMessage = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            isDetectingLocation = false;
            startPointName = "${widget.trip.location} City Center";
            locationStatusMessage =
                "Location services disabled on device. Set start point manually or enable GPS.";
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            isDetectingLocation = false;
            startPointName = "${widget.trip.location} City Center";
            locationStatusMessage =
                "Location permission denied. Enter your hotel or starting address manually.";
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          startLat = position.latitude;
          startLon = position.longitude;
          startPointName =
              "Current Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})";
          locationStatusMessage = null;
          isDetectingLocation = false;

          itineraryStartPoint = StartPoint(
            name: startPointName,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDetectingLocation = false;
          startPointName = "${widget.trip.location} City Center";
          locationStatusMessage =
              "Could not retrieve GPS location. Tap 'Set Manually' to enter your starting point.";
        });
      }
    }
  }

  void _showManualStartPointDialog() {
    final textController = TextEditingController(
      text: startPointName.startsWith("Current Location") ? "" : startPointName,
    );
    bool isSearching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_location_alt, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text("Set Starting Point"),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter your hotel name, airport, or starting address. The itinerary and shortest travel paths will be calculated from here.",
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "e.g. Grand Hyatt ${widget.trip.location}",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: textController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setDialogState(() => textController.clear()),
                          )
                        : null,
                  ),
                ),
                if (searchError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    searchError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                if (isSearching) ...[
                  const SizedBox(height: 12),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSearching
                    ? null
                    : () async {
                        final input = textController.text.trim();
                        if (input.isEmpty) return;

                        setDialogState(() {
                          isSearching = true;
                          searchError = null;
                        });

                        try {
                          final coords = await geocodingService.getCoordinates(
                            "$input, ${widget.trip.location}",
                          );

                          if (coords != null) {
                            if (mounted) {
                              setState(() {
                                startPointName = input;
                                startLat = coords["lat"];
                                startLon = coords["lon"];
                                locationStatusMessage = null;
                                itineraryStartPoint = StartPoint(
                                  name: input,
                                  latitude: coords["lat"]!,
                                  longitude: coords["lon"]!,
                                );
                              });
                            }
                            if (dialogCtx.mounted) {
                              Navigator.pop(dialogCtx);
                            }
                          } else {
                            setDialogState(() {
                              isSearching = false;
                              searchError =
                                  "Location not found. Please try a more specific name.";
                            });
                          }
                        } catch (e) {
                          setDialogState(() {
                            isSearching = false;
                            searchError = "Geocoding error: $e";
                          });
                        }
                      },
                child: const Text("Set Location"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Database Persistence ──────────────────────────────────

  Future<void> _loadSavedItinerary() async {
    try {
      if (widget.trip.id == null) return;
      final savedJson = await databaseService.getItinerary(widget.trip.id!);
      if (savedJson != null) {
        final Map<String, dynamic> parsed = jsonDecode(savedJson);

        List<ItineraryPlace> loadedPlaces = [];
        if (parsed["mapPlaces"] != null) {
          for (var p in parsed["mapPlaces"]) {
            loadedPlaces.add(
              ItineraryPlace.fromMap(Map<String, dynamic>.from(p)),
            );
          }
        }

        List<ItineraryLeg> loadedLegs = [];
        if (parsed["legs"] != null) {
          for (var l in parsed["legs"]) {
            loadedLegs.add(
              ItineraryLeg.fromMap(Map<String, dynamic>.from(l)),
            );
          }
        }

        StartPoint? loadedStart;
        if (parsed["startPoint"] != null) {
          loadedStart = StartPoint.fromMap(Map<String, dynamic>.from(parsed["startPoint"]));
        }

        setState(() {
          itineraryData = parsed["itineraryData"];
          routingData = parsed["routingData"];
          itineraryMapPlaces = loadedPlaces;
          itineraryLegs = loadedLegs;
          if (loadedStart != null) {
            itineraryStartPoint = loadedStart;
            startPointName = loadedStart.name;
            startLat = loadedStart.latitude;
            startLon = loadedStart.longitude;
          }
          isPreferencesExpanded = false;
        });
      } else {
        setState(() {
          isPreferencesExpanded = true;
        });
      }
    } catch (e) {
      debugPrint("Error loading saved itinerary: $e");
    }
  }

  Future<void> _saveCurrentItinerary() async {
    if (widget.trip.id == null) return;

    final dataToSave = {
      "itineraryData": itineraryData,
      "routingData": routingData,
      "mapPlaces": itineraryMapPlaces.map((p) => p.toMap()).toList(),
      "legs": itineraryLegs.map((l) => l.toMap()).toList(),
      "startPoint": itineraryStartPoint?.toMap(),
    };

    await databaseService.saveItinerary(
      widget.trip.id!,
      jsonEncode(dataToSave),
    );
  }

  // ── Itinerary Generation Pipeline ──────────────────────────

  Future<void> _generateItinerary() async {
    setState(() {
      isLoading = true;
    });

    try {
      debugPrint("Generating refined itinerary for ${widget.trip.location}...");

      Map<String, dynamic>? startPointPayload;
      if (startLat != null && startLon != null) {
        startPointPayload = {
          "name": startPointName,
          "lat": startLat,
          "lon": startLon,
        };
      }

      final result = await itineraryService.generateItinerary(
        destination: widget.trip.location,
        days: widget.trip.days,
        interests: selectedInterests.toList(),
        startPoint: startPointPayload,
      );

      List<ItineraryPlace> allPlaces = [];
      List<ItineraryLeg> allLegs = [];
      StartPoint? resolvedStart;

      if (result != null && result["startPoint"] != null) {
        resolvedStart = StartPoint.fromMap(
          Map<String, dynamic>.from(result["startPoint"]),
        );
      }

      if (result != null && result["itinerary"] != null) {
        for (var dayData in result["itinerary"]) {
          int dayNum = dayData["day"] is int
              ? dayData["day"]
              : int.tryParse(dayData["day"].toString()) ?? 1;

          String dayTitle = "Day $dayNum";

          // Attractions
          if (dayData["attractions"] != null) {
            for (var place in dayData["attractions"]) {
              final mapped = Map<String, dynamic>.from(place);
              mapped["day"] = dayTitle;
              mapped["dayNumber"] = dayNum;
              allPlaces.add(ItineraryPlace.fromMap(mapped));
            }
          }

          // Legs
          if (dayData["legs"] != null) {
            for (var leg in dayData["legs"]) {
              allLegs.add(
                ItineraryLeg.fromMap(Map<String, dynamic>.from(leg)),
              );
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        itineraryData = result;
        itineraryMapPlaces = allPlaces;
        itineraryLegs = allLegs;
        if (resolvedStart != null) {
          itineraryStartPoint = resolvedStart;
          startPointName = resolvedStart.name;
          startLat = resolvedStart.latitude;
          startLon = resolvedStart.longitude;
        }
        isPreferencesExpanded = false;
        selectedDayTab = 0;
      });

      await _saveCurrentItinerary();
    } catch (e) {
      debugPrint("ERROR DETAILS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
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
  }

  void _openMap({int initialDay = 0}) {
    if (itineraryMapPlaces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No map coordinates available yet")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          title: "${widget.trip.location} Route Map",
          places: itineraryMapPlaces,
          legs: itineraryLegs,
          startPoint: itineraryStartPoint,
          initialDay: initialDay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysList = (itineraryData != null && itineraryData!["itinerary"] != null)
        ? (itineraryData!["itinerary"] as List)
        : [];

    final hasItinerary = daysList.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("${widget.trip.location} Itinerary"),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasItinerary)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: "View Map",
              onPressed: () => _openMap(initialDay: selectedDayTab),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Summary & Action Banner ───────────────────
            _buildTopBanner(hasItinerary),

            // ── Start Point Card ──────────────────────────────
            _buildStartPointCard(),

            // ── Expandable Preferences Section ───────────────
            _buildPreferencesSection(hasItinerary),

            // ── Itinerary Content ────────────────────────────
            if (hasItinerary) ...[
              _buildDayTabsBar(daysList),
              _buildDaysContent(daysList),
            ] else if (!isLoading) ...[
              _buildEmptyState(),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: hasItinerary
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.map, color: Colors.white),
                        label: Text(
                          selectedDayTab == 0
                              ? "View Full Route Map (${itineraryMapPlaces.length} Stops)"
                              : "View Day $selectedDayTab on Map",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedDayTab == 0
                              ? Colors.deepPurple
                              : _getDayColor(selectedDayTab),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _openMap(initialDay: selectedDayTab),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildTopBanner(bool hasItinerary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.trip.location,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${widget.trip.days} Days • ${itineraryMapPlaces.length} Stops • Clustered by Area",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasItinerary)
                TextButton.icon(
                  icon: Icon(
                    isPreferencesExpanded ? Icons.keyboard_arrow_up : Icons.tune,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    isPreferencesExpanded ? "Close" : "Preferences",
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      isPreferencesExpanded = !isPreferencesExpanded;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartPointCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.deepPurple.shade100),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trip_origin, color: Colors.deepPurple, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Itinerary Start Point",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (isDetectingLocation)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  startPointName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.gps_fixed, size: 14),
                label: const Text("GPS", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: isDetectingLocation ? null : _detectUserLocation,
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_location_alt, size: 14),
                label: const Text("Edit", style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showManualStartPointDialog,
              ),
            ],
          ),
          if (locationStatusMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              locationStatusMessage!,
              style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreferencesSection(bool hasItinerary) {
    if (!isPreferencesExpanded && hasItinerary) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Select Your Interests",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Attractions are geographically clustered so each day covers one area with no repetition, ordered by shortest path from your start point.",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: interests.map((interest) {
              final isSelected = selectedInterests.contains(interest);
              return FilterChip(
                label: Text(
                  interest,
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: Colors.deepPurple,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
                  ),
                ),
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
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading ? null : _generateItinerary,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Calculating Optimal Routes & Schedules...",
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    )
                  : Text(
                      hasItinerary ? "Regenerate Itinerary" : "Generate Itinerary",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabsBar(List daysList) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: daysList.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = selectedDayTab == 0;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text(
                  "All Days",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                selected: isSelected,
                selectedColor: Colors.deepPurple,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                backgroundColor: Colors.white,
                elevation: isSelected ? 2 : 0,
                onSelected: (sel) {
                  if (sel) setState(() => selectedDayTab = 0);
                },
              ),
            );
          }

          final dayData = daysList[index - 1];
          final dayNum = dayData["day"] is int
              ? dayData["day"]
              : int.tryParse(dayData["day"].toString()) ?? index;

          final isSelected = selectedDayTab == dayNum;
          final color = _getDayColor(dayNum);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: CircleAvatar(
                backgroundColor: isSelected ? Colors.white : color,
                radius: 5,
              ),
              label: Text(
                "Day $dayNum",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              selected: isSelected,
              selectedColor: color,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
              ),
              backgroundColor: Colors.white,
              elevation: isSelected ? 2 : 0,
              onSelected: (sel) {
                if (sel) setState(() => selectedDayTab = dayNum);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDaysContent(List daysList) {
    final filteredDays = selectedDayTab == 0
        ? daysList
        : daysList.where((d) {
            final num = d["day"] is int
                ? d["day"]
                : int.tryParse(d["day"].toString()) ?? 1;
            return num == selectedDayTab;
          }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredDays.length,
      itemBuilder: (context, dayIndex) {
        final day = filteredDays[dayIndex];
        final dayNum = day["day"] is int
            ? day["day"]
            : int.tryParse(day["day"].toString()) ?? (dayIndex + 1);
        final theme = day["theme"]?.toString() ?? "Day $dayNum Sightseeing";
        final area = day["area"]?.toString();
        final attractions = (day["attractions"] as List?) ?? [];
        final legs = (day["legs"] as List?) ?? (day["travel"] as List?) ?? [];
        final color = _getDayColor(dayNum);

        // Totals
        final totalStops = day["totalStops"] ?? attractions.length;
        final totalKm = day["totalKm"]?.toString() ?? "";
        final totalTransit = day["totalTransitTime"]?.toString() ?? "";

        // Start point
        final dayStartPoint = day["startPoint"] != null
            ? Map<String, dynamic>.from(day["startPoint"])
            : null;
        final startName = dayStartPoint?["name"] ?? startPointName;
        final departureTime = dayStartPoint?["departureTime"] ?? "09:00";

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Day Header Banner with Area & Totals ──────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: color.withValues(alpha: 0.2)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "DAY $dayNum",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            theme,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.map_outlined, color: color, size: 22),
                          tooltip: "View Day $dayNum Map",
                          onPressed: () => _openMap(initialDay: dayNum),
                        ),
                      ],
                    ),
                    if (area != null && area.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.near_me, size: 13, color: color),
                          const SizedBox(width: 4),
                          Text(
                            "Area: $area (No cross-area repetition)",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Totals Row
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(Icons.flag_outlined, "$totalStops stops"),
                          if (totalKm.isNotEmpty)
                            _buildMiniStat(Icons.straighten, totalKm),
                          if (totalTransit.isNotEmpty)
                            _buildMiniStat(Icons.timer_outlined, totalTransit),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Start Point Departure Row ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_filled, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Start: $startName",
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Departs at $departureTime",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Attractions Timeline & Legs ───────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attractions.length,
                  itemBuilder: (ctx, idx) {
                    final place = attractions[idx];
                    final leg = (idx < legs.length) ? legs[idx] : null;

                    return Column(
                      children: [
                        // Leg connecting to this stop (Leg 0 is start->stop 1, Leg 1 is stop 1->stop 2)
                        _buildTravelConnector(leg, color),
                        // Stop card
                        _buildPlaceCard(place, idx + 1, color, dayNum),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniStat(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade700),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(
    dynamic placeMap,
    int index,
    Color dayColor,
    int dayNum,
  ) {
    final Map<dynamic, dynamic> place = placeMap is Map ? placeMap : {};
    final name = place["name"]?.toString() ?? "";
    final description = place["description"]?.toString() ?? "";
    final arrivalTime = place["arrivalTime"]?.toString() ?? place["time"]?.toString();
    final leaveTime = place["leaveTime"]?.toString();
    final duration = place["duration"]?.toString();
    final bestTime = place["bestTime"]?.toString();
    final openingHours = place["openingHours"]?.toString() ?? "check locally";

    final isExpanded = expandedStopNames.contains(name);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Number badge & Time column
        SizedBox(
          width: 58,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: dayColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dayColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    "$index",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (arrivalTime != null && arrivalTime.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  arrivalTime,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
              if (leaveTime != null && leaveTime.isNotEmpty) ...[
                Text(
                  "- $leaveTime",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 10),

        // Place details card with expandable details
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    expandedStopNames.remove(name);
                  } else {
                    expandedStopNames.add(name);
                  }
                });
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                    ],
                  ),

                  // One-line reason
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                  ],

                  // Chips: Opening hours & Best time
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: Colors.teal),
                            const SizedBox(width: 4),
                            Text(
                              "Hours: $openingHours",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.teal.shade900,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (bestTime != null && bestTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_sunny_outlined, size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                "Best: $bestTime",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Expandable Section
                  if (isExpanded) ...[
                    const Divider(height: 18),
                    if (duration != null && duration.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          "Suggested Stay: $duration",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.map, size: 14),
                          label: const Text("View on Map", style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dayColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () => _openMap(initialDay: dayNum),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTravelConnector(dynamic travelMap, Color dayColor) {
    final Map<dynamic, dynamic> travel = travelMap is Map ? travelMap : {};
    final distance = travel["distance"]?.toString();
    final duration = travel["duration"]?.toString();
    final mode = travel["mode"]?.toString();
    final transitLine = travel["transitLine"]?.toString() ?? travel["details"]?.toString();

    final transportIcon = _getTransportIcon(mode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Timeline vertical bar
        SizedBox(
          width: 58,
          child: Center(
            child: Container(
              width: 2,
              height: 48,
              color: dayColor.withValues(alpha: 0.35),
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Leg connector pill
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(transportIcon, size: 16, color: dayColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      if (distance != null && distance.isNotEmpty)
                        Text(
                          distance,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      if (distance != null && duration != null)
                        const Text(" • ", style: TextStyle(fontSize: 12)),
                      if (duration != null && duration.isNotEmpty)
                        Text(
                          duration,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      if (mode != null && mode.isNotEmpty) ...[
                        const Text(" via ", style: TextStyle(fontSize: 11)),
                        Text(
                          mode.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: dayColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (transitLine != null && transitLine.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      transitLine,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.explore_outlined,
            size: 56,
            color: Colors.deepPurple.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            "No Itinerary Generated Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Confirm your starting point above, select your interests, and tap 'Generate Itinerary' to build a day-by-day plan clustered geographically with real transit times and opening hours.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}