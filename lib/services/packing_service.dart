import 'weather_service.dart';

class PackingService {
  final WeatherService weatherService = WeatherService();

  List<String> baseItems() {
    return [
      "Charger",
      "Toiletries",
      "Documents",
      "Phone",
      "Wallet"
    ];
  }

  List<String> coldItems() {
    return [
      "Jacket",
      "Sweater",
      "Gloves",
      "Thermal wear"
    ];
  }

  List<String> hotItems() {
    return [
      "Sunscreen",
      "Sunglasses",
      "Hat",
      "Light clothes"
    ];
  }

  List<String> rainItems() {
    return [
      "Umbrella",
      "Raincoat",
      "Waterproof bag"
    ];
  }

  Future<List<String>> generateSmartList(String location) async {
    List<String> items = [];

    // STEP 1: always add base items
    items.addAll(baseItems());

    try {
      // STEP 2: get weather from API
      final data = await weatherService.getWeather(location);

      double temp = data["main"]["temp"];
      String condition = data["weather"][0]["main"];

      // STEP 3: temperature rules
      if (temp < 18) {
        items.addAll(coldItems());
      } else if (temp > 30) {
        items.addAll(hotItems());
      } else {
        items.addAll(coldItems());
        items.addAll(hotItems());
      }

      // STEP 4: rain condition
      if (condition.toLowerCase().contains("rain")) {
        items.addAll(rainItems());
      }

    } catch (e) {
      // fallback if API fails
      items.addAll(hotItems());
    }

    return items.toSet().toList(); // remove duplicates
  }
}