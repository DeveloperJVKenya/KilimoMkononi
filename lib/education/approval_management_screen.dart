// lib/education/approval_management_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:logger/logger.dart';

class ApprovalManagementScreen extends StatefulWidget {
  final String schoolName;
  final EduRole currentUserRole;
  final String? classId;

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

class _ApprovalManagementScreenState
    extends State<ApprovalManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _logger = Logger(printer: PrettyPrinter());
  String _selectedTab = 'pending';

  // School code banner after mainadmin approves headteacher
  String? _justApprovedSchoolCode;
  String? _justApprovedSchoolName;

  @override
  void initState() {
    super.initState();
    _logger.i('ApprovalManagementScreen — Role: ${widget.currentUserRole.name}');
  }

  // ── Helpers ──────────────────────────────────────────────────────
  String _getTitle() {
    switch (widget.currentUserRole) {
      case EduRole.headteacher:
        return 'Teacher Approvals';
      case EduRole.mainadmin:
        return 'Headteacher Approvals';
      case EduRole.teacher:
        return 'Student Approvals';
      default:
        return 'Approvals';
    }
  }


  String _formatTier(String? tier) {
    switch (tier) {
      case 'primary':
        return 'Primary (Gr 1–6)';
      case 'junior':
        return 'Junior Secondary (Gr 7–9)';
      case 'senior':
        return 'Senior Secondary (Gr 10–12)';
      default:
        return tier ?? 'Not set';
    }
  }

    // ── Approve ───────────────────────────────────────────────────────
  Future<void> _approveUser(EduUser user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      EduRole roleToAssign;
      switch (user.requestedRole) {
        case 'teacher':
          roleToAssign = EduRole.teacher;
          break;
        case 'headteacher':
          roleToAssign = EduRole.headteacher;
          break;
        case 'student':
          roleToAssign = EduRole.student;
          break;
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid role requested')),
          );
          return;
      }

