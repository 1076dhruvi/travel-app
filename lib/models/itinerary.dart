class StartPoint {
  final String name;
  final double latitude;
  final double longitude;
  final String source; // 'gps' | 'search'
  final String departureTime;

  double get lat => latitude;
  double get lng => longitude;

  StartPoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.source = 'gps',
    this.departureTime = "09:00",
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': latitude,
      'lng': longitude,
      'lon': longitude,
      'source': source,
      'departureTime': departureTime,
    };
  }

  factory StartPoint.fromMap(Map<String, dynamic> map) {
    return StartPoint(
      name: map['name']?.toString() ?? 'Start Point',
      latitude: (map['lat'] as num?)?.toDouble() ??
          (map['latitude'] as num?)?.toDouble() ??
          0.0,
      longitude: (map['lng'] as num?)?.toDouble() ??
          (map['lon'] as num?)?.toDouble() ??
          (map['longitude'] as num?)?.toDouble() ??
          0.0,
      source: map['source']?.toString() ?? 'gps',
      departureTime: map['departureTime']?.toString() ?? '09:00',
    );
  }
}

class TransitStep {
  final String type; // 'walk', 'transit', 'drive'
  final String instruction;
  final String? duration;
  final String? distance;
  final String? lineName;
  final String? boardingStop;
  final String? alightingStop;
  final int? stopCount;
  final String? departureTime;

  TransitStep({
    required this.type,
    required this.instruction,
    this.duration,
    this.distance,
    this.lineName,
    this.boardingStop,
    this.alightingStop,
    this.stopCount,
    this.departureTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'instruction': instruction,
      'duration': duration,
      'distance': distance,
      'lineName': lineName,
      'boardingStop': boardingStop,
      'alightingStop': alightingStop,
      'stopCount': stopCount,
      'departureTime': departureTime,
    };
  }

  factory TransitStep.fromMap(Map<String, dynamic> map) {
    return TransitStep(
      type: map['type']?.toString().toLowerCase() ?? 'transit',
      instruction: map['instruction']?.toString() ?? '',
      duration: map['duration']?.toString(),
      distance: map['distance']?.toString(),
      lineName: map['lineName']?.toString(),
      boardingStop: map['boardingStop']?.toString(),
      alightingStop: map['alightingStop']?.toString(),
      stopCount: (map['stopCount'] as num?)?.toInt(),
      departureTime: map['departureTime']?.toString(),
    );
  }
}

class TransportOption {
  final String mode; // 'walk', 'cab', 'bus', 'train'
  final String title;
  final String duration;
  final int durationMinutes;
  final int durationSeconds;
  final String distance;
  final int distanceMeters;
  final String cost; // '₹120', '₹15', 'Free', 'check locally'
  final String? transitLine;
  final String? boardingStop;
  final String? alightingStop;
  final int? stopCount;
  final String? departureTime;
  final List<List<double>> polyline;
  final List<TransitStep> steps;

  TransportOption({
    required this.mode,
    required this.title,
    required this.duration,
    this.durationMinutes = 0,
    this.durationSeconds = 0,
    required this.distance,
    this.distanceMeters = 0,
    required this.cost,
    this.transitLine,
    this.boardingStop,
    this.alightingStop,
    this.stopCount,
    this.departureTime,
    this.polyline = const [],
    this.steps = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'mode': mode,
      'title': title,
      'duration': duration,
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'distance': distance,
      'distanceMeters': distanceMeters,
      'cost': cost,
      'transitLine': transitLine,
      'boardingStop': boardingStop,
      'alightingStop': alightingStop,
      'stopCount': stopCount,
      'departureTime': departureTime,
      'polyline': polyline,
      'steps': steps.map((s) => s.toMap()).toList(),
    };
  }

