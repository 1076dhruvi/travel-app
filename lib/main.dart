import 'package:flutter/material.dart';
import 'screens/dashboard.dart'; // make sure this file exists

void main() {
  runApp(const TripDashboardApp());
}

class TripDashboardApp extends StatelessWidget {
  const TripDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trip Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
      ),
      home: const DashboardScreen(), // works because constructor is const
    );
  }
}