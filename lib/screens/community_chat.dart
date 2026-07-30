import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'dart:io';

class CommunityChatScreen extends StatefulWidget {
  final String channelId; // e.g., "Kajiado_Kaputiei-North_Kitengela_Pests_Diseases"
  const CommunityChatScreen({super.key, required this.channelId});

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final Logger _logger = Logger(printer: PrettyPrinter());
  String? _userName;

  @override
  void initState() {
    super.initState();
    _logger.i('Initializing CommunityChatScreen for channel: ${widget.channelId}');
    _fetchUserName();
    _postWelcomeMessage();
  }

  Future<void> _fetchUserName() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userDoc = await _firestore.collection('Users').doc(user.uid).get();
      setState(() {
        _userName = userDoc['fullName'] ?? 'Anonymous';
        _logger.i('Fetched username: $_userName');
      });
    } else {
      _logger.w('No user logged in');
    }
  }

  Future<void> _postWelcomeMessage() async {
    final parts = widget.channelId.split('_');
    if (parts.length < 3) {
      _logger.w('Invalid channel ID: ${widget.channelId}');
      return;
    }
    final county = parts[0];
    final constituency = parts[1];
    final ward = parts[2];

    // Check for existing messages to avoid duplicates
    final existingMessages = await _firestore
        .collection('Chats')
        .doc(widget.channelId)
        .collection('Messages')
        .limit(1)
        .get();

    if (existingMessages.docs.isNotEmpty) {
      _logger.i('Channel ${widget.channelId} already has messages, skipping welcome');
      return;
    }

    // Fetch latest pest alert
    final alertSnapshot = await _firestore
        .collection('PestAlerts')
        .where('county', isEqualTo: county)
        .where('constituency', isEqualTo: constituency)
        .where('ward', isEqualTo: ward)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    String welcomeText = 'Welcome to the ${widget.channelId.split('_').last} chat for $ward!';
    if (alertSnapshot.docs.isNotEmpty) {
      final alert = alertSnapshot.docs.first.data();
      welcomeText += '\nLatest Alert: ${alert['pestName']} - ${alert['description']}';
    } else {
      welcomeText += '\nNo recent alerts for your area. Start the conversation!';
    }

    // Create collection by posting welcome message
    try {
      await _firestore.collection('Chats').doc(widget.channelId).set({'createdAt': FieldValue.serverTimestamp()});
      await _firestore.collection('Chats').doc(widget.channelId).collection('Messages').add({
        'text': welcomeText,
        'senderId': 'bot',
        'senderName': 'KilimoBot',
        'timestamp': FieldValue.serverTimestamp(),
      });
      _logger.i('Posted welcome message for ${widget.channelId}');
    } catch (e) {
      _logger.e('Error posting welcome message: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send messages')),
      );
      _logger.w('Send message attempted while not logged in');
      return;
    }

    try {
      await _firestore.collection('Chats').doc(widget.channelId).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _firestore.collection('Chats').doc(widget.channelId).collection('Messages').add({
        'text': _messageController.text.trim(),
        'senderId': user.uid,
        'senderName': _userName,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _messageController.clear();
      _logger.i('Message sent by $_userName in ${widget.channelId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
      _logger.e('Error sending message: $e');
    }
  }

  Future<void> _sendImage() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to send images')),
      );
      _logger.w('Image upload attempted while not logged in');
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile == null) {
      _logger.i('No image selected');
      return;
    }

    try {
      final file = File(pickedFile.path);
      final storageRef = _storage.ref().child('chat_images/${widget.channelId}/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await storageRef.putFile(file);
      final imageUrl = await storageRef.getDownloadURL();

      await _firestore.collection('Chats').doc(widget.channelId).set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      await _firestore.collection('Chats').doc(widget.channelId).collection('Messages').add({
        'text': 'Shared an image',
        'senderId': user.uid,
        'senderName': _userName,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      _logger.i('Image uploaded by $_userName in ${widget.channelId}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      _logger.e('Error uploading image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _logger.i('Building CommunityChatScreen for ${widget.channelId}');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.channelId.split('_').sublist(0, 3).join(', ').replaceAll('_', ' '),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        iconTheme: const IconThemeData(
          color: Colors.white,
          size: 24,
        ),
        elevation: 4,
        shadowColor: Colors.black54,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('Chats')
                  .doc(widget.channelId)
                  .collection('Messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  _logger.i('StreamBuilder: Waiting for messages');
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  _logger.e('StreamBuilder error: ${snapshot.error}');
                  return const Center(child: Text('Error loading messages. Please check your connection.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  _logger.i('StreamBuilder: No messages found');
                  return const Center(child: Text('No messages yet. Start the conversation!'));
                }
                final messages = snapshot.data!.docs;
                _logger.i('StreamBuilder: Loaded ${messages.length} messages');
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == _auth.currentUser?.uid;
                    final isBot = msg['senderId'] == 'bot';
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.teal[100]
                              : isBot
                                  ? Colors.grey[300]
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(12.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.2),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['senderName'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 12.0,
                                color: isBot ? Colors.teal : Colors.grey[600],
                                fontWeight: isBot ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              msg['text'] ?? '',
                              style: TextStyle(
                                fontSize: 16.0,
                                color: isBot ? Colors.teal[800] : Colors.black,
                              ),
                            ),
                            if (msg['imageUrl'] != null) ...[
                              const SizedBox(height: 8.0),
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      child: Image.network(
                                        msg['imageUrl'],
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) =>
                                            const Text('Failed to load image'),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    msg['imageUrl'],
                                    width: 150,
                                    height: 150,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Text('Failed to load image'),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 4.0),
                            Text(
                              msg['timestamp'] != null
                                  ? DateFormat('HH:mm').format((msg['timestamp'] as Timestamp).toDate())
                                  : 'Sending...',
                              style: TextStyle(fontSize: 10.0, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.camera_alt, color: Colors.teal),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30.0)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.teal),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}