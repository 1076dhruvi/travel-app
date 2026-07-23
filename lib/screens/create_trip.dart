import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/database_service.dart';

class CreateTrip extends StatefulWidget {
  final Trip? trip;

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

    if (widget.trip != null) {
      titleController.text = widget.trip!.title;
      locationController.text = widget.trip!.location;
      dateController.text = widget.trip!.date;
    }
  }

  Future<void> pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null) {
      setState(() {
        dateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  Future<void> saveTrip() async {
    if (titleController.text.isEmpty ||
        locationController.text.isEmpty ||
        dateController.text.isEmpty) return;

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

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.trip != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),

      // 🌈 APP BAR
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: Text(
          isEditing ? "Edit Trip" : "Create Trip",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 10),

              const Text(
                "Plan Your Trip ✈️",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                "Fill in the details below",
                style: TextStyle(color: Colors.black54),
              ),

              const SizedBox(height: 25),

              _buildField(
                controller: titleController,
                label: "Trip Name",
                icon: Icons.location_city,
              ),

              const SizedBox(height: 15),

              _buildField(
                controller: locationController,
                label: "Location",
                icon: Icons.place,
              ),

              const SizedBox(height: 15),

              GestureDetector(
                onTap: pickDate,
                child: AbsorbPointer(
                  child: _buildField(
                    controller: dateController,
                    label: "Start Date",
                    icon: Icons.date_range,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // 🚀 BUTTON
              SizedBox(
                width: double.infinity,
                height: 55,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C4DFF), Color(0xFFB388FF)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: ElevatedButton(
                    onPressed: saveTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      isEditing ? "Update Trip" : "Create Trip",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 💅 CLEAN INPUT FIELD
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          icon: Icon(icon, color: const Color(0xFF7C4DFF)),
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }
}