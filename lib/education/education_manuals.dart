// education_manuals.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/utils/string_ext.dart';
import 'package:open_file/open_file.dart';

import '../utils/class_id_notifier.dart';
import '../models/education_user.dart';

const Color primaryGreen = Color(0xFF032704);
const Color fabGreen = Color(0xFF4CAF50);

// Global cache for education manuals
List<StorageManual> _cachedManuals = [];
bool _hasLoaded = false;

class EducationManuals extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const EducationManuals({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EducationManuals> createState() => _EducationManualsState();
}

class StorageManual {
  final String title;
  final String fileName;
  final String downloadUrl;
  final DateTime? uploadedAt;
  final String category;
  final String uploadedBy;

  StorageManual({
    required this.title,
    required this.fileName,
    required this.downloadUrl,
    this.uploadedAt,
    required this.category,
    required this.uploadedBy,
  });
}

class _EducationManualsState extends State<EducationManuals> {
  final TextEditingController _titleCtrl = TextEditingController();
  String? _selectedCrop;
  bool _isLoading = false;

  final List<String> _crops = [
    'maize',
    'beans',
    'tomatoes',
    'carrots',
    'cabbage',
    'onions',
    'irish potatoes',
  ];

  @override
  void initState() {
    super.initState();
    classIdNotifier.value = widget.classId;
    _loadManualsOnce();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadManualsOnce() async {
    if (_hasLoaded) return;

    try {
      final ref = FirebaseStorage.instance.ref('manuals');
      final result = await ref.listAll();

      final List<StorageManual> manuals = [];

      for (final item in result.items) {
        final url = await item.getDownloadURL();
        final meta = await item.getMetadata();
        final fullName = item.name;
        final cleanName = fullName.contains('_')
            ? fullName.split('_').sublist(1).join('_')
            : fullName;

        final category = _detectCrop(cleanName);
        final title = _formatTitle(cleanName);

        manuals.add(StorageManual(
          title: title,
          fileName: cleanName,
          downloadUrl: url,
          uploadedAt: meta.timeCreated,
          category: category,
          uploadedBy: meta.customMetadata?['uploadedBy'] ?? 'Teacher',
        ));
      }

      manuals.sort((a, b) => (b.uploadedAt ?? DateTime(1970)).compareTo(a.uploadedAt ?? DateTime(1970)));

      _cachedManuals = manuals;
      _hasLoaded = true;

      if (mounted && _selectedCrop != null) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to load manuals: $e');
    }
  }

  String _formatTitle(String name) {
    return name
        .replaceAll('.pdf', '')
        .replaceAll('.PDF', '')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String _detectCrop(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('bean')) return 'beans';
    if (lower.contains('tomato') || lower.contains('tomatoes')) return 'tomatoes';
    if (lower.contains('carrot')) return 'carrots';
    if (lower.contains('cabbage')) return 'cabbage';
    if (lower.contains('onion')) return 'onions';
    if (lower.contains('potato')) return 'irish potatoes';
    if (lower.contains('maize') || lower.contains('corn')) return 'maize';
    return 'maize';
  }

  Future<void> _uploadManual() async {
    if (_selectedCrop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop first')),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final fileName = '${_selectedCrop}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final ref = FirebaseStorage.instance.ref('manuals/$fileName');

    try {
      setState(() => _isLoading = true);

      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      // Correct class name: SettableMetadata (not SettledMetadata)
      await ref.updateMetadata(SettableMetadata(
        customMetadata: {'uploadedBy': FirebaseAuth.instance.currentUser?.email ?? 'Teacher'},
      ));

      // Save reference in Firestore using helper
      await FirestoreHelper.ensureGradeExists(widget.classId);
      final collection = FirestoreHelper.getContentFromClassId(widget.classId, 'manuals_content');
      if (collection != null) {
        await collection.add({
          'type': 'manual',
          'title': _titleCtrl.text.isEmpty ? _formatTitle(fileName) : _titleCtrl.text,
          'crop': _selectedCrop,
          'url': url,
          'fileName': fileName,
          'createdAt': FieldValue.serverTimestamp(),
          'userId': FirebaseAuth.instance.currentUser!.uid,
        });
      }

      _titleCtrl.clear();
      _hasLoaded = false;
      _loadManualsOnce();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual uploaded successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openPdf(String url) async {
    try {
      final result = await OpenFile.open(url);
      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No PDF reader app found')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final double titleSize = isMobile ? 20.0 : 24.0;  // Fixed typo
    final double subtitleSize = isMobile ? 16.0 : 18.0;

    final filtered = _selectedCrop == null
        ? []
        : _cachedManuals.where((m) => m.category == _selectedCrop).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manuals & Guides'),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: widget.role == EduRole.teacher
          ? FloatingActionButton(
              backgroundColor: fabGreen,
              onPressed: _uploadManual,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(Icons.upload_file),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Crop Manuals & Guides',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleSize, color: primaryGreen),
            ),
            Text(
              'Class resources uploaded by your teacher',
              style: TextStyle(fontSize: subtitleSize - 2, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: InputDecoration(
                labelText: 'Select Crop',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryGreen, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: _crops.map((c) => DropdownMenuItem(value: c, child: Text(c.capitalize()))).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCrop = value;
                  _isLoading = true;
                });
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _isLoading = false);
                });
              },
            ),
            const SizedBox(height: 32),

            if (_selectedCrop == null)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.menu_book, size: 90, color: primaryGreen.withOpacity(0.7)),
                    const SizedBox(height: 24),
                    const Text('Select a crop to view its manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey)),
                    const SizedBox(height: 12),
                    const Text('Your teacher uploads guides here', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            else if (_isLoading || !_hasLoaded)
              const Center(child: CircularProgressIndicator(color: primaryGreen))
            else if (filtered.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 70, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('No manual available yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text('Teacher will upload soon', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final m = filtered[i];
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf, color: primaryGreen, size: isMobile ? 40 : 48),
                        title: Text(m.title, style: TextStyle(color: primaryGreen, fontWeight: FontWeight.w600, fontSize: subtitleSize)),
                        subtitle: Text('Uploaded by ${m.uploadedBy}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new, color: primaryGreen),
                          onPressed: () => _openPdf(m.downloadUrl),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}