      await _firestore.collection('EducationUsers').doc(user.uid).update({
        'approvalStatus': 'approved',
        'role': roleToAssign.name,
        'approvedBy': currentUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} approved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Show school code banner for headteachers
      if (roleToAssign == EduRole.headteacher) {
        final htDoc = await _firestore
            .collection('EducationUsers')
            .doc(user.uid)
            .get();
        final code = htDoc.data()?['schoolCode'] as String?;
        if (code != null && mounted) {
          setState(() {
            _justApprovedSchoolCode = code;
            _justApprovedSchoolName = user.schoolName;
          });
        }
      }
    } catch (e) {
      _logger.e('Error approving user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e')),
        );
      }
    }
  }
  // ── Delete user account ──────────────────────────────────────────
  // Called by: mainadmin deletes headteacher, headteacher deletes teacher,
  //            teacher deletes student
  Future<void> _deleteUser(EduUser user) async {
    // Confirm dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade600),
          const SizedBox(width: 10),
          const Expanded(child: Text('Delete Account')),
        ]),
        content: Text(
          'Are you sure you want to permanently remove '
          '${user.fullName} from your school?\n\n'
          'This cannot be undone.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Delete from Firestore — the user's own document
      await _firestore.collection('EducationUsers').doc(user.uid).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\${user.fullName} has been removed.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      _logger.e('Error deleting user: \$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e')),
        );
      }
    }
  }

  // ── Deny ──────────────────────────────────────────────────────────
  Future<void> _denyUser(EduUser user) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      await _firestore.collection('EducationUsers').doc(user.uid).update({
        'approvalStatus': 'denied',
        'approvedBy': currentUserId,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.fullName} denied'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      _logger.e('Error denying user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────
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
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── School code success banner (mainadmin only) ────────────
          if (_justApprovedSchoolCode != null)
            _buildSchoolCodeBanner(),

          _buildTabBar(),
          Expanded(child: _buildUserList()),
        ],
      ),
    );
  }

  // ── School code banner ────────────────────────────────────────────
  Widget _buildSchoolCodeBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_justApprovedSchoolName ?? "School"} has been approved!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: Colors.green.shade700),
                onPressed: () => setState(() {
                  _justApprovedSchoolCode = null;
                  _justApprovedSchoolName = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Their school code is:',
            style: TextStyle(color: Colors.green.shade700, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF003900),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _justApprovedSchoolCode!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: _justApprovedSchoolCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('School code copied!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copy'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share this with the headteacher so teachers & students can join.',
            style:
                TextStyle(color: Colors.green.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────
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
        onTap: () => setState(() => _selectedTab = value),
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
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  // ── User list ─────────────────────────────────────────────────────
  Widget _buildUserList() {
    Query query;

    if (widget.currentUserRole == EduRole.mainadmin) {
      query = _firestore.collection('EducationUsers');
    } else {
      query = _firestore
          .collection('EducationUsers')
          .where('schoolName', isEqualTo: widget.schoolName);
    }

    query = query.where('approvalStatus', isEqualTo: _selectedTab);

    // Role filter
    if (widget.currentUserRole == EduRole.mainadmin) {
      query = query.where('requestedRole', isEqualTo: 'headteacher');
    } else if (widget.currentUserRole == EduRole.headteacher) {
      query = query.where('requestedRole', isEqualTo: 'teacher');
    } else if (widget.currentUserRole == EduRole.teacher) {
      query = query.where('requestedRole', isEqualTo: 'student');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  'No $_selectedTab requests',
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final users = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return EduUser.fromMap(data, doc.id);
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (_, i) => _buildUserCard(users[i]),
        );
      },
    );
  }

  // ── User card ─────────────────────────────────────────────────────
  Widget _buildUserCard(EduUser user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name row
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.teal.shade100,
                  child: Text(
                    user.fullName.isNotEmpty
                        ? user.fullName[0].toUpperCase()
                        : 'U',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(user.email,
                          style: TextStyle(color: Colors.grey.shade600)),
                      if (user.phone != null)
                        Text(user.phone!,
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Role badge
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _badge(
                  label: 'Role: ${user.requestedRole.toUpperCase()}',
                  bgColor: Colors.blue.shade50,
                  textColor: Colors.blue.shade700,
                ),
                if (user.schoolName.isNotEmpty)
                  _badge(
                    label: user.schoolName,
                    bgColor: Colors.grey.shade100,
                    textColor: Colors.grey.shade700,
                    icon: Icons.account_balance,
                  ),
                // Show tier for headteachers
                if (user.requestedRole == 'headteacher')
                  FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('EducationUsers')
                        .doc(user.uid)
                        .get(),
                    builder: (_, snap) {
                      if (!snap.hasData) return const SizedBox.shrink();
                      final tier =
                          snap.data?.get('educationTier') as String?;
                      if (tier == null) return const SizedBox.shrink();
                      return _badge(
                        label: _formatTier(tier),
                        bgColor: Colors.orange.shade50,
                        textColor: Colors.orange.shade700,
                        icon: Icons.school,
                      );
                    },
                  ),
              ],
            ),

            if (user.currentClassId != null &&
                widget.currentUserRole == EduRole.teacher) ...[
              const SizedBox(height: 8),
              Text('Class: ${user.currentClassId}',
                  style: TextStyle(color: Colors.grey.shade700)),
            ],

            // Approve / Deny buttons
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (_selectedTab == 'approved' &&
                user.approvedAt != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Approved on: \${_formatDate(user.approvedAt!)}',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                  // Delete button — always available on approved tab
                  TextButton.icon(
                    onPressed: () => _deleteUser(user),
                    icon: const Icon(Icons.person_remove, size: 16),
                    label: const Text('Remove'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              // Show school code for approved headteachers (mainadmin view)
              if (widget.currentUserRole == EduRole.mainadmin &&
                  user.requestedRole == 'headteacher')
                FutureBuilder<DocumentSnapshot>(
                  future: _firestore
                      .collection('EducationUsers')
                      .doc(user.uid)
                      .get(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const SizedBox.shrink();
                    final code =
                        snap.data?.get('schoolCode') as String?;
                    if (code == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.vpn_key,
                              size: 16, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Text(
                            'Code: $code',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: code));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('School code copied!')),
                              );
                            },
                            child: Icon(Icons.copy,
                                size: 16,
                                color: Colors.teal.shade600),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge({
    required String label,
    required Color bgColor,
    required Color textColor,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ],
      ),
    );
  }
}