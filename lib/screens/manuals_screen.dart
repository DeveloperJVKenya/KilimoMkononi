import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kilimomkononi/home.dart';

// Global cache
List<StorageManual> _cachedManuals = [];
bool _hasLoaded = false;

const Color appPrimaryColor = Color.fromARGB(255, 3, 39, 4);

class ManualsScreen extends StatefulWidget {
  const ManualsScreen({super.key});

  @override
  State<ManualsScreen> createState() => _ManualsScreenState();
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

class _ManualsScreenState extends State<ManualsScreen> {
  final logger = Logger(printer: PrettyPrinter());
  final TextEditingController _titleController = TextEditingController();
  double? _uploadProgress;
  String _selectedCategory = 'All Crops';
  bool _isAdmin = false;
  bool _isLoading = false;

  static const Map<String, String> manualCategories = {
    'All Crops': 'All Crops',
    'maize': 'Maize',
    'beans': 'Beans',
    'tomatoes': 'Tomatoes',
    'carrots': 'Carrots',
    'cabbage': 'Cabbage',
    'onions': 'Onions',
    'irish potatoes': 'Irish Potatoes',
  };

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _loadManualsOnce();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('Admins').doc(user.uid).get();
      if (mounted) setState(() => _isAdmin = doc.exists);
    } catch (e) {
      logger.e('Admin check error: $e');
    }
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
          uploadedBy: meta.customMetadata?['uploadedBy'] ?? 'Admin',
        ));
      }

      manuals.sort((a, b) => (b.uploadedAt ?? DateTime(1970)).compareTo(a.uploadedAt ?? DateTime(1970)));

      _cachedManuals = manuals;
      _hasLoaded = true;

      if (mounted && _selectedCategory != 'All Crops') {
        setState(() {});
      }
    } catch (e) {
      logger.e('Failed to load manuals: $e');
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

  IconData _getFileIcon(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (ext.contains('doc')) return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'pdf') return Colors.red;
    if (ext.contains('doc')) return Colors.blue;
    return Colors.green;
  }

  // ==================== UPLOAD & ACTIONS ====================

  Future<void> _showUploadDialog() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can upload manuals.')));
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Upload Manual', style: TextStyle(color: appPrimaryColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(16.0),
              const SizedBox(height: 12),
              _buildCategoryDropdown(16.0),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadManual();
            },
            style: ElevatedButton.styleFrom(backgroundColor: appPrimaryColor),
            child: const Text('Upload File', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadManual() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || !_isAdmin) return;

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final fileName = file.name;
      final title = _titleController.text.trim().isEmpty ? fileName : _titleController.text.trim();

      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Confirm Upload', style: TextStyle(color: appPrimaryColor)),
          content: Text('Upload "$fileName"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Upload')),
          ],
        ),
      );
      if (confirm != true) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Uploading...', style: TextStyle(color: appPrimaryColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 8),
              Text(_uploadProgress != null ? '${(_uploadProgress! * 100).toStringAsFixed(0)}%' : 'Starting...'),
            ],
          ),
        ),
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('manuals/${DateTime.now().millisecondsSinceEpoch}_$fileName');

      final task = kIsWeb ? storageRef.putData(file.bytes!) : storageRef.putFile(File(file.path!));
      task.snapshotEvents.listen((s) => setState(() => _uploadProgress = s.bytesTransferred / s.totalBytes));
      await task;
      final url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('Manuals').add({
        'title': title,
        'fileName': fileName,
        'downloadUrl': url,
        'uploadedAt': FieldValue.serverTimestamp(),
        'category': _selectedCategory == 'All Crops' ? 'maize' : _selectedCategory,
        'uploadedBy': user.displayName ?? 'Admin',
      });

      _hasLoaded = false;
      _loadManualsOnce();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploaded successfully!')));
        _titleController.clear();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _uploadProgress = null);
    }
  }

  Future<void> _viewManual(String url, String fileName) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator(color: appPrimaryColor)));

    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        Navigator.pop(context);
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/$fileName';
        await Dio().download(url, path);
        if (mounted) {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (_) => PDFViewerScreen(filePath: path, fileName: fileName)));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _downloadManual(String url, String fileName) async {
    if (!await Permission.storage.request().isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied')));
      return;
    }
    final dir = await getExternalStorageDirectory();
    final path = '${dir!.path}/$fileName';
    await Dio().download(url, path);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $path')));
    OpenFile.open(path);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width <= 600;
    final padding = isMobile ? 16.0 : 32.0;
    final titleSize = isMobile ? 20.0 : 28.0;
    final subtitleSize = isMobile ? 14.0 : 18.0;

    final filtered = _selectedCategory == 'All Crops'
        ? <StorageManual>[]
        : _cachedManuals.where((m) => m.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage())),
        ),
        title: const Text('Farming Manuals', style: TextStyle(color: Colors.white, fontSize: 18)),
        backgroundColor: appPrimaryColor,
        elevation: 2,
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: _showUploadDialog,
              backgroundColor: appPrimaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Available Manuals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: titleSize, color: appPrimaryColor)),
            Text('Sourced from various agricultural institutes and farmers', style: TextStyle(fontSize: subtitleSize - 2, color: Colors.grey[600])),
            const SizedBox(height: 16),
            _buildCategoryFilter(subtitleSize),
            const SizedBox(height: 24),

            if (_selectedCategory == 'All Crops')
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.menu_book, size: 90, color: appPrimaryColor.withOpacity(0.7)),
                      const SizedBox(height: 24),
                      const Text('Select a crop to view its manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey)),
                      const SizedBox(height: 12),
                      const Text('Choose from maize, beans, tomatoes, etc.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (_isLoading || !_hasLoaded)
              const Center(child: CircularProgressIndicator(color: appPrimaryColor))
            else if (filtered.isEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.book, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No manual available for ${manualCategories[_selectedCategory] ?? _selectedCategory} yet', style: TextStyle(fontSize: subtitleSize, color: Colors.grey[700])),
                      const SizedBox(height: 8),
                      Text(_isAdmin ? 'Tap + to upload one' : 'Coming soon', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final m = filtered[i];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(Icons.picture_as_pdf, color: Colors.red, size: isMobile ? 32 : 36),
                      title: Text(m.title, style: TextStyle(color: appPrimaryColor, fontWeight: FontWeight.w600, fontSize: subtitleSize)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uploaded: ${m.uploadedAt != null ? DateFormat('MMM dd, yyyy').format(m.uploadedAt!) : 'Recently'}'),
                          Text('By: ${m.uploadedBy}'),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) => v == 'view' ? _viewManual(m.downloadUrl, m.fileName) : _downloadManual(m.downloadUrl, m.fileName),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility), SizedBox(width: 8), Text('View')])),
                          PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download), SizedBox(width: 8), Text('Download')])),
                        ],
                        icon: const Icon(Icons.more_vert, color: appPrimaryColor),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(double fontSize) {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: 'Manual Title (Optional)',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appPrimaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      style: TextStyle(fontSize: fontSize),
    );
  }

  Widget _buildCategoryDropdown(double fontSize) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Manual Category',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appPrimaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      items: manualCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontSize: fontSize)))).toList(),
      onChanged: (v) => setState(() => _selectedCategory = v!),
      style: TextStyle(fontSize: fontSize, color: Colors.black),
    );
  }

  Widget _buildCategoryFilter(double fontSize) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Filter by Crop',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: appPrimaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey[100],
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
      items: manualCategories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(fontSize: fontSize)))).toList(),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value!;
          _isLoading = true;
        });
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) setState(() => _isLoading = false);
        });
      },
      style: TextStyle(fontSize: fontSize, color: Colors.black),
    );
  }
}

class PDFViewerScreen extends StatelessWidget {
  final String filePath;
  final String fileName;
  const PDFViewerScreen({super.key, required this.filePath, required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: appPrimaryColor,
      ),
      body: SafeArea(child: PDFView(filePath: filePath)),
    );
  }
}