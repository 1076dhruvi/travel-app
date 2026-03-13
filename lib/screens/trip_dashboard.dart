import 'package:flutter/material.dart';
import '../models/trip.dart';

class TripDashboard extends StatelessWidget {

  final Trip trip;

  const TripDashboard({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.title),
      ),
      body: Center(
        child: Text("Trip Dashboard"),
      ),
    );
  }
}