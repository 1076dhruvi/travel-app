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

  // 🔥 SMART LOGIC (NUMERIC MONTH + FALLBACK)
  List<String> getSmartSuggestions(String location, String date) {
    List<String> items = [];

    location = location.toLowerCase();

    int month = int.parse(date.split("/")[1]);

    bool isWinter = (month == 12 || month == 1 || month == 2);
    bool isSummer = (month >= 3 && month <= 6);
    bool isRainy = (month == 7 || month == 8);

    bool isBeach =
        location.contains("goa") || location.contains("beach");

    bool isColdPlace =
        location.contains("manali") ||
            location.contains("shimla") ||
            location.contains("kashmir") ||
            location.contains("leh") ||
            location.contains("ladakh") ||
            location.contains("gulmarg") ||
            location.contains("nainital") ||
            location.contains("mussoorie");

    // ❄️ Cold + winter
    if (isColdPlace && isWinter) {
      items.addAll([
        "Heavy Jacket",
        "Gloves",
        "Thermal wear",
        "Woolen socks"
      ]);
    }

    // 🏖 Beach
    if (isBeach) {
      items.addAll([
        "Sunglasses",
        "Swimwear",
        "Sunscreen",
        "Flip flops"
      ]);
    }

    // ☀️ Summer (non-beach)
    if (isSummer && !isBeach) {
      items.addAll([
        "Light clothes",
        "Cap",
        "Sunscreen"
      ]);
    }

    // 🌧 Rainy
    if (isRainy) {
      items.addAll([
        "Umbrella",
        "Raincoat",
        "Waterproof bag"
      ]);
    }

    // 🔥 FALLBACK (for Feb, Sep, Oct, Nov or unknown places)
    if (items.isEmpty) {
      items.addAll([
        "Comfortable clothes",
        "Shoes",
        "Toiletries",
        "Power bank"
      ]);
    }

    // 📌 Always needed
    items.addAll([
      "Phone Charger",
      "Wallet",
      "ID Proof"
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
    final fetchedItems =
    await DatabaseService().getPackingItems(widget.tripId);
    setState(() {
      items = fetchedItems;
    });
  }

  Future<void> _addItem() async {
    final text = itemController.text.trim();
    if (text.isEmpty) return;

    await DatabaseService().insertPackingItem(widget.tripId, text);
    itemController.clear();
    await _loadItems();
  }

  Future<void> _toggleItem(int index) async {
    final item = items[index];
    final newDone = item['done'] == 0;

    await DatabaseService().updatePackingItem(item['id'], newDone);
    await _loadItems();
  }

  Future<void> _deleteItem(int index) async {
    final item = items[index];

    await DatabaseService().deletePackingItem(item['id']);
    await _loadItems();
  }

  int get completedCount =>
      items.where((item) => item['done'] == 1).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Packing Checklist"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
          ),
        ),
        child: Column(
          children: [
            if (items.isNotEmpty)
              Text(
                "Packed: $completedCount / ${items.length}",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),

            const SizedBox(height: 15),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add item",
                      hintStyle:
                      const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.white24,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
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

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  return ListTile(
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
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteItem(index),
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