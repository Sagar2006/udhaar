import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({Key? key}) : super(key: key);

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  int notificationCount = 0;
  int emiAccessRequestCount = 0;

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
      setState(() {
        notificationCount = data?.length ?? 0;
      });
    });
  }

  void _listenForEmiAccessRequests() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final ref = FirebaseDatabase.instance.ref('emi_sharing_requests/$uid');
    ref.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      setState(() {
        emiAccessRequestCount = data?.length ?? 0;
      });
    });
  }

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
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.blue),
        titleTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AnimationLimiter(
          child: StreamBuilder(
            stream: FirebaseDatabase.instance.ref('notifications/$uid').onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off, color: Colors.blueGrey, size: 64),
                      const SizedBox(height: 16),
                      const Text('No notifications', style: TextStyle(fontSize: 20, color: Colors.blueGrey)),
                    ],
                  ),
                );
              }
              final data = snapshot.data!.snapshot.value as Map?;
              final notifications = data?.entries.toList() ?? [];
              notifications.sort((a, b) {
                final aTime = DateTime.tryParse(a.value['timestamp'] ?? '') ?? DateTime.now();
                final bTime = DateTime.tryParse(b.value['timestamp'] ?? '') ?? DateTime.now();
                return bTime.compareTo(aTime);
              });
              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notif = notifications[index].value;
                  final type = notif['type'] ?? 'info';
                  final icon = type == 'friend_request'
                      ? Icons.person_add
                      : type == 'emi_access'
                          ? Icons.lock_open
                          : Icons.notifications;
                  final color = type == 'friend_request'
                      ? Colors.blue
                      : type == 'emi_access'
                          ? Colors.orange
                          : Colors.blueGrey;
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 400),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            leading: Icon(icon, color: color, size: 32),
                            title: Text(notif['title'] ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(notif['body'] ?? ''),
                            trailing: type == 'friend_request'
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check, color: Colors.green),
                                        tooltip: 'Accept',
                                        onPressed: () async {
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user == null) return;
                                          final uid = user.uid;
                                          final fromUid = notif['fromUid'];
                                          // Accept friend request
                                          await FirebaseDatabase.instance.ref('friends/$uid/$fromUid').set(true);
                                          await FirebaseDatabase.instance.ref('friends/$fromUid/$uid').set(true);
                                          await FirebaseDatabase.instance.ref('friend_requests/$uid/incoming/$fromUid').remove();
                                          await FirebaseDatabase.instance.ref('friend_requests/$fromUid/outgoing/$uid').remove();
                                          // Remove notification
                                          await FirebaseDatabase.instance.ref('notifications/$uid/${notifications[index].key}').remove();
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, color: Colors.red),
                                        tooltip: 'Reject',
                                        onPressed: () async {
                                          final user = FirebaseAuth.instance.currentUser;
                                          if (user == null) return;
                                          final uid = user.uid;
                                          final fromUid = notif['fromUid'];
                                          // Reject friend request
                                          await FirebaseDatabase.instance.ref('friend_requests/$uid/incoming/$fromUid').remove();
                                          await FirebaseDatabase.instance.ref('friend_requests/$fromUid/outgoing/$uid').remove();
                                          // Remove notification
                                          await FirebaseDatabase.instance.ref('notifications/$uid/${notifications[index].key}').remove();
                                        },
                                      ),
                                    ],
                                  )
                                : type == 'emi_access'
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.check, color: Colors.green),
                                            tooltip: 'Allow',
                                            onPressed: () async {
                                              final user = FirebaseAuth.instance.currentUser;
                                              if (user == null) return;
                                              final uid = user.uid;
                                              final fromUid = notif['fromUid'];
                                              // Grant EMI access
                                              await FirebaseDatabase.instance.ref('emi_sharing/$uid/$fromUid').set(true);
                                              await FirebaseDatabase.instance.ref('emi_sharing_requests/$uid/$fromUid').remove();
                                              // Remove notification
                                              await FirebaseDatabase.instance.ref('notifications/$uid/${notifications[index].key}').remove();
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            tooltip: 'Reject',
                                            onPressed: () async {
                                              final user = FirebaseAuth.instance.currentUser;
                                              if (user == null) return;
                                              final uid = user.uid;
                                              final fromUid = notif['fromUid'];
                                              // Reject EMI access
                                              await FirebaseDatabase.instance.ref('emi_sharing_requests/$uid/$fromUid').remove();
                                              // Remove notification
                                              await FirebaseDatabase.instance.ref('notifications/$uid/${notifications[index].key}').remove();
                                            },
                                          ),
                                        ],
                                      )
                                    : Text(
                                        notif['timestamp'] != null ? notif['timestamp'].toString().split('T').first : '',
                                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                                      ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
