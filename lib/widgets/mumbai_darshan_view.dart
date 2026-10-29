import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class MumbaiDarshanView extends StatefulWidget {
  const MumbaiDarshanView({super.key});

  @override
  State<MumbaiDarshanView> createState() => _MumbaiDarshanViewState();
}

class _MumbaiDarshanViewState extends State<MumbaiDarshanView> {
  Map<String, dynamic>? _darshanData;
  bool _isLoading = true;
  String? _errorMessage;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDarshanData();
  }

  Future<void> _loadDarshanData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/mumbai_darshan.json');
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _darshanData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Could not load Mumbai Darshan details: $e";
        });
      }
    }
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not open link: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'halt':
        return const Color(0xFF16A34A); // Green
      case 'selfie-point':
        return const Color(0xFF0284C7); // Blue
      case 'food':
        return const Color(0xFFEA580C); // Orange
      case 'on-the-way':
        return const Color(0xFF64748B); // Slate
      default:
        return AppTheme.primaryTeal;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'halt':
        return Icons.directions_walk;
      case 'selfie-point':
        return Icons.camera_alt_outlined;
      case 'food':
        return Icons.restaurant;
      case 'on-the-way':
        return Icons.directions_bus_outlined;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppTheme.primaryTeal),
        ),
      );
    }

    if (_errorMessage != null || _darshanData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.orangeAccent),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? "No Mumbai Darshan details found.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSlateSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final data = _darshanData!;
    final stops = (data['stops'] as List? ?? [])
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final boardingPoints = (data['boardingPoints'] as List? ?? [])
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    final filteredStops = _activeFilter == 'all'
        ? stops
        : stops.where((s) => (s['type']?.toString().toLowerCase() ?? '') == _activeFilter).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF57220), Color(0xFFEA580C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33F57220),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.directions_bus, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "Guided AC Bus Tour",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "Chalo Bus",
                        style: TextStyle(
                          color: Color(0xFFEA580C),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  data['title']?.toString() ?? "Chalo Mumbai Darshan",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data['description']?.toString() ??
                      "12-hour guided AC bus tour, multilingual live guide, guide charges included",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Timing & Transport Info ──
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.access_time_filled,
                  iconColor: const Color(0xFFF57220),
                  title: "Tour Timings",
                  content: "Pickup: 7:00 to 8:00 AM\nReturn: 8:00 to 9:00 PM",
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.airline_seat_recline_extra,
                  iconColor: const Color(0xFF0284C7),
                  title: "Transport",
                  content: "AC bus\nTwo scenic routes across MMR",
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Pricing & Cancellation ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderSlate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Price per seat:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.textSlatePrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: const Text(
                        "prices may change",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.currency_rupee, size: 16, color: Color(0xFF16A34A)),
                    Text(
                      "₹499",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      " (Thane, Panvel, Borivali)   •   ",
                      style: TextStyle(fontSize: 13, color: AppTheme.textSlateSecondary),
                    ),
                    Text(
                      "₹349",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    Text(
                      " (CSMT)",
                      style: TextStyle(fontSize: 13, color: AppTheme.textSlateSecondary),
                    ),
                  ],
                ),
                const Divider(height: 18, color: AppTheme.borderSlateLight),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 16, color: Color(0xFF16A34A)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        data['cancellation']?.toString() ??
                            "Free cancellation up to 12 hours before the trip",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Boarding Points ──
          if (boardingPoints.isNotEmpty) ...[
            const Text(
              "Boarding Points & Routes",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSlatePrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final bp in boardingPoints)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSlate),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, size: 16, color: Color(0xFFEA580C)),
                        const SizedBox(width: 6),
                        Text(
                          bp['name']?.toString() ?? "Route",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSlatePrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      bp['text']?.toString() ?? "",
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSlateSecondary, height: 1.3),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],

          // ── Itinerary Timeline Header & Filters ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Tour Stops (${stops.length})",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlatePrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', "All (${stops.length})"),
                _buildFilterChip('halt', "Halt"),
                _buildFilterChip('selfie-point', "Selfie Point"),
                _buildFilterChip('food', "Food"),
                _buildFilterChip('on-the-way', "On The Way"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Timeline Cards ──
          if (filteredStops.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSlate),
              ),
              child: const Center(
                child: Text(
                  "No stops found for selected filter.",
                  style: TextStyle(color: AppTheme.textSlateSecondary),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStops.length,
              itemBuilder: (context, index) {
                final stop = filteredStops[index];
                final stopNumber = stop['stopNumber'] ?? index + 1;
                final title = stop['title']?.toString() ?? "";
                final type = stop['type']?.toString() ?? "halt";
                final duration = stop['duration']?.toString();
                final location = stop['location']?.toString() ?? "";
                final description = stop['description']?.toString() ?? "";
                final highlights = (stop['highlights'] as List? ?? []).map((h) => h.toString()).toList();
                final typeColor = _getTypeColor(type);
                final isLast = index == filteredStops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Timeline indicator
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "$stopNumber",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: typeColor.withValues(alpha: 0.3),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Card Content
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.borderSlate),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A0F172A),
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
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.textSlatePrimary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getTypeIcon(type), size: 12, color: typeColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          duration != null ? "$type · $duration" : type,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: typeColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.place_outlined, size: 12, color: AppTheme.textSlateSecondary),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textSlateSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  description,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSlatePrimary, height: 1.3),
                                ),
                              ],
                              if (highlights.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: highlights.map((h) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        h,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF475569)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // ── Footer: Tappable Info Link & Book Tickets Button ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSlate),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () => _launchUrl("https://chalo.com/mumbai/mumbai-darshan"),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.link, size: 16, color: Color(0xFFF57220)),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "For more info visit https://chalo.com/mumbai/mumbai-darshan",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF57220),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.confirmation_number, color: Colors.white),
                    label: const Text(
                      "Book tickets on Chalo",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF57220),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () => _launchUrl("https://chalo.com/app/mumbai-darshan"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppTheme.textSlatePrimary,
        ),
        selected: isSelected,
        selectedColor: const Color(0xFFF57220),
        backgroundColor: const Color(0xFFF1F5F9),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? const Color(0xFFF57220) : AppTheme.borderSlate,
          ),
        ),
        onSelected: (val) {
          setState(() {
            _activeFilter = key;
          });
        },
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderSlate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSlatePrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSlateSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
