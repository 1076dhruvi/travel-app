import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDirectory extends StatefulWidget {
  final String location;

  const EmergencyDirectory({super.key, required this.location});

  @override
  State<EmergencyDirectory> createState() => _EmergencyDirectoryState();
}

class _EmergencyDirectoryState extends State<EmergencyDirectory> {
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _resolvedCity = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Resolves the city key from location string
  String _resolveCity(String location) {
    final loc = location.toLowerCase().trim();
    const cityKeys = ['mumbai', 'delhi', 'pune', 'goa'];
    for (final city in cityKeys) {
      if (loc.contains(city)) return city;
    }
    return 'india'; // default fallback
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String rawJson = await rootBundle
          .loadString('assets/data/emergency_data.json');

      final Map<String, dynamic> jsonData = json.decode(rawJson);

      final String cityKey = _resolveCity(widget.location);
      _resolvedCity = cityKey[0].toUpperCase() + cityKey.substring(1);

      final List<dynamic> cityData = jsonData[cityKey] ?? jsonData['india'] ?? [];

      setState(() {
        _contacts = List<Map<String, dynamic>>.from(cityData);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not load emergency data.\nPlease try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _makeCall(String number) async {
    final Uri url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open dialer for $number'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Directory',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.location,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('Loading emergency contacts...'),
          ],
        ),
      );
    }

    // Error state
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Data loaded
    return Column(
      children: [
        // City banner
        Container(
          width: double.infinity,
          color: Colors.red.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Text(
                'Showing contacts for: $_resolvedCity',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Contact list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _contacts.length,
            itemBuilder: (context, index) {
              return _buildContactCard(_contacts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactCard(Map<String, dynamic> item) {
    final title = item['title'] ?? 'Unknown';
    final number = item['number'] ?? '';

    // Pick icon by title keyword
    IconData cardIcon = Icons.warning_amber_rounded;
    Color iconColor = Colors.red;

    final t = title.toLowerCase();
    if (t.contains('police')) {
      cardIcon = Icons.local_police;
      iconColor = Colors.blue.shade700;
    } else if (t.contains('ambulance') || t.contains('hospital') ||
        t.contains('medical') || t.contains('clinic')) {
      cardIcon = Icons.local_hospital;
      iconColor = Colors.green.shade700;
    } else if (t.contains('fire')) {
      cardIcon = Icons.local_fire_department;
      iconColor = Colors.orange.shade700;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(cardIcon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            number,
            style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                letterSpacing: 0.5),
          ),
        ),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: number.isNotEmpty ? () => _makeCall(number) : null,
          icon: const Icon(Icons.call, size: 16),
          label: const Text('Call', style: TextStyle(fontSize: 13)),
        ),
      ),
    );
  }
}