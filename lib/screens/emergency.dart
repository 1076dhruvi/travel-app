import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/emergency_places_service.dart';
import '../services/geocoding_service.dart';

class EmergencyDirectory extends StatefulWidget {
  final String location;

  const EmergencyDirectory({
    super.key,
    required this.location,
  });

  @override
  State<EmergencyDirectory> createState() => _EmergencyDirectoryState();
}

class _EmergencyDirectoryState extends State<EmergencyDirectory> {
  // ============================================================
  // SERVICES
  // ============================================================

  final EmergencyPlacesService _placesService =
  EmergencyPlacesService();

  final GeocodingService _geocodingService =
  GeocodingService();

  // ============================================================
  // EMERGENCY CONTACTS
  // ============================================================

  List<Map<String, dynamic>> _contacts = [];

  String _resolvedCountry = 'Unknown';

  bool _isLoadingContacts = true;

  String _contactError = '';

  // ============================================================
  // LOCATION
  // ============================================================

  Map<String, double>? _currentCoordinates;

  bool _isLoadingLocation = false;

  String _locationError = '';

  // ============================================================
  // NEARBY PLACES
  // ============================================================

  List<EmergencyPlace> _hospitals = [];

  List<EmergencyPlace> _policeStations = [];

  List<EmergencyPlace> _fireStations = [];

  bool _isLoadingPlaces = false;

