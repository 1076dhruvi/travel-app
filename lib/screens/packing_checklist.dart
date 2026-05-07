import 'package:flutter/material.dart';
import '../services/database_service.dart';

class PackingChecklist extends StatefulWidget {
  final int tripId;
  final String location;
  final String date;

  const PackingChecklist({
    super.key,
    required this.tripId,
    required this.location,
    required this.date,
  });

  @override
  State<PackingChecklist> createState() => _PackingChecklistState();
}

class _PackingChecklistState extends State<PackingChecklist> {
  final TextEditingController itemController = TextEditingController();
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _initChecklist();
  }

  // 🧠 SMART LOGIC (FIXED PRIORITY SYSTEM)
  List<String> getSmartSuggestions(String location, String date) {
    List<String> items = [];

    location = location.toLowerCase();

    int month = int.parse(date.split("/")[1]);

    bool isWinter = (month == 12 || month == 1 || month == 2);
    bool isSummer = (month >= 3 && month <= 6);
    bool isRainy = (month == 7 || month == 8);

    bool isGoa = location.contains("goa");
    bool isBeach = isGoa || location.contains("beach");

    bool isColdPlace =
        location.contains("manali") ||
            location.contains("shimla") ||
            location.contains("kashmir") ||
            location.contains("leh") ||
            location.contains("ladakh") ||
            location.contains("gulmarg") ||
            location.contains("nainital") ||
            location.contains("mussoorie");

    // 🥇 PRIORITY 1: STRONG LOCATION RULES

    if (isColdPlace) {
      items.addAll([
        "Heavy Jacket",
        "Thermal Wear",
        "Gloves",
        "Woolen Socks"
      ]);
    }

    if (isBeach) {
      items.addAll([
        "Sunglasses",
        "Swimwear",
        "Sunscreen",
        "Flip Flops"
      ]);
    }

    // 🥈 PRIORITY 2: WEATHER (only if neutral location)
    if (!isColdPlace && !isBeach) {
      if (isSummer) {
        items.addAll([
          "Light Clothes",
          "Cap",
          "Sunscreen"
        ]);
      }

      if (isWinter) {
        items.addAll([
          "Light Jacket",
          "Full Sleeves"
        ]);
      }
    }

    if (isRainy) {
      items.addAll([
        "Umbrella",
        "Raincoat",
        "Waterproof Bag"
      ]);
    }

    // 🧳 ALWAYS REQUIRED ITEMS
    items.addAll([
      "Phone Charger",
      "Wallet",
      "ID Proof",
      "Power Bank"
    ]);

    return items.toSet().toList();
  }

  Future<void> _initChecklist() async {
    await DatabaseService().deletePackingItemsByTrip(widget.tripId);

    List<String> suggestions =
    getSmartSuggestions(widget.location, widget.date);

    for (var item in suggestions) {
      await DatabaseService()
          .insertPackingItem(widget.tripId, item);
    }

    await _loadItems();
  }

  Future<void> _loadItems() async {
    final fetched =
    await DatabaseService().getPackingItems(widget.tripId);

    setState(() {
      items = fetched;
    });
  }

  Future<void> _addItem() async {
    final text = itemController.text.trim();
    if (text.isEmpty) return;

    await DatabaseService()
        .insertPackingItem(widget.tripId, text);

    itemController.clear();
    await _loadItems();
  }

  Future<void> _toggleItem(int index) async {
    final item = items[index];
    final newDone = item['done'] == 0;

    await DatabaseService()
        .updatePackingItem(item['id'], newDone);

    await _loadItems();
  }

  Future<void> _deleteItem(int index) async {
    final item = items[index];

    await DatabaseService()
        .deletePackingItem(item['id']);

    await _loadItems();
  }

  int get completedCount =>
      items.where((e) => e['done'] == 1).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FF),

      appBar: AppBar(
        title: const Text("Packing Checklist"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // 📊 Progress
            if (items.isNotEmpty)
              Text(
                "Packed: $completedCount / ${items.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

            const SizedBox(height: 15),

            // ➕ Add item
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemController,
                    style: const TextStyle(color: Colors.black),
                    decoration: InputDecoration(
                      hintText: "Add item",
                      hintStyle:
                      const TextStyle(color: Colors.black54),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _addItem,
                  child: const Icon(Icons.add),
                ),
              ],
            ),

            const SizedBox(height: 15),

            // 📦 List
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  return Card(
                    margin: const EdgeInsets.symmetric(
                        vertical: 6),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: item['done'] == 1,
                        onChanged: (_) => _toggleItem(index),
                      ),
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          decoration: item['done'] == 1
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () => _deleteItem(index),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}