  factory TransportOption.fromMap(Map<String, dynamic> map) {
    List<List<double>> decoded = [];
    if (map['polyline'] != null && map['polyline'] is List) {
      for (var pt in map['polyline']) {
        if (pt is List && pt.length >= 2) {
          decoded.add([
            (pt[0] as num).toDouble(),
            (pt[1] as num).toDouble(),
          ]);
        }
      }
    }

    List<TransitStep> loadedSteps = [];
    if (map['steps'] != null && map['steps'] is List) {
      for (var s in map['steps']) {
        if (s is Map) {
          loadedSteps.add(TransitStep.fromMap(Map<String, dynamic>.from(s)));
        }
      }
    }

    return TransportOption(
      mode: map['mode']?.toString().toLowerCase() ?? 'cab',
      title: map['title']?.toString() ?? 'Option',
      duration: map['duration']?.toString() ?? '0 min',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      distance: map['distance']?.toString() ?? '0 km',
      distanceMeters: (map['distanceMeters'] as num?)?.toInt() ?? 0,
      cost: map['cost']?.toString() ?? 'check locally',
      transitLine: map['transitLine']?.toString(),
      boardingStop: map['boardingStop']?.toString(),
      alightingStop: map['alightingStop']?.toString(),
      stopCount: (map['stopCount'] as num?)?.toInt(),
      departureTime: map['departureTime']?.toString(),
      polyline: decoded,
      steps: loadedSteps,
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
  final int durationSeconds;
  final String mode; // 'walk', 'bus', 'train', 'cab'
  final String? transitLine;
  final String? cost;
  final String? boardingStop;
  final String? alightingStop;
  final int? stopCount;
  final String? departureTime;
  final List<List<double>> polyline; // [[lat, lon], ...]
  final List<TransportOption> options;
  final int selectedOptionIndex;
  final List<TransitStep> steps;

  ItineraryLeg({
    required this.from,
    required this.to,
    required this.distance,
    this.distanceMeters = 0,
    required this.duration,
    this.durationMinutes = 0,
    this.durationSeconds = 0,
    required this.mode,
    this.transitLine,
    this.cost,
    this.boardingStop,
    this.alightingStop,
    this.stopCount,
    this.departureTime,
    this.polyline = const [],
    this.options = const [],
    this.selectedOptionIndex = 0,
    this.steps = const [],
  });

  ItineraryLeg copyWithSelectedOption(int index) {
    if (index < 0 || index >= options.length) return this;
    final opt = options[index];
    return ItineraryLeg(
      from: from,
      to: to,
      distance: opt.distance,
      distanceMeters: opt.distanceMeters,
      duration: opt.duration,
      durationMinutes: opt.durationMinutes,
      durationSeconds: opt.durationSeconds,
      mode: opt.mode,
      transitLine: opt.transitLine,
      cost: opt.cost,
      boardingStop: opt.boardingStop,
      alightingStop: opt.alightingStop,
      stopCount: opt.stopCount,
      departureTime: opt.departureTime,
      polyline: opt.polyline.isNotEmpty ? opt.polyline : polyline,
      options: options,
      selectedOptionIndex: index,
      steps: opt.steps.isNotEmpty ? opt.steps : steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'distance': distance,
      'distanceMeters': distanceMeters,
      'duration': duration,
      'durationMinutes': durationMinutes,
      'durationSeconds': durationSeconds,
      'mode': mode,
      'transitLine': transitLine,
      'cost': cost,
      'boardingStop': boardingStop,
      'alightingStop': alightingStop,
      'stopCount': stopCount,
      'departureTime': departureTime,
      'polyline': polyline,
      'options': options.map((o) => o.toMap()).toList(),
      'selectedOptionIndex': selectedOptionIndex,
      'steps': steps.map((s) => s.toMap()).toList(),
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

    List<TransportOption> loadedOptions = [];
    if (map['options'] != null && map['options'] is List) {
      for (var opt in map['options']) {
        if (opt is Map) {
          loadedOptions.add(TransportOption.fromMap(Map<String, dynamic>.from(opt)));
        }
      }
    }

    List<TransitStep> loadedSteps = [];
    if (map['steps'] != null && map['steps'] is List) {
      for (var s in map['steps']) {
        if (s is Map) {
          loadedSteps.add(TransitStep.fromMap(Map<String, dynamic>.from(s)));
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
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      mode: map['mode']?.toString().toLowerCase() ?? 'cab',
      transitLine: map['transitLine']?.toString(),
      cost: map['cost']?.toString(),
      boardingStop: map['boardingStop']?.toString(),
      alightingStop: map['alightingStop']?.toString(),
      stopCount: (map['stopCount'] as num?)?.toInt(),
      departureTime: map['departureTime']?.toString(),
      polyline: decoded,
      options: loadedOptions,
      selectedOptionIndex: (map['selectedOptionIndex'] as num?)?.toInt() ?? 0,
      steps: loadedSteps,
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
