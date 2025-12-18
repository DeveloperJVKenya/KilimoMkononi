/*// lib/education/student/ask_teacher.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/education/utils/education_utils.dart'; // ← NEW

class AskTeacherScreen extends StatefulWidget {
  const AskTeacherScreen({super.key});

  @override
  State<AskTeacherScreen> createState() => _AskTeacherScreenState();
}

class _AskTeacherScreenState extends State<AskTeacherScreen> {
  final _controller = TextEditingController();
  bool _isSending = false;

  Future<void> _sendQuestion() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('EducationUsers')
        .doc(user.uid)
        .get();

    final fullName = userDoc['fullName'] ?? 'Student';
    final classId = userDoc['currentClassId'] as String?;
    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No class selected")),
      );
      return;
    }

    final (schoolId, gradeId, _) = parseClassIdAndModule(classId, 'farming');

    setState(() => _isSending = true);

    try {
      await FirebaseFirestore.instance
          .collection('schools')
          .doc(schoolId)
          .collection('grades')
          .doc(gradeId)
          .collection('questions')
          .add({
        'question': text,
        'studentName': fullName,
        'studentId': user.uid,
        'classId': classId,
        'createdAt': FieldValue.serverTimestamp(),
        'answered': false,
      });

      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Question sent to teacher!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e")),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ask Teacher"),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: "Type your question here...",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendQuestion,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSending
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text("Send Question", style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Your question will appear in the class feed.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}*/