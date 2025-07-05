import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class AddEmiPage extends StatefulWidget {
  const AddEmiPage({Key? key}) : super(key: key);

  @override
  State<AddEmiPage> createState() => _AddEmiPageState();
}

class _AddEmiPageState extends State<AddEmiPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController lenderController = TextEditingController();
  final TextEditingController customCategoryController = TextEditingController();
  DateTime? dueDate;
  String message = '';
  String selectedCategory = 'Bank';
  final List<String> categories = ['Bank', 'App', 'Friend', 'Other'];
  bool setRepaymentDate = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        dueDate = picked;
      });
    }
  }

  Future<void> _saveEmi() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedCategory != 'Friend' && dueDate == null) return;
    if (selectedCategory == 'Friend' && setRepaymentDate && dueDate == null) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('emis/$uid').push();
    final categoryToSave = selectedCategory == 'Other' ? customCategoryController.text.trim() : selectedCategory;
    await ref.set({
      'amount': amountController.text.trim(),
      'category': categoryToSave,
      'lender': lenderController.text.trim(),
      'dueDate': (selectedCategory == 'Friend' && !setRepaymentDate) ? null : dueDate?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    setState(() {
      message = 'EMI saved!';
      amountController.clear();
      lenderController.clear();
      customCategoryController.clear();
      dueDate = null;
      selectedCategory = 'Bank';
      setRepaymentDate = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add EMI')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.isEmpty ? 'Enter amount' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      items: categories.map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat == 'Other' ? 'Add your own category' : cat),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedCategory = val!;
                          if (selectedCategory != 'Friend') setRepaymentDate = false;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Category',
                        prefixIcon: const Icon(Icons.category),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (selectedCategory == 'Other') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: customCategoryController,
                        decoration: InputDecoration(
                          labelText: 'Enter your category',
                          prefixIcon: const Icon(Icons.edit),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter category' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: lenderController,
                      decoration: InputDecoration(
                        labelText: 'Lender Name',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Enter lender name' : null,
                    ),
                    const SizedBox(height: 16),
                    if (selectedCategory == 'Friend') ...[
                      SwitchListTile(
                        title: const Text('Set repayment date?'),
                        value: setRepaymentDate,
                        onChanged: (val) {
                          setState(() => setRepaymentDate = val);
                        },
                      ),
                      if (setRepaymentDate)
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: Colors.white,
                          title: Text(
                            dueDate == null ? 'Select Due Date' : 'Due Date: \\${dueDate!.toLocal().toString().split(' ')[0]}',
                            style: TextStyle(
                              color: dueDate == null ? Colors.grey : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                          onTap: _pickDate,
                        ),
                    ] else ...[
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: Colors.white,
                        title: Text(
                          dueDate == null ? 'Select Due Date' : 'Due Date: \\${dueDate!.toLocal().toString().split(' ')[0]}',
                          style: TextStyle(
                            color: dueDate == null ? Colors.grey : Colors.black,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(Icons.calendar_today, color: Colors.blueAccent),
                        onTap: _pickDate,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.blueAccent,
                          elevation: 4,
                        ),
                        onPressed: _saveEmi,
                        child: const Text('Save EMI', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(message, style: const TextStyle(color: Colors.green)),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
