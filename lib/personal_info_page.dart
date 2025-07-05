import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({Key? key}) : super(key: key);

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String username = '';
  String dob = '';
  String phone = '';
  String email = '';
  DateTime? selectedDob;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      email = user.email ?? '';
      phone = user.phoneNumber ?? '';
      final uid = user.uid;
      final ref = FirebaseDatabase.instance.ref('users/$uid');
      ref.get().then((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.value as Map?;
          if (data != null) {
            setState(() {
              name = data['name'] ?? '';
              username = data['username'] ?? '';
              dob = data['dob'] ?? '';
              phone = data['phone'] ?? '';
              if (dob.isNotEmpty) {
                selectedDob = DateTime.tryParse(dob);
              }
            });
          }
        }
      });
    }
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDob ?? DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        selectedDob = picked;
        dob = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _saveInfo() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('users/$uid');
    await ref.update({
      'name': name,
      'username': username,
      'dob': dob,
      'phone': phone,
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Info updated!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Personal Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (v) => name = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: username,
                decoration: const InputDecoration(labelText: 'Username'),
                onChanged: (v) => username = v,
                validator: (v) => v == null || v.isEmpty ? 'Enter username' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(selectedDob == null ? 'Select Date of Birth' : 'DOB: ${selectedDob!.toLocal().toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDob,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                onChanged: (v) => phone = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: email,
                decoration: const InputDecoration(labelText: 'Email'),
                enabled: false,
              ),
              const SizedBox(height: 32),
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
                  onPressed: _saveInfo,
                  child: const Text('Save', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
