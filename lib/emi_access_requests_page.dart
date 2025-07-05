import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class EmiAccessRequestsPage extends StatefulWidget {
  const EmiAccessRequestsPage({Key? key}) : super(key: key);

  @override
  State<EmiAccessRequestsPage> createState() => _EmiAccessRequestsPageState();
}

class _EmiAccessRequestsPageState extends State<EmiAccessRequestsPage> {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('emi_sharing_requests/$uid');
    return Scaffold(
      appBar: AppBar(title: const Text('EMI Access Requests')),
      body: Center(
        child: Text('This page has been removed. EMI access requests are now handled in the notification center.'),
      ),
    );
  }
}