  String _placesError = '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadEmergencyContacts();
  }

  // ============================================================
  // COUNTRY DETECTION
  // ============================================================

  String _resolveCountry(String location) {
    final loc = location
        .toLowerCase()
        .trim()
        .replaceAll(',', ' ')
        .replaceAll('-', ' ');

    // ------------------------------------------------------------
    // INDIA
    // ------------------------------------------------------------

    // Country name
    if (loc.contains('india') ||
        loc.contains('bharat') ||
        loc.contains('republic of india')) {
      return 'india';
    }

    // Indian states and union territories
    const indiaStates = [
      'andhra pradesh',
      'arunachal pradesh',
      'assam',
      'bihar',
      'chhattisgarh',
      'goa',
      'gujarat',
      'haryana',
      'himachal pradesh',
      'jharkhand',
      'karnataka',
      'kerala',
      'madhya pradesh',
      'maharashtra',
      'manipur',
      'meghalaya',
      'mizoram',
      'nagaland',
      'odisha',
      'orissa',
      'punjab',
      'rajasthan',
      'sikkim',
      'tamil nadu',
      'telangana',
      'tripura',
      'uttar pradesh',
      'uttarakhand',
      'west bengal',
      'andaman and nicobar',
      'andaman',
      'nicobar',
      'chandigarh',
      'dadra and nagar haveli',
      'daman and diu',
      'delhi',
      'jammu and kashmir',
      'ladakh',
      'lakshadweep',
      'puducherry',
      'pondicherry',
    ];

    for (final state in indiaStates) {
      if (loc.contains(state)) {
        return 'india';
      }
    }

    // ------------------------------------------------------------
    // INDIAN CITIES
    // ------------------------------------------------------------

    const indiaCities = [
      // Maharashtra
      'mumbai',
      'bombay',
      'pune',
      'nagpur',
      'nashik',
      'nashik',
      'thane',
      'aurangabad',
      'chhatrapati sambhajinagar',
      'kolhapur',
      'navi mumbai',
      'vasai',
      'virar',
      'solapur',
      'amravati',
      'akola',
      'satara',
      'ratnagiri',

      // Odisha
      'bhubaneswar',
      'bhubaneshwar',
      'cuttack',
      'rourkela',
      'puri',
      'sambalpur',
      'berhampur',
      'brahmapur',
      'balasore',
      'baripada',
      'jharsuguda',
      'angul',
      'koraput',

      // Delhi NCR
      'new delhi',
      'delhi',
      'gurgaon',
      'gurugram',
      'noida',
      'greater noida',
      'ghaziabad',
      'faridabad',

      // Karnataka
      'bengaluru',
      'bangalore',
      'mysuru',
      'mysore',
      'mangalore',
      'mangaluru',
      'hubli',
      'hubballi',
      'belgaum',
      'belagavi',
      'shimoga',
      'shivamogga',
      'tumkur',
      'tumakuru',
      'udupi',
      'davangere',
      'ballari',
      'bellary',

      // Tamil Nadu
      'chennai',
      'madurai',
      'coimbatore',
      'tiruchirappalli',
      'trichy',
      'salem',
      'tirunelveli',
      'vellore',
      'erode',
      'thoothukudi',
      'tuticorin',
      'thanjavur',
      'dindigul',
      'kanchipuram',
      'tiruppur',
      'ooty',
      'coonoor',

      // Telangana
      'hyderabad',
      'warangal',
      'nizamabad',
      'karimnagar',
      'khammam',
      'secunderabad',

      // Andhra Pradesh
      'visakhapatnam',
      'vizag',
      'vijayawada',
      'guntur',
      'tirupati',
      'nellore',
      'kurnool',
      'kadapa',
      'rajahmundry',
      'kakinada',
      'anantapur',

      // Kerala
      'thiruvananthapuram',
      'trivandrum',
      'kochi',
      'cochin',
      'kozhikode',
      'calicut',
      'thrissur',
      'kollam',
      'alappuzha',
      'alleppey',
      'palakkad',
      'kannur',
      'kottayam',
      'munnar',
      'wayanad',

      // West Bengal
      'kolkata',
      'calcutta',
      'howrah',
      'durgapur',
      'siliguri',
      'asansol',
      'darjeeling',

      // Gujarat
      'ahmedabad',
      'surat',
      'vadodara',
      'baroda',
      'rajkot',
      'gandhinagar',
      'bhavnagar',
      'jamnagar',
      'junagadh',
      'anand',
      'vapi',
      'dwarka',

      // Rajasthan
      'jaipur',
      'jodhpur',
      'udaipur',
      'kota',
      'ajmer',
      'bikaner',
      'alwar',
      'pushkar',
      'jaisalmer',
      'mount abu',

      // Uttar Pradesh
      'lucknow',
      'kanpur',
      'agra',
      'varanasi',
      'prayagraj',
      'allahabad',
      'meerut',
      'bareilly',
      'aligarh',
      'mathura',
      'ayodhya',
      'gorakhpur',
      'noida',
      'ghaziabad',

      // Bihar
      'patna',
      'gaya',
      'muzaffarpur',
      'bhagalpur',
      'darbhanga',
      'purnia',

      // Madhya Pradesh
      'bhopal',
      'indore',
      'jabalpur',
      'gwalior',
      'ujjain',
      'sagar',
      'rewa',

      // Punjab
      'amritsar',
      'ludhiana',
      'jalandhar',
      'patiala',
      'bathinda',
      'mohali',

      // Haryana
      'gurugram',
      'gurgaon',
      'faridabad',
      'panipat',
      'ambala',
      'hisar',
      'rohtak',
      'karnal',

      // Jharkhand
      'ranchi',
      'jamshedpur',
      'dhanbad',
      'bokaro',
      'deoghar',

      // Chhattisgarh
      'raipur',
      'bilaspur',
      'durg',
      'bhilai',
      'korba',

      // Uttarakhand
      'dehradun',
      'haridwar',
      'rishikesh',
      'nainital',
      'mussoorie',
      'haldwani',

      // Himachal Pradesh
      'shimla',
      'manali',
      'dharamshala',
      'kullu',
      'solan',

      // Goa
      'panaji',
      'panjim',
      'margao',
      'vasco da gama',
      'calangute',

      // Assam
      'guwahati',
      'dibrugarh',
      'silchar',
      'jorhat',

      // Meghalaya
      'shillong',

      // Sikkim
      'gangtok',

      // Jammu & Kashmir
      'srinagar',
      'jammu',
      'gulmarg',
      'pahalgam',

      // Ladakh
      'leh',
      'kargil',

      // Tripura
      'agartala',

      // Manipur
      'imphal',

      // Mizoram
      'aizawl',

      // Nagaland
      'kohima',
      'dimapur',

      // Arunachal Pradesh
      'itanagar',

      // Puducherry
      'puducherry',
      'pondicherry',

      // Andaman
      'port blair',
      'sri vijaya puram',

      // Chandigarh
      'chandigarh',
    ];

    for (final city in indiaCities) {
      if (loc.contains(city)) {
        return 'india';
      }
    }

    // ------------------------------------------------------------
    // UNITED STATES
    // ------------------------------------------------------------

    const usaTerms = [
      'usa',
      'u.s.a',
      'united states',
      'america',
      'new york',
      'california',
      'texas',
      'florida',
      'los angeles',
      'chicago',
      'washington',
      'san francisco',
      'boston',
      'seattle',
      'las vegas',
      'miami',
      'houston',
    ];

    for (final term in usaTerms) {
      if (loc.contains(term)) {
        return 'united_states';
      }
    }

    // ------------------------------------------------------------
    // CANADA
    // ------------------------------------------------------------

    const canadaTerms = [
      'canada',
      'toronto',
      'vancouver',
      'montreal',
      'ottawa',
      'calgary',
      'edmonton',
      'quebec',
    ];

    for (final term in canadaTerms) {
      if (loc.contains(term)) {
        return 'canada';
      }
    }

    // ------------------------------------------------------------
    // UNITED KINGDOM
    // ------------------------------------------------------------

    const ukTerms = [
      'uk',
      'u.k',
      'united kingdom',
      'england',
      'london',
      'manchester',
      'birmingham',
      'scotland',
      'wales',
      'liverpool',
      'edinburgh',
      'glasgow',
    ];

    for (final term in ukTerms) {
      if (loc.contains(term)) {
        return 'united_kingdom';
      }
    }

    // ------------------------------------------------------------
    // AUSTRALIA
    // ------------------------------------------------------------

    const australiaTerms = [
      'australia',
      'sydney',
      'melbourne',
      'brisbane',
      'perth',
      'adelaide',
      'canberra',
      'gold coast',
    ];

    for (final term in australiaTerms) {
      if (loc.contains(term)) {
        return 'australia';
      }
    }

    // ------------------------------------------------------------
    // NEW ZEALAND
    // ------------------------------------------------------------

    const newZealandTerms = [
      'new zealand',
      'auckland',
      'wellington',
      'christchurch',
      'queenstown',
    ];

    for (final term in newZealandTerms) {
      if (loc.contains(term)) {
        return 'new_zealand';
      }
    }

    // ------------------------------------------------------------
    // UAE
    // ------------------------------------------------------------

    const uaeTerms = [
      'uae',
      'u.a.e',
      'united arab emirates',
      'dubai',
      'abu dhabi',
      'sharjah',
      'ajman',
      'ras al khaimah',
      'fujairah',
    ];

    for (final term in uaeTerms) {
      if (loc.contains(term)) {
        return 'uae';
      }
    }

    // ------------------------------------------------------------
    // SINGAPORE
    // ------------------------------------------------------------

    if (loc.contains('singapore')) {
      return 'singapore';
    }

    // ------------------------------------------------------------
    // FRANCE
    // ------------------------------------------------------------

    const franceTerms = [
      'france',
      'paris',
      'lyon',
      'marseille',
      'nice',
      'toulouse',
      'bordeaux',
    ];

    for (final term in franceTerms) {
      if (loc.contains(term)) {
        return 'france';
      }
    }

    // ------------------------------------------------------------
    // GERMANY
    // ------------------------------------------------------------

    const germanyTerms = [
      'germany',
      'berlin',
      'munich',
      'frankfurt',
      'hamburg',
      'cologne',
      'dresden',
    ];

    for (final term in germanyTerms) {
      if (loc.contains(term)) {
        return 'germany';
      }
    }

    // ------------------------------------------------------------
    // ITALY
    // ------------------------------------------------------------

    const italyTerms = [
      'italy',
      'rome',
      'milan',
      'venice',
      'florence',
      'naples',
    ];

    for (final term in italyTerms) {
      if (loc.contains(term)) {
        return 'italy';
      }
    }

    // ------------------------------------------------------------
    // SPAIN
    // ------------------------------------------------------------

    const spainTerms = [
      'spain',
      'madrid',
      'barcelona',
      'seville',
      'valencia',
    ];

    for (final term in spainTerms) {
      if (loc.contains(term)) {
        return 'spain';
      }
    }

    // ------------------------------------------------------------
    // PORTUGAL
    // ------------------------------------------------------------

    const portugalTerms = [
      'portugal',
      'lisbon',
      'porto',
    ];

    for (final term in portugalTerms) {
      if (loc.contains(term)) {
        return 'portugal';
      }
    }

    // ------------------------------------------------------------
    // GREECE
    // ------------------------------------------------------------

    const greeceTerms = [
      'greece',
      'athens',
      'thessaloniki',
    ];

    for (final term in greeceTerms) {
      if (loc.contains(term)) {
        return 'greece';
      }
    }

    // ------------------------------------------------------------
    // SWITZERLAND
    // ------------------------------------------------------------

    const switzerlandTerms = [
      'switzerland',
      'zurich',
      'geneva',
      'bern',
      'basel',
    ];

    for (final term in switzerlandTerms) {
      if (loc.contains(term)) {
        return 'switzerland';
      }
    }

    // ------------------------------------------------------------
    // NETHERLANDS
    // ------------------------------------------------------------

    const netherlandsTerms = [
      'netherlands',
      'amsterdam',
      'rotterdam',
      'the hague',
    ];

    for (final term in netherlandsTerms) {
      if (loc.contains(term)) {
        return 'netherlands';
      }
    }

    // ------------------------------------------------------------
    // JAPAN
    // ------------------------------------------------------------

    const japanTerms = [
      'japan',
      'tokyo',
      'osaka',
      'kyoto',
      'hiroshima',
      'nagoya',
    ];

    for (final term in japanTerms) {
      if (loc.contains(term)) {
        return 'japan';
      }
    }

    // ------------------------------------------------------------
    // SOUTH KOREA
    // ------------------------------------------------------------

    const southKoreaTerms = [
      'south korea',
      'korea',
      'seoul',
      'busan',
      'incheon',
      'daegu',
    ];

    for (final term in southKoreaTerms) {
      if (loc.contains(term)) {
        return 'south_korea';
      }
    }

    // ------------------------------------------------------------
    // THAILAND
    // ------------------------------------------------------------

    const thailandTerms = [
      'thailand',
      'bangkok',
      'phuket',
      'pattaya',
      'chiang mai',
    ];

    for (final term in thailandTerms) {
      if (loc.contains(term)) {
        return 'thailand';
      }
    }

    // ------------------------------------------------------------
    // MALAYSIA
    // ------------------------------------------------------------

    const malaysiaTerms = [
      'malaysia',
      'kuala lumpur',
      'penang',
      'langkawi',
      'malacca',
    ];

    for (final term in malaysiaTerms) {
      if (loc.contains(term)) {
        return 'malaysia';
      }
    }

    // ------------------------------------------------------------
    // INDONESIA
    // ------------------------------------------------------------

    const indonesiaTerms = [
      'indonesia',
      'jakarta',
      'bali',
      'surabaya',
      'bandung',
      'yogyakarta',
    ];

    for (final term in indonesiaTerms) {
      if (loc.contains(term)) {
        return 'indonesia';
      }
    }

    // ------------------------------------------------------------
    // FALLBACK
    // ------------------------------------------------------------

    return 'fallback';
  }

  // ============================================================
  // LOAD EMERGENCY NUMBERS
  // ============================================================

  Future<void> _loadEmergencyContacts() async {
    setState(() {
      _isLoadingContacts = true;
      _contactError = '';
    });

    try {
      final rawJson = await rootBundle.loadString(
        'assets/data/emergency_data.json',
      );

      final jsonData =
      json.decode(rawJson) as Map<String, dynamic>;

      final countryKey =
      _resolveCountry(widget.location);

      final selectedData =
          jsonData[countryKey] ??
              jsonData['fallback'] ??
              [];

      setState(() {
        _resolvedCountry =
            _formatCountryName(countryKey);

        _contacts =
        List<Map<String, dynamic>>.from(
          selectedData,
        );

        _isLoadingContacts = false;
      });
    } catch (e) {
      setState(() {
        _contactError =
        'Could not load emergency numbers.\n'
            'Please try again.';

        _isLoadingContacts = false;
      });
    }
  }

  String _formatCountryName(String country) {
    if (country == 'fallback') {
      return 'International';
    }

    return country
        .split('_')
        .map(
          (word) =>
      word[0].toUpperCase() +
          word.substring(1),
    )
        .join(' ');
  }

  // ============================================================
  // FIND NEARBY EMERGENCY PLACES
  // ============================================================

  Future<void> _findNearbyEmergencyPlaces() async {
    setState(() {
      _isLoadingLocation = true;
      _isLoadingPlaces = true;
      _locationError = '';
      _placesError = '';
    });

    try {
      final coordinates =
      await _geocodingService.getCoordinates(
        widget.location,
      );

      if (coordinates == null) {
        setState(() {
          _isLoadingLocation = false;
          _isLoadingPlaces = false;

          _locationError =
          'Could not find the location: '
              '${widget.location}';
        });

        return;
      }

      final latitude = coordinates['lat']!;
      final longitude = coordinates['lon']!;

      setState(() {
        _currentCoordinates = coordinates;
        _isLoadingLocation = false;
      });

      final results = await Future.wait([
        _placesService.getNearbyHospitals(
          latitude: latitude,
          longitude: longitude,
        ),
        _placesService.getNearbyPoliceStations(
          latitude: latitude,
          longitude: longitude,
        ),
        _placesService.getNearbyFireStations(
          latitude: latitude,
          longitude: longitude,
        ),
      ]);

      setState(() {
        _hospitals = results[0];
        _policeStations = results[1];
        _fireStations = results[2];

        _isLoadingPlaces = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _isLoadingPlaces = false;

        _placesError =
        'Could not find nearby emergency facilities.\n'
            'Please check your internet connection and try again.';
      });
    }
  }

  // ============================================================
  // PHONE CALL
  // ============================================================

  Future<void> _makeCall(String number) async {
    final cleanedNumber =
    number.replaceAll(RegExp(r'[^0-9+]'), '');

    final Uri url =
    Uri.parse('tel:$cleanedNumber');

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open dialer for $number',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open dialer for $number',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================================
  // OPEN NAVIGATION
  // ============================================================

  Future<void> _navigateToPlace(
      EmergencyPlace place,
      ) async {
    if (_currentCoordinates == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location is not available.',
            ),
          ),
        );
      }
      return;
    }

    final latitude =
    _currentCoordinates!['lat']!;

    final longitude =
    _currentCoordinates!['lon']!;

    // Try Google Maps app directly.
    final Uri googleMapsAppUrl = Uri.parse(
      'google.navigation:q='
          '${place.latitude},${place.longitude}'
          '&mode=d',
    );

    try {
      final openedApp = await launchUrl(
        googleMapsAppUrl,
        mode: LaunchMode.externalApplication,
      );

      if (openedApp) {
        return;
      }
    } catch (_) {
      // Continue to web fallback.
    }

    // Fallback to Google Maps web URL.
    final Uri googleMapsWebUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
          '&origin=$latitude,$longitude'
          '&destination=${place.latitude},${place.longitude}'
          '&travelmode=driving',
    );

    try {
      final openedWeb = await launchUrl(
        googleMapsWebUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!openedWeb && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Google Maps. Please install Google Maps or a browser.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not open Google Maps.',
            ),
          ),
        );
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF5F5F5),

      appBar: AppBar(
        backgroundColor:
        Colors.red.shade700,

        title: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            const Text(
              'Emergency Directory',
              style: TextStyle(
                fontSize: 17,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            Text(
              widget.location,
              style: const TextStyle(
                fontSize: 12,
                color:
                Colors.white70,
              ),
            ),
          ],
        ),
      ),

      body: _buildBody(),
    );
  }

  // ============================================================
  // MAIN BODY
  // ============================================================

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh:
      _loadEmergencyContacts,

      child: ListView(
        padding:
        const EdgeInsets.only(
          bottom: 24,
        ),

        children: [
          _buildCountryBanner(),

          _buildEmergencyNumbersSection(),

          _buildNearbySection(),
        ],
      ),
    );
  }

  // ============================================================
  // COUNTRY BANNER
  // ============================================================

  Widget _buildCountryBanner() {
    return Container(
      width: double.infinity,

      color:
      Colors.red.shade50,

      padding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      child: Row(
        children: [
          const Icon(
            Icons.public,
            color: Colors.red,
            size: 20,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              'Emergency numbers for $_resolvedCountry',
              style: TextStyle(
                color:
                Colors.red.shade700,
                fontWeight:
                FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMERGENCY NUMBERS
  // ============================================================

  Widget _buildEmergencyNumbersSection() {
    if (_isLoadingContacts) {
      return const Padding(
        padding:
        EdgeInsets.all(24),

        child: Center(
          child:
          CircularProgressIndicator(
            color: Colors.red,
          ),
        ),
      );
    }

    if (_contactError.isNotEmpty) {
      return _buildErrorCard(
        message: _contactError,
        onRetry:
        _loadEmergencyContacts,
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Padding(
          padding:
          EdgeInsets.fromLTRB(
            16,
            18,
            16,
            8,
          ),

          child: Text(
            'Emergency Numbers',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        ..._contacts.map(
          _buildEmergencyContactCard,
        ),
      ],
    );
  }

  Widget _buildEmergencyContactCard(
      Map<String, dynamic> item,
      ) {
    final title =
        item['title']?.toString() ??
            'Emergency Service';

    final number =
        item['number']?.toString() ??
            '';

    IconData icon =
        Icons.warning_amber_rounded;

    Color iconColor =
        Colors.red;

    final lowerTitle =
    title.toLowerCase();

    if (lowerTitle.contains('police')) {
      icon =
          Icons.local_police;

      iconColor =
          Colors.blue.shade700;
    } else if (
    lowerTitle.contains('ambulance') ||
        lowerTitle.contains('medical')) {
      icon =
          Icons.local_hospital;

      iconColor =
          Colors.green.shade700;
    } else if (
    lowerTitle.contains('fire')) {
      icon =
          Icons.local_fire_department;

      iconColor =
          Colors.orange.shade700;
    }

    return Card(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),

      elevation: 2,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),

      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),

        leading: Container(
          width: 44,
          height: 44,

          decoration:
          BoxDecoration(
            color:
            iconColor.withOpacity(0.1),

            borderRadius:
            BorderRadius.circular(10),
          ),

          child: Icon(
            icon,
            color:
            iconColor,
            size: 24,
          ),
        ),

        title: Text(
          title,
          style:
          const TextStyle(
            fontWeight:
            FontWeight.w600,
            fontSize: 14,
          ),
        ),

        subtitle: Text(
          number,
          style: TextStyle(
            color:
            Colors.grey.shade600,
            fontSize: 13,
            letterSpacing:
            0.5,
          ),
        ),

        trailing:
        ElevatedButton.icon(
          style:
          ElevatedButton.styleFrom(
            backgroundColor:
            Colors.green.shade600,

            foregroundColor:
            Colors.white,

            padding:
            const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),

            shape:
            RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(8),
            ),
          ),

          onPressed:
          number.isNotEmpty
              ? () =>
              _makeCall(number)
              : null,

          icon:
          const Icon(
            Icons.call,
            size: 16,
          ),

          label:
          const Text(
            'Call',
            style:
            TextStyle(
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NEARBY SECTION
  // ============================================================

  Widget _buildNearbySection() {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        const Padding(
          padding:
          EdgeInsets.fromLTRB(
            16,
            24,
            16,
            8,
          ),

          child: Text(
            'Nearby Emergency Facilities',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
              FontWeight.bold,
            ),
          ),
        ),

        Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 12,
          ),

          child:
          SizedBox(
            width:
            double.infinity,

            child:
            ElevatedButton.icon(
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                Colors.red.shade700,

                foregroundColor:
                Colors.white,

                padding:
                const EdgeInsets.symmetric(
                  vertical: 13,
                ),

                shape:
                RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(
                    10,
                  ),
                ),
              ),

              onPressed:
              _isLoadingLocation ||
                  _isLoadingPlaces
                  ? null
                  : _findNearbyEmergencyPlaces,

              icon:
              _isLoadingLocation ||
                  _isLoadingPlaces
                  ? const SizedBox(
                width: 18,
                height: 18,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                  Colors.white,
                ),
              )
                  : const Icon(
                Icons.location_on,
              ),

              label:
              Text(
                _isLoadingLocation ||
                    _isLoadingPlaces
                    ? 'Finding Nearby Facilities...'
                    : 'Find Nearby Emergency Facilities',
              ),
            ),
          ),
        ),

        if (_currentCoordinates != null)
          Padding(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              0,
            ),

            child: Text(
              'Showing facilities near ${widget.location}',
              style: TextStyle(
                color:
                Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ),

        if (_locationError.isNotEmpty)
          _buildErrorCard(
            message:
            _locationError,
            onRetry:
            _findNearbyEmergencyPlaces,
          ),

        if (_placesError.isNotEmpty)
          _buildErrorCard(
            message:
            _placesError,
            onRetry:
            _findNearbyEmergencyPlaces,
          ),

        if (!_isLoadingPlaces &&
            _placesError.isEmpty &&
            _currentCoordinates != null) ...[
          _buildFacilityCategory(
            title:
            'Nearby Hospitals',
            icon:
            Icons.local_hospital,
            iconColor:
            Colors.green.shade700,
            places:
            _hospitals,
          ),

          _buildFacilityCategory(
            title:
            'Nearby Police Stations',
            icon:
            Icons.local_police,
            iconColor:
            Colors.blue.shade700,
            places:
            _policeStations,
          ),

          _buildFacilityCategory(
            title:
            'Nearby Fire Stations',
            icon:
            Icons.local_fire_department,
            iconColor:
            Colors.orange.shade700,
            places:
            _fireStations,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // FACILITY CATEGORY
  // ============================================================

  Widget _buildFacilityCategory({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<EmergencyPlace> places,
  }) {
    if (places.isEmpty) {
      return Card(
        margin:
        const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          0,
        ),

        child: ListTile(
          leading:
          Icon(
            icon,
            color:
            iconColor,
          ),

          title:
          Text(title),

          subtitle:
          const Text(
            'No facilities found nearby.',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,

      children: [
        Padding(
          padding:
          const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            4,
          ),

          child: Row(
            children: [
              Icon(
                icon,
                color:
                iconColor,
                size: 21,
              ),

              const SizedBox(width: 8),

              Text(
                title,
                style:
                const TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        ...places.map(
              (place) =>
              _buildFacilityCard(
                place,
                icon,
                iconColor,
              ),
        ),
      ],
    );
  }

  // ============================================================
  // FACILITY CARD
  // ============================================================

  Widget _buildFacilityCard(
      EmergencyPlace place,
      IconData icon,
      Color iconColor,
      ) {
    final distanceKm =
        place.distance / 1000;

    return Card(
      margin:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 5,
      ),

      elevation: 2,

      shape:
      RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),

      child: Padding(
        padding:
        const EdgeInsets.all(14),

        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,

          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [
                Container(
                  width: 42,
                  height: 42,

                  decoration:
                  BoxDecoration(
                    color:
                    iconColor.withOpacity(
                      0.1,
                    ),

                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                  ),

                  child: Icon(
                    icon,
                    color:
                    iconColor,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,

                    children: [
                      Text(
                        place.name,
                        style:
                        const TextStyle(
                          fontWeight:
                          FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        place.address,
                        style:
                        TextStyle(
                          color:
                          Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${distanceKm.toStringAsFixed(1)} km away',
                        style:
                        TextStyle(
                          color:
                          iconColor,
                          fontWeight:
                          FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            Row(
              mainAxisAlignment:
              MainAxisAlignment.end,

              children: [
                if (place.phone != null &&
                    place.phone!.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed:
                        () => _makeCall(
                      place.phone!,
                    ),

                    icon:
                    const Icon(
                      Icons.call,
                      size: 16,
                    ),

                    label:
                    const Text(
                      'Call',
                    ),
                  ),

                const SizedBox(
                  width: 8,
                ),

                ElevatedButton.icon(
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    iconColor,
                    foregroundColor:
                    Colors.white,
                  ),

                  onPressed:
                      () =>
                      _navigateToPlace(
                        place,
                      ),

                  icon:
                  const Icon(
                    Icons.directions,
                    size: 16,
                  ),

                  label:
                  const Text(
                    'Navigate',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR CARD
  // ============================================================

  Widget _buildErrorCard({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Card(
      margin:
      const EdgeInsets.all(12),

      child: Padding(
        padding:
        const EdgeInsets.all(16),

        child: Column(
          children: [
            Text(
              message,
              textAlign:
              TextAlign.center,
              style:
              const TextStyle(
                color:
                Colors.black54,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            TextButton.icon(
              onPressed:
              onRetry,

              icon:
              const Icon(
                Icons.refresh,
              ),

              label:
              const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}