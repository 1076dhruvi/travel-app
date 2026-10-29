import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TripWeather {
  final double currentTemp;
  final double maxTemp;
  final double minTemp;
  final double precipitation;
  final int weatherCode;
  final String condition;
  final String timezone;

  TripWeather({
    required this.currentTemp,
    required this.maxTemp,
    required this.minTemp,
    required this.precipitation,
    required this.weatherCode,
    required this.condition,
    required this.timezone,
  });

  IconData get icon {
    switch (weatherCode) {
      case 0:
        return Icons.wb_sunny;
      case 1:
      case 2:
      case 3:
        return Icons.wb_cloudy;
      case 45:
      case 48:
        return Icons.cloud;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return Icons.grain;
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return Icons.water_drop;
      case 71:
      case 73:
      case 75:
      case 77:
        return Icons.ac_unit;
      case 80:
      case 81:
      case 82:
        return Icons.beach_access;
      case 95:
      case 96:
      case 99:
        return Icons.flash_on;
      default:
        return Icons.cloud_outlined;
    }
  }
}

class WeatherService {
  /// Fetches weather from the free Open-Meteo API using latitude and longitude.
  /// Zero-cost, no API key required, reliable worldwide.
  Future<TripWeather?> getWeather(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$latitude'
      '&longitude=$longitude'
      '&current=temperature_2m,weather_code'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum'
      '&timezone=auto',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        final daily = data['daily'];

        if (current != null) {
          final temp = (current['temperature_2m'] as num).toDouble();
          final code = (current['weather_code'] as num).toInt();
          final timezone = (data['timezone'] as String?) ?? 'UTC';

          double maxT = temp;
          double minT = temp;
          double precip = 0.0;

          if (daily != null) {
            final maxList = daily['temperature_2m_max'] as List<dynamic>?;
            final minList = daily['temperature_2m_min'] as List<dynamic>?;
            final precipList = daily['precipitation_sum'] as List<dynamic>?;

            if (maxList != null && maxList.isNotEmpty) {
              maxT = (maxList[0] as num).toDouble();
            }
            if (minList != null && minList.isNotEmpty) {
              minT = (minList[0] as num).toDouble();
            }
            if (precipList != null && precipList.isNotEmpty) {
              precip = (precipList[0] as num).toDouble();
            }
          }

          return TripWeather(
            currentTemp: temp,
            maxTemp: maxT,
            minTemp: minT,
            precipitation: precip,
            weatherCode: code,
            condition: _weatherCodeToString(code),
            timezone: timezone,
          );
        }
      }
    } catch (_) {
      // Graceful offline/error handling: returns null so UI shows offline placeholder
    }
    return null;
  }

  static String _weatherCodeToString(int code) {
    switch (code) {
      case 0:
        return 'Clear Sky';
      case 1:
        return 'Mainly Clear';
      case 2:
        return 'Partly Cloudy';
      case 3:
        return 'Overcast';
      case 45:
      case 48:
        return 'Foggy';
      case 51:
      case 53:
      case 55:
        return 'Drizzle';
      case 61:
      case 63:
      case 65:
        return 'Rain';
      case 71:
      case 73:
      case 75:
        return 'Snow';
      case 80:
      case 81:
      case 82:
        return 'Showers';
      case 95:
      case 96:
      case 99:
        return 'Thunderstorm';
      default:
        return 'Pleasant';
    }
  }
}
