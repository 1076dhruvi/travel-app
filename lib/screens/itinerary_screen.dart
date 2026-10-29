import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../config/fare_config.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import '../services/geocoding_service.dart';
import '../services/google_places_service.dart';
import '../services/itinerary_service.dart';
import '../services/routing_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mumbai_darshan_view.dart';
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

class _ItineraryScreenState extends State<ItineraryScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> selectedInterests = {};
  final Set<String> expandedStopNames = {};
  final Set<String> expandedLegIndices = {};

  final ItineraryService itineraryService = ItineraryService();
  final RoutingService routingService = RoutingService();
  final GeocodingService geocodingService = GeocodingService();
  final GooglePlacesService googlePlacesService = GooglePlacesService();
  final DatabaseService databaseService = DatabaseService();

  Map<String, dynamic>? routingData;
  Map<String, dynamic>? itineraryData;
  List<ItineraryPlace> itineraryMapPlaces = [];
  List<ItineraryLeg> itineraryLegs = [];
  StartPoint? itineraryStartPoint;

  bool isLoading = false;
  bool isPreferencesExpanded = false;

  // Top Mode Tab for Mumbai: 0 = Custom itinerary, 1 = Mumbai Darshan
  int _selectedTopTab = 0;

  // Start Point Detection & Places Autocomplete
  // Stored as one unified object {name, lat, lng, source: gps|search}
  StartPoint? currentStart;
  bool _hasRunInitialGps = false;

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  String? _placesSessionToken;
  List<PlacePrediction> autocompleteSuggestions = [];
  bool isSearchingPlaces = false;
  bool hasResolvedStartCoords = false;

  String startPointName = "Detecting start location...";
  bool isDetectingLocation = false;
  String? locationStatusMessage;

  // Shimmer skeleton animation
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

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

  List<Color> get dayColors => AppTheme.dayColors;

  Color _getDayColor(int dayNum) {
    return AppTheme.getDayColor(dayNum);
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
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOutSine),
    );

    _initScreenData();
  }

  Future<void> _initScreenData() async {
    await _loadSavedItinerary();
    // GPS runs only once when no start is set
    if (currentStart == null && !_hasRunInitialGps) {
      await _detectUserLocation(isExplicitGpsTap: false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _showPlacesApiError(int status, String userMessage, String bodySnippet) {
    if (!mounted) return;
    debugPrint("[PLACES API ERROR] Status: $status, Snippet: $bodySnippet");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userMessage),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // ── Start Point & Autocomplete Handling (Places API New REST) ──

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        autocompleteSuggestions = [];
        isSearchingPlaces = false;
        hasResolvedStartCoords = false;
      });
      return;
    }

    // Invalidate previous resolved coordinates when user changes text
    hasResolvedStartCoords = false;

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() {
        isSearchingPlaces = true;
      });

      _placesSessionToken ??=
          DateTime.now().millisecondsSinceEpoch.toString();

      final results = await googlePlacesService.getAutocomplete(
        query,
        sessionToken: _placesSessionToken,
        onError: _showPlacesApiError,
      );

      if (mounted) {
        setState(() {
          autocompleteSuggestions = results;
          isSearchingPlaces = false;
        });
      }
    });
  }

  Future<void> _onSelectPrediction(PlacePrediction prediction) async {
    // Close the keyboard
    searchFocusNode.unfocus();
    setState(() {
      autocompleteSuggestions = [];
      isDetectingLocation = true;
      locationStatusMessage = null;
      startPointName = prediction.primaryText;
      searchController.text = prediction.primaryText;
    });

    try {
      double? lat = prediction.lat;
      double? lon = prediction.lon;
      String resolvedName = prediction.primaryText;

      if (lat == null || lon == null) {
        final details = await googlePlacesService.getPlaceDetails(
          prediction.placeId,
          onError: _showPlacesApiError,
        );
        if (details != null && details['lat'] != null && details['lon'] != null) {
          lat = (details['lat'] as num).toDouble();
          lon = (details['lon'] as num).toDouble();
          resolvedName = details['name']?.toString() ?? prediction.primaryText;
        }
      }

      _placesSessionToken = null;

      if (lat != null && lon != null) {
        if (mounted) {
          final newStart = StartPoint(
            name: resolvedName,
            latitude: lat,
            longitude: lon,
            source: 'search',
          );

          setState(() {
            currentStart = newStart;
            itineraryStartPoint = newStart;
            startPointName = resolvedName;
            searchController.text = resolvedName;
            hasResolvedStartCoords = true;
            isDetectingLocation = false;
            // Clear cached legs so itinerary recalculates from new start
            itineraryLegs = [];
          });

          // Immediately regenerate itinerary with new coordinates
          await _generateItinerary();
        }
      } else {
        if (mounted) {
          setState(() {
            isDetectingLocation = false;
            locationStatusMessage =
                "Could not get coordinates for selected place. Please try another.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDetectingLocation = false;
          locationStatusMessage = "Error selecting place: $e";
        });
        _showPlacesApiError(500, "Error selecting place: $e", e.toString());
      }
    }
  }

  Future<void> _detectUserLocation({bool isExplicitGpsTap = false}) async {
    // GPS runs only once when no start is set, and when user taps GPS icon.
    // Never overwrite source=search.
    if (!isExplicitGpsTap) {
      if (currentStart != null || _hasRunInitialGps) return;
      _hasRunInitialGps = true;
    }

    if (currentStart != null && currentStart!.source == 'search' && !isExplicitGpsTap) {
      return;
    }

    setState(() {
      isDetectingLocation = true;
      locationStatusMessage = null;
      autocompleteSuggestions = [];
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            isDetectingLocation = false;
            if (!hasResolvedStartCoords && currentStart == null) {
              startPointName = "${widget.trip.location} City Center";
              searchController.text = startPointName;
            }
            locationStatusMessage =
                "Location services disabled on device. Search your starting hotel or address.";
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
            if (!hasResolvedStartCoords && currentStart == null) {
              startPointName = "${widget.trip.location} City Center";
              searchController.text = startPointName;
            }
            locationStatusMessage =
                "Location permission denied. Search your hotel name above.";
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Reverse geocode GPS coordinates to a friendly name
      final friendlyName = await googlePlacesService.reverseGeocode(
        position.latitude,
        position.longitude,
      );

      final finalName = friendlyName ?? "Current Location";

      if (mounted) {
        // Never overwrite if user picked search in the meantime
        if (currentStart != null && currentStart!.source == 'search' && !isExplicitGpsTap) {
          return;
        }

        final gpsStart = StartPoint(
          name: finalName,
          latitude: position.latitude,
          longitude: position.longitude,
          source: 'gps',
        );

        setState(() {
          currentStart = gpsStart;
          itineraryStartPoint = gpsStart;
          startPointName = finalName;
          searchController.text = finalName;
          hasResolvedStartCoords = true;
          locationStatusMessage = null;
          isDetectingLocation = false;
          itineraryLegs = [];
        });

        // Regenerate itinerary with current GPS location
        if (itineraryData != null) {
          await _generateItinerary();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDetectingLocation = false;
          if (!hasResolvedStartCoords && currentStart == null) {
            startPointName = "${widget.trip.location} City Center";
            searchController.text = startPointName;
          }
          locationStatusMessage =
              "Could not retrieve GPS location. Search your starting address.";
        });
      }
    }
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
          loadedStart = StartPoint.fromMap(
            Map<String, dynamic>.from(parsed["startPoint"]),
          );
        }

        setState(() {
          itineraryData = parsed["itineraryData"];
          routingData = parsed["routingData"];
          itineraryMapPlaces = loadedPlaces;
          itineraryLegs = loadedLegs;
          if (loadedStart != null) {
            currentStart = loadedStart;
            itineraryStartPoint = loadedStart;
            startPointName = loadedStart.name;
            searchController.text = loadedStart.name;
            hasResolvedStartCoords = true;
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
      "startPoint": (currentStart ?? itineraryStartPoint)?.toMap(),
    };

    await databaseService.saveItinerary(
      widget.trip.id!,
      jsonEncode(dataToSave),
    );
  }

  // ── Itinerary Generation Pipeline ──────────────────────────

  Future<void> _generateItinerary() async {
    // Sanity check: Never regenerate with stale coordinates
    if (!hasResolvedStartCoords && currentStart == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a starting place from the search suggestions or tap GPS to fix coordinates.",
          ),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
      autocompleteSuggestions = [];
    });
    _shimmerController.repeat();

    try {
      debugPrint("Generating refined itinerary for ${widget.trip.location}...");

      Map<String, dynamic>? startPointPayload;
      if (currentStart != null) {
        startPointPayload = {
          "name": currentStart!.name,
          "lat": currentStart!.lat,
          "lon": currentStart!.lng,
          "source": currentStart!.source,
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
        // Only update startPoint from backend if the user hasn't chosen a search place
        if (resolvedStart != null && (currentStart == null || currentStart!.source != 'search')) {
          currentStart = resolvedStart;
          itineraryStartPoint = resolvedStart;
          startPointName = resolvedStart.name;
          searchController.text = resolvedStart.name;
          hasResolvedStartCoords = true;
        } else if (currentStart != null) {
          itineraryStartPoint = currentStart;
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
        _shimmerController.stop();
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
          startPoint: currentStart ?? itineraryStartPoint,
          initialDay: initialDay,
        ),
      ),
    );
  }

  // ── Dynamic Transport Options & Fare Fallbacks ───────────

  List<TransportOption> _ensureCompleteOptions(ItineraryLeg leg) {
    List<TransportOption> opts = List.from(leg.options);

    if (opts.isEmpty) {
      opts.add(
        TransportOption(
          mode: leg.mode,
          title: leg.transitLine ?? leg.mode.toUpperCase(),
          duration: leg.duration,
          durationMinutes: leg.durationMinutes,
          durationSeconds: leg.durationSeconds,
          distance: leg.distance,
          distanceMeters: leg.distanceMeters,
          cost: leg.cost ?? (leg.mode == 'walk' ? 'Free' : 'check locally'),
          transitLine: leg.transitLine,
          boardingStop: leg.boardingStop,
          alightingStop: leg.alightingStop,
          stopCount: leg.stopCount,
          departureTime: leg.departureTime,
          polyline: leg.polyline,
          steps: leg.steps,
        ),
      );
    }

    final double distKm = leg.distanceMeters > 0
        ? (leg.distanceMeters / 1000.0)
        : (double.tryParse(leg.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0);
    final int baseDriveMins = math.max(2, (distKm / 20.0 * 60).round());
    final int driveSec = baseDriveMins * 60;
    final int walkMins = math.max(2, (distKm / 4.5 * 60).round());
    final int walkSec = walkMins * 60;

    final hasWalk = opts.any((o) => o.mode == 'walk');
    final hasTransit = opts.any((o) => o.mode == 'bus' || o.mode == 'train' || o.mode == 'metro');
    final hasAuto = opts.any((o) => o.mode == 'auto');
    final hasCab = opts.any((o) => o.mode == 'cab');

    // 1. Walk option: time and distance
    if (!hasWalk) {
      opts.add(
        TransportOption(
          mode: 'walk',
          title: 'Walk',
          duration: '$walkMins min',
          durationMinutes: walkMins,
          durationSeconds: walkSec,
          distance: '${distKm.toStringAsFixed(1)} km',
          distanceMeters: (distKm * 1000).round(),
          cost: 'Free',
          steps: [
            TransitStep(
              type: 'walk',
              instruction: 'Walk to ${leg.to} (${distKm.toStringAsFixed(1)} km)',
              duration: '$walkMins min',
              distance: '${distKm.toStringAsFixed(1)} km',
            ),
          ],
        ),
      );
    }

    // 2. Transit option: if no data from API, show "check locally" instead of hiding it
    if (!hasTransit) {
      final transitMins = math.max(8, (distKm * 3.5 + 5).round());
      opts.add(
        TransportOption(
          mode: 'bus',
          title: 'Transit',
          duration: '$transitMins min',
          durationMinutes: transitMins,
          durationSeconds: transitMins * 60,
          distance: '${distKm.toStringAsFixed(1)} km',
          distanceMeters: (distKm * 1000).round(),
          cost: 'check locally',
          transitLine: 'check locally',
          steps: [
            TransitStep(
              type: 'transit',
              instruction: 'Local bus/transit to ${leg.to} (check locally)',
              lineName: 'check locally',
            ),
          ],
        ),
      );
    }

    // 3. Auto option: Mumbai RTO fare card rates
    if (!hasAuto) {
      final autoFare = MumbaiFareRates.calculateAutoFare(distKm, baseDriveMins);
      opts.add(
        TransportOption(
          mode: 'auto',
          title: 'Auto',
          duration: '$baseDriveMins min',
          durationMinutes: baseDriveMins,
          durationSeconds: driveSec,
          distance: '${distKm.toStringAsFixed(1)} km',
          distanceMeters: (distKm * 1000).round(),
          cost: autoFare.label,
          steps: [
            TransitStep(
              type: 'drive',
              instruction: 'Auto-rickshaw ride to ${leg.to} (${distKm.toStringAsFixed(1)} km)',
              duration: '$baseDriveMins min',
              distance: '${distKm.toStringAsFixed(1)} km',
            ),
          ],
        ),
      );
    }

    // 4. Cab option: Mumbai RTO fare card rates
    if (!hasCab) {
      final cabFare = MumbaiFareRates.calculateCabFare(distKm, baseDriveMins);
      opts.add(
        TransportOption(
          mode: 'cab',
          title: 'Cab',
          duration: '$baseDriveMins min',
          durationMinutes: baseDriveMins,
          durationSeconds: driveSec,
          distance: '${distKm.toStringAsFixed(1)} km',
          distanceMeters: (distKm * 1000).round(),
          cost: cabFare.label,
          steps: [
            TransitStep(
              type: 'drive',
              instruction: 'Cab / Taxi ride to ${leg.to} (${distKm.toStringAsFixed(1)} km)',
              duration: '$baseDriveMins min',
              distance: '${distKm.toStringAsFixed(1)} km',
            ),
          ],
        ),
      );
    }

    return opts;
  }

  /// Default selection: walk if under 1 km (< 1000 m), otherwise the fastest
  /// NON-walk option (any leg over 1 km must not default to Walk).
  int _determineDefaultOptionIndex(List<TransportOption> options, int distanceMeters) {
    if (options.isEmpty) return 0;
    if (distanceMeters < 1000) {
      final walkIdx = options.indexWhere((o) => o.mode == 'walk');
      if (walkIdx != -1) return walkIdx;
    }
    // For >= 1 km: find fastest non-walk option
    int fastestIdx = -1;
    int minSec = 9999999;
    for (int i = 0; i < options.length; i++) {
      if (options[i].mode == 'walk') continue;
      final sec = options[i].durationSeconds > 0
          ? options[i].durationSeconds
          : options[i].durationMinutes * 60;
      if (sec > 0 && sec < minSec) {
        minSec = sec;
        fastestIdx = i;
      }
    }
    // Fallback: if only walk is available, select it
    if (fastestIdx == -1) {
      return options.indexWhere((o) => o.mode == 'walk').clamp(0, options.length - 1);
    }
    return fastestIdx;
  }

  /// Computes day summary dynamically from the currently selected options of each leg.
  Map<String, dynamic> _computeDaySummary(List daysList, int targetDay) {
    int totalStops = 0;
    double totalKm = 0.0;
    int totalMinutes = 0;
    int minCost = 0;
    int maxCost = 0;
    bool hasLocalCheck = false;

    for (int d = 0; d < daysList.length; d++) {
      final day = daysList[d];
      final dayNum = day["day"] is int
          ? day["day"]
          : int.tryParse(day["day"].toString()) ?? (d + 1);

      if (targetDay != 0 && dayNum != targetDay) continue;

      final attractions = (day["attractions"] as List?) ?? [];
      totalStops += attractions.length;

      int legOffset = 0;
      for (int prev = 0; prev < d; prev++) {
        final prevLegs = (daysList[prev]["legs"] as List?) ?? [];
        legOffset += prevLegs.length;
      }

      for (int i = 0; i < attractions.length; i++) {
        final globalLegIdx = legOffset + i;
        if (globalLegIdx < itineraryLegs.length) {
          final leg = itineraryLegs[globalLegIdx];
          final opts = _ensureCompleteOptions(leg);
          final optIdx = leg.selectedOptionIndex.clamp(0, opts.length - 1);
          final activeOpt = opts[optIdx];

          // KM
          final meters = activeOpt.distanceMeters > 0
              ? activeOpt.distanceMeters
              : leg.distanceMeters;
          if (meters > 0) {
            totalKm += meters / 1000.0;
          } else {
            final match = RegExp(r'([\d.]+)').firstMatch(activeOpt.distance);
            if (match != null) {
              totalKm += double.tryParse(match.group(1) ?? '0') ?? 0.0;
            }
          }

          // Duration
          final mins = activeOpt.durationMinutes > 0
              ? activeOpt.durationMinutes
              : (activeOpt.durationSeconds / 60).round();
          if (mins > 0) {
            totalMinutes += mins;
          } else {
            final match = RegExp(r'(\d+)').firstMatch(activeOpt.duration);
            if (match != null) {
              totalMinutes += int.tryParse(match.group(1) ?? '0') ?? 0;
            }
          }

          // Cost
          final costStr = activeOpt.cost;
          if (costStr.toLowerCase().contains('check locally')) {
            hasLocalCheck = true;
          } else {
            final (cLow, cHigh) = MumbaiFareRates.parseCostToRange(costStr);
            minCost += cLow;
            maxCost += cHigh;
          }
        }
      }
    }

    String costText;
    if (minCost == 0 && maxCost == 0) {
      costText = hasLocalCheck ? "check locally" : "Free";
    } else if (minCost == maxCost) {
      costText = "₹$minCost est.";
    } else {
      costText = "est. ₹$minCost - ₹$maxCost";
    }
    if (hasLocalCheck && (minCost > 0 || maxCost > 0)) {
      costText = "$costText + transit";
    }

    String timeText;
    if (totalMinutes >= 60) {
      final h = totalMinutes ~/ 60;
      final m = totalMinutes % 60;
      timeText = m > 0 ? "${h}h ${m}m" : "${h}h";
    } else {
      timeText = "$totalMinutes min";
    }

    return {
      "stops": "$totalStops stops",
      "km": "${totalKm.toStringAsFixed(1)} km",
      "time": timeText,
      "cost": costText,
    };
  }

  Widget _buildTopModeToggle() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTopTab = 0;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTopTab == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTopTab == 0
                      ? const [
                          BoxShadow(
                            color: Color(0x140F172A),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    "Custom itinerary",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _selectedTopTab == 0
                          ? AppTheme.primaryTeal
                          : AppTheme.textSlateSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTopTab = 1;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTopTab == 1 ? const Color(0xFFF57220) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTopTab == 1
                      ? const [
                          BoxShadow(
                            color: Color(0x33F57220),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.tour_outlined,
                        size: 15,
                        color: _selectedTopTab == 1 ? Colors.white : AppTheme.textSlateSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Mumbai Darshan",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _selectedTopTab == 1
                              ? Colors.white
                              : AppTheme.textSlateSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysList = (itineraryData != null && itineraryData!["itinerary"] != null)
        ? (itineraryData!["itinerary"] as List)
        : [];

    final hasItinerary = daysList.isNotEmpty;
    final bool isMumbai = widget.trip.location.toLowerCase().contains("mumbai");

    return Scaffold(
      backgroundColor: AppTheme.backgroundSlate,
      appBar: AppBar(
        title: Text(
          (isMumbai && _selectedTopTab == 1)
              ? "Mumbai Darshan"
              : "${widget.trip.location} Itinerary",
        ),
        backgroundColor: (isMumbai && _selectedTopTab == 1)
            ? const Color(0xFFF57220)
            : AppTheme.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasItinerary && _selectedTopTab == 0)
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: "View Map",
              onPressed: () => _openMap(initialDay: selectedDayTab),
            ),
        ],
      ),
      body: isMumbai && _selectedTopTab == 1
          ? Column(
              children: [
                _buildTopModeToggle(),
                const Expanded(child: MumbaiDarshanView()),
              ],
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mumbai Mode Switcher (Custom Itinerary vs Mumbai Darshan)
                  if (isMumbai) _buildTopModeToggle(),

                  // ── Top Summary & Action Banner ───────────────────
                  _buildTopBanner(hasItinerary),

                  // ── Rounded Search Bar Start Card with GPS inside ─
                  _buildStartPointCard(),

                  // ── Day Summary at the Top (Stops, KM, Time, Cost) ─
                  if (hasItinerary && !isLoading)
                    _buildDaySummaryCard(daysList, selectedDayTab),

                  // ── Expandable Preferences Section ───────────────
                  _buildPreferencesSection(hasItinerary),

                  // ── Skeleton Loader or Itinerary Content ──────────
                  if (isLoading)
                    _buildSkeletonTimeline()
                  else if (hasItinerary) ...[
                    _buildDayTabsBar(daysList),
                    _buildDaysContent(daysList),
                  ] else ...[
                    _buildEmptyState(),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
      bottomNavigationBar: (hasItinerary && !isLoading && _selectedTopTab == 0)
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 10,
                    offset: Offset(0, -3),
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
                              ? AppTheme.primaryTeal
                              : _getDayColor(selectedDayTab),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        color: AppTheme.primaryTeal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
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
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${widget.trip.days} Days • ${itineraryMapPlaces.length} Stops • Clustered by Area",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
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

  // ── Day Summary Card at the Top (Requirement 4 & 1) ───────────

  Widget _buildDaySummaryCard(List daysList, int selectedDay) {
    final summary = _computeDaySummary(daysList, selectedDay);
    final String title = selectedDay == 0
        ? "Trip Overview (${daysList.length} Days)"
        : "Day $selectedDay Overview";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSlate),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlatePrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Interactive Totals",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTopSummaryTile(
                icon: Icons.place_outlined,
                iconColor: AppTheme.primaryTeal,
                label: "STOPS",
                value: summary["stops"]!,
              ),
              const SizedBox(width: 8),
              _buildTopSummaryTile(
                icon: Icons.straighten,
                iconColor: AppTheme.modeTransit,
                label: "DISTANCE",
                value: summary["km"]!,
              ),
              const SizedBox(width: 8),
              _buildTopSummaryTile(
                icon: Icons.timer_outlined,
                iconColor: AppTheme.secondaryAmberDark,
                label: "TIME",
                value: summary["time"]!,
              ),
              const SizedBox(width: 8),
              _buildTopSummaryTile(
                icon: Icons.currency_rupee,
                iconColor: AppTheme.modeCab,
                label: "EST. COST",
                value: summary["cost"]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummaryTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppTheme.backgroundSlate,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderSlate),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSlateSecondary,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSlatePrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Rounded Search Bar Start Card with GPS Inside ─────────────

  Widget _buildStartPointCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSlate),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
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
                decoration: const BoxDecoration(
                  color: AppTheme.primaryTealLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trip_origin, color: AppTheme.primaryTeal, size: 16),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Starting Point",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSlatePrimary,
                  ),
                ),
              ),
              if (currentStart != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: currentStart!.source == 'search'
                        ? AppTheme.primaryTealLight
                        : AppTheme.modeWalkLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    currentStart!.source == 'search' ? "Searched" : "GPS",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: currentStart!.source == 'search'
                          ? AppTheme.primaryTealDark
                          : AppTheme.modeWalk,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Rounded search bar with GPS icon INSIDE it
          TextField(
            controller: searchController,
            focusNode: searchFocusNode,
            onChanged: _onSearchChanged,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSlatePrimary),
            decoration: InputDecoration(
              hintText: "Search hotel, airport, or landmark in ${widget.trip.location}...",
              hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSlateSecondary),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.primaryTeal),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSlateSecondary),
                      onPressed: () {
                        searchController.clear();
                        setState(() {
                          autocompleteSuggestions = [];
                          hasResolvedStartCoords = false;
                        });
                      },
                    ),
                  IconButton(
                    icon: (isDetectingLocation || isSearchingPlaces)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryTeal,
                            ),
                          )
                        : const Icon(Icons.gps_fixed, size: 20, color: AppTheme.primaryTeal),
                    tooltip: "Use Current GPS Location",
                    onPressed: isDetectingLocation
                        ? null
                        : () => _detectUserLocation(isExplicitGpsTap: true),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              filled: true,
              fillColor: AppTheme.backgroundSlate,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.borderSlate),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.borderSlate),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.primaryTeal, width: 1.6),
              ),
            ),
          ),

          // Autocomplete Suggestions List
          if (autocompleteSuggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderSlate),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: autocompleteSuggestions.length,
                separatorBuilder: (ctx, idx) => const Divider(height: 1, color: AppTheme.borderSlateLight),
                itemBuilder: (ctx, idx) {
                  final suggestion = autocompleteSuggestions[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined, color: AppTheme.primaryTeal, size: 20),
                    title: Text(
                      suggestion.primaryText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSlatePrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: suggestion.secondaryText.isNotEmpty
                        ? Text(
                            suggestion.secondaryText,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSlateSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () => _onSelectPrediction(suggestion),
                  );
                },
              ),
            ),
          ],

          // Show real lat/lng under start name
          if (currentStart != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  currentStart!.source == 'search' ? Icons.search : Icons.gps_fixed,
                  size: 12,
                  color: AppTheme.textSlateSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${currentStart!.lat.toStringAsFixed(5)}, ${currentStart!.lng.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSlateSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],

          if (locationStatusMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: AppTheme.secondaryAmberDark),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    locationStatusMessage!,
                    style: const TextStyle(fontSize: 11, color: AppTheme.secondaryAmberDark),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Skeleton Loader while Fetching (Requirement 6) ─────────

  Widget _buildSkeletonTimeline() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShimmerBox(height: 40, width: double.infinity, radius: 10),
          const SizedBox(height: 16),
          for (int i = 0; i < 3; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    _buildShimmerBox(height: 32, width: 32, radius: 16),
                    const SizedBox(height: 4),
                    _buildShimmerBox(height: 70, width: 2.5, radius: 2),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildShimmerBox(height: 20, width: 140, radius: 6),
                      const SizedBox(height: 8),
                      _buildShimmerBox(height: 14, width: double.infinity, radius: 4),
                      const SizedBox(height: 6),
                      _buildShimmerBox(height: 14, width: 180, radius: 4),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildShimmerBox(height: 24, width: 80, radius: 12),
                          const SizedBox(width: 8),
                          _buildShimmerBox(height: 24, width: 80, radius: 12),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmerBox({required double height, required double width, double radius = 8}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade200,
                Colors.grey.shade100,
                Colors.grey.shade200,
              ],
              stops: [
                (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                _shimmerAnimation.value.clamp(0.0, 1.0),
                (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Preferences Section ────────────────────────────────────

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
                    color: isSelected ? Colors.white : AppTheme.textSlatePrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryTeal,
                backgroundColor: AppTheme.backgroundSlate,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryTeal : AppTheme.borderSlate,
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
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
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

  // ── Day Tabs Bar ───────────────────────────────────────────

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
                selectedColor: AppTheme.primaryTeal,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSlatePrimary,
                ),
                backgroundColor: Colors.white,
                elevation: isSelected ? 2 : 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected ? AppTheme.primaryTeal : AppTheme.borderSlate,
                  ),
                ),
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
                color: isSelected ? Colors.white : AppTheme.textSlatePrimary,
              ),
              backgroundColor: Colors.white,
              elevation: isSelected ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isSelected ? color : AppTheme.borderSlate,
                ),
              ),
              onSelected: (sel) {
                if (sel) setState(() => selectedDayTab = dayNum);
              },
            ),
          );
        },
      ),
    );
  }

  // ── Days Content & Leg Logic ───────────────────────────────

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
        final rawLegs = (day["legs"] as List?) ?? [];
        final color = _getDayColor(dayNum);

        // Compute global leg offset across all days
        int legOffset = 0;
        for (int d = 0; d < daysList.length; d++) {
          final current = daysList[d];
          final curNum = current["day"] is int
              ? current["day"]
              : int.tryParse(current["day"].toString()) ?? (d + 1);
          if (curNum == dayNum) break;
          final prevLegs = (current["legs"] as List?) ?? [];
          legOffset += prevLegs.length;
        }

        // Dynamic day summary driven by current option choices
        final daySummary = _computeDaySummary(daysList, dayNum);

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
            border: Border.all(color: AppTheme.borderSlate),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Day Header Banner with Area & Dynamic Totals ──────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(
                    bottom: BorderSide(color: color.withValues(alpha: 0.15)),
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSlatePrimary,
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
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSlateSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Real-time dynamic totals for this day
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.borderSlate),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMiniStat(Icons.flag_outlined, daySummary["stops"]!),
                          _buildMiniStat(Icons.straighten, daySummary["km"]!),
                          _buildMiniStat(Icons.timer_outlined, daySummary["time"]!),
                          _buildMiniStat(Icons.currency_rupee, daySummary["cost"]!),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Start Point Departure Row ──────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryTeal,
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
                              color: AppTheme.textSlatePrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "Departs at $departureTime",
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSlateSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Attractions Timeline & Legs ────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: attractions.length,
                  itemBuilder: (ctx, idx) {
                    final place = attractions[idx];
                    final globalLegIdx = legOffset + idx;
                    final leg = (globalLegIdx < itineraryLegs.length)
                        ? itineraryLegs[globalLegIdx]
                        : (idx < rawLegs.length)
                            ? ItineraryLeg.fromMap(Map<String, dynamic>.from(rawLegs[idx]))
                            : null;

                    return Column(
                      children: [
                        // Leg connecting to this stop:
                        // idx == 0: start -> stop 1
                        // idx == 1: stop 1 -> stop 2
                        // idx == N-1: stop N-1 -> stop N
                        if (leg != null)
                          _buildLegRow(leg, globalLegIdx, color),

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
        Icon(icon, size: 13, color: AppTheme.textSlateSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSlatePrimary,
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
        // Number badge & Time column (Numbered stop marker)
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
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSlatePrimary,
                  ),
                ),
              ],
              if (leaveTime != null && leaveTime.isNotEmpty) ...[
                Text(
                  "- $leaveTime",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSlateSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Place details card with expandable details
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSlate),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
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
                            color: AppTheme.textSlatePrimary,
                          ),
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textSlateSecondary,
                        size: 20,
                      ),
                    ],
                  ),

                  // One-line reason
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSlateSecondary,
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
                          color: AppTheme.primaryTealLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryTealLight),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 12, color: AppTheme.primaryTeal),
                            const SizedBox(width: 4),
                            Text(
                              "Hours: $openingHours",
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.primaryTealDark,
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
                            color: AppTheme.secondaryAmberLight,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.secondaryAmberLight),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_sunny_outlined, size: 12, color: AppTheme.secondaryAmberDark),
                              const SizedBox(width: 4),
                              Text(
                                "Best: $bestTime",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.secondaryAmberDark,
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
                    const Divider(height: 18, color: AppTheme.borderSlateLight),
                    if (duration != null && duration.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          "Suggested Stay: $duration",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSlateSecondary,
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
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

  // ── Mode Color Helper (Walk: green, Bus/Train/Metro: blue, Auto/Cab: orange) ──
  Color _getModeColor(String mode) {
    switch (mode.toLowerCase()) {
      case 'walk':
        return AppTheme.modeWalk; // Green #16A34A
      case 'bus':
      case 'train':
      case 'metro':
      case 'transit':
        return AppTheme.modeTransit; // Blue #2563EB
      case 'auto':
      case 'cab':
      case 'taxi':
      case 'drive':
        return AppTheme.modeCab; // Orange #F97316
      default:
        return AppTheme.primaryTeal;
    }
  }

  // ── Leg Row with Transport Chips & Step Details (Requirements 1, 2, 3, 4) ──

  Widget _buildLegRow(ItineraryLeg leg, int legIndex, Color dayColor) {
    // Ensure all 4 modes are present (Walk, Bus/Train, Auto, Cab) with Mumbai RTO rates and fallbacks
    final options = _ensureCompleteOptions(leg);
    final defaultIdx = _determineDefaultOptionIndex(options, leg.distanceMeters);
    final currentOptionIdx = (leg.selectedOptionIndex >= 0 && leg.selectedOptionIndex < options.length)
        ? leg.selectedOptionIndex
        : defaultIdx;
    final activeOption = options[currentOptionIdx];
    final isExpanded = expandedLegIndices.contains('$legIndex');
    final activeModeColor = _getModeColor(activeOption.mode);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thin timeline vertical connector line (Requirement 4)
        SizedBox(
          width: 58,
          child: Center(
            child: Container(
              width: 2.0,
              height: isExpanded ? 130 : 54,
              decoration: BoxDecoration(
                color: dayColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // Slim leg container between stop cards (Requirement 4)
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.backgroundSlate,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSlate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Horizontal scrolling selectable chips for all transport modes
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(options.length, (optIdx) {
                      final opt = options[optIdx];
                      final isSelected = optIdx == currentOptionIdx;
                      final modeColor = _getModeColor(opt.mode);
                      final icon = _getTransportIcon(opt.mode);

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          avatar: Icon(
                            icon,
                            size: 14,
                            color: isSelected ? Colors.white : modeColor,
                          ),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                opt.transitLine ?? opt.title,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppTheme.textSlatePrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "• ${opt.duration}",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected ? Colors.white70 : AppTheme.textSlateSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "(${opt.distance})",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected ? Colors.white60 : AppTheme.textSlateSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : modeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  opt.cost,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? Colors.white : modeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: modeColor,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? modeColor : AppTheme.borderSlate,
                            ),
                          ),
                          onSelected: (sel) {
                            if (sel && legIndex < itineraryLegs.length) {
                              setState(() {
                                itineraryLegs[legIndex] =
                                    leg.copyWithSelectedOption(optIdx);

                                // Tapping a transit chip auto-expands step-by-step directions (Requirement 2)
                                if (opt.mode == 'bus' ||
                                    opt.mode == 'train' ||
                                    opt.mode == 'metro' ||
                                    opt.mode == 'transit') {
                                  expandedLegIndices.add('$legIndex');
                                }
                              });
                              _saveCurrentItinerary();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),

                // Transit details badge: bus number / metro, boarding stop, alighting stop, departure time
                if (activeOption.boardingStop != null || activeOption.departureTime != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.directions_transit, size: 12, color: activeModeColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          [
                            if (activeOption.boardingStop != null) "Board at ${activeOption.boardingStop}",
                            if (activeOption.alightingStop != null) "alight at ${activeOption.alightingStop}",
                            if (activeOption.stopCount != null) "${activeOption.stopCount} stops",
                            if (activeOption.departureTime != null) "Dep: ${activeOption.departureTime}",
                          ].join(" • "),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSlateSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],

                // Step-by-step transit details toggle & view (Requirement 2)
                const SizedBox(height: 3),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        expandedLegIndices.remove('$legIndex');
                      } else {
                        expandedLegIndices.add('$legIndex');
                      }
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isExpanded ? "Hide route steps" : "View step-by-step directions",
                        style: TextStyle(
                          fontSize: 11,
                          color: activeModeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        size: 14,
                        color: activeModeColor,
                      ),
                    ],
                  ),
                ),

                if (isExpanded) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.borderSlate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildStepByStepWidgets(activeOption, leg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper to build step-by-step directions (Requirement 2)
  List<Widget> _buildStepByStepWidgets(TransportOption opt, ItineraryLeg leg) {
    // If structured steps are provided from API or synthesis:
    if (opt.steps.isNotEmpty) {
      return opt.steps.map((st) {
        final isWalk = st.type.toLowerCase().contains('walk');
        final icon = isWalk ? Icons.directions_walk : _getTransportIcon(opt.mode);
        final color = isWalk ? AppTheme.modeWalk : _getModeColor(opt.mode);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  st.instruction,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSlatePrimary),
                ),
              ),
              if (st.duration != null && st.duration!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  st.duration!,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSlateSecondary),
                ),
              ],
            ],
          ),
        );
      }).toList();
    }

    // Transit step-by-step synthesis if API returned transit details without sub-steps
    if (opt.mode == 'bus' || opt.mode == 'train' || opt.mode == 'metro' || opt.mode == 'transit') {
      final board = opt.boardingStop ?? 'Transit Stop';
      final alight = opt.alightingStop ?? leg.to;
      final line = opt.transitLine ?? 'Transit';

      return [
        _buildSynthesizedStepRow(
          Icons.directions_walk,
          AppTheme.modeWalk,
          "Walk to $board",
        ),
        _buildSynthesizedStepRow(
          _getTransportIcon(opt.mode),
          AppTheme.modeTransit,
          "Board $line at $board${opt.stopCount != null ? ' (${opt.stopCount} stops)' : ''}",
        ),
        _buildSynthesizedStepRow(
          Icons.transfer_within_a_station,
          AppTheme.modeTransit,
          "Get off at $alight",
        ),
        _buildSynthesizedStepRow(
          Icons.directions_walk,
          AppTheme.modeWalk,
          "Walk to destination: ${leg.to}",
        ),
      ];
    }

    if (opt.mode == 'walk') {
      return [
        _buildSynthesizedStepRow(
          Icons.directions_walk,
          AppTheme.modeWalk,
          "Walk directly from ${leg.from} to ${leg.to} (${opt.distance}, ~${opt.duration})",
        ),
      ];
    }

    // Auto or Cab
    return [
      _buildSynthesizedStepRow(
        opt.mode == 'auto' ? Icons.electric_rickshaw : Icons.local_taxi,
        AppTheme.modeCab,
        "Hail ${opt.title} to ${leg.to} (${opt.distance}, ~${opt.duration})",
      ),
      _buildSynthesizedStepRow(
        Icons.info_outline,
        AppTheme.textSlateSecondary,
        "Fare based on Mumbai RTO meter rates (${opt.cost}). Pay directly or via meter.",
      ),
    ];
  }

  Widget _buildSynthesizedStepRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSlatePrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSlate),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.explore_outlined,
            size: 56,
            color: AppTheme.primaryTeal,
          ),
          const SizedBox(height: 16),
          const Text(
            "No Itinerary Generated Yet",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSlatePrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Search and confirm your starting point above, select your interests, and tap 'Generate Itinerary' to build a day-by-day plan clustered geographically with real transit options, opening hours, and routes.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSlateSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}