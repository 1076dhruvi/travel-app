import 'package:flutter/material.dart';
import '../services/database_service.dart';

class BudgetScreen extends StatefulWidget {
  final int tripId;

  const BudgetScreen({super.key, required this.tripId});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final db = DatabaseService();

  final budgetController = TextEditingController();
  final daysController = TextEditingController();
  final expenseController = TextEditingController();
  final titleController = TextEditingController();

  double totalBudget = 0;
  int tripDays = 1;

  String selectedCategory = "Food";
  List<Map<String, dynamic>> expenses = [];

  List<String> categories = [
    "Food",
    "Transport",
    "Stay",
    "Shopping",
    "Other"
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final trip = await db.getTrip(widget.tripId);
    final exp = await db.getExpenses(widget.tripId);

    setState(() {
      if (trip != null) {
        totalBudget = (trip['budget'] ?? 0).toDouble();
        tripDays = trip['days'] ?? 1;

        budgetController.text = totalBudget.toString();
        daysController.text = tripDays.toString();
      }

      expenses = exp;
    });
  }

  double get spent =>
      expenses.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

  double get remaining => totalBudget - spent;

  // ---------------- SAVE ----------------
  void saveBudget() async {
    double budget = double.tryParse(budgetController.text) ?? 0;
    int days = int.tryParse(daysController.text) ?? 1;

    await db.updateTripBudget(widget.tripId, budget, days);
    loadData();
  }

  // ---------------- ADD EXPENSE (LOGIC SAME) ----------------
  void addExpense() async {
    double amount = double.tryParse(expenseController.text) ?? 0;
    String title = titleController.text;

    if (amount <= 0) return;

    await db.addExpense(
      widget.tripId,
      title,
      amount,
      selectedCategory,
      DateTime.now().toIso8601String(),
    );

    String message = "Expense added successfully";

    double expectedDaily =
        totalBudget / (tripDays == 0 ? 1 : tripDays);

    if (amount > expectedDaily) {
      message = "⚠ High expense compared to planned budget";
    } else if (remaining - amount < 0) {
      message = "🚨 Budget exceeded!";
    } else if (spent > totalBudget * 0.8) {
      message = "⚠ You are nearing budget limit";
    }

    expenseController.clear();
    titleController.clear();

    loadData();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
        message.contains("🚨") ? Colors.red : Colors.black87,
      ),
    );
  }

  void deleteExpense(int id) async {
    final dbClient = await db.database;

    await dbClient.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    loadData();
  }

  @override
  Widget build(BuildContext context) {
    bool overBudget = remaining < 0;
    bool warning = spent > totalBudget * 0.8;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text("Budget Dashboard"),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ================= BUDGET OVERVIEW =================
            _card(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: overBudget
                        ? [Colors.redAccent, Colors.red]
                        : warning
                        ? [Colors.orange, Colors.deepOrange]
                        : [Colors.deepPurple, Colors.purple],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "Budget Overview",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "₹$spent / ₹$totalBudget",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: totalBudget == 0
                            ? 0
                            : spent / totalBudget,
                        minHeight: 10,
                        backgroundColor: Colors.white24,
                        valueColor:
                        const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      "Remaining: ₹$remaining",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ================= BUDGET INPUT =================
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: budgetController,
                    decoration: _input("Total Budget"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: daysController,
                    decoration: _input("Trip Days"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: saveBudget,
                    child: const Text("Save Budget"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ================= EXPENSE INPUT =================
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: _input("Expense Title"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expenseController,
                    keyboardType: TextInputType.number,
                    decoration: _input("Amount"),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField(
                    value: selectedCategory,
                    decoration: _input("Category"),
                    items: categories
                        .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ))
                        .toList(),
                    onChanged: (v) {
                      setState(() =>
                      selectedCategory = v.toString());
                    },
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: addExpense,
                    child: const Text("Add Expense"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ================= EXPENSE LIST =================
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                final e = expenses[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.monetization_on,
                      color: Colors.deepPurple,
                    ),
                    title:
                    Text("${e['title']} - ₹${e['amount']}"),
                    subtitle: Text(e['category']),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete,
                          color: Colors.red),
                      onPressed: () => deleteExpense(e['id']),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
          )
        ],
      ),
      child: child,
    );
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}