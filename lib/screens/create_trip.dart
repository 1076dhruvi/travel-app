import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class CreateTripScreen extends StatefulWidget {

  final Trip? trip;

  const CreateTripScreen({super.key, this.trip});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {

  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.trip != null) {
      titleController.text = widget.trip!.title;
      locationController.text = widget.trip!.location;
      dateController.text = widget.trip!.date;
    }
  }

  void saveTrip() async {

    final trip = Trip(
      id: widget.trip?.id,
      title: titleController.text,
      location: locationController.text,
      date: dateController.text,
    );

    if (widget.trip == null) {
      await DatabaseService().insertTrip(trip);
    } else {
      await DatabaseService().updateTrip(trip);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(widget.trip == null ? "Create Trip" : "Edit Trip"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: "Trip Title",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: locationController,
              decoration: const InputDecoration(
                labelText: "Location",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: "Date",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: saveTrip,
              child: const Text("Save Trip"),
            )

          ],
        ),
      ),
    );
  }
}