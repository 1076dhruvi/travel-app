import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';
import 'trip_dashboard.dart';
import 'create_trip.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {

  List<Trip> trips = [];

  @override
  void initState() {
    super.initState();
    loadTrips();
  }

  Future<void> loadTrips() async {

    List<Trip> fetchedTrips = await DatabaseService().getTrips();

    setState(() {
      trips = fetchedTrips;
    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Trips"),
      ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateTrip(),
            ),
          ).then((result) {
            if (result == true) {
              loadTrips();
            }
          });
        },
      ),

      body: trips.isEmpty
          ? const Center(child: Text("No Trips Yet"))

          : ListView.builder(
        itemCount: trips.length,
        itemBuilder: (context, index) {

          final trip = trips[index];

          return Card(
            margin: const EdgeInsets.all(10),

            child: ListTile(
              title: Text(trip.title),
              subtitle: Text("${trip.location} - ${trip.date}"),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TripDashboard(trip: trip),
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