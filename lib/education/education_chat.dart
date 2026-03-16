// lib/education/education_chat.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kilimomkononi/models/education_user.dart';

class EducationChat extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final String userName;

  const EducationChat({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    required this.userName,
  });

  @override
  State<EducationChat> createState() => _EducationChatState();
}

class _EducationChatState extends State<EducationChat> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _userId;
  String _selectedConversation = '';
  bool _isTyping = false;
  
  // Direct Messages state
  String? _selectedDMUserId;
  String? _selectedDMUserName;
  final TextEditingController _dmMessageController = TextEditingController();
  final ScrollController _dmScrollController = ScrollController();
  bool _isDMTyping = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _selectedConversation = 'class_${widget.classId}';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _dmMessageController.dispose();
    _dmScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.of(context).size.width < 600 ? _buildMobileLayout() : _buildDesktopLayout();
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.groups), text: 'Class Chat'),
            Tab(icon: Icon(Icons.message), text: 'Direct Messages'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildClassChatView(),
          _buildDirectMessagesView(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Education Chat'),
        backgroundColor: const Color(0xFF003900),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, spreadRadius: 2)],
            ),
            child: Column(
              children: [
                _buildConversationItem(
                  icon: Icons.groups,
                  title: 'Class Chat',
                  subtitle: 'Group conversation',
                  isSelected: _selectedConversation.startsWith('class'),
                  onTap: () => setState(() {
                    _selectedConversation = 'class_${widget.classId}';
                    _tabController.index = 0;
                  }),
                ),
                _buildConversationItem(
                  icon: Icons.message,
                  title: 'Direct Messages',
                  subtitle: 'Private chats',
                  isSelected: _selectedConversation == 'direct',
                  onTap: () => setState(() {
                    _selectedConversation = 'direct';
                    _tabController.index = 1;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedConversation == 'direct' 
                ? _buildDirectMessagesView() 
                : _buildClassChatView(),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected ? const Color(0xFF003900).withOpacity(0.1) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: isSelected ? const Color(0xFF003900) : Colors.grey[300],
                child: Icon(icon, color: isSelected ? Colors.white : Colors.grey[700], size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDirectMessages() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.message_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No direct messages yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildClassChatView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFF003900),
                child: Icon(Icons.groups, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Class Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    FutureBuilder<int>(
                      future: _getTotalMemberCount(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        return Text('${snapshot.data} members', 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]));
                      },
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.info_outline), onPressed: _showChatInfo),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('ClassChats')
                .doc(widget.classId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyChat();

              final messages = snapshot.data!.docs;
              return ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMe = message['userId'] == _userId;
                  return _buildMessageBubble(message, isMe);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message, bool isMe) {
    final senderName = message['senderName'] ?? 'Unknown';
    final senderRole = message['senderRole'] ?? '';
    final messageText = message['message'] ?? '';
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 8),
                child: Text('$senderName ${senderRole.isNotEmpty ? "($senderRole)" : ""}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF003900) : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(messageText, 
                style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
              child: Text(_formatTime(timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No messages yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Start the conversation!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.attach_file), onPressed: _attachFile, 
            color: const Color(0xFF003900)),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              maxLines: null,
              onChanged: (value) => setState(() => _isTyping = value.isNotEmpty),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: const Color(0xFF003900),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _isTyping ? _sendMessage : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectMessagesView() {
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    if (isMobile) {
      // Mobile: Show list OR conversation
      if (_selectedDMUserId != null) {
        return _buildDMConversation();
      }
      return _buildDMList();
    } else {
      // Tablet/Desktop: Side-by-side
      return Row(
        children: [
          SizedBox(width: 320, child: _buildDMList()),
          const VerticalDivider(width: 1),
          Expanded(
            child: _selectedDMUserId == null
                ? _buildDMEmptyState()
                : _buildDMConversation(),
          ),
        ],
      );
    }
  }
  
  Widget _buildDMEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.message_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Select a conversation', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Choose a person to start chatting', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
  
  Widget _buildDMList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              const Text('Direct Messages', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (widget.role == EduRole.teacher)
                ElevatedButton.icon(
                  onPressed: _showStudentSelector,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003900),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _getAllClassMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyDirectMessages();
              }
              
              final members = snapshot.data!.where((doc) => doc.id != _userId).toList();
              if (members.isEmpty) return _buildEmptyDirectMessages();
              
              return ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index].data() as Map<String, dynamic>;
                  final memberId = members[index].id;
                  final name = member['fullName'] ?? 'Unknown';
                  final role = member['role'] ?? '';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      role.isNotEmpty ? '${role[0].toUpperCase()}${role.substring(1)}' : '', 
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () {
                      setState(() {
                        _selectedDMUserId = memberId;
                        _selectedDMUserName = name;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildDMConversation() {
    final conversationId = _getConversationId(_userId!, _selectedDMUserId!);
    final isMobile = MediaQuery.of(context).size.width < 900;
    
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Row(
            children: [
              if (isMobile)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _selectedDMUserId = null;
                    _selectedDMUserName = null;
                  }),
                ),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.green.shade100,
                child: Text(
                  _selectedDMUserName!.isNotEmpty ? _selectedDMUserName![0].toUpperCase() : '?',
                  style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_selectedDMUserName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('DirectMessages')
                .doc(conversationId)
                .collection('messages')
                .orderBy('timestamp', descending: true)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
              }
              if (snapshot.hasError) {
              }
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('Conv ID: $conversationId', 
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('No messages yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Start the conversation!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              final messages = snapshot.data!.docs;
              return ListView.builder(
                controller: _dmScrollController,
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMe = message['userId'] == _userId;
                  return _buildMessageBubble(message, isMe);
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, -2))],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _dmMessageController,
                    decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none),
                    maxLines: null,
                    onChanged: (value) => setState(() => _isDMTyping = value.trim().isNotEmpty),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isDMTyping ? const Color(0xFF003900) : Colors.grey[300],
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: _isDMTyping ? _sendDirectMessage : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getConversationId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
  
  void _sendDirectMessage() async {
    if (_dmMessageController.text.trim().isEmpty || _selectedDMUserId == null) return;

    final message = _dmMessageController.text.trim();
    _dmMessageController.clear();
    setState(() => _isDMTyping = false);

    final conversationId = _getConversationId(_userId!, _selectedDMUserId!);

    try {
      await FirebaseFirestore.instance
          .collection('DirectMessages')
          .doc(conversationId)
          .collection('messages')
          .add({
        'userId': _userId,
        'senderName': widget.userName,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('Conversations')
          .doc(conversationId)
          .set({
        'participants': [_userId, _selectedDMUserId],
        'participantNames': {_userId!: widget.userName, _selectedDMUserId!: _selectedDMUserName!},
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': _userId,
      }, SetOptions(merge: true));

      if (_dmScrollController.hasClients) {
        _dmScrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<List<QueryDocumentSnapshot>> _getAllClassMembers() async {
    
    // Get ONLY ACTUAL STUDENTS (must have role='student')
    final students = await FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('schoolName', isEqualTo: widget.schoolName)
        .where('currentClassId', isEqualTo: widget.classId)
        .where('role', isEqualTo: 'student')  // ← FIX: Only get actual students
        .get();
    
    for (var doc in students.docs) {
      final _ = doc.data();
    }
    
    // Get teachers who teach this class
    final teachers = await FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('schoolName', isEqualTo: widget.schoolName)
        .where('role', isEqualTo: 'teacher')
        .where('classIds', arrayContains: widget.classId)
        .get();
    
    for (var doc in teachers.docs) {
      final _ = doc.data();
    }
    
    // Combine both lists (no deduplication needed now since roles are exclusive)
    final allMembers = [...students.docs, ...teachers.docs];
    
    return allMembers;
  }
  
  // Get total member count (students + teachers)
  Future<int> _getTotalMemberCount() async {
    final students = await FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('schoolName', isEqualTo: widget.schoolName)
        .where('currentClassId', isEqualTo: widget.classId)
        .where('role', isEqualTo: 'student')  // ← FIX: Only count actual students
        .get();
    
    final teachers = await FirebaseFirestore.instance
        .collection('EducationUsers')
        .where('schoolName', isEqualTo: widget.schoolName)
        .where('role', isEqualTo: 'teacher')
        .where('classIds', arrayContains: widget.classId)
        .get();
    
    return students.docs.length + teachers.docs.length;
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final message = _messageController.text.trim();
    _messageController.clear();
    setState(() => _isTyping = false);

    try {
      await FirebaseFirestore.instance
          .collection('ClassChats')
          .doc(widget.classId)
          .collection('messages')
          .add({
        'userId': _userId,
        'senderName': widget.userName,
        'senderRole': widget.role.name,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'text',
        'isEdited': false,
      });

      await FirebaseFirestore.instance.collection('ClassChats').doc(widget.classId).set({
        'schoolName': widget.schoolName,
        'className': 'Grade ${widget.classId}',
        'lastMessage': message,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageBy': widget.userName,
      }, SetOptions(merge: true));

      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  void _attachFile() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File attachment coming soon!')));
  }

  void _showChatInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Class Chat Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('School: ${widget.schoolName}'),
            Text('Class: ${_formatGradeDisplay(widget.classId)}'),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: _getTotalMemberCount(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Loading members...');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Members: ${snapshot.data}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('(Students + Teachers)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays == 0) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
  
  String _formatGradeDisplay(String classId) {
    // Format: "Kianda_School_junior_7" -> "Junior 7"
    final parts = classId.split('_');
    if (parts.length >= 3) {
      final system = parts[parts.length - 2]; // e.g., "junior"
      final gradeNum = parts.last; // e.g., "7"
      
      // Capitalize system name
      final systemName = system.isNotEmpty 
          ? '${system[0].toUpperCase()}${system.substring(1)}' 
          : system;
      
      return '$systemName $gradeNum'; // e.g., "Junior 7"
    }
    return classId; // Fallback to original if format doesn't match
  }
  
  void _showStudentSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Student'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _getAllClassMembers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No students in this class'));
              }
              
              final students = snapshot.data!
                  .where((doc) => doc.id != _userId)
                  .where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['role'] == 'student';
                  })
                  .toList();
              
              if (students.isEmpty) {
                return const Center(child: Text('No students in this class'));
              }
              
              return ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index].data() as Map<String, dynamic>;
                  final studentId = students[index].id;
                  final name = student['fullName'] ?? 'Unknown';
                  final email = student['email'] ?? '';
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.green.shade100,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Text(email),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedDMUserId = studentId;
                        _selectedDMUserName = name;
                      });
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
} 