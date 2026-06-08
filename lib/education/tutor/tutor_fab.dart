// lib/education/tutor/tutor_fab.dart
//
// Persistent "Ask Shamba AI" floating button used on EducationHomeScreen.

import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/tutor/tutor_chat_screen.dart';

const Color _appGreen = Color(0xFF003900);

class TutorFab extends StatefulWidget {
  final String topic;
  final String grade;
  final String classId;
  final bool isPrimary;

  const TutorFab({
    super.key,
    required this.topic,
    required this.grade,
    required this.classId,
    this.isPrimary = false,
  });

  @override
  State<TutorFab> createState() => _TutorFabState();
}

class _TutorFabState extends State<TutorFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    // Auto-collapse after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  void _openTutor() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TutorChatScreen(
          topic:     widget.topic.isNotEmpty ? widget.topic : 'Agricultural Science',
          grade:     widget.grade,
          classId:   widget.classId,
          isPrimary: widget.isPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _expanded
          ? FloatingActionButton.extended(
              key: const ValueKey('expanded'),
              heroTag: 'tutor_fab',                    // ← FIXED: Unique hero tag
              onPressed: _openTutor,
              backgroundColor: _appGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.psychology_outlined),
              label: const Text(
                'Ask Shamba AI',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : FloatingActionButton(
              key: const ValueKey('collapsed'),
              heroTag: 'tutor_fab',                    // ← FIXED: Same unique hero tag
              onPressed: () {
                setState(() => _expanded = true);
                // Collapse again after 3 seconds
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _expanded = false);
                });
              },
              backgroundColor: _appGreen,
              foregroundColor: Colors.white,
              tooltip: 'Ask Shamba AI',
              child: const Icon(Icons.psychology_outlined),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Reusable Ask Tutor Button (used inside quizzes & simulations)
// ═══════════════════════════════════════════════════════════════════════════

class AskTutorButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const AskTutorButton({
    super.key,
    required this.onTap,
    this.label = 'I still don\'t understand — ask Shamba AI',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.psychology_outlined, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _appGreen,
          side: const BorderSide(color: _appGreen),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}