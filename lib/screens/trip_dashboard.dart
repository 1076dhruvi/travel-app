import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'create_trip.dart';
import 'packing_checklist.dart';

class TripDashboard extends StatelessWidget {
  final Trip trip;

  const TripDashboard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: ListTile(
                leading: const Icon(Icons.place, color: Colors.deepPurple),
                title: Text(trip.location,
                    style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 15),
            // Date Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              elevation: 5,
              child: ListTile(
                leading: const Icon(Icons.date_range, color: Colors.deepPurple),
                title: Text(trip.date, style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 30),
            // Row 1: Edit & Delete
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Edit Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
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
                // Delete Button
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12)),
                  onPressed: () async {
                    await DatabaseService().deleteTrip(trip.id!);
                    Navigator.pop(context, true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Row 2: Packing Checklist (centered)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.checklist),
                label: const Text("Packing Checklist"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 14)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          PackingChecklist(tripId: trip.id!), // fixed
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}