import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class CreateTrip extends StatefulWidget {
  final Trip? trip; // optional trip to edit

  const CreateTrip({super.key, this.trip});

  @override
  State<CreateTrip> createState() => _CreateTripState();
}

class _CreateTripState extends State<CreateTrip> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final TextEditingController dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // pre-fill if editing
    if (widget.trip != null) {
      titleController.text = widget.trip!.title;
      locationController.text = widget.trip!.location;
      dateController.text = widget.trip!.date;
    }
  }

  Future<void> saveTrip() async {
    if (titleController.text.isEmpty ||
        locationController.text.isEmpty ||
        dateController.text.isEmpty) return;

    final trip = Trip(
      id: widget.trip?.id, // keep id if editing
      title: titleController.text,
      location: locationController.text,
      date: dateController.text,
    );

    if (widget.trip == null) {
      await DatabaseService().insertTrip(trip);
    } else {
      await DatabaseService().updateTrip(trip);
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Trip" : "Create Trip"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTextField(titleController, "Trip Title", Icons.card_travel),
            const SizedBox(height: 15),
            _buildTextField(locationController, "Location", Icons.place),
            const SizedBox(height: 15),
            _buildTextField(dateController, "Date", Icons.date_range),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: saveTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isEditing ? "Update Trip" : "Save Trip",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        filled: true,
        fillColor: Colors.white24,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(color: Colors.white),
    );
  }
}