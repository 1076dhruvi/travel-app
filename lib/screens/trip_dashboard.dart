import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'create_trip.dart';
import 'packing_checklist.dart';
import 'emergency.dart';
import 'package:trip_dashboard/screens/documents_vault.dart';
import 'budget_screen.dart';
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

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.map,
                  color: Colors.blue,
                ),
                title: const Text("Trip Map"),
                subtitle: const Text("View your destination"),
                onTap: () async {
                  final geocoding = GeocodingService();

                  final coordinates =
                  await geocoding.getCoordinates(trip.location);

                  if (coordinates == null) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Couldn't find that location."),
                      ),
                    );
                    return;
                  }

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(
                        location: trip.location,
                        latitude: coordinates["lat"]!,
                        longitude: coordinates["lon"]!,
                      ),
                    ),
                  );
                },
              ),
            ),

            // 📄 Documents
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder, color: Colors.deepPurple),
                title: const Text("Documents Vault"),
                subtitle: const Text("Tap to open secure vault"),
                onTap: () {
                  print("Documents tapped");

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

            // 🚨 Emergency Directory (NEW)
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

            // 📝 Notes
            Card(
              child: ListTile(
                leading: const Icon(Icons.note, color: Colors.orange),
                title: const Text("Notes"),
                subtitle: const Text("No notes added"),
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
                      backgroundColor: Colors.orangeAccent),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateTrip(trip: trip),
                      ),
                    ).then((value) {
                      if (value == true) Navigator.pop(context, true);
                    });
                  },
                ),

                // Delete
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: () async {
  if (trip.id == null) return;

  await DatabaseService().deleteTrip(trip.id!);
  Navigator.pop(context, true);
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