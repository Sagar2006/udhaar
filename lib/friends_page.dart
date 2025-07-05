import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'friend_detail_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({Key? key}) : super(key: key);

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController searchController = TextEditingController();
  String message = '';
  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  Set<String> myFriends = {};
  List<Map<String, dynamic>> myFriendsList = [];
  bool isLoading = true;

  void _openFriendDetail(Map<String, dynamic> friend) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FriendDetailPage(
          friendUid: friend['uid'],
          friendUsername: friend['username'],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
    _loadMyFriends();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllUsers() async {
    final usersSnap = await FirebaseDatabase.instance.ref('users').get();
    final user = FirebaseAuth.instance.currentUser;
    List<Map<String, dynamic>> users = [];
    for (final child in usersSnap.children) {
      final data = child.value as Map?;
      if (data != null && child.key != user?.uid) {
        users.add({
          'uid': child.key,
          'username': data['username'] ?? '',
          'name': data['name'] ?? '',
        });
      }
    }
    setState(() {
      allUsers = users;
    });
  }

  Future<void> _loadMyFriends() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final friendsSnap = await FirebaseDatabase.instance.ref('friends/${user.uid}').get();
    Set<String> friends = {};
    List<Map<String, dynamic>> friendsList = [];
    for (final child in friendsSnap.children) {
      friends.add(child.key!);
    }
    // Get friend details
    for (final friendId in friends) {
      final snap = await FirebaseDatabase.instance.ref('users/$friendId').get();
      final data = snap.value as Map?;
      if (data != null) {
        friendsList.add({
          'uid': friendId,
          'username': data['username'] ?? '',
          'name': data['name'] ?? '',
        });
      }
    }
    setState(() {
      myFriends = friends;
      myFriendsList = friendsList;
      isLoading = false;
    });
  }

  void _onSearchChanged() {
    final value = searchController.text;
    if (value.isEmpty) {
      setState(() {
        filteredUsers = [];
      });
      return;
    }
    setState(() {
      filteredUsers = allUsers
          .where((u) => u['username'].toLowerCase().contains(value.toLowerCase()))
          .toList();
      filteredUsers.sort((a, b) => a['username'].compareTo(b['username']));
    });
  }

  Future<void> sendFriendRequest(String targetId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    await FirebaseDatabase.instance.ref('friend_requests/$targetId/incoming/$uid').set(true);
    await FirebaseDatabase.instance.ref('friend_requests/$uid/outgoing/$targetId').set(true);
    // Add notification for the friend
    final notifRef = FirebaseDatabase.instance.ref('notifications/$targetId').push();
    await notifRef.set({
      'type': 'friend_request',
      'title': 'Friend Request',
      'body': '${user.email ?? user.uid} has sent you a friend request.',
      'timestamp': DateTime.now().toIso8601String(),
      'fromUid': user.uid,
    });
    setState(() { message = 'Friend request sent!'; });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request sent!')),
    );
  }

  void _showAddFriendDialog() {
    TextEditingController addFriendController = TextEditingController();
    List<Map<String, dynamic>> dialogFilteredUsers = [];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            void onDialogSearchChanged() {
              final value = addFriendController.text;
              if (value.isEmpty) {
                setStateDialog(() { dialogFilteredUsers = []; });
                return;
              }
              setStateDialog(() {
                dialogFilteredUsers = allUsers
                    .where((u) => u['username'].toLowerCase().contains(value.toLowerCase()))
                    .toList();
                dialogFilteredUsers.sort((a, b) => a['username'].compareTo(b['username']));
              });
            }
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.blue[100]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.person_add, color: Colors.blue, size: 28),
                        SizedBox(width: 10),
                        Text('Add a Friend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blue)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: addFriendController,
                      onChanged: (_) => onDialogSearchChanged(),
                      decoration: InputDecoration(
                        hintText: 'Search by username...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: addFriendController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  addFriendController.clear();
                                  onDialogSearchChanged();
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      height: 220,
                      child: dialogFilteredUsers.isEmpty
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.person_off, color: Colors.blueGrey, size: 48),
                                SizedBox(height: 10),
                                Text('No users found.', style: TextStyle(color: Colors.blueGrey)),
                              ],
                            )
                          : ListView.builder(
                              itemCount: dialogFilteredUsers.length,
                              itemBuilder: (context, idx) {
                                final user = dialogFilteredUsers[idx];
                                return Card(
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue[100],
                                      child: Text(user['username'] != null && user['username'].isNotEmpty ? user['username'][0].toUpperCase() : '?', style: const TextStyle(color: Colors.blue)),
                                    ),
                                    title: Text(user['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(user['name'] ?? ''),
                                    trailing: myFriends.contains(user['uid'])
                                        ? const Icon(Icons.check, color: Colors.green)
                                        : ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () {
                                              sendFriendRequest(user['uid']);
                                              Navigator.pop(context);
                                            },
                                            child: const Text('Add', style: TextStyle(color: Colors.white)),
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
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.blue),
        titleTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search friends...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimationConfiguration.synchronized(
              child: SlideAnimation(
                verticalOffset: 30.0,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: _showAddFriendDialog,
                    child: Card(
                      color: Colors.blue[100],
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.person_add, color: Colors.blue, size: 28),
                            SizedBox(width: 10),
                            Text('Add Friend', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : myFriendsList.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/empty_friends.png', height: 120, fit: BoxFit.contain, errorBuilder: (c, e, s) => const Icon(Icons.people_outline, size: 80, color: Colors.blueGrey)),
                            const SizedBox(height: 18),
                            const Text('No friends yet!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                            const SizedBox(height: 8),
                            const Text('Tap "Add Friend" to connect with others.', style: TextStyle(color: Colors.blueGrey)),
                          ],
                        )
                      : AnimationLimiter(
                          child: ListView.builder(
                            itemCount: myFriendsList.length,
                            itemBuilder: (context, index) {
                              final friend = myFriendsList[index];
                              final initials = (friend['username'] != null && friend['username'].isNotEmpty)
                                  ? friend['username'].substring(0, 2).toUpperCase()
                                  : '?';
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 400),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: Card(
                                      elevation: 3,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          radius: 26,
                                          backgroundColor: Colors.blue[100],
                                          child: Text(initials, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                        title: Text(friend['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                        subtitle: Text(friend['name'] ?? '', style: const TextStyle(color: Colors.blueGrey)),
                                        trailing: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [Colors.blue[200]!, Colors.blue[400]!]),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                                          padding: const EdgeInsets.all(6),
                                        ),
                                        onTap: () => _openFriendDetail(friend),
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
        ),
      ),
    );
  }
}
