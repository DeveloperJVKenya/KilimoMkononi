import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _sortField = 'fullName';
  bool _sortAscending = true;
  bool _groupByLocation = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String?> _performResetPassword(String email) async {
    try {
      if (email.isEmpty) return 'Email is required';
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return 'Password reset email sent!';
    } catch (e) {
      return 'Error sending password reset: $e';
    }
  }

  Future<String?> _performToggleUserStatus(String uid, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({'isDisabled': !currentStatus});
      return 'User ${!currentStatus ? 'disabled' : 'enabled'} successfully!';
    } catch (e) {
      return 'Error toggling user status: $e';
    }
  }

  Future<String?> _performDeleteUser(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      return 'User deleted successfully!';
    } catch (e) {
      return 'Error deleting user: $e';
    }
  }

  void _showUserDetails(Map<String, dynamic> userData, String uid) {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(userData['fullName'] ?? 'User Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Full Name: ${userData['fullName'] ?? 'N/A'}'),
                Text('Email: ${userData['email'] ?? 'N/A'}'),
                Text('Farm Location: ${userData['farmLocation'] ?? 'N/A'}'),
                Text('Phone Number: ${userData['phoneNumber'] ?? 'N/A'}'),
                Text('National ID: ${userData['nationalId'] ?? 'N/A'}'),
                Text('Gender: ${userData['gender'] ?? 'N/A'}'),
                Text('Date of Birth: ${userData['dateOfBirth'] ?? 'N/A'}'),
                Text(
                  'Account Status: ${userData['isDisabled'] == true ? 'Disabled' : 'Active'}',
                  style: TextStyle(color: userData['isDisabled'] == true ? Colors.red : Colors.green),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () {},
              tooltip: 'Call User',
            ),
            IconButton(
              icon: const Icon(Icons.message, color: Colors.blue),
              onPressed: () {},
              tooltip: 'Message User',
            ),
            TextButton(
              onPressed: () async {
                final result = await _performResetPassword(userData['email'] ?? '');
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(result!),
                      backgroundColor: result.startsWith('Error') ? Colors.red : null,
                    ),
                  );
                }
              },
              child: const Text('Reset Password'),
            ),
            TextButton(
              onPressed: () async {
                final result = await _performToggleUserStatus(uid, userData['isDisabled'] ?? false);
                if (dialogContext.mounted) {
                  setDialogState(() {
                    userData['isDisabled'] = !(userData['isDisabled'] ?? false);
                  });
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(result!),
                      backgroundColor: result.startsWith('Error') ? Colors.red : null,
                    ),
                  );
                }
              },
              child: Text(userData['isDisabled'] == true ? 'Enable User' : 'Disable User'),
            ),
            TextButton(
              onPressed: () async {
                final result = await _performDeleteUser(uid);
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text(result!),
                      backgroundColor: result.startsWith('Error') ? Colors.red : null,
                    ),
                  );
                  if (!result.startsWith('Error')) {
                    Navigator.pop(dialogContext);
                  }
                }
              },
              child: const Text('Delete User', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('UID copied to clipboard!')),
                  );
                }
              },
              child: const Text('Copy UID'),
            ),
            TextButton(
              onPressed: () {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildSortSection(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Farm Location or Gender',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
          filled: true,
          fillColor: Colors.grey[100],
          hintStyle: const TextStyle(color: Colors.grey),
          contentPadding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        ),
        style: const TextStyle(color: Colors.black),
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildSortSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text('Sort by: ', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                value: _sortField,
                items: const [
                  DropdownMenuItem(value: 'fullName', child: Text('Full Name')),
                  DropdownMenuItem(value: 'farmLocation', child: Text('Farm Location')),
                  DropdownMenuItem(value: 'gender', child: Text('Gender')),
                  DropdownMenuItem(value: 'nationalId', child: Text('National ID')),
                ],
                onChanged: (value) => setState(() => _sortField = value!),
                style: const TextStyle(color: Colors.black),
              ),
              IconButton(
                icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () => setState(() => _sortAscending = !_sortAscending),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(_groupByLocation ? Icons.group_off : Icons.group),
                tooltip: 'Group by Location',
                onPressed: () => setState(() => _groupByLocation = !_groupByLocation),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('Users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Text('Users: 0', style: TextStyle(fontWeight: FontWeight.bold));
                  final filteredUsers = _filterUsers(snapshot.data!.docs);
                  return Text('Users: ${filteredUsers.length}', style: const TextStyle(fontWeight: FontWeight.bold));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filterUsers(List<QueryDocumentSnapshot> docs) {
    final searchText = _searchController.text.toLowerCase();
    return docs.map((doc) => doc.data() as Map<String, dynamic>).where((user) {
      final farmLocation = user['farmLocation']?.toString().toLowerCase() ?? '';
      final gender = user['gender']?.toString().toLowerCase() ?? '';
      return farmLocation.contains(searchText) || gender.contains(searchText);
    }).toList();
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
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

        var filteredUsers = _filterUsers(snapshot.data!.docs);

        if (_groupByLocation && _searchController.text.isNotEmpty) {
          final locationGroups = <String, List<Map<String, dynamic>>>{};
          for (var user in filteredUsers) {
            final location = user['farmLocation'] ?? 'Unknown';
            locationGroups[location] = locationGroups[location] ?? [];
            locationGroups[location]!.add(user);
          }
          return ListView(
            children: locationGroups.entries.map((entry) {
              return ExpansionTile(
                title: Text('${entry.key} (${entry.value.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                children: entry.value.map((user) => _buildUserTile(user, snapshot.data!.docs.firstWhere((doc) => doc['email'] == user['email']).id)).toList(),
              );
            }).toList(),
          );
        }

        if (_sortField == 'farmLocation') {
          filteredUsers.sort((a, b) => _sortAscending
              ? (a['farmLocation'] ?? '').compareTo(b['farmLocation'] ?? '')
              : (b['farmLocation'] ?? '').compareTo(a['farmLocation'] ?? ''));
        } else if (_sortField == 'nationalId') {
          filteredUsers.sort((a, b) {
            final aId = int.tryParse(a['nationalId'] ?? '0') ?? 0;
            final bId = int.tryParse(b['nationalId'] ?? '0') ?? 0;
            return _sortAscending ? aId.compareTo(bId) : bId.compareTo(aId);
          });
        } else {
          filteredUsers.sort((a, b) => _sortAscending
              ? (a[_sortField] ?? '').compareTo(b[_sortField] ?? '')
              : (b[_sortField] ?? '').compareTo(a[_sortField] ?? ''));
        }

        return ListView.builder(
          itemCount: filteredUsers.length,
          itemBuilder: (context, index) {
            final user = filteredUsers[index];
            final uid = snapshot.data!.docs.firstWhere((doc) => doc['email'] == user['email']).id;
            return _buildUserTile(user, uid);
          },
        );
      },
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, String uid) {
    return GestureDetector(
      onTap: () => _showUserDetails(user, uid),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['fullName'] ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Email: ${user['email'] ?? 'N/A'}'),
                ],
              ),
            ),
            if (_sortField != 'fullName')
              Expanded(
                flex: 1,
                child: Text(
                  _sortField == 'farmLocation'
                      ? user['farmLocation'] ?? 'N/A'
                      : _sortField == 'gender'
                          ? user['gender'] ?? 'N/A'
                          : user['nationalId'] ?? 'N/A',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}