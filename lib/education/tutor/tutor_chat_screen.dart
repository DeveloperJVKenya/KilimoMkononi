// lib/education/tutor/tutor_chat_screen.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/tutor/gemini_tutor_service.dart';

const Color _appGreen    = Color(0xFF003900);
const Color _lightGreen  = Color(0xFF388E3C);
const Color _mintBg      = Color(0xFFF0F7F0);

// ═══════════════════════════════════════════════════════════════════════════
//  TutorChatScreen
//  Can be launched:
//   (a) standalone — from the FAB on EducationHomeScreen
//   (b) contextually — from a quiz/simulation with a pre-loaded question
// ═══════════════════════════════════════════════════════════════════════════

class TutorChatScreen extends StatefulWidget {
  /// Short topic label, e.g. "Pest Management", "Farm Finance"
  final String topic;

  /// Grade label, e.g. "Grade 8"
  final String grade;

  final bool isPrimary;

  final String classId;

  /// If launched from a quiz/sim: the question text that was confusing
  final String? contextQuestion;

  /// If launched from a quiz/sim: 'pest_content', 'disease_content', etc.
  final String? contextModule;

  /// True when the student got the question WRONG (changes opening message)
  final bool wrongAnswer;

  const TutorChatScreen({
    super.key,
    required this.topic,
    required this.grade,
    required this.classId,
    this.isPrimary = false,
    this.contextQuestion,
    this.contextModule,
    this.wrongAnswer = false,
  });

  @override
  State<TutorChatScreen> createState() => _TutorChatScreenState();
}

class _TutorChatScreenState extends State<TutorChatScreen> {
  final _service        = const GeminiTutorService();
  final _inputCtrl      = TextEditingController();
  final _scrollCtrl     = ScrollController();
  final _focusNode      = FocusNode();

  final List<TutorMessage> _messages = [];

