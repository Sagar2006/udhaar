import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? selectedCategory;
  String? selectedSort;
  List<String> categories = ['All', 'Bank', 'App', 'Friend', 'Other'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }
    final uid = user.uid;
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.blue),
        titleTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder(
          stream: FirebaseDatabase.instance.ref('emis/$uid').onValue,
          builder: (context, snapshot) {
            double totalOutstanding = 0.0;
            List<MapEntry> emis = [];
            Map<String, double> sourceTotals = {};
            Map<String, int> sourceCounts = {};
            if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
              final data = snapshot.data!.snapshot.value as Map?;
              emis = data?.entries
                  .where((entry) => entry.value['paid'] != true)
                  .toList() ?? [];
              // Filtering
              if (selectedCategory != null && selectedCategory != 'All') {
                emis = emis.where((entry) => entry.value['category'] == selectedCategory).toList();
              }
              // Calculate totals and counts per source
              for (final entry in emis) {
                final emi = entry.value;
                final amt = double.tryParse(emi['amount'].toString()) ?? 0.0;
                totalOutstanding += amt;
                final cat = emi['category'] ?? 'Other';
                sourceTotals[cat] = (sourceTotals[cat] ?? 0) + amt;
                sourceCounts[cat] = (sourceCounts[cat] ?? 0) + 1;
              }
              // Sorting
              if (selectedSort == 'Amount') {
                emis.sort((a, b) {
                  final aAmt = double.tryParse(a.value['amount'].toString()) ?? 0.0;
                  final bAmt = double.tryParse(b.value['amount'].toString()) ?? 0.0;
                  return bAmt.compareTo(aAmt);
                });
              } else if (selectedSort == 'Due Date') {
                emis.sort((a, b) {
                  final aDate = DateTime.tryParse(a.value['dueDate'] ?? '') ?? DateTime.now();
                  final bDate = DateTime.tryParse(b.value['dueDate'] ?? '') ?? DateTime.now();
                  return aDate.compareTo(bDate);
                });
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter and Sort Row
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCategory ?? 'All',
                              items: categories.map((cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              )).toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedCategory = val;
                                });
                              },
                              hint: const Text('Filter by Source'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedSort,
                            items: ['Amount', 'Due Date'].map((sort) => DropdownMenuItem(
                              value: sort,
                              child: Text('Sort by $sort'),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                selectedSort = val;
                              });
                            },
                            hint: const Text('Sort'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Outstanding summary by source
                Card(
                  color: Colors.blue[100],
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.bar_chart, color: Colors.blue, size: 22),
                            SizedBox(width: 8),
                            Text('Outstanding by Source', style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...sourceTotals.entries.map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.label, color: Colors.blue[700], size: 18),
                                  const SizedBox(width: 6),
                                  Text('${e.key}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Text('₹${e.value.toStringAsFixed(2)}  |  EMIs: ${sourceCounts[e.key]}', style: const TextStyle(fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.account_balance_wallet, color: Colors.red, size: 22),
                                SizedBox(width: 8),
                                Text('Total Outstanding', style: TextStyle(fontSize: 16, color: Colors.blueGrey)),
                              ],
                            ),
                            Text('₹${totalOutstanding.toStringAsFixed(2)}', style: const TextStyle(fontSize: 28, color: Colors.red, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: const [
                    Icon(Icons.list_alt, color: Colors.blue, size: 22),
                    SizedBox(width: 8),
                    Text('Your EMIs:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: emis.isEmpty
                      ? const Center(child: Text('No EMIs added yet.', style: TextStyle(fontSize: 16, color: Colors.grey)))
                      : AnimationLimiter(
                          child: ListView.builder(
                            itemCount: emis.length,
                            itemBuilder: (context, index) {
                              final entry = emis[index];
                              final emi = entry.value;
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 400),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Card(
                                      color: Colors.white,
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      margin: const EdgeInsets.symmetric(vertical: 8),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor: Colors.blue[100],
                                          child: const Icon(Icons.payments, color: Colors.blue),
                                        ),
                                        title: Text('${emi['category']} - ₹${emi['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.person, size: 16, color: Colors.blueGrey),
                                                const SizedBox(width: 4),
                                                Text('Lender: ${emi['lender']}', style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 15, color: Colors.blueGrey),
                                                const SizedBox(width: 4),
                                                Text('Due: ${emi['dueDate']?.toString().split('T')[0] ?? ''}', style: const TextStyle(fontSize: 14)),
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing: ElevatedButton.icon(
                                          icon: const Icon(Icons.done),
                                          label: const Text('Paid'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () async {
                                            await FirebaseDatabase.instance
                                                .ref('emis/$uid/${entry.key}/paid')
                                                .set(true);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
