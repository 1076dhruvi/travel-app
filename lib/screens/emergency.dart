import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDirectory extends StatefulWidget {
  final String location;

  const EmergencyDirectory({super.key, required this.location});

  @override
  State<EmergencyDirectory> createState() => _EmergencyDirectoryState();
}

class _EmergencyDirectoryState extends State<EmergencyDirectory> {
  List<dynamic> data = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final String response =
    await rootBundle.loadString('assets/data/emergency_data.json');

    final jsonData = json.decode(response);

    String key = widget.location.toLowerCase().trim();

    if (key.contains("mumbai")) key = "mumbai";
    else if (key.contains("delhi")) key = "delhi";
    else if (key.contains("pune")) key = "pune";
    else key = "india";

    setState(() {
      data = jsonData[key] ?? [];
    });
  }

  void makeCall(String number) async {
    final Uri url = Uri.parse("tel:$number");
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Emergency - ${widget.location}"),
        backgroundColor: Colors.red,
      ),
      body: data.isEmpty
          ? const Center(child: Text("No emergency data available"))
          : ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          final item = data[index];

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.red),
              title: Text(item["title"] ?? "Unknown"),
              subtitle: Text(item["number"] ?? "-"),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () =>
                    makeCall(item["number"] ?? ""),
              ),
            ),
          );
        },
      ),
    );
  }
}