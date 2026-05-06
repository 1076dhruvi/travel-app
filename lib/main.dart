import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'theme/app_theme.dart';

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
      theme: AppTheme.lightTheme,
      home: const DashboardScreen(),
    );
  }
}