// lib/education/quiz/quiz_home.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:rxdart/rxdart.dart';
import 'shared_quiz_widgets.dart';

// ─── Tab selector ─────────────────────────────────────────────────────────
enum QuizHomeTab { quizzes, essays }

const Color _appGreen = Color(0xFF003900);

// ═══════════════════════════════════════════════════════════════════════════
//  QuizHome
// ═══════════════════════════════════════════════════════════════════════════

class QuizHome extends StatefulWidget {
  final String        classId;
  final String        schoolName;
  final QuizHomeTab   initialTab;
  final VoidCallback? onClose;

  const QuizHome({
    super.key,
    required this.classId,
    required this.schoolName,
    this.initialTab = QuizHomeTab.quizzes,
    this.onClose,
  });

  @override
  State<QuizHome> createState() => _QuizHomeState();
}

class _QuizHomeState extends State<QuizHome>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Module metadata ────────────────────────────────────────────────
  static const Map<String, Map<String, Object>> _moduleInfo = {
    'farming_content':         {'name': 'Farming Tips',    'icon': Icons.agriculture,            'color': Colors.green},
    'market_content':          {'name': 'Market Price',    'icon': Icons.store,                  'color': Colors.orange},
    'weather_content':         {'name': 'Weather',         'icon': Icons.cloud,                  'color': Colors.blue},
    'manuals_content':         {'name': 'Manuals',         'icon': Icons.book,                   'color': Colors.brown},
    'farm_management_content': {'name': 'Farm Management', 'icon': Icons.account_balance_wallet, 'color': Colors.purple},
    'field_content':           {'name': 'Field Data',      'icon': Icons.terrain,                'color': Color(0xFF00BFA5)},
    'pest_content':            {'name': 'Pest',            'icon': Icons.bug_report,             'color': Colors.red},
    'disease_content':         {'name': 'Disease',         'icon': Icons.local_hospital,         'color': Colors.deepOrange},
  };

  static const Map<String, String> _geminiSubjects = {
    'farming_content':         'crop farming and agriculture in Kenya',
    'market_content':          'agricultural market prices and trade in Kenya',
    'weather_content':         'weather patterns, climate and agriculture in Kenya',
    'manuals_content':         'agricultural manuals and best practices in Kenya',
    'farm_management_content': 'farm financial management and agricultural economics in Kenya',
    'field_content':           'field operations, soil preparation and crop management in Kenya',
    'pest_content':            'agricultural pest identification and integrated pest management in Kenya',
    'disease_content':         'plant disease identification, symptoms and management in Kenyan crops',
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length:       2,
      vsync:        this,
      initialIndex: widget.initialTab == QuizHomeTab.essays ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Stream: all quiz docs grouped by module ────────────────────────

  Stream<Map<String, List<_QuizDoc>>> _quizStream() {
    final collections = _moduleInfo.keys.toList();

    final streams = collections.map((coll) {
      final collection =
          FirestoreHelper.getContentFromClassId(widget.classId, coll);
      if (collection == null) {
        return Stream.value(<_QuizDoc>[]);
      }
      return collection
          .where('type', isEqualTo: 'quiz')
          .snapshots()
          .map((snap) {
            // Sort client-side — no composite index required on each content collection
            final sorted = List.of(snap.docs)
              ..sort((a, b) {
                final aT = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                final bT = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                return (bT?.millisecondsSinceEpoch ?? 0)
                    .compareTo(aT?.millisecondsSinceEpoch ?? 0);
              });
            return sorted;
          })
          .map((docs) => docs
              .map((doc) {
                final d = doc.data() as Map<String, dynamic>?;
                if (d == null) return null;

                List<dynamic> questions = [];
                try {
                  final raw = d['data'];
                  questions = raw is String
                      ? (jsonDecode(raw) as List? ?? [])
                      : (raw as List? ?? []);
                } catch (_) {}

                final mcqQs   = questions
                    .where((q) =>
                        (q as Map<String, dynamic>?)?['type'] != 'essay')
                    .toList();
                final essayQs = questions
                    .where((q) =>
                        (q as Map<String, dynamic>?)?['type'] == 'essay')
                    .toList();

                return _QuizDoc(
                  id:             doc.id,
                  title:          (d['title'] as String?)?.trim().isNotEmpty == true
                                      ? d['title'] as String
                                      : 'Untitled Quiz',
                  allQuestions:   questions,
                  mcqQuestions:   mcqQs,
                  essayQuestions: essayQs,
                  contentType:    coll,
                  createdAt:      d['createdAt'] as Timestamp?,
                );
              })
              .whereType<_QuizDoc>()
              .toList());
    });

    return CombineLatestStream.list(streams).map((listOfLists) {
      final grouped = <String, List<_QuizDoc>>{};
      for (var i = 0; i < listOfLists.length; i++) {
        grouped[collections[i]] = listOfLists[i];
      }
      return grouped;
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _gradeLabel() {
    final classId = widget.classId;
    if (classId.contains('|')) {
      final parts      = classId.split('|');
      final shortId    = parts[0];
      final systemName = parts.length > 1 ? parts[1] : 'cbcJunior';
      const systemGrades = {
        'cbcPrimary':   ['Grade 1','Grade 2','Grade 3','Grade 4','Grade 5','Grade 6'],
        'cbcJunior':    ['Grade 7','Grade 8','Grade 9'],
        'cbcSenior':    ['Grade 10','Grade 11','Grade 12'],
        'eightFourFour':['Standard 1','Standard 2','Standard 3','Standard 4',
                         'Standard 5','Standard 6','Standard 7','Standard 8',
                         'Form 1','Form 2','Form 3','Form 4'],
      };
      final grades = systemGrades[systemName] ?? systemGrades['cbcJunior']!;
      return grades.firstWhere(
          (g) => g.split(' ').last == shortId,
          orElse: () => 'Grade $shortId');
    }
    final match = RegExp(r'_(\d+)$').firstMatch(classId);
    if (match != null) {
      final n      = match.group(1)!;
      final prefix = classId.contains('primary') || classId.contains('junior') || classId.contains('senior')
          ? 'Grade'
          : int.parse(n) <= 8 ? 'Standard' : 'Form';
      return '$prefix $n';
    }
    return classId;
  }

  bool get _isPrimary {
    if (widget.classId.contains('cbcPrimary')) return true;
    final match = RegExp(r'_(\d+)$').firstMatch(widget.classId);
    return match != null && (int.tryParse(match.group(1)!) ?? 7) <= 6;
  }

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7)  return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _launchMcqQuiz(BuildContext context, _QuizDoc doc) {
    if (doc.mcqQuestions.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EduQuizScreen(
          payload: {
            'id':        doc.id,
            'title':     doc.title,
            'grade':     _gradeLabel(),
            'questions': doc.mcqQuestions,
            'module':    _moduleInfo[doc.contentType]?['name'] as String? ?? 'Unknown',
          },
          classId:       widget.classId,
          isPrimary:     _isPrimary,
          geminiSubject: _geminiSubjects[doc.contentType] ?? 'agriculture in Kenya',
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Quizzes & Essays – ${_gradeLabel()}'),
        backgroundColor: _appGreen,
        foregroundColor: Colors.white,
        leading: isLargeScreen
            ? IconButton(
                icon:    const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: widget.onClose,
              )
            : null,
        bottom: TabBar(
          controller:          _tabCtrl,
          indicatorColor:      Colors.white,
          labelColor:          Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.check_circle_outline), text: 'Quizzes'),
            Tab(icon: Icon(Icons.edit_note),            text: 'Essays'),
          ],
        ),
      ),
      body: StreamBuilder<Map<String, List<_QuizDoc>>>(
        stream: _quizStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: _appGreen));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final grouped = snapshot.data ?? {};

          return TabBarView(
            controller: _tabCtrl,
            children: [
              _buildQuizTab(context, grouped),
              _buildEssayTab(context, grouped),
            ],
          );
        },
      ),
    );
  }

  // ── MCQ tab ────────────────────────────────────────────────────────

  Widget _buildQuizTab(
      BuildContext context, Map<String, List<_QuizDoc>> grouped) {
    final entries = grouped.entries
        .where((e) => e.value.any((d) => d.mcqQuestions.isNotEmpty))
        .toList();

    if (entries.isEmpty) {
      return _emptyState(
        icon:    Icons.quiz_outlined,
        title:   'No MCQ quizzes yet',
        message: 'Your teacher hasn\'t created any multiple choice quizzes yet. Check back soon!',
        color:   Colors.blue,
      );
    }

    return ListView.builder(
      padding:   const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, idx) {
        final coll      = entries[idx].key;
        final docs      = entries[idx].value
            .where((d) => d.mcqQuestions.isNotEmpty)
            .toList();
        final info      = _moduleInfo[coll] ??
            <String, Object>{'name': coll, 'icon': Icons.help, 'color': Colors.grey};
        final modColor  = info['color'] as Color;
        final modIcon   = info['icon'] as IconData;
        final modName   = info['name'] as String;
        final totalQs   =
            docs.fold(0, (s, d) => s + d.mcqQuestions.length);

        return Card(
          margin:    const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: entries.length == 1,
            leading: CircleAvatar(
              radius:          18,
              backgroundColor: modColor.withValues(alpha: 0.12),
              child: Icon(modIcon, color: modColor, size: 18),
            ),
            title: Text(modName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${docs.length} quiz${docs.length == 1 ? '' : 'zes'} · $totalQs MCQ question${totalQs == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${docs.length}',
                  style: TextStyle(
                      color:      Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize:   13)),
            ),
            children: docs.map((doc) {
              final created = doc.createdAt?.toDate();
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 4),
                leading: CircleAvatar(
                  radius:          16,
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.play_arrow,
                      color: Colors.blue.shade700, size: 18),
                ),
                title: Text(doc.title,
                    style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Row(children: [
                  Icon(Icons.check_circle_outline,
                      size: 12, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(
                    '${doc.mcqQuestions.length} question${doc.mcqQuestions.length == 1 ? '' : 's'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (created != null) ...[
                    const SizedBox(width: 8),
                    Text('· ${_formatDate(created)}',
                        style: TextStyle(
                            fontSize: 12,
                            color:    Colors.grey.shade500)),
                  ],
                ]),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () => _launchMcqQuiz(context, doc),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ── Essay tab ──────────────────────────────────────────────────────

  Widget _buildEssayTab(
      BuildContext context, Map<String, List<_QuizDoc>> grouped) {
    final entries = grouped.entries
        .where((e) => e.value.any((d) => d.essayQuestions.isNotEmpty))
        .toList();

    if (entries.isEmpty) {
      return _emptyState(
        icon:    Icons.edit_note,
        title:   'No essay assignments yet',
        message: 'Your teacher hasn\'t set any essay assignments yet. Check back soon!',
        color:   Colors.purple,
      );
    }

    return ListView.builder(
      padding:   const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, idx) {
        final coll     = entries[idx].key;
        final docs     = entries[idx].value
            .where((d) => d.essayQuestions.isNotEmpty)
            .toList();
        final info     = _moduleInfo[coll] ??
            <String, Object>{'name': coll, 'icon': Icons.help, 'color': Colors.grey};
        final modColor = info['color'] as Color;
        final modIcon  = info['icon'] as IconData;
        final modName  = info['name'] as String;
        final totalEssays =
            docs.fold(0, (s, d) => s + d.essayQuestions.length);

        return Card(
          margin:    const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: entries.length == 1,
            leading: CircleAvatar(
              radius:          18,
              backgroundColor: modColor.withValues(alpha: 0.12),
              child: Icon(modIcon, color: modColor, size: 18),
            ),
            title: Text(modName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${docs.length} assignment${docs.length == 1 ? '' : 's'} · $totalEssays essay question${totalEssays == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.purple.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$totalEssays',
                  style: TextStyle(
                      color:      Colors.purple.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize:   13)),
            ),
            children: docs
                .map((doc) => _EssayAssignmentTile(
                      doc:           doc,
                      classId:       widget.classId,
                      gradeLabel:    _gradeLabel(),
                      isPrimary:     _isPrimary,
                      geminiSubject: _geminiSubjects[doc.contentType] ??
                          'agriculture in Kenya',
                      formatDate:    _formatDate,
                    ))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String   title,
    required String   message,
    required Color    color,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: color.withValues(alpha: 0.35)),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(message,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 14),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
//  _QuizDoc — parsed quiz Firestore document
// ═══════════════════════════════════════════════════════════════════════════

class _QuizDoc {
  final String        id;
  final String        title;
  final List<dynamic> allQuestions;
  final List<dynamic> mcqQuestions;
  final List<dynamic> essayQuestions;
  final String        contentType;
  final Timestamp?    createdAt;

  const _QuizDoc({
    required this.id,
    required this.title,
    required this.allQuestions,
    required this.mcqQuestions,
    required this.essayQuestions,
    required this.contentType,
    this.createdAt,
  });

  /// Human-readable module name matching the _moduleInfo map.
  String get moduleName {
    const names = {
      'farming_content':         'Farming Tips',
      'market_content':          'Market Price',
      'weather_content':         'Weather Forecast',
      'manuals_content':         'Manuals',
      'farm_management_content': 'Farm Management',
      'field_content':           'Field Data',
      'pest_content':            'Pest',
      'disease_content':         'Disease',
    };
    return names[contentType] ?? contentType;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _EssayAssignmentTile
//  One essay assignment row. Checks submission status from Firestore,
//  shows Submitted / Pending badge, opens EduQuizScreen for unsubmitted.
// ═══════════════════════════════════════════════════════════════════════════

class _EssayAssignmentTile extends StatelessWidget {
  final _QuizDoc                  doc;
  final String                    classId;
  final String                    gradeLabel;
  final bool                      isPrimary;
  final String                    geminiSubject;
  final String Function(DateTime) formatDate;

  const _EssayAssignmentTile({
    required this.doc,
    required this.classId,
    required this.gradeLabel,
    required this.isPrimary,
    required this.geminiSubject,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final created = doc.createdAt?.toDate();
    final userId  = FirebaseAuth.instance.currentUser?.uid;
    final subsColl = FirestoreHelper.getSubmissionsFromClassId(classId);

    return FutureBuilder<bool>(
      // Check whether this student has already submitted this assignment
      future: subsColl == null || userId == null
          ? Future.value(false)
          : subsColl
              .where('quizId', isEqualTo: doc.id)
              .where('userId', isEqualTo: userId)
              .limit(1)
              .get()
              .then((s) => s.docs.isNotEmpty),
      builder: (context, snap) {
        final hasSubmitted = snap.data ?? false;

        return ListTile(
          contentPadding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
          leading: CircleAvatar(
            radius:          16,
            backgroundColor: hasSubmitted
                ? Colors.green.shade50
                : Colors.purple.shade50,
            child: Icon(
              hasSubmitted ? Icons.check_circle : Icons.edit_note,
              color: hasSubmitted
                  ? Colors.green.shade700
                  : Colors.purple.shade700,
              size: 18,
            ),
          ),
          title: Text(doc.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 2,
            children: [
              // Question count
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.edit_note,
                    size: 12, color: Colors.purple.shade400),
                const SizedBox(width: 3),
                Text(
                  '${doc.essayQuestions.length} question${doc.essayQuestions.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ]),
              if (created != null)
                Text('· ${formatDate(created)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:        hasSubmitted
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: hasSubmitted
                          ? Colors.green.shade200
                          : Colors.orange.shade200),
                ),
                child: Text(
                  hasSubmitted ? 'Submitted' : 'Pending',
                  style: TextStyle(
                      color: hasSubmitted
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                      fontSize:   10,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: hasSubmitted
                ? Colors.green.shade300
                : Colors.purple.shade400,
          ),
          onTap: hasSubmitted
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'You\'ve already submitted this essay. '
                        'Your teacher will review and mark it.',
                      ),
                      backgroundColor: Colors.green.shade700,
                      behavior:    SnackBarBehavior.floating,
                      duration:    const Duration(seconds: 3),
                    ),
                  )
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EduQuizScreen(
                        payload: {
                          'id':        doc.id,
                          'title':     doc.title,
                          'grade':     gradeLabel,
                          'questions': doc.essayQuestions,
                          'module':    doc.moduleName,
                        },
                        classId:       classId,
                        isPrimary:     isPrimary,
                        geminiSubject: geminiSubject,
                      ),
                    ),
                  ),
        );
      },
    );
  }
}