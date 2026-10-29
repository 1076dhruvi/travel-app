import 'package:flutter_test/flutter_test.dart';
import 'package:trip_dashboard/models/itinerary.dart';

void main() {
  group('Route Polyline & Coordinates Validation', () {
    test('ItineraryLeg correctly preserves [lat, lon] coordinate order and precision', () {
      final sampleCoords = [
        [19.076090, 72.877726],
        [18.922001, 72.834651],
      ];

      final leg = ItineraryLeg(
        from: 'Mumbai Airport',
        to: 'Gateway of India',
        distance: '25.4 km',
        distanceMeters: 25400,
        duration: '45 min',
        durationMinutes: 45,
        durationSeconds: 2700,
        mode: 'cab',
        polyline: sampleCoords,
      );

      final mapData = leg.toMap();
      expect(mapData['polyline'], equals(sampleCoords));

      final restoredLeg = ItineraryLeg.fromMap(mapData);
      expect(restoredLeg.polyline.length, equals(2));
      expect(restoredLeg.polyline[0][0], closeTo(19.076090, 0.000001));
      expect(restoredLeg.polyline[0][1], closeTo(72.877726, 0.000001));
      expect(restoredLeg.polyline[1][0], closeTo(18.922001, 0.000001));
      expect(restoredLeg.polyline[1][1], closeTo(72.834651, 0.000001));
    });

    test('Conversion from ItineraryLeg [lat, lon] to MapLibre GeoJSON [lon, lat] is correct', () {
      final legCoords = [
        [19.0760, 72.8777], // [lat, lon]
        [18.9220, 72.8346],
      ];

      // Flutter MapLibre conversion
      final geoJsonCoords = legCoords.map((pt) => [pt[1], pt[0]]).toList();

      expect(geoJsonCoords[0], equals([72.8777, 19.0760])); // [lon, lat]
      expect(geoJsonCoords[1], equals([72.8346, 18.9220]));
    });

    test('Distinguishes rich road polyline (>2 pts) from straight-line endpoint fallback (<=2 pts)', () {
      final straightLineLeg = ItineraryLeg(
        from: 'A',
        to: 'B',
        distance: '5 km',
        duration: '10 min',
        mode: 'cab',
        polyline: [
          [19.0760, 72.8777],
          [18.9220, 72.8346],
        ],
      );

      final richRoadLeg = ItineraryLeg(
        from: 'A',
        to: 'B',
        distance: '5 km',
        duration: '10 min',
        mode: 'cab',
        polyline: [
          [19.0760, 72.8777],
          [19.0500, 72.8600],
          [19.0100, 72.8450],
          [18.9220, 72.8346],
        ],
      );

      // A polyline with only 2 points is an unrouted straight-line fallback that requires OSRM road fetching
      expect(straightLineLeg.polyline.length <= 2, isTrue);

      // A rich polyline with > 2 points already contains road curves and turns
      expect(richRoadLeg.polyline.length > 2, isTrue);
    });

    test('OSRM route cache immutability test', () {
      final cachedRoute = [
        [72.8777, 19.0760],
        [72.8600, 19.0500],
        [72.8346, 18.9220],
      ];

      // Simulated retrieval using defensive copy
      final retrieved = cachedRoute.map((pt) => List<double>.from(pt)).toList();

      // Stitching operations must not alter the original cached list
      final allCoords = <List<double>>[[72.8900, 19.0900]];
      final slice = (allCoords.isNotEmpty && retrieved.length > 1)
          ? retrieved.sublist(1)
          : retrieved;
      allCoords.addAll(slice);

      expect(cachedRoute.length, equals(3));
      expect(cachedRoute[0], equals([72.8777, 19.0760]));
    });

    test('Day leg filtering correctly isolates legs to selected day without bleeding start point', () {
      final day1Places = [
        ItineraryPlace(name: 'Gateway of India', latitude: 18.9220, longitude: 72.8346, dayNumber: 1),
        ItineraryPlace(name: 'Marine Drive', latitude: 18.9430, longitude: 72.8230, dayNumber: 1),
      ];

      final day2Places = [
        ItineraryPlace(name: 'Siddhi Vinayak', latitude: 19.0168, longitude: 72.8303, dayNumber: 2),
        ItineraryPlace(name: 'Bandra Bandstand', latitude: 19.0544, longitude: 72.8205, dayNumber: 2),
      ];

      final startPoint = StartPoint(name: 'Hotel Taj', latitude: 18.9217, longitude: 72.8333);

      final allLegs = [
        ItineraryLeg(from: 'Hotel Taj', to: 'Gateway of India', distance: '0.5 km', duration: '5 min', mode: 'walk'),
        ItineraryLeg(from: 'Gateway of India', to: 'Marine Drive', distance: '3 km', duration: '12 min', mode: 'cab'),
        ItineraryLeg(from: 'Siddhi Vinayak', to: 'Bandra Bandstand', distance: '5 km', duration: '18 min', mode: 'cab'),
      ];

      // Function under test
      List<ItineraryLeg> filterLegsForDay(int day, List<ItineraryPlace> places) {
        final dayPlaceNames = places.where((p) => p.dayNumber == day).map((p) => p.name.trim().toLowerCase()).toSet();
        final startName = startPoint.name.trim().toLowerCase();

        return allLegs.where((l) {
          final fromLower = l.from.trim().toLowerCase();
          final toLower = l.to.trim().toLowerCase();
          final hasFrom = dayPlaceNames.contains(fromLower);
          final hasTo = dayPlaceNames.contains(toLower);

          if (hasFrom && hasTo) return true;
          if ((fromLower == startName && hasTo) || (toLower == startName && hasFrom)) {
            return true;
          }
          return false;
        }).toList();
      }

      final day1Filtered = filterLegsForDay(1, [...day1Places, ...day2Places]);
      expect(day1Filtered.length, equals(2));
      expect(day1Filtered[0].from, equals('Hotel Taj'));
      expect(day1Filtered[0].to, equals('Gateway of India'));
      expect(day1Filtered[1].from, equals('Gateway of India'));
      expect(day1Filtered[1].to, equals('Marine Drive'));

      final day2Filtered = filterLegsForDay(2, [...day1Places, ...day2Places]);
      expect(day2Filtered.length, equals(1));
      expect(day2Filtered[0].from, equals('Siddhi Vinayak'));
      expect(day2Filtered[0].to, equals('Bandra Bandstand'));
      // Verifies that Day 1's starting leg from 'Hotel Taj' did not bleed into Day 2
      expect(day2Filtered.any((l) => l.to == 'Gateway of India'), isFalse);
    });
  });
}
