import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class FriendDetailPage extends StatefulWidget {
  final String friendUid;
  final String friendUsername;
  const FriendDetailPage({Key? key, required this.friendUid, required this.friendUsername}) : super(key: key);

  @override
  State<FriendDetailPage> createState() => _FriendDetailPageState();
}

class _FriendDetailPageState extends State<FriendDetailPage> {
  bool hasAccess = false;
  bool requested = false;
  double totalOutstanding = 0.0;
  bool isOwner = false;
  bool allowAccess = false;
  String _sortBy = 'due';
  String? selectedCategory;
  List<String> categories = ['All', 'Bank', 'App', 'Friend', 'Other'];

  @override
  void initState() {
    super.initState();
    _checkIfOwner();
    _listenToRequestStatus();
  }

  void _listenToRequestStatus() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('emi_sharing_requests/${widget.friendUid}/${user.uid}');
    ref.onValue.listen((event) {
      final exists = event.snapshot.value != null;
      setState(() {
        requested = exists;
      });
    });
    final accessRef = FirebaseDatabase.instance.ref('emi_sharing/${widget.friendUid}/${user.uid}');
    accessRef.onValue.listen((event) {
      setState(() {
        hasAccess = event.snapshot.value == true;
        // If access is granted, clear requested (hide request button)
        if (hasAccess) requested = false;
      });
    });
  }

  void _checkIfOwner() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      isOwner = user.uid == widget.friendUid;
    });
    if (isOwner) {
      // Owner doesn't need access logic
      setState(() {
        allowAccess = false;
      });
    } else {
      _loadAllowAccess();
    }
  }

  void _loadAllowAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('emi_sharing/${user.uid}/${widget.friendUid}');
    final snap = await ref.get();
    setState(() {
      allowAccess = snap.value == true;
    });
  }

  Future<void> _toggleAllowAccess(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('emi_sharing/${user.uid}/${widget.friendUid}');
    await ref.set(value);
    setState(() {
      allowAccess = value;
    });
  }

  void _requestAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final ref = FirebaseDatabase.instance.ref('emi_sharing_requests/${widget.friendUid}/${user.uid}');
    await ref.set(true);
    // Add notification for the friend
    final notifRef = FirebaseDatabase.instance.ref('notifications/${widget.friendUid}').push();
    await notifRef.set({
      'type': 'emi_access',
      'title': 'EMI Access Request',
      'body': '${user.email ?? user.uid} has requested access to your EMI info.',
      'timestamp': DateTime.now().toIso8601String(),
      'fromUid': user.uid,
    });
    setState(() { requested = true; });
  }

  Widget _buildEmiTiles() {
    return StreamBuilder(
      stream: FirebaseDatabase.instance.ref('emis/${widget.friendUid}').onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
          if (!hasAccess && !isOwner) {
            return _buildAccessRequestSection();
          }
          return const Center(child: Text('No EMIs to show.'));
        }
        
        final data = snapshot.data!.snapshot.value as Map?;
        double total = 0.0;
        List<MapEntry> emis = data?.entries.toList() ?? [];
        Map<String, double> sourceTotals = {};
        Map<String, int> sourceCounts = {};
        
        // Filter out if needed
        if (selectedCategory != null && selectedCategory != 'All') {
          emis = emis.where((entry) => entry.value['category'] == selectedCategory).toList();
        }
        
        // Calculate totals and counts per source
        for (final entry in emis) {
          final emi = entry.value;
          if (emi['paid'] != true) {
            final amt = double.tryParse(emi['amount'].toString()) ?? 0.0;
            total += amt;
            final cat = emi['category'] ?? 'Other';
            sourceTotals[cat] = (sourceTotals[cat] ?? 0) + amt;
            sourceCounts[cat] = (sourceCounts[cat] ?? 0) + 1;
          }
        }
        
        // Sorting logic
        emis.sort((a, b) {
          if (_sortBy == 'amount') {
            final aAmt = double.tryParse(a.value['amount'].toString()) ?? 0.0;
            final bAmt = double.tryParse(b.value['amount'].toString()) ?? 0.0;
            return bAmt.compareTo(aAmt);
          } else if (_sortBy == 'category') {
            return (a.value['category'] ?? '').toString().compareTo((b.value['category'] ?? '').toString());
          } else {
            final aDate = DateTime.tryParse(a.value['dueDate'] ?? '') ?? DateTime.now();
            final bDate = DateTime.tryParse(b.value['dueDate'] ?? '') ?? DateTime.now();
            return aDate.compareTo(bDate);
          }
        });
        
        if (emis.isEmpty) {
          return const Center(child: Text('No EMIs to show.'));
        }
        
        // Now we have access but we're checking if there are actually any EMIs
        if (!hasAccess && !isOwner) {
          return _buildAccessRequestSection();
        }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        Text('Outstanding by Source', 
                          style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
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
                          Text('₹${e.value.toStringAsFixed(2)}  |  EMIs: ${sourceCounts[e.key]}', 
                            style: const TextStyle(fontWeight: FontWeight.w500)),
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
                        Text('₹${total.toStringAsFixed(2)}', 
                          style: const TextStyle(fontSize: 28, color: Colors.red, fontWeight: FontWeight.bold)),
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
                Text('EMI Details:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimationLimiter(
                child: ListView.builder(
                  itemCount: emis.length,
                  itemBuilder: (context, index) {
                    final entry = emis[index];
                    final emi = entry.value;
                    final paid = emi['paid'] == true;
                    
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 400),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Card(
                            color: paid ? Colors.green[50] : Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: paid ? Colors.green[100] : Colors.blue[100],
                                child: Icon(
                                  paid ? Icons.done : Icons.payments,
                                  color: paid ? Colors.green : Colors.blue,
                                ),
                              ),
                              title: Text(
                                '${emi['category']} - ₹${emi['amount']}',
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
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
                                      Text('Due: ${emi['dueDate']?.toString().split('T')[0] ?? ''}', 
                                        style: const TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                  if (paid)
                                    Row(
                                      children: const [
                                        Icon(Icons.check_circle, size: 15, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text('Status: Paid', style: TextStyle(fontSize: 14, color: Colors.green)),
                                      ],
                                    ),
                                ],
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
    );
  }
  
  Widget _buildAccessRequestSection() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 20),
          const Text(
            "You don't have access to view EMI information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            "Send a request to view your friend's EMI details",
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: requested
                ? Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    color: Colors.orange[100],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.hourglass_top, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Request Sent',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    key: const ValueKey('request'),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Request EMI Access'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _requestAccess,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid;
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        title: Row(
          children: [
            Hero(
              tag: 'profile_${widget.friendUid}',
              child: CircleAvatar(
                backgroundColor: Colors.blue[100],
                radius: 18,
                child: const Icon(Icons.person, color: Colors.blue, size: 20),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.friendUsername, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.blue),
        titleTextStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 22),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert, color: Colors.blue),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Switch(
                      value: allowAccess,
                      onChanged: _toggleAllowAccess,
                      activeColor: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const Text('Allow this friend to view your EMI info'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
                          icon: const Icon(Icons.filter_list, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortBy,
                        items: const [
                          DropdownMenuItem(value: 'due', child: Text('Due Date')),
                          DropdownMenuItem(value: 'amount', child: Text('Amount')),
                          DropdownMenuItem(value: 'category', child: Text('Category')),
                        ],
                        onChanged: (val) {
                          setState(() { 
                            _sortBy = val!; 
                          });
                        },
                        icon: const Icon(Icons.sort, color: Colors.blue),
                        hint: const Text('Sort'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _buildEmiTiles(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
