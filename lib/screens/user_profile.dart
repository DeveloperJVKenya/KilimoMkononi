// lib/screens/user_profile.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// ---------------------------------------------------------------
/// UserProfileScreen – works for Farmer, Teacher, and Student
/// ---------------------------------------------------------------
class UserProfileScreen extends StatefulWidget {
  /// Optional: pre-loaded image bytes
  final Uint8List? profileImageBytes;

  /// Optional: full name (will load from Firestore if null)
  final String? fullName;

  /// Optional: school name (only for teacher/student)
  final String? schoolName;

  /// Optional: role (farmer, teacher, student)
  final String? role;

  const UserProfileScreen({
    super.key,
    this.profileImageBytes,
    this.fullName,
    this.schoolName,
    this.role,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _schoolCtrl;
  late final TextEditingController _countyCtrl;
  late final TextEditingController _constituencyCtrl;
  late final TextEditingController _wardCtrl;

  File? _pickedImageFile;
  Uint8List? _displayedImageBytes;
  bool _isLoading = false;
  bool _isEducationUser = false;
  bool _isHeadteacher = false;
  String? _schoolCode;
  String? _resolvedFullName;

  @override
  void initState() {
    super.initState();
    _displayedImageBytes = widget.profileImageBytes;
    _resolvedFullName = widget.fullName;
    // Include headteacher so their schoolCode also shows
    _isEducationUser = widget.role == 'teacher' ||
        widget.role == 'student' ||
        widget.role == 'headteacher';

    _nameCtrl = TextEditingController(text: _resolvedFullName ?? '');
    _emailCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _schoolCtrl = TextEditingController(text: widget.schoolName ?? '');
    _countyCtrl = TextEditingController();
    _constituencyCtrl = TextEditingController();
    _wardCtrl = TextEditingController();

    if (_currentUser != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      // Try EducationUsers first
      final eduSnap = await _firestore
          .collection('EducationUsers')
          .doc(_currentUser!.uid)
          .get();

      if (eduSnap.exists) {
        final data = eduSnap.data()!;
        final imgBase64 = data['profileImage'] as String?;
        final name = data['fullName'] as String?;
        final phone = data['phone'] as String?;

        if (imgBase64 != null && imgBase64.isNotEmpty) {
          _displayedImageBytes = base64Decode(imgBase64);
        }
        final isHT = data['role'] == 'headteacher';
        final isTeacher = data['role'] == 'teacher';
        // Load schoolCode directly from user doc first
        String? code = data['schoolCode'] as String?;
        // If teacher/student has no code on their record, look up from Schools
        if ((isTeacher || isHT) && (code == null || code.isEmpty)) {
          final schoolName = data['schoolName'] as String?;
          if (schoolName != null && schoolName.isNotEmpty) {
            try {
              final schoolSnap = await _firestore
                  .collection('Schools')
                  .where('schoolName', isEqualTo: schoolName)
                  .limit(1)
                  .get();
              if (schoolSnap.docs.isNotEmpty) {
                code = schoolSnap.docs.first.data()['schoolCode'] as String?;
                // Backfill silently onto the user's own doc
                if (code != null && code.isNotEmpty) {
                  await _firestore
                      .collection('EducationUsers')
                      .doc(_currentUser.uid)
                      .update({'schoolCode': code});
                }
              }
            } catch (_) {}
          }
        }
        if (mounted) {
          setState(() {
            _resolvedFullName = name;
            _nameCtrl.text = name ?? '';
            _emailCtrl.text = data['email'] ?? '';
            _phoneCtrl.text = phone ?? '';
            // Ensure school name is populated even if not passed via widget
            if (_schoolCtrl.text.isEmpty && data['schoolName'] != null) {
              _schoolCtrl.text = data['schoolName'] as String;
            }
            _isEducationUser = true;
            _isHeadteacher = isHT;
            _schoolCode = code;
          });
        }
        return;
      }

      // Then try regular Users
      final userSnap = await _firestore.collection('Users').doc(_currentUser.uid).get();
      if (userSnap.exists) {
        final data = userSnap.data()!;
        final imgBase64 = data['profileImage'] as String?;
        final name = data['fullName'] as String?;

        if (imgBase64 != null && imgBase64.isNotEmpty) {
          _displayedImageBytes = base64Decode(imgBase64);
        }
        if (mounted) {
          setState(() {
            _resolvedFullName = name;
            _nameCtrl.text = name ?? '';
            _emailCtrl.text = data['email'] ?? '';
            _phoneCtrl.text = data['phoneNumber'] ?? '';
            _countyCtrl.text = data['county'] ?? '';
            _constituencyCtrl.text = data['constituency'] ?? '';
            _wardCtrl.text = data['ward'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Profile load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final file = File(picked.path);
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      minWidth: 800,
      minHeight: 800,
      quality: 85,
    );

    if (compressed != null) {
      setState(() {
        _pickedImageFile = file;
        _displayedImageBytes = compressed;
      });
    }
  }

  Future<void> _updateProfile() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? base64Image;
      if (_pickedImageFile != null || _displayedImageBytes != null) {
        final bytes = _pickedImageFile != null
            ? await _pickedImageFile!.readAsBytes()
            : _displayedImageBytes!;
        base64Image = base64Encode(bytes);
      }

      if (_isEducationUser) {
        await _firestore.collection('EducationUsers').doc(_currentUser!.uid).update({
          'fullName': _nameCtrl.text.trim(),
          'profileImage': base64Image,
        });
      } else {
        await _firestore.collection('Users').doc(_currentUser!.uid).update({
          'fullName': _nameCtrl.text.trim(),
          'profileImage': base64Image,
          'phoneNumber': _phoneCtrl.text.trim(),
          'county': _countyCtrl.text.trim(),
          'constituency': _constituencyCtrl.text.trim(),
          'ward': _wardCtrl.text.trim(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _editableField(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Profile Picture
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _displayedImageBytes != null
                              ? MemoryImage(_displayedImageBytes!)
                              : null,
                          child: _displayedImageBytes == null
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: _pickImage,
                            style: IconButton.styleFrom(backgroundColor: Colors.teal),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Name
                  _editableField(_nameCtrl, 'Full Name', Icons.person),
                  const SizedBox(height: 16),

                  // Email (read-only)
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _editableField(_phoneCtrl, 'Phone Number', Icons.phone),
                  const SizedBox(height: 24),


                  // School code — visible to headteachers AND teachers
                  // Teachers need it so they can share with new students
                  if (_isEducationUser && _schoolCode != null && _schoolCode!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.vpn_key, color: Color(0xFF2E7D32), size: 18),
                            SizedBox(width: 8),
                            Text('School Code',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                    fontSize: 14)),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(255, 3, 39, 4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _schoolCode!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: () {
                                // ignore: deprecated_member_use
                                Clipboard.setData(
                                    ClipboardData(text: _schoolCode!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('School code copied!')),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E7D32),
                                side: const BorderSide(
                                    color: Color(0xFF81C784)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                          Text(
                            _isHeadteacher
                              ? 'Share this code with teachers and students so they can join your school.'
                              : 'Share this with new students so they can join your class.',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF388E3C)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Role-Specific Fields
                  if (_isEducationUser) ...[
                    _editableField(_schoolCtrl, 'School Name', Icons.school),
                  ] else ...[
                    _editableField(_countyCtrl, 'County', Icons.location_city),
                    const SizedBox(height: 16),
                    _editableField(_constituencyCtrl, 'Constituency', Icons.map),
                    const SizedBox(height: 16),
                    _editableField(_wardCtrl, 'Ward', Icons.place),
                  ],

                  const SizedBox(height: 40),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Update Profile', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _schoolCtrl.dispose();
    _countyCtrl.dispose();
    _constituencyCtrl.dispose();
    _wardCtrl.dispose();
    super.dispose();
  }
}