import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import 'package:kilimomkononi/screens/collection_management_screen.dart';
import 'package:kilimomkononi/screens/pest%20management/admin_pest_management_page.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final logger = Logger(printer: PrettyPrinter());
  final TextEditingController _uidController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<String> _allCollections = [];

  @override
  void initState() {
    super.initState();
    _fetchCollections();
  }

  Future<void> _fetchCollections() async {
    try {
      setState(() {
        _allCollections = [
          'Users',
          'marketdata',
          'fielddata',
          'Admins',
          'admin_logs',
          'diseaseinterventiondata', // Added
          'pestinterventiondata',   // Added
          'User_logs',              // Added
        ];
      });
    } catch (e) {
      logger.e('Error fetching collections: $e');
    }
  }

  Future<void> _assignRole(String uid, String collection) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      if (!userDoc.exists) throw 'User not found';
      await FirebaseFirestore.instance.collection(collection).doc(uid).set({'added': true});
      _logActivity('Assigned $collection role to $uid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${collection.replaceAll('s', '')} role assigned successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error assigning role: $e')));
      }
    }
  }

  Future<void> _disableUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({'isDisabled': true});
      _logActivity('Disabled user $uid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User disabled successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error disabling user: $e')));
      }
    }
  }

  Future<void> _deleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      _logActivity('Deleted user $uid');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted from Firestore!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  Future<void> _resetPassword(String email) async {
    try {
      if (email.isEmpty) throw 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _logActivity('Sent password reset for $email');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email sent!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending password reset: $e')));
      }
    }
  }

  Future<void> _logActivity(String action) async {
    try {
      await FirebaseFirestore.instance.collection('admin_logs').add({
        'action': action,
        'timestamp': Timestamp.now(),
        'adminUid': FirebaseAuth.instance.currentUser?.uid,
      });
    } catch (e) {
      logger.e('Error logging activity: $e');
    }
  }

  @override
  void dispose() {
    _uidController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollectionStats(),
              const SizedBox(height: 20),
              _buildManagementOptions(),
              const SizedBox(height: 20),
              _buildUserList(),
              const SizedBox(height: 20),
              _buildActivityLogs(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Collection Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_allCollections.isEmpty)
              const CircularProgressIndicator()
            else
              ..._allCollections.map((collection) => StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection(collection).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      final count = snapshot.data?.docs.length ?? 0;
                      return ListTile(
                        title: Text(collection, style: const TextStyle(fontSize: 16)),
                        trailing: Text('$count', style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 3, 39, 4))),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CollectionManagementScreen(collectionName: collection),
                          ),
                        ),
                      );
                    },
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildManagementOptions() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _buildOptionCard('Assign Admin', Icons.person_add, () => _showAssignRoleDialog('Admins')),
        _buildOptionCard('Manage Pests', Icons.bug_report, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPestManagementPage()))),
        _buildOptionCard('Add Price Analyst', Icons.monetization_on, () => _showAssignRoleDialog('PriceAnalysts')),
        _buildOptionCard('Manage Users', Icons.people, () => _showManageUsersScreen()),
      ],
    );
  }

  Widget _buildOptionCard(String title, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: onTap == null ? Colors.grey[300] : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: const Color.fromARGB(255, 3, 39, 4)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAssignRoleDialog(String collection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign ${collection.replaceAll('s', '')} Role'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _uidController,
                decoration: InputDecoration(
                  labelText: 'Enter User UID',
                  hintText: 'e.g., abc123xyz789',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.paste),
              onPressed: () async {
                final clipboardData = await Clipboard.getData('text/plain');
                if (clipboardData != null && clipboardData.text != null) {
                  _uidController.text = clipboardData.text!;
                }
              },
              tooltip: 'Paste UID',
            ),
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _showUserListDialog(),
              tooltip: 'Select User',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (_uidController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a UID')));
                return;
              }
              _assignRole(_uidController.text, collection);
              Navigator.pop(context);
              _uidController.clear();
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showUserListDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select User'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('Users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No users found.');
              }
              final users = snapshot.data!.docs;
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  final uid = users[index].id;
                  return ListTile(
                    title: Text(user['fullName'] ?? 'No Name'),
                    subtitle: Text('UID: $uid'),
                    onTap: () {
                      _uidController.text = uid;
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManageUsersScreen() {
    String? bulkAction;
    List<String> selectedUids = [];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(
              title: const Text('Manage Users', style: TextStyle(color: Colors.white)),
              backgroundColor: const Color.fromARGB(255, 3, 39, 4),
              foregroundColor: Colors.white,
              actions: [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu),
                  onSelected: (value) {
                    setState(() {
                      bulkAction = value;
                      selectedUids.clear();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'Bulk Disable', child: Text('Bulk Disable')),
                    const PopupMenuItem(value: 'Bulk Delete', child: Text('Bulk Delete')),
                    const PopupMenuItem(value: 'Bulk Reset Password', child: Text('Bulk Reset Password')),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No users found.'));
                      }

                      final users = snapshot.data!.docs;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            columns: [
                              if (bulkAction != null) const DataColumn(label: Text('Select')),
                              const DataColumn(label: Text('Profile')),
                              const DataColumn(label: Text('Full Name')),
                              const DataColumn(label: Text('Email')),
                              const DataColumn(label: Text('Farm Location')),
                              const DataColumn(label: Text('Phone Number')),
                              const DataColumn(label: Text('Gender')),
                              const DataColumn(label: Text('National ID')),
                              const DataColumn(label: Text('Date of Birth')),
                              const DataColumn(label: Text('Actions')),
                            ],
                            rows: users.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final uid = doc.id;
                              final isAdmin = FirebaseAuth.instance.currentUser?.uid == uid;
                              return DataRow(cells: [
                                if (bulkAction != null)
                                  DataCell(
                                    Checkbox(
                                      value: selectedUids.contains(uid),
                                      onChanged: isAdmin
                                          ? null
                                          : (value) {
                                              setState(() {
                                                if (value == true) {
                                                  selectedUids.add(uid);
                                                } else {
                                                  selectedUids.remove(uid);
                                                }
                                              });
                                            },
                                    ),
                                  ),
                                DataCell(
                                  data['profileImage'] != null
                                      ? Image.memory(
                                          base64Decode(data['profileImage']),
                                          width: 28,
                                          height: 28,
                                          fit: BoxFit.cover,
                                        )
                                      : const Icon(Icons.person, size: 28),
                                ),
                                DataCell(Text(data['fullName'] ?? 'N/A')),
                                DataCell(Text(data['email'] ?? 'N/A')),
                                DataCell(Text(data['farmLocation'] ?? 'N/A')),
                                DataCell(Text(data['phoneNumber'] ?? 'N/A')),
                                DataCell(Text(data['gender'] ?? 'N/A')),
                                DataCell(Text(data['nationalId'] ?? 'N/A')),
                                DataCell(Text(data['dateOfBirth'] ?? 'N/A')),
                                DataCell(
                                  PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'Disable') _disableUser(uid);
                                      if (value == 'Delete') _deleteUser(uid);
                                      if (value == 'Reset Password') _resetPassword(data['email'] ?? '');
                                      if (value == 'Copy UID') {
                                        Clipboard.setData(ClipboardData(text: uid));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('UID copied to clipboard!')),
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'Disable', child: Text('Disable User')),
                                      const PopupMenuItem(value: 'Delete', child: Text('Delete User')),
                                      const PopupMenuItem(value: 'Reset Password', child: Text('Reset Password')),
                                      const PopupMenuItem(value: 'Copy UID', child: Text('Copy UID')),
                                    ],
                                    icon: const Icon(Icons.more_vert),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (bulkAction != null && selectedUids.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (bulkAction == 'Bulk Disable') {
                          for (var uid in selectedUids) {
                            await _disableUser(uid);
                          }
                        } else if (bulkAction == 'Bulk Delete') {
                          for (var uid in selectedUids) {
                            await _deleteUser(uid);
                          }
                        } else if (bulkAction == 'Bulk Reset Password') {
                          for (var uid in selectedUids) {
                            final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
                            await _resetPassword(doc['email'] ?? '');
                          }
                        }
                        setState(() {
                          bulkAction = null;
                          selectedUids.clear();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                      ),
                      child: Text('Execute $bulkAction'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('User Management', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search Users',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
            ),
          ),
          onChanged: (value) => setState(() {}),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('Users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Text('No users found.');
            }
            final users = snapshot.data!.docs.where((doc) {
              final user = doc.data() as Map<String, dynamic>;
              final fullName = user['fullName']?.toString().toLowerCase() ?? '';
              final email = user['email']?.toString().toLowerCase() ?? '';
              return fullName.contains(_searchController.text.toLowerCase()) ||
                  email.contains(_searchController.text.toLowerCase());
            }).toList();
            return SizedBox(
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index].data() as Map<String, dynamic>;
                  return ListTile(
                    title: Text(user['fullName'] ?? 'No Name'),
                    subtitle: Text('Email: ${user['email'] ?? 'N/A'}'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        SizedBox(
          height: 200,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('admin_logs').orderBy('timestamp', descending: true).limit(10).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Text('No recent activity logs.');
              }
              final logs = snapshot.data!.docs;
              return ListView.builder(
                shrinkWrap: true,
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index].data() as Map<String, dynamic>;
                  final timestamp = (log['timestamp'] as Timestamp).toDate();
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(log['action']),
                      subtitle: Text('By: ${log['adminUid']} at $timestamp'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}