class StartPoint {
  final String name;
  final double latitude;
  final double longitude;
  final String departureTime;

  StartPoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.departureTime = "09:00",
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': latitude,
      'lon': longitude,
      'departureTime': departureTime,
    };
  }

  factory StartPoint.fromMap(Map<String, dynamic> map) {
    return StartPoint(
      name: map['name']?.toString() ?? 'Start Point',
      latitude: (map['lat'] as num?)?.toDouble() ??
          (map['latitude'] as num?)?.toDouble() ??
          0.0,
      longitude: (map['lon'] as num?)?.toDouble() ??
          (map['longitude'] as num?)?.toDouble() ??
          0.0,
      departureTime: map['departureTime']?.toString() ?? '09:00',
    );
  }
}

class ItineraryLeg {
  final String from;
  final String to;
  final String distance;
  final int distanceMeters;
  final String duration;
  final int durationMinutes;
  final String mode; // 'walk', 'bus', 'train', 'cab'
  final String? transitLine;
  final List<List<double>> polyline; // [[lat, lon], ...]

  ItineraryLeg({
    required this.from,
    required this.to,
    required this.distance,
    this.distanceMeters = 0,
    required this.duration,
    this.durationMinutes = 0,
    required this.mode,
    this.transitLine,
    this.polyline = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'distance': distance,
      'distanceMeters': distanceMeters,
      'duration': duration,
      'durationMinutes': durationMinutes,
      'mode': mode,
      'transitLine': transitLine,
      'polyline': polyline,
    };
  }

  factory ItineraryLeg.fromMap(Map<String, dynamic> map) {
    List<List<double>> decoded = [];
    if (map['polyline'] != null && map['polyline'] is List) {
      for (var pt in map['polyline']) {
        if (pt is List && pt.length >= 2) {
          final lat = (pt[0] as num).toDouble();
          final lon = (pt[1] as num).toDouble();
          decoded.add([lat, lon]);
        }
      }
    }

    return ItineraryLeg(
      from: map['from']?.toString() ?? '',
      to: map['to']?.toString() ?? '',
      distance: map['distance']?.toString() ?? '0 km',
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 0,
      duration: map['duration']?.toString() ?? '0 min',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      mode: map['mode']?.toString().toLowerCase() ?? 'cab',
      transitLine: map['transitLine']?.toString(),
      polyline: decoded,
    );
  }
}

class ItineraryPlace {
  final String name;
  final double latitude;
  final double longitude;
  final String? day;
  final int dayNumber;
  final int stopNumber;
  final String? time;
  final String? arrivalTime;
  final String? leaveTime;
  final String? duration;
  final String? description;
  final String? bestTime;
  final String? openingHours;

  ItineraryPlace({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.day,
    this.dayNumber = 1,
    this.stopNumber = 1,
    this.time,
    this.arrivalTime,
    this.leaveTime,
    this.duration,
    this.description,
    this.bestTime,
    this.openingHours,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'day': day,
      'dayNumber': dayNumber,
      'stopNumber': stopNumber,
      'time': time ?? arrivalTime,
      'arrivalTime': arrivalTime ?? time,
      'leaveTime': leaveTime,
      'duration': duration,
      'description': description,
      'bestTime': bestTime,
      'openingHours': openingHours,
    };
  }

  factory ItineraryPlace.fromMap(Map<String, dynamic> map) {
    final arrTime = map['arrivalTime']?.toString() ?? map['time']?.toString();
    final levTime = map['leaveTime']?.toString();

    return ItineraryPlace(
      name: map['name'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble() ??
          0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ??
          (map['lon'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble() ??
          0.0,
      day: map['day']?.toString() ?? 'Day 1',
      dayNumber: (map['dayNumber'] as num?)?.toInt() ??
          (map['day'] is int ? map['day'] as int : 1),
      stopNumber: (map['stopNumber'] as num?)?.toInt() ?? 1,
      time: arrTime,
      arrivalTime: arrTime,
      leaveTime: levTime,
      duration: map['duration']?.toString(),
      description: map['description']?.toString(),
      bestTime: map['bestTime']?.toString(),
      openingHours: map['openingHours']?.toString() ?? 'check locally',
    );
  }
}