  bool _isLoading    = false;
  bool _isOpening    = true;  // loading the context opener on launch
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadOpener();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    _persistSession(); // save on close
    super.dispose();
  }

  // ── Opening message ───────────────────────────────────────────────────
  Future<void> _loadOpener() async {
    setState(() => _isOpening = true);

    String? opener;

    if (widget.contextQuestion != null) {
      // Context-aware opener from quiz/sim
      opener = await _service.generateContextOpener(
        questionText:  widget.contextQuestion!,
        module:        widget.contextModule ?? widget.topic,
        grade:         widget.grade,
        isPrimary:     widget.isPrimary,
        wrongAnswer:   widget.wrongAnswer,
      );
    }

    opener ??= widget.isPrimary
        ? 'Habari! Mimi ni Shamba AI, mwalimu wako wa kilimo. 🌱 Una swali gani leo? (Hello! I am Shamba AI, your farming tutor. What question do you have today?)'
        : 'Hello! I\'m Shamba AI, your agricultural tutor for ${widget.topic}. 🌿 I won\'t just give you answers — I\'ll help you think through them. What would you like to explore?';

    final openingMsg = TutorMessage(
      role:      'assistant',
      text:      opener,
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _messages.add(openingMsg);
        _isOpening = false;
      });
    }

    _scrollToBottom();
  }

  // ── Send a message ────────────────────────────────────────────────────
  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _isLoading) return;

    _inputCtrl.clear();
    _focusNode.unfocus();

    final userMsg = TutorMessage(
      role:      'user',
      text:      text,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    _scrollToBottom();

    // Pass all messages except the very last (new user msg) as history
    final history = _messages.sublist(0, _messages.length - 1);

    final reply = await _service.sendMessage(
      userMessage:      text,
      history:          history,
      topic:            widget.topic,
      grade:            widget.grade,
      isPrimary:        widget.isPrimary,
      contextQuestion:  widget.contextQuestion,
      contextModule:    widget.contextModule,
    );

    if (!mounted) return;

    final assistantMsg = TutorMessage(
      role:      'assistant',
      text:      reply ?? (widget.isPrimary
          ? 'Samahani, jaribu tena! (Sorry, try again!)'
          : 'I had a connection issue. Please try again!'),
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(assistantMsg);
      _isLoading = false;
    });

    _scrollToBottom();

    // Auto-persist after every exchange
    _persistSession();
  }

  // ── Persist to Firestore ──────────────────────────────────────────────
  Future<void> _persistSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _messages.length < 2) return;

    try {
      await FirebaseFirestore.instance
          .collection('EducationUsers')
          .doc(uid)
          .collection('tutorSessions')
          .doc(_sessionId)
          .set({
        'sessionId':       _sessionId,
        'classId':         widget.classId,
        'topic':           widget.topic,
        'grade':           widget.grade,
        'contextModule':   widget.contextModule,
        'contextQuestion': widget.contextQuestion,
        'messageCount':    _messages.length,
        'messages':        _messages.map((m) => m.toJson()).toList(),
        'startedAt':       _messages.first.timestamp.toIso8601String(),
        'lastMessageAt':   _messages.last.timestamp.toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Non-critical — don't show error to student
      debugPrint('[TutorChat] persist error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mintBg,
      appBar: AppBar(
        backgroundColor: _appGreen,
        foregroundColor: Colors.white,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Shamba AI Tutor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(widget.topic,
                    style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Shamba AI',
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Context banner (shown when launched from quiz/sim)
          if (widget.contextQuestion != null)
            _ContextBanner(
              question: widget.contextQuestion!,
              wrongAnswer: widget.wrongAnswer,
            ),

          // Messages list
          Expanded(
            child: _isOpening
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _appGreen),
                        SizedBox(height: 12),
                        Text('Shamba AI is getting ready…',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _messages.length) {
                        return const _TypingIndicator();
                      }
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
          ),

          // Input bar
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            isLoading: _isLoading,
            onSend: _send,
            isPrimary: widget.isPrimary,
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.psychology, color: _appGreen),
          SizedBox(width: 8),
          Text('About Shamba AI'),
        ]),
        content: const Text(
          'Shamba AI is your personal agricultural tutor.\n\n'
          '🌱 It will not do your work for you — instead it guides you to find answers yourself.\n\n'
          '🇰🇪 All examples use Kenyan farming context.\n\n'
          '🗣️ You can ask in English or Swahili.',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!',
                style: TextStyle(color: _appGreen)),
          ),
        ],
      ),
    );
  }
}

// ─── Context banner ───────────────────────────────────────────────────────

class _ContextBanner extends StatelessWidget {
  final String question;
  final bool wrongAnswer;

  const _ContextBanner({required this.question, required this.wrongAnswer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: wrongAnswer ? Colors.red.shade50 : Colors.blue.shade50,
      child: Row(children: [
        Icon(
          wrongAnswer ? Icons.lightbulb_outline : Icons.link,
          size: 18,
          color: wrongAnswer ? Colors.red.shade700 : Colors.blue.shade700,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            wrongAnswer
                ? 'Let\'s understand: "$question"'
                : 'Exploring: "$question"',
            style: TextStyle(
              fontSize: 12,
              color: wrongAnswer ? Colors.red.shade800 : Colors.blue.shade800,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final TutorMessage msg;

  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: _appGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isUser ? _appGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: isUser ? Colors.white : const Color(0xFF1A1A1A),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─── Typing indicator ─────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
                color: _appGreen, shape: BoxShape.circle),
            child: const Icon(Icons.psychology, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ],
            ),
            child: FadeTransition(
              opacity: _anim,
              child: Row(children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: _lightGreen,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isLoading;
  final VoidCallback onSend;
  final bool isPrimary;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isLoading,
    required this.onSend,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isPrimary
                    ? 'Uliza swali lako hapa… (Ask your question here…)'
                    : 'Ask anything about ${_shortHint()}…',
                hintStyle:
                    const TextStyle(color: Colors.grey, fontSize: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide:
                      const BorderSide(color: Color(0xFFDDE8DD)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: _appGreen, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: _mintBg,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isLoading ? Colors.grey.shade300 : _appGreen,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
              onPressed: isLoading ? null : onSend,
            ),
          ),
        ]),
      ),
    );
  }

  String _shortHint() => 'farming';
}