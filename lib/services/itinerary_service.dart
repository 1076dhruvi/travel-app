import 'dart:convert';
import 'package:http/http.dart' as http;


class ItineraryService {


  Future<dynamic> generateItinerary({

    required String destination,
    required int days,
    required List<String> interests,

  }) async {


    final url = Uri.parse(
      "http://10.0.2.2:3000/api/itinerary/generate",
    );


    final response = await http.post(

      url,

      headers: {

        "Content-Type": "application/json",

      },


      body: jsonEncode({

        "destination": destination,

        "days": days,

        "interests": interests,

      }),

    );



    if(response.statusCode == 200){


      return jsonDecode(response.body);


    }
    else{


      throw Exception(
        "Failed to generate itinerary"
      );


    }


  }

}