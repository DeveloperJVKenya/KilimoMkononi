import 'package:flutter/material.dart';

class LessonListScreen extends StatefulWidget {
  const LessonListScreen({super.key});

  @override
  State<LessonListScreen> createState() => _LessonListScreenState();
}

class _LessonListScreenState extends State<LessonListScreen> {
  final List<Map<String, dynamic>> _lessons = [
    {
      'title': 'Soil Health 101',
      'date': 'Oct 28, 2025',
      'teacher': 'Mr. Ochieng',
      'status': 'Active',
      'icon': Icons.spa,
      'color': Colors.brown,
    },
    {
      'title': 'Pest Management',
      'date': 'Oct 25, 2025',
      'teacher': 'Ms. Achieng',
      'status': 'Completed',
      'icon': Icons.bug_report,
      'color': Colors.red,
    },
    {
      'title': 'Crop Rotation Strategies',
      'date': 'Oct 22, 2025',
      'teacher': 'Mr. Ochieng',
      'status': 'Upcoming',
      'icon': Icons.sync,
      'color': Colors.blue,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Lessons'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _lessons.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final lesson = _lessons[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: lesson['color'].withValues(alpha: 0.15),
                child: Icon(lesson['icon'], color: lesson['color']),
              ),
              title: Text(
                lesson['title'],
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${lesson['teacher']} • ${lesson['date']}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lesson['status'] == 'Active'
                      ? Colors.green
                      : lesson['status'] == 'Completed'
                          ? Colors.grey
                          : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lesson['status'],
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening: ${lesson['title']}')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}