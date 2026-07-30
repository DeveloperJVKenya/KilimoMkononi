import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/screens/community_chat.dart';

class CommunityHomeScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const CommunityHomeScreen({super.key, this.userData});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<String> _joinedChannels = [];

  @override
  void initState() {
    super.initState();
    _fetchJoinedChannels();
  }

  Future<void> _fetchJoinedChannels() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final userDoc = await _firestore.collection('Users').doc(userId).get();
      setState(() {
        _joinedChannels = List<String>.from(userDoc.get('joinedChannels') ?? []);
      });
    }
  }

  Future<void> _toggleChannel(String channelId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to join channels')),
      );
      return;
    }

    setState(() {
      if (_joinedChannels.contains(channelId)) {
        _joinedChannels.remove(channelId);
      } else {
        _joinedChannels.add(channelId);
      }
    });

    await _firestore.collection('Users').doc(userId).update({
      'joinedChannels': _joinedChannels,
    });
  }

  // Helper method to get responsive values (from home.dart)
  double _getResponsiveValue(BuildContext context, {
    required double mobile,
    required double tablet,
    required double desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return mobile;
    } else if (width < 1200) {
      return tablet;
    } else {
      return desktop;
    }
  }

  // Helper method to get cross-axis count for grid
  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return 2;
    } else if (width < 1200) {
      return 3;
    } else {
      return 4;
    }
  }

  Widget _buildChannelButton(String title, String channelId, IconData icon) {
    final isJoined = _joinedChannels.contains(channelId);
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommunityChatScreen(channelId: channelId),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(_getResponsiveValue(
          context,
          mobile: 15,
          tablet: 20,
          desktop: 25,
        )),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 3, 39, 4),
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.5),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: _getResponsiveValue(
                context,
                mobile: 35,
                tablet: 40,
                desktop: 45,
              ),
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _getResponsiveValue(
                  context,
                  mobile: 14,
                  tablet: 16,
                  desktop: 18,
                ),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            IconButton(
              icon: Icon(
                isJoined ? Icons.remove_circle : Icons.add_circle,
                color: isJoined ? Colors.red : Colors.green,
                size: _getResponsiveValue(
                  context,
                  mobile: 24,
                  tablet: 28,
                  desktop: 32,
                ),
              ),
              onPressed: () => _toggleChannel(channelId),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String county = widget.userData?['county'] ?? 'General';
    final String constituency = widget.userData?['constituency'] ?? 'General';
    final String ward = widget.userData?['ward'] ?? 'General';
    final String locationPrefix = '${county}_${constituency}_$ward';
    final List<Map<String, String>> channels = [
      {'id': '${locationPrefix}_Pests_Diseases', 'title': 'Pests & Diseases'},
      {'id': '${locationPrefix}_Soil_Fertilizers', 'title': 'Soil & Fertilizers'},
      {'id': '${locationPrefix}_Market_Sales', 'title': 'Market & Sales'},
      {'id': '${locationPrefix}_Weather_Climate', 'title': 'Weather & Climate'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Community Channels - $ward',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Location-specific pest alert preview
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('PestAlerts')
                  .where('county', isEqualTo: county)
                  .where('constituency', isEqualTo: constituency)
                  .where('ward', isEqualTo: ward)
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Text('No recent pest alerts for your area.');
                }
                if (snapshot.hasError) {
                  return const Text('Error loading pest alerts.');
                }
                final alert = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                return Text(
                  'Latest Alert: ${alert['pestName']} in $ward - ${alert['description']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: _getResponsiveValue(context, mobile: 16, tablet: 20, desktop: 24),
                vertical: _getResponsiveValue(context, mobile: 20, tablet: 25, desktop: 30),
              ),
              child: GridView.count(
                crossAxisCount: _getCrossAxisCount(context),
                childAspectRatio: _getResponsiveValue(context, mobile: 1.0, tablet: 1.1, desktop: 1.2),
                mainAxisSpacing: _getResponsiveValue(context, mobile: 10, tablet: 15, desktop: 20),
                crossAxisSpacing: _getResponsiveValue(context, mobile: 10, tablet: 15, desktop: 20),
                children: channels.map((channel) {
                  return _buildChannelButton(
                    channel['title']!,
                    channel['id']!,
                    channel['title']!.contains('Pests')
                        ? Icons.bug_report
                        : channel['title']!.contains('Soil')
                            ? Icons.eco
                            : channel['title']!.contains('Market')
                                ? Icons.store
                                : Icons.cloud,
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}