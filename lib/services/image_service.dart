import 'dart:convert';
import 'package:http/http.dart' as http;

class ImageService {
  static const String accessKey = "8F8VHaiMkTr-KvusJywGSpyAsHvE82blFdp8y0Vehhc";

  Future<String?> getCoverImage(String city) async {
    final url = Uri.parse(
      "https://api.unsplash.com/search/photos"
      "?query=$city travel"
      "&per_page=1",
    );

    final response = await http.get(
      url,
      headers: {
        "Authorization": "Client-ID $accessKey",
      },
    );

    print("Status Code: ${response.statusCode}");

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);

  return data["results"][0]["urls"]["regular"];
}

return null;
  }
}