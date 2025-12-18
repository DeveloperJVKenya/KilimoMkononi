// lib/screens/user_profile.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  String? _resolvedFullName;

  @override
  void initState() {
    super.initState();
    _displayedImageBytes = widget.profileImageBytes;
    _resolvedFullName = widget.fullName;
    _isEducationUser = widget.role == 'teacher' || widget.role == 'student';

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
        if (mounted) {
          setState(() {
            _resolvedFullName = name;
            _nameCtrl.text = name ?? '';
            _emailCtrl.text = data['email'] ?? '';
            _phoneCtrl.text = phone ?? '';
            _isEducationUser = true;
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