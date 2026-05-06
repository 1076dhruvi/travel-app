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

  // 🧠 SMART RULE ENGINE
  List<String> getSmartSuggestions(String location, String date) {
    List<String> items = [];

    location = location.toLowerCase();

    int month = int.parse(date.split("/")[1]);

    bool isWinter = (month == 12 || month == 1 || month == 2);
    bool isSummer = (month >= 3 && month <= 6);
    bool isRainy = (month == 7 || month == 8);

    bool isBeach = location.contains("goa") || location.contains("beach");

    bool isColdPlace =
        location.contains("manali") ||
            location.contains("shimla") ||
            location.contains("kashmir") ||
            location.contains("ladakh");

    if (isColdPlace && isWinter) {
      items.addAll([
        "Heavy Jacket",
        "Gloves",
        "Thermal wear",
        "Woolen socks"
      ]);
    }

    if (isBeach) {
      items.addAll([
        "Sunglasses",
        "Swimwear",
        "Sunscreen",
        "Flip flops"
      ]);
    }

    if (isSummer && !isBeach) {
      items.addAll([
        "Light clothes",
        "Cap",
        "Sunscreen"
      ]);
    }

    if (isRainy) {
      items.addAll([
        "Umbrella",
        "Raincoat",
        "Waterproof bag"
      ]);
    }

    if (items.isEmpty) {
      items.addAll([
        "Comfortable clothes",
        "Shoes",
        "Toiletries",
        "Power bank"
      ]);
    }

    items.addAll([
      "Phone Charger",
      "Wallet",
      "ID Proof"
    ]);

    return items.toSet().toList();
  }

  Future<void> _initChecklist() async {
    await DatabaseService().deletePackingItemsByTrip(widget.tripId);

    final packingService = PackingService();

    final suggestions =
    await packingService.generateSmartList(widget.location);

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
      items.where((e) => e['done'] == 1).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FF),

      appBar: AppBar(
        title: const Text("Packing Checklist"),
        backgroundColor: const Color(0xFF6A1B9A),
        elevation: 0,
      ),

      body: Column(
        children: [
          const SizedBox(height: 12),

          // 📊 Progress header
          Text(
            "Packed: $completedCount / ${items.length}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 10),

          // ➕ Input box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemController,
                    decoration: const InputDecoration(
                      hintText: "Add new item...",
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  child: const Text("Add"),
                )
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 📦 List
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    activeColor: const Color(0xFF6A1B9A),
                    value: item['done'] == 1,
                    onChanged: (_) => _toggleItem(index),

                    title: Text(
                      item['name'],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        decoration: item['done'] == 1
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    secondary: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteItem(index),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}