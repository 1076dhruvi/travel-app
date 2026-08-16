import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../services/database_service.dart';
import '../services/image_service.dart';
import '../services/geocoding_service.dart';

class CreateTrip extends StatefulWidget {
  final Trip? trip;

  const CreateTrip({
    super.key,
    this.trip,
  });

  @override
  State<CreateTrip> createState() => _CreateTripState();
}

class _CreateTripState extends State<CreateTrip> {
  final TextEditingController titleController =
      TextEditingController();

  final TextEditingController locationController =
      TextEditingController();

  final TextEditingController dateController =
      TextEditingController();

  final TextEditingController daysController =
      TextEditingController();

  final GeocodingService geocodingService =
      GeocodingService();

  List<Map<String, dynamic>> locationSuggestions = [];

  bool isSearchingLocation = false;

  int currentStep = 0;

  Map<String, dynamic>? selectedLocation;

  @override
  void initState() {
    super.initState();

    if (widget.trip != null) {
      titleController.text = widget.trip!.title;
      locationController.text = widget.trip!.location;
      dateController.text = widget.trip!.date;
      daysController.text =
          widget.trip!.days.toString();

      // When editing, skip directly to details.
      currentStep = 1;
    } else {
      daysController.text = "1";
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    locationController.dispose();
    dateController.dispose();
    daysController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // LOCATION SEARCH
  // ------------------------------------------------------------

  Future<void> searchLocations(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        locationSuggestions = [];
        isSearchingLocation = false;
      });
      return;
    }

    setState(() {
      isSearchingLocation = true;
    });

