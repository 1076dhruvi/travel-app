import 'package:flutter/material.dart';
import '../services/itinerary_service.dart';
import '../models/trip.dart';
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

              onPressed:() async {

                try{

                  final result =
                  await itineraryService.generateItinerary(

                    destination: widget.trip.location,

                    days:3,

                    interests:selectedInterests.toList(),

                  );


                  setState((){

                    itineraryData=result;

                  });


                }
                catch(e){

                  print("ERROR: $e");

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