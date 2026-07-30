// lib/education/pest/edu_photo_diagnosis_page.dart
// Full-page AI Photo Diagnosis (standalone).
// AI logic lives in gemini_vision_helper.dart — do not duplicate prompts here.
//

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilimomkononi/education/pest/gemini_vision_helper.dart';
import 'package:kilimomkononi/models/education_user.dart';

const List<String> _eduCrops = [
  'Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes',
  'Onions', 'Irish Potatoes',
];

// ─────────────────────────────────────────────────────────────────────────────
class EduPhotoDiagnosisPage extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const EduPhotoDiagnosisPage({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<EduPhotoDiagnosisPage> createState() => _EduPhotoDiagnosisPageState();
}

class _EduPhotoDiagnosisPageState extends State<EduPhotoDiagnosisPage> {
  Uint8List? _imageBytes;
  String? _selectedCrop;
  GeminiDiagResult? _result;
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xfile =
        await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _result     = null;
      _error      = null;
    });
  }

  Future<void> _analyse() async {
    if (_imageBytes == null) { _snack('Please take or select a photo first'); return; }
    if (_selectedCrop == null) { _snack('Please select the crop in the photo'); return; }

    setState(() { _isLoading = true; _error = null; _result = null; });

    try {
      // isPest: null — this page diagnoses both pests AND diseases
      final result = await runGeminiVisionDiagnosis(
        imageBytes: _imageBytes!,
        crop:       _selectedCrop!,
        isPest:     null,
      );

      // Rejected image
      if (result.isRejected) {
        setState(() {
          _isLoading = false;
          _error = _buildRejectionMessage(result);
        });
        return;
      }

      // Low confidence — show result with warning, but do NOT save to Firestore.
      // Users with low-res phones still deserve a best-effort diagnosis.
      // Blocking them entirely is worse than showing an uncertain answer.
      setState(() { _result = result; _isLoading = false; });

      // Save only high/medium confidence, non-healthy results
      if (!result.isHealthy) {
        try {
          final user  = FirebaseAuth.instance.currentUser;
          final parts = widget.classId.split('_');
          if (user != null && parts.length >= 3) {
            await FirebaseFirestore.instance
                .collection('schools').doc(parts[0])
                .collection('systems').doc(parts[1])
                .collection('grades').doc(parts.sublist(2).join('_'))
                .collection('photo_diagnoses')
                .add({
              'userId':         user.uid,
              'crop':           _selectedCrop,
              'diagnosedName':  result.name,
              'type':           result.type,
              'confidence':     result.confidence,
              'description':    result.description,
              'recommendation': result.recommendation,
              'isPest':         result.type == 'pest',
              'createdAt':      FieldValue.serverTimestamp(),
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _buildRejectionMessage(GeminiDiagResult r) {
    final seen = r.imageSubject.isNotEmpty
        ? 'The AI saw: "${r.imageSubject}"'
        : '';
    final reason = r.rejectionReason;
    final parts = [if (seen.isNotEmpty) seen, if (reason.isNotEmpty) reason];
    return '${parts.join('\n\n')}\n\nPlease upload a photo of:\n'
        '• The affected leaf, stem, fruit or root of your $_selectedCrop plant, OR\n'
        '• The pest (insect, worm, mite) you found on the crop.\n\n'
        'Animals, people, and general scenes cannot be diagnosed.';
  }

  CollectionReference? get _photoDiagnosesCollection {
    final parts = widget.classId.split('_');
    if (parts.length < 3) return null;
    return FirebaseFirestore.instance
        .collection('schools').doc(parts[0])
        .collection('systems').doc(parts[1])
        .collection('grades').doc(parts.sublist(2).join('_'))
        .collection('photo_diagnoses');
  }

  void _showHistory() {
    final user = FirebaseAuth.instance.currentUser;
    final coll = _photoDiagnosesCollection;
    if (user == null || coll == null) { _snack('History unavailable'); return; }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.95,
        builder: (_, controller) => Column(children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              const Icon(Icons.history, color: Color(0xFF032704)),
              const SizedBox(width: 10),
              const Text('My Diagnosis History',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Color(0xFF032704))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: coll.where('userId', isEqualTo: user.uid).snapshots(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = (snapshot.data?.docs ?? []).toList()
                  ..sort((a, b) {
                    final aTs = (a.data() as Map)['createdAt'];
                    final bTs = (b.data() as Map)['createdAt'];
                    if (aTs == null || bTs == null) return 0;
                    return (bTs as Timestamp).compareTo(aTs as Timestamp);
                  });
                if (docs.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.photo_camera_back_outlined,
                          size: 52, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No diagnoses saved yet',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Analyse a photo to save your first result',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ]),
                  );
                }
                return ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final ts = d['createdAt'] as Timestamp?;
                    final confidence = d['confidence'] as String? ?? '';
                    Color confColor;
                    switch (confidence.toLowerCase()) {
                      case 'high':   confColor = Colors.green; break;
                      case 'medium': confColor = Colors.orange; break;
                      default:       confColor = Colors.red;
                    }
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: Colors.teal.shade100)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(d['isPest'] == true ? Icons.bug_report : Icons.local_florist,
                                color: Colors.teal.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d['diagnosedName'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: confColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: confColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(confidence,
                                  style: TextStyle(fontSize: 11, color: confColor,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text('Crop: ${d['crop'] ?? ''}  •  ${d['isPest'] == true ? 'Pest' : 'Disease'}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          if (ts != null)
                            Text(_fmtDate(ts.toDate()),
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          if ((d['recommendation'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(d['recommendation'] as String,
                                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)  return '${diff.inHours}h ago';
    if (diff.inDays == 1)   return 'Yesterday';
    return '${d.day}/${d.month}/${d.year}';
  }

  void _useResult() {
    if (_result == null || _result!.isHealthy) {
      _snack('No issue detected. Try a clearer photo of the affected area.');
      return;
    }
    Navigator.pop(context, {
      'crop':  _selectedCrop ?? '',
      'stage': '',
      'name':  _result!.name,
      'type':  _result!.type,
    });
    _snack('✓ Pre-filled with: ${_result!.name}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Photo Diagnosis'),
        backgroundColor: const Color(0xFF032704),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Diagnosis History',
            onPressed: _showHistory,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Card(
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.camera_alt, color: Colors.teal.shade700, size: 28),
                    const SizedBox(width: 12),
                    const Text('AI Photo Diagnosis',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a photo of an affected crop part OR a pest you found. '
                    'The AI will identify the pest or disease from what it literally sees.',
                    style: TextStyle(fontSize: 13, color: Colors.teal.shade800, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.tips_and_updates, size: 16, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tips: photograph close-up in good light, keep the camera steady, '
                          'and let the damaged leaf/fruit/pest fill most of the frame.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Crop selector
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use  — value: (not initialValue:) is required so this dropdown stays in sync with external state resets (cascading selects / AI prefill).
              value: _selectedCrop,
              decoration: const InputDecoration(
                labelText: 'Crop in the Photo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.eco),
              ),
              items: _eduCrops
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() { _selectedCrop = v; _result = null; _error = null; }),
            ),
            const SizedBox(height: 16),

            // Camera / gallery
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Photo preview
            if (_imageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(children: [
                  Image.memory(_imageBytes!,
                      width: double.infinity, height: 220, fit: BoxFit.cover),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () => setState(() { _imageBytes = null; _result = null; _error = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 20),

            // Analyse button
            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: Text(_isLoading ? 'Analysing…' : 'Identify Problem'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _isLoading ? null : _analyse,
            ),

            // Error / rejection
            if (_error != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Text('Photo Not Accepted',
                          style: TextStyle(color: Colors.red.shade700,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ]),
                ),
              ),
            ],

            // Results
            if (_result != null && !_isLoading) ...[
              const SizedBox(height: 24),
              _buildResults(_result!),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(GeminiDiagResult r) {
    if (r.isHealthy) {
      return Card(
        color: Colors.green.shade50,
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'The plant appears healthy — no clear issue detected.\n\n'
            'Try taking a clearer, closer photo of the affected area if symptoms persist.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('AI Identification Result',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),

      if (r.confidence.toLowerCase() == 'medium')
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Medium confidence — verify with a local agronomist or extension officer '
                'before applying any treatment.',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
              ),
            ),
          ]),
        ),

      Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.teal.shade300, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(r.type == 'pest' ? Icons.bug_report : Icons.local_florist,
                  color: Colors.teal.shade700),
              const SizedBox(width: 10),
              Expanded(child: Text(r.name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: r.confColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: r.confColor.withValues(alpha: 0.4)),
                ),
                child: Text(r.confidence.toUpperCase(),
                    style: TextStyle(color: r.confColor,
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ]),

            if (r.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(r.description, style: const TextStyle(fontSize: 13, height: 1.5)),
            ],

            if (r.recommendation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.lightbulb, size: 16, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r.recommendation,
                      style: TextStyle(fontSize: 13, color: Colors.amber.shade900))),
                ]),
              ),
            ],

            if (r.alternatives.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Other possibilities: ${r.alternatives.join(', ')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 20),

      ElevatedButton.icon(
        icon: const Icon(Icons.auto_fix_high),
        label: const Text('Use This Result & Return to Form'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 56),
        ),
        onPressed: _useResult,
      ),

      const SizedBox(height: 12),
      const Text(
        'After returning, go to the Pest or Disease Data tab to complete your answer.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}