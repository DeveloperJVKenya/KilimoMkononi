// lib/education/farm_management/tabs/learning_tab.dart
//
// ════════════════════════════════════════════════════════════════════════════
//  FIX #3 — QUIZ CARD TOO BIG / PAGE OVER-SCROLLABLE
// ════════════════════════════════════════════════════════════════════════════
//
//  Root cause:
//  The previous version wrapped FarmQuizScreen as an inline child of
//  _LearningCard.  FarmQuizScreen is a full Scaffold with its own scrollable
//  list, so it expanded to its full intrinsic height inside the card,
//  making the Learning tab a very long scrollable page — poor UX.
//
//  Fix:
//  The Learning tab is now a FIXED-HEIGHT page (no scrolling needed).
//  Instead of embedding FarmQuizScreen inside a card, we show a compact
//  action card with a single "Open Quizzes →" button that navigates to
//  FarmQuizScreen as a full-screen push route.  The simulation card is
//  treated the same way.
//
//  Layout:
//  • Role header strip (green band at top).
//  • For STUDENTS: "Practice Quizzes" action card + "Farm Simulation" card.
//  • For TEACHERS:  "Create & Manage Quizzes" card + "Farm Simulation" card.
//  • Cards are compact (fixed height ~140 dp) — the page fits without scroll.
//  • On larger screens (tablet/desktop) cards are shown in a 2-column grid.
// ════════════════════════════════════════════════════════════════════════════

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import '../farm_quiz.dart';
import '../simulations/farm_financial_management_simulation.dart';

// ── Design tokens ─────────────────────────────────────────────────────────
const Color _kDark   = Color(0xFF003900);
const Color _kGreen  = Color(0xFF1B5E20);
const Color _kGreenS = Color(0xFFE8F5E9);
const Color _kAmber  = Color(0xFFE65100);
const Color _kAmberS = Color(0xFFFFF8E1);
const Color _kBlue   = Color(0xFF1565C0);
const Color _kBlueS  = Color(0xFFE3F2FD);

class LearningTab extends StatefulWidget {
  final EduRole role;
  final String  classId;
  final String  schoolName;

  const LearningTab({
    super.key,
    required this.role,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<LearningTab> createState() => _LearningTabState();
}

class _LearningTabState extends State<LearningTab> {

  bool get _isTeacher => widget.role == EduRole.teacher;

  // ── Navigation helpers ──────────────────────────────────────────────────

  void _openQuizzes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmQuizScreen(
          role:       widget.role,
          schoolName: widget.schoolName,
          classId:    widget.classId,
        ),
      ),
    );
  }

  void _launchSimulation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FarmFinancialManagementSimulation(
          classId:     widget.classId,
          module:      'farm_management',
          studentName: 'Student',
          onComplete: () {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:         Text('Farm simulation completed! 🎉'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isTwoCol = screenW >= 600; // tablet / desktop → 2-column grid

    return Column(
      children: [
        // ── Role header ────────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: _kDark,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(children: [
            const Icon(Icons.school, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              _isTeacher ? 'Learning Hub — Teacher' : 'Learning Hub — Student',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ]),
        ),

        // ── Cards ──────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isTwoCol
                // Tablet / desktop: 2-column grid
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _quizCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _simulationCard()),
                    ],
                  )
                // Mobile: stacked
                : Column(children: [
                    _quizCard(),
                    const SizedBox(height: 16),
                    _simulationCard(),
                  ]),
          ),
        ),
      ],
    );
  }

  // ── Quiz action card ────────────────────────────────────────────────────

  Widget _quizCard() {
    final isTeacher = _isTeacher;
    return _ActionCard(
      emoji:    isTeacher ? '🛠️' : '📝',
      surface:  _kGreenS,
      accent:   _kGreen,
      title:    isTeacher ? 'Create & Manage Quizzes' : 'Practice Quizzes',
      subtitle: isTeacher
          ? 'Use AI to build quizzes, review essay submissions, and preview existing quizzes for your class.'
          : 'Test your knowledge of farm financial management, budgeting and agricultural economics.',
      chips: isTeacher
          ? const [
              _InfoChip(label: 'AI Builder',       icon: Icons.auto_awesome),
              _InfoChip(label: 'Essay Review',      icon: Icons.rate_review_outlined),
              _InfoChip(label: 'Quiz Preview',      icon: Icons.preview_outlined),
            ]
          : const [
              _InfoChip(label: 'Multiple Choice',   icon: Icons.check_circle_outline),
              _InfoChip(label: 'Essay Questions',   icon: Icons.edit_note),
              _InfoChip(label: 'Instant Feedback',  icon: Icons.feedback_outlined),
            ],
      buttonLabel: isTeacher ? 'Manage Quizzes →' : 'Open Quizzes →',
      buttonColor: _kGreen,
      onTap: _openQuizzes,
    );
  }

  // ── Simulation action card ──────────────────────────────────────────────

  Widget _simulationCard() {
    final isTeacher = _isTeacher;
    return _ActionCard(
      emoji:    '🚜',
      surface:  _kAmberS,
      accent:   _kAmber,
      title:    'Farm Financial Simulation',
      subtitle: isTeacher
          ? 'Demo the simulation live in class. Shows tractor hire vs manual labour, fertiliser choices, forward contracts and more.'
          : 'Step into a Kenyan farmer\'s shoes. Make monthly decisions about costs and sales, and watch your profit or loss change.',
      chips: const [
        _InfoChip(label: '5 seasons',          icon: Icons.calendar_month),
        _InfoChip(label: 'Real KES values',    icon: Icons.payments_outlined),
        _InfoChip(label: 'P/L tracker',        icon: Icons.analytics_outlined),
      ],
      buttonLabel: isTeacher ? 'Launch Demo →' : 'Start Simulation →',
      buttonColor: _kDark,
      onTap: _launchSimulation,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPACT ACTION CARD  — fixed-height, no inner scroll
// ═══════════════════════════════════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  final String         emoji;
  final Color          surface;
  final Color          accent;
  final String         title;
  final String         subtitle;
  final List<_InfoChip> chips;
  final String         buttonLabel;
  final Color          buttonColor;
  final VoidCallback   onTap;

  const _ActionCard({
    required this.emoji,
    required this.surface,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Coloured header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                    child: Text(emoji,
                        style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            height: 1.4),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ]),
          ),

          // ── Info chips ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Wrap(spacing: 8, runSpacing: 6, children: chips),
          ),

          // ── CTA button ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(buttonLabel,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  INFO CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _InfoChip extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: _kBlueS,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kBlue.withOpacity(0.2)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _kBlue),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: _kBlue, fontWeight: FontWeight.w600)),
    ]),
  );
}