    try {
      final results =
          await geocodingService.searchPlaces(query);

      if (!mounted) return;

      setState(() {
        locationSuggestions = results;
        isSearchingLocation = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        locationSuggestions = [];
        isSearchingLocation = false;
      });

      print("LOCATION SEARCH ERROR: $e");
    }
  }

  // ------------------------------------------------------------
  // SELECT LOCATION
  // ------------------------------------------------------------

  void selectLocation(Map<String, dynamic> place) {
    setState(() {
      selectedLocation = place;

      locationController.text =
          place["name"]?.toString() ?? "";

      locationSuggestions = [];
    });
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> pickDate() async {
    DateTime? pickedDate =
        await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
    );

    if (pickedDate != null) {
      setState(() {
        dateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  // ------------------------------------------------------------
  // NEXT BUTTON
  // ------------------------------------------------------------

  void goToDetails() {
    if (locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a destination first.",
          ),
        ),
      );

      return;
    }

    setState(() {
      currentStep = 1;
    });
  }

  // ------------------------------------------------------------
  // BACK BUTTON
  // ------------------------------------------------------------

  void goBackToLocation() {
    setState(() {
      currentStep = 0;
    });
  }

  // ------------------------------------------------------------
  // SAVE TRIP
  // ------------------------------------------------------------

  Future<void> saveTrip() async {
    if (titleController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty ||
        dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please fill in all trip details.",
          ),
        ),
      );

      return;
    }

    int days =
        int.tryParse(daysController.text) ?? 1;

    if (days < 1) {
      days = 1;
    }

    String? imageUrl;

    try {
      imageUrl =
          await ImageService().getCoverImage(
        locationController.text,
      );
    } catch (e) {
      print("IMAGE ERROR: $e");
    }

    final trip = Trip(
      id: widget.trip?.id,
      title: titleController.text.trim(),
      location: locationController.text.trim(),
      date: dateController.text.trim(),
      days: days,
      coverImage: imageUrl,
    );

    try {
      if (widget.trip == null) {
        await DatabaseService().insertTrip(trip);

        print("TRIP CREATED");
      } else {
        await DatabaseService().updateTrip(trip);

        print("TRIP UPDATED");
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      print("SAVE TRIP ERROR: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Could not save trip. Please try again.",
          ),
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,

        title: Text(
          isEditing
              ? "Edit Trip"
              : currentStep == 0
                  ? "Create Trip"
                  : "Trip Details",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        flexibleSpace: Container(
          decoration:
              const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF7C4DFF),
                Color(0xFFB388FF),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: AnimatedSwitcher(
        duration:
            const Duration(milliseconds: 300),

        child: currentStep == 0
            ? _buildLocationStep()
            : _buildDetailsStep(),
      ),
    );
  }

  // ============================================================
  // STEP 1 — LOCATION
  // ============================================================

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      key: const ValueKey("location"),

      padding: const EdgeInsets.fromLTRB(
        20,
        35,
        20,
        30,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // TOP ICON
          Center(
            child: Container(
              width: 75,
              height: 75,

              decoration: BoxDecoration(
                color:
                    const Color(0xFF7C4DFF)
                        .withOpacity(0.1),

                shape: BoxShape.circle,
              ),

              child: const Icon(
                Icons.flight_takeoff,
                size: 38,
                color: Color(0xFF7C4DFF),
              ),
            ),
          ),

          const SizedBox(height: 25),

          const Center(
            child: Text(
              "Where are you going?",
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Center(
            child: Text(
              "Search for a city or destination",
              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
          ),

          const SizedBox(height: 35),

          // SEARCH BAR
          Container(
            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(18),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.07),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),

            child: TextField(
              controller: locationController,

              onChanged: (value) {
                // If user changes the selected
                // location, clear previous selection.
                if (selectedLocation != null) {
                  setState(() {
                    selectedLocation = null;
                  });
                }

                searchLocations(value);
              },

              style: const TextStyle(
                fontSize: 16,
              ),

              decoration:
                  InputDecoration(
                prefixIcon:
                    const Icon(
                  Icons.search,
                  color: Color(0xFF7C4DFF),
                  size: 28,
                ),

                suffixIcon:
                    isSearchingLocation
                        ? const Padding(
                            padding:
                                EdgeInsets.all(15),

                            child:
                                SizedBox(
                              width: 18,
                              height: 18,

                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Color(0xFF7C4DFF),
                              ),
                            ),
                          )
                        : locationController
                                .text
                                .isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(
                                  Icons.close,
                                  color:
                                      Colors.grey,
                                ),
                                onPressed: () {
                                  setState(() {
                                    locationController
                                        .clear();

                                    locationSuggestions =
                                        [];

                                    selectedLocation =
                                        null;
                                  });
                                },
                              )
                            : null,

                hintText:
                    "Search your destination",

                hintStyle:
                    const TextStyle(
                  color: Colors.grey,
                ),

                border:
                    InputBorder.none,

                contentPadding:
                    const EdgeInsets.symmetric(
                  vertical: 20,
                ),
              ),
            ),
          ),

          // SEARCH RESULTS
          if (locationSuggestions.isNotEmpty)
            _buildSearchResults(),

          const SizedBox(height: 30),

          // SELECTED LOCATION
          if (selectedLocation != null)
            _buildSelectedLocation(),

          const SizedBox(height: 30),

          // NEXT BUTTON
          SizedBox(
            width: double.infinity,
            height: 56,

            child: ElevatedButton(
              onPressed:
                  locationController.text
                          .trim()
                          .isEmpty
                      ? null
                      : goToDetails,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF7C4DFF),

                disabledBackgroundColor:
                    Colors.grey.shade300,

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),

              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [
                  Text(
                    "Next",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(width: 8),

                  Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH RESULTS
  // ============================================================

  Widget _buildSearchResults() {
    return Container(
      margin:
          const EdgeInsets.only(top: 12),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(18),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.07),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: ListView.separated(
        shrinkWrap: true,

        physics:
            const NeverScrollableScrollPhysics(),

        itemCount:
            locationSuggestions.length,

        separatorBuilder:
            (context, index) =>
                const Divider(
          height: 1,
          indent: 65,
        ),

        itemBuilder:
            (context, index) {
          final place =
              locationSuggestions[index];

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),

            leading: Container(
              width: 42,
              height: 42,

              decoration: BoxDecoration(
                color:
                    const Color(0xFF7C4DFF)
                        .withOpacity(0.1),

                borderRadius:
                    BorderRadius.circular(12),
              ),

              child: const Icon(
                Icons.location_on,
                color: Color(0xFF7C4DFF),
              ),
            ),

            title: Text(
              place["name"] ?? "",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),

            trailing:
                const Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: Colors.grey,
            ),

            onTap: () {
              selectLocation(place);
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // SELECTED LOCATION
  // ============================================================

  Widget _buildSelectedLocation() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color:
            const Color(0xFF7C4DFF)
                .withOpacity(0.08),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              const Color(0xFF7C4DFF)
                  .withOpacity(0.2),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,

            decoration: BoxDecoration(
              color:
                  const Color(0xFF7C4DFF),
              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.check,
              color: Colors.white,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  "Destination selected",
                  style: TextStyle(
                    color:
                        Colors.black54,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  locationController.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              setState(() {
                locationController.clear();
                selectedLocation = null;
              });
            },

            icon: const Icon(
              Icons.edit_outlined,
              color:
                  Color(0xFF7C4DFF),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2 — TRIP DETAILS
  // ============================================================

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      key: const ValueKey("details"),

      padding:
          const EdgeInsets.fromLTRB(
        20,
        25,
        20,
        30,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // BACK
          TextButton.icon(
            onPressed:
                goBackToLocation,

            icon: const Icon(
              Icons.arrow_back,
              color:
                  Color(0xFF7C4DFF),
            ),

            label: const Text(
              "Change destination",
              style: TextStyle(
                color:
                    Color(0xFF7C4DFF),
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            "Trip Details",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            "Tell us a little more about your trip.",
            style: TextStyle(
              color: Colors.black54,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 25),

          // DESTINATION CARD
          Container(
            padding:
                const EdgeInsets.all(16),

            decoration: BoxDecoration(
              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(16),

              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset:
                      const Offset(0, 4),
                ),
              ],
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color:
                      Color(0xFF7C4DFF),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [
                      const Text(
                        "Destination",
                        style:
                            TextStyle(
                          color:
                              Colors.black54,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        locationController.text,
                        style:
                            const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          _buildField(
            controller:
                titleController,
            label: "Trip Name",
            icon:
                Icons.edit_outlined,
          ),

          const SizedBox(height: 16),

          GestureDetector(
            onTap: pickDate,

            child: AbsorbPointer(
              child: _buildField(
                controller:
                    dateController,
                label:
                    "Start Date",
                icon:
                    Icons.calendar_month,
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildField(
            controller:
                daysController,
            label:
                "Number of Days",
            icon:
                Icons.date_range,
            keyboardType:
                TextInputType.number,
          ),

          const SizedBox(height: 35),

          // CREATE TRIP
          SizedBox(
            width: double.infinity,
            height: 56,

            child: ElevatedButton(
              onPressed: saveTrip,

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF7C4DFF),

                elevation: 0,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),

              child: Text(
                widget.trip == null
                    ? "Create Trip"
                    : "Update Trip",

                style:
                    const TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMON FIELD
  // ============================================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType =
        TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset:
                const Offset(0, 4),
          ),
        ],
      ),

      child: TextField(
        controller: controller,

        keyboardType:
            keyboardType,

        decoration:
            InputDecoration(
          prefixIcon: Icon(
            icon,
            color:
                const Color(0xFF7C4DFF),
          ),

          labelText: label,

          border:
              InputBorder.none,

          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}