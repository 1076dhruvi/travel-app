import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'create_trip.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

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
        title: const Text("My Trips"),
      ),

      body: trips.isEmpty
          ? const Center(
              child: Text(
                "No trips yet.\nClick + to create a trip",
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {

                final trip = trips[index];

                return Card(
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  child: ListTile(
                    leading: const Icon(Icons.flight_takeoff),
                    title: Text(trip.title),
                    subtitle: Text("${trip.location} • ${trip.date}"),

                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Selected trip: ${trip.title}"),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),

        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateTripScreen(),
            ),
          ).then((_) => loadTrips());
        },
      ),
    );
  }
}