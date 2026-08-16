import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'create_trip.dart';
import 'packing_checklist.dart';
import 'emergency.dart';
import 'notes_screen.dart';
import 'package:trip_dashboard/screens/documents_vault.dart';
import 'budget_screen.dart';
import 'itinerary_screen.dart';
import 'map_screen.dart';
import '../services/geocoding_service.dart';

class TripDashboard extends StatelessWidget {
  final Trip trip;

  const TripDashboard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {

    // ✅ Days Left Logic
    int daysLeft = 0;

    try {
      List<String> parts = trip.date.split('/'); // DD/MM/YYYY

      DateTime tripDate = DateTime(
        int.parse(parts[2]), // year
        int.parse(parts[1]), // month
        int.parse(parts[0]), // day
      );

      daysLeft = tripDate.difference(DateTime.now()).inDays;
    } catch (e) {
      daysLeft = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 Days Left
            Text(
              "Days left: $daysLeft",
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 15),

            // 📍 Location Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: ListTile(
                leading: const Icon(Icons.place, color: Colors.deepPurple),
                title: Text(trip.location,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 10),

            // 📅 Date Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.deepPurple),
                title: Text(trip.date,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 20),

            // 📄 Documents
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.deepPurple),
                title: const Text("Documents Vault"),
                subtitle: const Text("Tap to open secure vault"),
                onTap: () {
                  debugPrint("Documents tapped");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentsVault(
                        tripId: trip.id!,
                        tripTitle: trip.title,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 📋 Checklist
            Card(
              child: ListTile(
                leading: const Icon(Icons.checklist, color: Colors.deepPurple),
                title: const Text("Packing Checklist"),
                subtitle: const Text("Tap to open"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PackingChecklist(
                        tripId: trip.id!,
                        location: trip.location,
                        date: trip.date,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 🚨 Emergency Directory
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: const Text("Emergency Directory"),
                subtitle: const Text("Tap to view emergency contacts"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmergencyDirectory(
                        location: trip.location.split(",")[0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 💰 Budget
            Card(
              child: ListTile(
                leading: const Icon(Icons.currency_rupee, color: Colors.green),
                title: const Text("Budget"),
                subtitle: const Text("Tap to manage budget"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BudgetScreen(tripId: trip.id!),
                    ),
                  );
                },
              ),
            ),

            // 🗺️ Itinerary
            Card(
              child: ListTile(
                leading: const Icon(Icons.route, color: Colors.deepPurple),
                title: const Text("Itinerary"),
                subtitle: const Text("Generate your personalized itinerary"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItineraryScreen(trip: trip),
                    ),
                  );
                },
              ),
            ),

            // 🗺️ Offline Map
            Card(
              child: ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text("Offline Map"),
                subtitle: const Text("View destination map"),
                onTap: () async {
                  final coordinates =
                  await GeocodingService().getCoordinates(trip.location);

                  if (coordinates != null && context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          title: trip.location,
                          places: [
                            ItineraryPlace(
                              name: trip.location,
                              latitude: coordinates["lat"]!,
                              longitude: coordinates["lon"]!,
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Unable to load map."),
                        ),
                      );
                    }
                  }
                },
              ),
            ),

            // 📝 Notes
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.note,
                  color: Colors.orange,
                ),
                title: const Text("Notes"),
                subtitle: const Text("Add and manage your trip notes"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NotesScreen(
                        tripId: trip.id!,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 25),

            // ✏️ Edit & 🗑 Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Edit
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateTrip(trip: trip),
                      ),
                    ).then((value) {
                      if (value == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    });
                  },
                ),

                // Delete
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    if (trip.id == null) return;

                    await DatabaseService().deleteTrip(trip.id!);
                    if (context.mounted) {
                      Navigator.pop(context, true);
                    }
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