import 'package:flutter/material.dart';
import '../services/database_service.dart';

class PackingChecklist extends StatefulWidget {
  final int tripId;
  const PackingChecklist({super.key, required this.tripId});

  @override
  State<PackingChecklist> createState() => _PackingChecklistState();
}

class _PackingChecklistState extends State<PackingChecklist> {
  final TextEditingController itemController = TextEditingController();
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // Load items from database
  Future<void> _loadItems() async {
    final fetchedItems =
    await DatabaseService().getPackingItems(widget.tripId);
    setState(() {
      items = fetchedItems;
    });
  }

  // Add item
  Future<void> _addItem() async {
    final text = itemController.text.trim();
    if (text.isEmpty) return;

    await DatabaseService().insertPackingItem(widget.tripId, text);
    itemController.clear();
    FocusScope.of(context).unfocus(); // hide keyboard
    await _loadItems();
  }

  // Toggle done/undone
  Future<void> _toggleItem(int index) async {
    final item = items[index];
    final newDone = item['done'] == 0;
    await DatabaseService().updatePackingItem(item['id'], newDone);
    setState(() {
      items[index]['done'] = newDone ? 1 : 0;
    });
  }

  // Delete item
  Future<void> _deleteItem(int index) async {
    final item = items[index];
    await DatabaseService().deletePackingItem(item['id']);
    setState(() {
      items.removeAt(index);
    });
  }

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
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: itemController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add item",
                      hintStyle: const TextStyle(color: Colors.white70),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                child: Text(
                  "No items yet",
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              )
                  : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    child: ListTile(
                      leading: Checkbox(
                        value: item['done'] == 1,
                        onChanged: (_) => _toggleItem(index),
                        activeColor: Colors.deepPurple,
                      ),
                      title: Text(
                        item['name'],
                        style: TextStyle(
                          fontSize: 18,
                          decoration: item['done'] == 1
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: item['done'] == 1
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
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