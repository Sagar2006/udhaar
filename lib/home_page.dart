import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_page.dart';
import 'friends_page.dart';
import 'notification_center_page.dart';
import 'account_page.dart';
import 'add_emi_page.dart'; // Import the new EMI page
import 'package:firebase_database/firebase_database.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  int notificationCount = 0;
  int emiAccessRequestCount = 0;
  bool _badgePulse = false;

  final List<Widget> _pages = [
    const DashboardPage(),
    const FriendsPage(),
    const AddEmiPage(),
    NotificationCenterPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _listenForNotifications();
    _listenForEmiAccessRequests();
  }

  void _listenForNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('friend_requests/$uid/incoming');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final count = data?.length ?? 0;
      setState(() {
        _badgePulse = (count + emiAccessRequestCount) > (notificationCount + emiAccessRequestCount);
        notificationCount = count;
      });
      if (_badgePulse) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _badgePulse = false);
        });
      }
    });
  }

  void _listenForEmiAccessRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('emi_sharing_requests/$uid');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      final count = data?.length ?? 0;
      setState(() {
        _badgePulse = (notificationCount + count) > (notificationCount + emiAccessRequestCount);
        emiAccessRequestCount = count;
      });
      if (_badgePulse) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _badgePulse = false);
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Friends',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_box_rounded, size: 32),
            label: 'Add EMI',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.notifications),
                if ((notificationCount + emiAccessRequestCount) > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _badgePulse
                            ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]
                            : [],
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Center(
                        child: Text(
                          '${notificationCount + emiAccessRequestCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Notifications',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
