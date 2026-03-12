import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const TripDashboardApp());
}

class TripDashboardApp extends StatelessWidget {
  const TripDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const DashboardScreen(),
    );
  }
}