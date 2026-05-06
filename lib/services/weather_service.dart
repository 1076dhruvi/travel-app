import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = "d65bb1a05c068327fa5509d87b089ff0";

  Future<Map<String, dynamic>> getWeather(String city) async {
    final url =
        "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Weather fetch failed");
    }
  }
}
