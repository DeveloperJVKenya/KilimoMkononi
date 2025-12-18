// lib/education/teacher/view_students.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewStudentsScreen extends StatefulWidget {
  final String schoolName;
  final ValueNotifier<String?> classIdNotifier;
  final VoidCallback? onClose; // ← Added

  const ViewStudentsScreen({
    super.key,
    required this.schoolName,
    required this.classIdNotifier,
    this.onClose,
  });

  @override
  State<ViewStudentsScreen> createState() => _ViewStudentsScreenState();
}

class _ViewStudentsScreenState extends State<ViewStudentsScreen> {
  Stream<QuerySnapshot>? _stream;

  String _formatGradeDisplay(String? classId) {
    if (classId == null || classId.isEmpty) return 'Select Class';
    if (classId.contains('|')) {
      final parts = classId.split('|');
      final shortId = parts[0];
      final systemName = parts.length > 1 ? parts[1] : 'cbcJunior';

      final systemGrades = {
        'cbcPrimary': ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
        'cbcJunior': ['Grade 7', 'Grade 8', 'Grade 9'],
        'cbcSenior': ['Grade 10', 'Grade 11', 'Grade 12'],
        'eightFourFour': [
          'Standard 1', 'Standard 2', 'Standard 3', 'Standard 4',
          'Standard 5', 'Standard 6', 'Standard 7', 'Standard 8',
          'Form 1', 'Form 2', 'Form 3', 'Form 4',
        ],
      };

      final grades = systemGrades[systemName] ?? systemGrades['cbcJunior']!;
      final gradeText = grades.firstWhere((g) => g.split(' ').last == shortId, orElse: () => 'Grade $shortId');
      return gradeText;
    }

    final match = RegExp(r'_(\d+)$').firstMatch(classId);
    if (match != null) {
      final num = match.group(1);
      final prefix = classId.contains('primary') || classId.contains('junior') || classId.contains('senior')
          ? 'Grade'
          : (int.parse(num!) <= 8 ? 'Standard' : 'Form');
      return '$prefix $num';
    }
    return classId;
  }

  @override
  void initState() {
    super.initState();
    _updateStream();
    widget.classIdNotifier.addListener(_updateStream);
  }

  @override
  void dispose() {
    widget.classIdNotifier.removeListener(_updateStream);
    super.dispose();
  }

  void _updateStream() {
    final classId = widget.classIdNotifier.value;
    if (classId == null || classId.isEmpty) {
      setState(() => _stream = null);
      return;
    }

    setState(() {
      _stream = FirebaseFirestore.instance
          .collection('EducationUsers')
          .where('role', isEqualTo: 'student')
          .where('schoolName', isEqualTo: widget.schoolName)
          .where('currentClassId', isEqualTo: classId)
          .snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final niceGradeName = _formatGradeDisplay(widget.classIdNotifier.value);
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Students – $niceGradeName'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        leading: isLargeScreen
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: widget.onClose, // ← Works on tablet/desktop
              )
            : null, // Mobile: automatic back button
      ),
      body: _stream == null
          ? const Center(child: Text('Please select a class from home.'))
          : StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No students enrolled yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final name = data['fullName'] ?? 'Unknown Student';
                    final email = data['email'] ?? '';

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade100,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(email.isNotEmpty ? email : 'No email'),
                        trailing: const Icon(Icons.person_outline, color: Colors.grey),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}