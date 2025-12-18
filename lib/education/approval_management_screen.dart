import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:logger/logger.dart';

class ApprovalManagementScreen extends StatefulWidget {
  final String schoolName;
  final EduRole currentUserRole;
  final String? classId; // For teachers to see students in their class

  const ApprovalManagementScreen({
    super.key,
    required this.schoolName,
    required this.currentUserRole,
    this.classId,
  });

  @override
  State<ApprovalManagementScreen> createState() =>
      _ApprovalManagementScreenState();
}

class _ApprovalManagementScreenState extends State<ApprovalManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _logger = Logger(printer: PrettyPrinter());
  String _selectedTab = 'pending'; // pending, approved, denied

  @override
  void initState() {
    super.initState();
    _logger.i('=== ApprovalManagementScreen Initialized ===');
    _logger.i('School Name: ${widget.schoolName}');
    _logger.i('Current User Role: ${widget.currentUserRole.name}');
    _logger.i('Class ID: ${widget.classId}');
    _debugCheckData();
  }

  Future<void> _debugCheckData() async {
    _logger.i('=== Starting Debug Check ===');
    
    try {
      // Check what's in the database for this school
      final allUsersSnapshot = await _firestore
          .collection('EducationUsers')
          .where('schoolName', isEqualTo: widget.schoolName)
          .get();
      
      _logger.i('Total users in school "${widget.schoolName}": ${allUsersSnapshot.docs.length}');
      
      if (widget.currentUserRole == EduRole.mainadmin) {
        // Check for headteachers specifically
        final headteacherSnapshot = await _firestore
            .collection('EducationUsers')
            .where('requestedRole', isEqualTo: 'headteacher')
            .get();
        
        _logger.i('=== All Headteacher Registrations (ANY SCHOOL) ===');
        _logger.i('Total headteachers found: ${headteacherSnapshot.docs.length}');
        
        for (var doc in headteacherSnapshot.docs) {
          final data = doc.data();
          _logger.i('---');
          _logger.i('Doc ID: ${doc.id}');
          _logger.i('Name: ${data['fullName']}');
          _logger.i('Email: ${data['email']}');
          _logger.i('School: ${data['schoolName']}');
          _logger.i('Requested Role: ${data['requestedRole']}');
          _logger.i('Approval Status: ${data['approvalStatus']}');
          _logger.i('Current Role: ${data['role']}');
        }
        
        // Check specifically for pending headteachers in this school
        final pendingHeadteachers = await _firestore
            .collection('EducationUsers')
            .where('schoolName', isEqualTo: widget.schoolName)
            .where('approvalStatus', isEqualTo: 'pending')
            .where('requestedRole', isEqualTo: 'headteacher')
            .get();
        
        _logger.i('=== Pending Headteachers in "${widget.schoolName}" ===');
        _logger.i('Count: ${pendingHeadteachers.docs.length}');
        
        for (var doc in pendingHeadteachers.docs) {
          final data = doc.data();
          _logger.i('Found pending headteacher: ${data['fullName']} (${data['email']})');
        }
      }
      
      // Log all users in the school with their details
      _logger.i('=== All Users in "${widget.schoolName}" ===');
      for (var doc in allUsersSnapshot.docs) {
        final data = doc.data();
        _logger.i('---');
        _logger.i('Name: ${data['fullName']}');
        _logger.i('Email: ${data['email']}');
        _logger.i('Requested Role: ${data['requestedRole']}');
        _logger.i('Current Role: ${data['role']}');
        _logger.i('Approval Status: ${data['approvalStatus']}');
      }
      
      _logger.i('=== Debug Check Complete ===');
    } catch (e) {
      _logger.e('Error during debug check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _logger.i('Manual refresh triggered');
              _debugCheckData();
              setState(() {});
            },
            tooltip: 'Refresh & Debug',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  String _getTitle() {
    if (widget.currentUserRole == EduRole.headteacher) {
      return 'Teacher Approvals';
    } else if (widget.currentUserRole == EduRole.mainadmin) {
      return 'Headteacher Approvals';
    } else if (widget.currentUserRole == EduRole.teacher) {
      return 'Student Approvals';
    }
    return 'Approvals';
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey.shade200,
      child: Row(
        children: [
          _buildTab('Pending', 'pending'),
          _buildTab('Approved', 'approved'),
          _buildTab('Denied', 'denied'),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          _logger.i('Tab changed to: $value');
          setState(() => _selectedTab = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF003900) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? const Color(0xFF003900)
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserList() {
      _logger.i('=== Building User List ===');
      _logger.i('Selected Tab: $_selectedTab');
      _logger.i('School Name: ${widget.schoolName}');
      _logger.i('User Role: ${widget.currentUserRole.name}');
      
      Query query;
      
      // CRITICAL FIX: Mainadmin should see ALL headteachers across ALL schools
      if (widget.currentUserRole == EduRole.mainadmin) {
          // Don't filter by school for mainadmin
          query = _firestore.collection('EducationUsers');
          _logger.i('Mainadmin: No school filter applied (viewing all schools)');
      } else {
          // Other roles filter by their school
          query = _firestore
              .collection('EducationUsers')
              .where('schoolName', isEqualTo: widget.schoolName);
          _logger.i('Base query created with schoolName filter: ${widget.schoolName}');
      }

      // Filter by approval status
      if (_selectedTab == 'pending') {
          query = query.where('approvalStatus', isEqualTo: 'pending');
          _logger.i('Added filter: approvalStatus = pending');
      } else if (_selectedTab == 'approved') {
          query = query.where('approvalStatus', isEqualTo: 'approved');
          _logger.i('Added filter: approvalStatus = approved');
      } else if (_selectedTab == 'denied') {
          query = query.where('approvalStatus', isEqualTo: 'denied');
          _logger.i('Added filter: approvalStatus = denied');
      }

      // Filter by requested role
      if (widget.currentUserRole == EduRole.mainadmin) {
          query = query.where('requestedRole', isEqualTo: 'headteacher');
          _logger.i('Added filter: requestedRole = headteacher (for mainadmin - ALL SCHOOLS)');
      } else if (widget.currentUserRole == EduRole.headteacher) {
          query = query.where('requestedRole', isEqualTo: 'teacher');
          _logger.i('Added filter: requestedRole = teacher (for headteacher)');
      } else if (widget.currentUserRole == EduRole.teacher) {
          query = query.where('requestedRole', isEqualTo: 'student');
          _logger.i('Added filter: requestedRole = student (for teacher)');
      }

      _logger.i('Final query built, starting StreamBuilder...');

      return StreamBuilder<QuerySnapshot>(
          stream: query.snapshots(),
          builder: (context, snapshot) {
              _logger.i('=== StreamBuilder Update ===');
              _logger.i('Connection State: ${snapshot.connectionState}');
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                  _logger.i('Waiting for data...');
                  return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                  _logger.e('StreamBuilder Error: ${snapshot.error}');
                  _logger.e('Error Details: ${snapshot.error.toString()}');
                  return Center(
                      child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                                  const SizedBox(height: 16),
                                  const Text(
                                      'Database Error',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Error: ${snapshot.error}',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                      onPressed: () {
                                        _logger.i('Retry button pressed');
                                        setState(() {});
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry'),
                                  ),
                              ],
                          ),
                      ),
                  );
              }

              var users = snapshot.data?.docs ?? [];
              _logger.i('Raw documents received: ${users.length}');

              // Log each user found
              for (var i = 0; i < users.length; i++) {
                final data = users[i].data() as Map<String, dynamic>;
                _logger.i('User $i: ${data['fullName']} - School: ${data['schoolName']} - Role: ${data['requestedRole']} - Status: ${data['approvalStatus']}');
              }

              // If teacher, filter by classId in-memory
              if (widget.currentUserRole == EduRole.teacher && widget.classId != null) {
                  _logger.i('Filtering students by classId: ${widget.classId}');
                  final beforeFilterCount = users.length;
                  
                  users = users.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final studentClassId = data['currentClassId'];
                      final matches = studentClassId == widget.classId;
                      _logger.i('Student ${data['fullName']}: classId=$studentClassId, matches=$matches');
                      return matches;
                  }).toList();
                  
                  _logger.i('After class filter: $beforeFilterCount -> ${users.length} users');
              }

              if (users.isEmpty) {
                  _logger.w('No users found matching criteria');
                  _logger.w('Tab: $_selectedTab, Role: ${widget.currentUserRole.name}, School: ${widget.schoolName}');
                  
                  return Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(
                                  _selectedTab == 'pending'
                                      ? Icons.inbox
                                      : _selectedTab == 'approved'
                                          ? Icons.check_circle_outline
                                          : Icons.cancel_outlined,
                                  size: 80,
                                  color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                  _selectedTab == 'pending'
                                      ? 'No pending approvals'
                                      : _selectedTab == 'approved'
                                          ? 'No approved users yet'
                                          : 'No denied users',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                  'Check debug logs for details',
                                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                          ],
                      ),
                  );
              }

              _logger.i('Building list with ${users.length} users');
              
              return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                      final userData = users[index].data() as Map<String, dynamic>;
                      final user = EduUser.fromMap(userData, users[index].id);
                      _logger.i('Rendering user card for: ${user.fullName} from ${userData['schoolName']}');
                      return _buildUserCard(user);
                  },
              );
          },
      );
  }

  Widget _buildUserCard(EduUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (user.phone != null)
                        Text(
                          user.phone!,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Requested Role: ${user.requestedRole.toUpperCase()}',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (user.currentClassId != null &&
                widget.currentUserRole == EduRole.teacher) ...[
              const SizedBox(height: 8),
              Text(
                'Class: ${user.currentClassId}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (_selectedTab == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveUser(user),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _denyUser(user),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Deny'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedTab == 'approved' && user.approvedAt != null) ...[
              const SizedBox(height: 12),
              Text(
                'Approved on: ${_formatDate(user.approvedAt!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _approveUser(EduUser user) async {
    _logger.i('=== Approving User ===');
    _logger.i('User: ${user.fullName}');
    _logger.i('Email: ${user.email}');
    _logger.i('Requested Role: ${user.requestedRole}');
    
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      _logger.i('Current approver ID: $currentUserId');

      // Determine the role to assign
      EduRole roleToAssign;
      if (user.requestedRole == 'teacher') {
        roleToAssign = EduRole.teacher;
        _logger.i('Assigning role: teacher');
      } else if (user.requestedRole == 'headteacher') {
        roleToAssign = EduRole.headteacher;
        _logger.i('Assigning role: headteacher');
      } else if (user.requestedRole == 'student') {
        roleToAssign = EduRole.student;
        _logger.i('Assigning role: student');
      } else {
        _logger.e('Invalid role requested: ${user.requestedRole}');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid role requested')),
        );
        return;
      }

      _logger.i('Updating Firestore document...');
      await _firestore.collection('EducationUsers').doc(user.uid).update({
        'approvalStatus': 'approved',
        'role': roleToAssign.name,
        'approvedBy': currentUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('User approved successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} approved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _logger.e('Error approving user: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving user: $e')),
      );
    }
  }

  Future<void> _denyUser(EduUser user) async {
    _logger.i('=== Denying User ===');
    _logger.i('User: ${user.fullName}');
    _logger.i('Email: ${user.email}');
    
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      _logger.i('Current denier ID: $currentUserId');

      _logger.i('Updating Firestore document...');
      await _firestore.collection('EducationUsers').doc(user.uid).update({
        'approvalStatus': 'denied',
        'approvedBy': currentUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      _logger.i('User denied successfully');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} denied'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _logger.e('Error denying user: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error denying user: $e')),
      );
    }
  }
}