import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class TripDashboard extends StatefulWidget {
  const TripDashboard({super.key});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard> {

  List<Trip> trips = [];

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  void loadTrips() async {
    final data = await DatabaseService().getTrips();
    setState(() {
      trips = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trip Dashboard"),
      ),
      body: trips.isEmpty
          ? const Center(child: Text("No trips available"))
          : ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  child: ListTile(
                    leading: const Icon(Icons.flight),
                    title: Text(trip.destination),
                    subtitle: Text(trip.date),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChecklistScreen(trip: trip),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}