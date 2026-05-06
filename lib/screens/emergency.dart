import 'package:flutter/material.dart';

class EmergencyDirectory extends StatelessWidget {
  const EmergencyDirectory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Emergency Directory"),
      ),
      body: const Center(
        child: Text("Emergency Directory Coming Soon"),
      ),
    );
  }
}