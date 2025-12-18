/*// lib/education/student/my_grades.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/education/utils/education_utils.dart'; // ← NEW

class MyGradesScreen extends StatelessWidget {
  const MyGradesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Grades"),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('EducationUsers').doc(user.uid).get(),
        builder: (ctx, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = userSnap.data!.data() as Map<String, dynamic>;
          final classId = data['currentClassId'] as String?;
          final fullName = data['fullName'] ?? 'Student';
          final schoolName = data['schoolName'] ?? 'Unknown';

          if (classId == null) {
            return const Center(child: Text("No class assigned yet"));
          }

          final (schoolId, gradeId, _) = parseClassIdAndModule(classId, 'farming');

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.teal.shade100,
                      child: Text(fullName[0].toUpperCase()),
                    ),
                    title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("$schoolName • ${classId.replaceAll('_', ' ')}"),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Your Grades", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('submissions')
                      .where('studentId', isEqualTo: user.uid)
                      .where('gradeId', isEqualTo: classId)
                      .orderBy('submittedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text("No grades yet.\nComplete quizzes & simulations!", textAlign: TextAlign.center),
                      );
                    }

                    final subs = snapshot.data!.docs;
                    final Map<String, List<DocumentSnapshot>> grouped = {};

                    for (final doc in subs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final module = data['module'] ?? 'Unknown';
                      grouped.putIfAbsent(module, () => []).add(doc);
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: grouped.entries.map((entry) {
                        final module = entry.key;
                        final items = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                module,
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 16),
                              ),
                            ),
                            ...items.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final title = data['contentTitle'] ?? 'Untitled';
                              final type = data['type'] ?? '';
                              final score = data['score'] as int?;
                              final max = data['maxScore'] as int? ?? 100;

                              final percent = score != null ? (score / max * 100).round() : 0;
                              final color = percent >= 80
                                  ? Colors.green
                                  : percent >= 60
                                      ? Colors.orange
                                      : Colors.red;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Icon(type == 'quiz' ? Icons.quiz : Icons.science, color: color),
                                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(type.capitalize()),
                                  trailing: score == null
                                      ? const Chip(label: Text("Pending"), backgroundColor: Colors.grey)
                                      : Chip(
                                          label: Text("$score/$max", style: const TextStyle(color: Colors.white)),
                                          backgroundColor: color,
                                        ),
                                ),
                              );
                            }),
                            const Divider(),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension StringX on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}*/