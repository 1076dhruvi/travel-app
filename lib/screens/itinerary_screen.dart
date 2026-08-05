import 'package:flutter/material.dart';
import '../services/itinerary_service.dart';
import '../models/trip.dart';
import '../services/routing_service.dart';
  class ItineraryScreen extends StatefulWidget {
  final Trip trip;

  const ItineraryScreen({
    super.key,
    required this.trip,
  });

    @override
    State<ItineraryScreen> createState() => _ItineraryScreenState();
    }

    class _ItineraryScreenState extends State<ItineraryScreen> {
    final Set<String> selectedInterests = {};

    final ItineraryService itineraryService = ItineraryService();
    final RoutingService routingService = RoutingService();

    Map<String, dynamic>? routingData;

    Map<String, dynamic>? itineraryData;

    final List<String> interests = [
        "Beaches",
        "History",
        "Food",
        "Nature",
        "Adventure",
        "Shopping",
    ];

   @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text("${widget.trip.location} Itinerary"),
      backgroundColor: Colors.deepPurple,
    ),

    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Center(
            child: Column(
              children: [

                Text(
                  "Plan Your ${widget.trip.location} Trip",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Select your interests to generate a personalized itinerary.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),

              ],
            ),
          ),


          const SizedBox(height:30),



          const Text(
            "Choose Interests",
            style: TextStyle(
              fontSize:18,
              fontWeight:FontWeight.bold,
            ),
          ),


          const SizedBox(height:12),



          Wrap(
            spacing:12,
            runSpacing:12,

            children: interests.map((interest){

              return FilterChip(

                label: Text(
                  interest,
                  style: TextStyle(
                    color:selectedInterests.contains(interest)
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),

                selected:selectedInterests.contains(interest),

                selectedColor:Colors.deepPurple,

                backgroundColor:Colors.grey.shade200,


                onSelected:(selected){

                  setState((){

                    if(selected){
                      selectedInterests.add(interest);
                    }
                    else{
                      selectedInterests.remove(interest);
                    }

                  });

                },

              );

            }).toList(),
          ),



          const SizedBox(height:25),



          SizedBox(
            width:double.infinity,

            child:ElevatedButton(

              onPressed: () async {


                try {


                  print("Generating itinerary...");


// 1. Call Gemini

                  final result =
                  await itineraryService.generateItinerary(

                    destination: widget.trip.location,

                    days: widget.trip.days,

                    interests: selectedInterests.toList(),

                  );


                  print(result);



// 2. Extract places for routing

                  List<String> places = [];
                  final seen = <String>{};

                  for (var day in result["itinerary"]) {
                    for (var place in day["attractions"]) {

                      final name = place["name"].toString().trim();

                      if (name.isEmpty) continue;

                      // Ignore places outside the selected destination
                      if (name.toLowerCase().contains("bannerghatta biological park")) continue;
                      if (name.toLowerCase().contains("mysore")) continue;
                      if (name.toLowerCase().contains("hampi")) continue;
                      if (name.toLowerCase().contains("coorg")) continue;

                      if (!seen.contains(name)) {
                        seen.add(name);
                        places.add(name);
                      }
                    }
                  }

                  print("Places sent to routing:");
                  print(places);


// 3. Optimize route


                  final route =
                  await routingService.optimizeRoute(
                    widget.trip.location,
                    places,
                  );


// 4. Update UI


                  setState(() {
                    itineraryData = result;
                    routingData = route;
                  });


                }

                catch(e){


                  print(
                      "ERROR : $e"
                  );


                  ScaffoldMessenger.of(context)
                      .showSnackBar(

                      SnackBar(

                        content:Text(
                            "Failed to generate itinerary"
                        ),

                      )

                  );


                }


              },


              style:ElevatedButton.styleFrom(

                backgroundColor:Colors.deepPurple,

                padding:
                const EdgeInsets.symmetric(vertical:16),

                shape:RoundedRectangleBorder(

                  borderRadius:BorderRadius.circular(14),

                ),

              ),


              child:const Text(
                "Generate Itinerary",

                style:TextStyle(
                  fontSize:18,
                  color:Colors.white,
                ),
              ),

            ),
          ),




          const SizedBox(height:30),
          if (routingData != null)

            Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                const SizedBox(height: 25),

                const Text(
                  "Optimized Route",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                ...List.generate(

                  routingData!["routes"].length,

                      (index) {

                    final route = routingData!["routes"][index];

                    return Card(

                      elevation: 4,

                      margin: const EdgeInsets.only(bottom: 12),

                      child: ListTile(

                        leading: const Icon(
                          Icons.route,
                          color: Colors.deepPurple,
                        ),

                        title: Text(
                          "${route["from"]} → ${route["to"]}",
                        ),

                        subtitle: Text(
                          "Distance: ${route["distance"]}\nTime: ${route["time"]}",
                        ),

                      ),

                    );

                  },

                ),

              ],

            ),


          if(itineraryData != null)

            Column(

              crossAxisAlignment:CrossAxisAlignment.start,

              children:[


                const Text(
                  "Your Itinerary",
                  style:TextStyle(
                    fontSize:22,
                    fontWeight:FontWeight.bold,
                  ),
                ),


                const SizedBox(height:15),



                ...List.generate(

                  itineraryData!["itinerary"].length,

                  (index){

                    final day =
                    itineraryData!["itinerary"][index];


                    return Card(

                      elevation:4,

                      margin:
                      const EdgeInsets.only(bottom:15),


                      child:Padding(

                        padding:
                        const EdgeInsets.all(15),


                        child:Column(

                          crossAxisAlignment:
                          CrossAxisAlignment.start,


                          children:[


                            Text(

                              "Day ${day["day"]}",

                              style:
                              const TextStyle(

                                fontSize:22,

                                fontWeight:
                                FontWeight.bold,

                              ),

                            ),


                            const SizedBox(height:10),



                            ...List.generate(

                              day["attractions"].length,

                              (i){


                                final place =
                                day["attractions"][i];


                                return ListTile(

                                  contentPadding:
                                  EdgeInsets.zero,


                                  leading:
                                  const Icon(
                                    Icons.location_on,
                                    color:Colors.deepPurple,
                                  ),


                                  title:Text(
                                    place["name"] ??
                                    "Unknown place",
                                  ),


                                  subtitle:Text(
                                    "Best time: ${place["bestTime"] ?? "Anytime"}",
                                  ),

                                );


                              },

                            ),


                          ],

                        ),

                      ),

                    );

                  },

                ),


              ],

            ),


        ],

      ),

    ),

  );
}
    }