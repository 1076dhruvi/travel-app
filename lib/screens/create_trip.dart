import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class CreateTrip extends StatefulWidget {
  const CreateTrip({super.key});

  @override
  State<CreateTrip> createState() => _CreateTripState();
}

class _CreateTripState extends State<CreateTrip> {

  final TextEditingController titleController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  Future<void> saveTrip() async {

    final trip = Trip(
      title: titleController.text,
      location: locationController.text,
      date: dateController.text,
    );

    await DatabaseService().insertTrip(trip);

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Trip"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Trip Title",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: "Location",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: "Date",
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveTrip,
              child: const Text("Save Trip"),
            ),

          ],
        ),
      ),
    );
  }
}