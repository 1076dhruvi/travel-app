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

  Map<String, dynamic>? itineraryData;

  final Map<int, Map<String, dynamic>> dailyRoutingData = {};

  bool isGenerating = false;

  final List<String> interests = [
    "Beaches",
    "History",
    "Food",
    "Nature",
    "Adventure",
    "Shopping",
  ];

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8F7FB),
        foregroundColor: Colors.black87,
        title: Text(
          "${widget.trip.location} Itinerary",
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // ==================================================
            // INTRO
            // ==================================================

            const Text(
              "Plan your trip",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              "Choose what you love and we'll build your day-by-day journey.",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // ==================================================
            // INTERESTS
            // ==================================================

            const Text(
              "Interests",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,

              children: interests.map((interest) {

                final selected =
                    selectedInterests.contains(interest);

                return ChoiceChip(

                  label: Text(interest),

                  selected: selected,

                  onSelected: (value) {

                    setState(() {

                      if (value) {
                        selectedInterests.add(interest);
                      } else {
                        selectedInterests.remove(interest);
                      }

                    });

                  },

                  selectedColor:
                      const Color(0xFF6B3CC9),

                  backgroundColor:
                      Colors.white,

                  labelStyle: TextStyle(
                    color: selected
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),

                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF6B3CC9)
                        : Colors.grey.shade300,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(20),
                  ),

                );

              }).toList(),
            ),

            const SizedBox(height: 22),

            // ==================================================
            // GENERATE BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,

              height: 52,

              child: ElevatedButton(

                onPressed:
                    isGenerating
                        ? null
                        : _generateItinerary,

                style: ElevatedButton.styleFrom(

                  elevation: 0,

                  backgroundColor:
                      const Color(0xFF6B3CC9),

                  disabledBackgroundColor:
                      Colors.grey.shade400,

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),

                ),

                child: isGenerating

                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )

                    : const Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [

                          Icon(
                            Icons.auto_awesome,
                            size: 19,
                            color: Colors.white,
                          ),

                          SizedBox(width: 8),

                          Text(
                            "Generate My Itinerary",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),

                        ],
                      ),

              ),
            ),

            const SizedBox(height: 35),

            // ==================================================
            // ITINERARY
            // ==================================================

            if (itineraryData != null)
              _buildItinerary(),

          ],
        ),
      ),
    );
  }

  // ============================================================
  // GENERATE ITINERARY
  // ============================================================

  Future<void> _generateItinerary() async {

    setState(() {
      isGenerating = true;
      itineraryData = null;
      dailyRoutingData.clear();
    });

    try {

      print("Generating itinerary...");

      final result =
          await itineraryService.generateItinerary(

        destination: widget.trip.location,

        days: widget.trip.days,

        interests:
            selectedInterests.toList(),

      );

      print("ITINERARY RESPONSE:");
      print(result);

      if (!mounted) return;

      setState(() {
        itineraryData = result;
      });

      // --------------------------------------------------------
      // ROUTE EACH DAY SEPARATELY
      // --------------------------------------------------------

      for (var day in result["itinerary"]) {

        final int dayNumber =
            int.tryParse(
              day["day"].toString(),
            ) ??
            0;

        final List<String> places = [];

        final Set<String> seen = {};

        for (var place in day["attractions"]) {

          final name =
              place["name"]
                  .toString()
                  .trim();

          if (name.isEmpty) continue;

          if (_isInvalidPlace(name)) {
            continue;
          }

          if (!seen.contains(name)) {
            seen.add(name);
            places.add(name);
          }
        }

        print(
          "DAY $dayNumber PLACES:",
        );

        print(places);

        // Need at least two places for routing.
        if (places.length < 2) {
          continue;
        }

        try {

          final route =
              await routingService.optimizeRoute(
            widget.trip.location,
            places,
          );

          print(
            "ROUTE FOR DAY $dayNumber:",
          );

          print(route);

          if (!mounted) return;

          setState(() {
            dailyRoutingData[dayNumber] =
                route;
          });

        } catch (e) {

          print(
            "ROUTING ERROR DAY $dayNumber: $e",
          );

        }
      }

    } catch (e) {

      print(
        "ITINERARY ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Failed to generate itinerary",
          ),
        ),
      );

    } finally {

      if (!mounted) return;

      setState(() {
        isGenerating = false;
      });

    }
  }

  // ============================================================
  // INVALID PLACE FILTER
  // ============================================================

  bool _isInvalidPlace(String name) {

    final value =
        name.toLowerCase();

    return value.contains(
            "bannerghatta biological park") ||
        value.contains("mysore") ||
        value.contains("hampi") ||
        value.contains("coorg");
  }

  // ============================================================
  // MAIN ITINERARY
  // ============================================================

  Widget _buildItinerary() {

    final List<dynamic> days =
        List<dynamic>.from(
      itineraryData!["itinerary"] ?? [],
    );

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        // ------------------------------------------------------
        // ITINERARY TITLE
        // ------------------------------------------------------

        Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,

          children: [

            const Expanded(
              child: Text(
                "Your journey",
                style: TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            Text(
              "${widget.trip.days} DAYS",
              style: const TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
                color:
                    Color(0xFF6B3CC9),
                letterSpacing: 1,
              ),
            ),

          ],
        ),

        const SizedBox(height: 5),

        Text(
          widget.trip.location,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),

        const SizedBox(height: 28),

        // ------------------------------------------------------
        // DAYS
        // ------------------------------------------------------

        ...List.generate(

          days.length,

          (index) {

            final day =
                Map<String, dynamic>.from(
              days[index],
            );

            final dayNumber =
                int.tryParse(
                  day["day"].toString(),
                ) ??
                index + 1;

            return _buildDayTimeline(
              day,
              dayNumber,
              index == days.length - 1,
            );

          },

        ),

      ],
    );
  }

  // ============================================================
  // DAY TIMELINE
  // ============================================================

  Widget _buildDayTimeline(
      Map<String, dynamic> day,
      int dayNumber,
      bool isLastDay,
      ) {

    final List<dynamic> attractions =
        List<dynamic>.from(
      day["attractions"] ?? [],
    );

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        // ------------------------------------------------------
        // DAY HEADER
        // ------------------------------------------------------

        Row(

          children: [

            Container(

              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color:
                    const Color(0xFF6B3CC9),
                borderRadius:
                    BorderRadius.circular(12),
              ),

              alignment:
                  Alignment.center,

              child: Text(
                "$dayNumber",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Text(
                    "DAY $dayNumber",
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF6B3CC9),
                      letterSpacing: 1,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _getDayTitle(day),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                ],
              ),
            ),

          ],
        ),

        const SizedBox(height: 22),

        // ------------------------------------------------------
        // TIMELINE
        // ------------------------------------------------------

        if (attractions.isEmpty)

          Padding(
            padding:
                const EdgeInsets.only(
              left: 55,
            ),

            child: Text(
              "No places planned for this day.",
              style: TextStyle(
                color:
                    Colors.grey.shade600,
              ),
            ),
          )

        else

          ...List.generate(

            attractions.length,

            (index) {

              final place =
                  Map<String, dynamic>.from(
                attractions[index],
              );

              final placeName =
                  place["name"]
                      ?.toString() ??
                  "Unknown place";

              final bestTime =
                  place["bestTime"]
                      ?.toString() ??
                  "Anytime";

              final isLastPlace =
                  index ==
                      attractions.length - 1;

              final nextPlace =
                  !isLastPlace
                      ? Map<String, dynamic>.from(
                          attractions[index + 1],
                        )
                      : null;

              final nextPlaceName =
                  nextPlace?["name"]
                          ?.toString() ??
                      "";

              final route =
                  !isLastPlace
                      ? _findRouteBetweenPlaces(
                          dayNumber,
                          placeName,
                          nextPlaceName,
                        )
                      : null;

              return _buildTimelineItem(
                placeName: placeName,
                bestTime: bestTime,
                index: index,
                isLastPlace: isLastPlace,
                route: route,
              );
            },
          ),

        // ------------------------------------------------------
        // SPACE BETWEEN DAYS
        // ------------------------------------------------------

        if (!isLastDay)
          Container(
            height: 1,
            margin:
                const EdgeInsets.only(
              top: 25,
              bottom: 28,
            ),
            color:
                Colors.grey.shade200,
          ),

      ],
    );
  }

  // ============================================================
  // TIMELINE ITEM
  // ============================================================

  Widget _buildTimelineItem({
    required String placeName,
    required String bestTime,
    required int index,
    required bool isLastPlace,
    required Map<String, dynamic>? route,
  }) {

    return Row(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        // ======================================================
        // LEFT TIMELINE
        // ======================================================

        SizedBox(

          width: 38,

          child: Column(

            children: [

              // NODE

              Container(

                width: 18,
                height: 18,

                decoration: BoxDecoration(

                  color: Colors.white,

                  shape: BoxShape.circle,

                  border: Border.all(
                    color:
                        const Color(0xFF6B3CC9),
                    width: 4,
                  ),

                ),
              ),

              // LINE

              if (!isLastPlace)

                Container(
                  width: 2,
                  height: 115,
                  color:
                      const Color(0xFFD9C9F4),
                ),

            ],
          ),
        ),

        // ======================================================
        // CONTENT
        // ======================================================

        Expanded(

          child: Padding(

            padding:
                const EdgeInsets.only(
              bottom: 18,
            ),

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                // ------------------------------------------------
                // TIME LABEL
                // ------------------------------------------------

                Row(

                  children: [

                    Text(
                      _getTimeEmoji(
                        bestTime,
                      ),

                      style:
                          const TextStyle(
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      _formatTimeLabel(
                        bestTime,
                      ),

                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF6B3CC9),
                        letterSpacing: .5,
                      ),
                    ),

                  ],
                ),

                const SizedBox(height: 5),

                // ------------------------------------------------
                // PLACE NAME
                // ------------------------------------------------

                Text(
                  placeName,

                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 4),

                // ------------------------------------------------
                // BEST TIME
                // ------------------------------------------------

                if (bestTime.isNotEmpty)

                  Text(
                    "Best time · $bestTime",

                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.grey.shade500,
                    ),
                  ),

                // ------------------------------------------------
                // ROUTE
                // ------------------------------------------------

                if (!isLastPlace)

                  _buildRouteInfo(
                    route,
                  ),

              ],
            ),
          ),
        ),

      ],
    );
  }

  // ============================================================
  // ROUTE INFO
  // ============================================================

  Widget _buildRouteInfo(
      Map<String, dynamic>? route,
      ) {

    String distance = "";
    String time = "";

    if (route != null) {

      distance =
          route["distance"]
                  ?.toString() ??
              "";

      time =
          route["time"]
                  ?.toString() ??
              "";
    }

    final hasRoute =
        distance.isNotEmpty ||
            time.isNotEmpty;

    return Container(

      margin:
          const EdgeInsets.only(
        top: 12,
        bottom: 3,
      ),

      padding:
          const EdgeInsets.symmetric(
        vertical: 9,
        horizontal: 11,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(10),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),

      ),

      child: Row(

        mainAxisSize:
            MainAxisSize.min,

        children: [

          Icon(
            Icons.directions_car_outlined,
            size: 17,
            color:
                Colors.grey.shade600,
          ),

          const SizedBox(width: 7),

          Text(
            hasRoute
                ? [
                    if (distance.isNotEmpty)
                      distance,
                    if (time.isNotEmpty)
                      time,
                  ].join("  ·  ")
                : "Calculating route...",

            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color:
                  Colors.grey.shade700,
            ),
          ),

        ],
      ),
    );
  }

  // ============================================================
  // FIND ROUTE
  // ============================================================

  Map<String, dynamic>? _findRouteBetweenPlaces(
      int dayNumber,
      String from,
      String to,
      ) {

    final dayRouting =
        dailyRoutingData[dayNumber];

    if (dayRouting == null) {
      return null;
    }

    final routes =
        dayRouting["routes"];

    if (routes is! List) {
      return null;
    }

    for (final route in routes) {

      final routeFrom =
          route["from"]
                  ?.toString()
                  .trim() ??
              "";

      final routeTo =
          route["to"]
                  ?.toString()
                  .trim() ??
              "";

      if (_samePlace(
            routeFrom,
            from,
          ) &&
          _samePlace(
            routeTo,
            to,
          )) {

        return {
          "distance":
              route["distance"]
                      ?.toString() ??
                  "",
          "time":
              route["time"]
                      ?.toString() ??
                  "",
        };
      }
    }

    return null;
  }

  // ============================================================
  // PLACE COMPARISON
  // ============================================================

  bool _samePlace(
      String first,
      String second,
      ) {

    return first
            .trim()
            .toLowerCase() ==
        second
            .trim()
            .toLowerCase();
  }

  // ============================================================
  // DAY TITLE
  // ============================================================

  String _getDayTitle(
      Map<String, dynamic> day,
      ) {

    if (day["title"] != null &&
        day["title"]
            .toString()
            .trim()
            .isNotEmpty) {

      return day["title"].toString();
    }

    if (day["location"] != null &&
        day["location"]
            .toString()
            .trim()
            .isNotEmpty) {

      return day["location"].toString();
    }

    return "Explore ${widget.trip.location}";
  }

  // ============================================================
  // TIME LABEL
  // ============================================================

  String _formatTimeLabel(
      String bestTime,
      ) {

    final value =
        bestTime.toLowerCase();

    if (value.contains("morning")) {
      return "MORNING";
    }

    if (value.contains("afternoon")) {
      return "AFTERNOON";
    }

    if (value.contains("evening")) {
      return "EVENING";
    }

    if (value.contains("night")) {
      return "NIGHT";
    }

    return "ANYTIME";
  }

  // ============================================================
  // TIME EMOJI
  // ============================================================

  String _getTimeEmoji(
      String bestTime,
      ) {

    final value =
        bestTime.toLowerCase();

    if (value.contains("morning")) {
      return "🌅";
    }

    if (value.contains("afternoon")) {
      return "☀️";
    }

    if (value.contains("evening")) {
      return "🌆";
    }

    if (value.contains("night")) {
      return "🌙";
    }

    return "📍";
  }
}