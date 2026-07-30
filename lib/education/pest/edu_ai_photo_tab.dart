// lib/education/pest/edu_ai_photo_tab.dart
//
// Full-page AI photo diagnosis tab for the education pest/disease home.
// AI logic lives in gemini_vision_helper.dart — do not duplicate prompts here.
//

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilimomkononi/education/pest/gemini_vision_helper.dart';
import 'package:kilimomkononi/education/widgets/edu_ai_advice_card.dart';

const List<String> _aiTabCrops = [
  'Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes',
  'Onions', 'Irish Potatoes',
];

// ─────────────────────────────────────────────────────────────────────────────
class EduAiPhotoTab extends StatefulWidget {
  final bool isPest;
  final String classId;
  final String schoolName;
  final void Function(Map<String, String> prefill)? onPrefill;

  const EduAiPhotoTab({
    super.key,
    required this.isPest,
    required this.classId,
    required this.schoolName,
    this.onPrefill,
  });

  @override
  State<EduAiPhotoTab> createState() => _EduAiPhotoTabState();
}

class _EduAiPhotoTabState extends State<EduAiPhotoTab> {
  Uint8List? _imageBytes;
  String? _selectedCrop;
  EduDiagResult? _result;
  bool _isLoading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1200);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _result     = null;
      _error      = null;
    });
  }

  Future<void> _analyse() async {
    if (_imageBytes == null) { _snack('Please select a photo first'); return; }
    if (_selectedCrop == null) { _snack('Please select the crop'); return; }

    setState(() { _isLoading = true; _error = null; _result = null; });

    try {
      final result = await runGeminiVisionDiagnosis(
        imageBytes: _imageBytes!,
        crop:       _selectedCrop!,
        isPest:     widget.isPest,
      );

      // Rejected — show reason, do not save
      if (result.isRejected) {
        setState(() {
          _isLoading = false;
          _error = _buildRejectionMessage(result);
        });
        return;
      }

      // Map GeminiDiagResult to EduDiagResult for display
      final eduResult = EduDiagResult(
        name:           result.name,
        type:           result.type,
        confidence:     result.confidence,
        description:    result.description,
        recommendation: result.recommendation,
        alternatives:   result.alternatives,
        isHealthy:      result.isHealthy,
      );
      // Low confidence — show result with warning, do NOT save to Firestore.
      setState(() { _result = eduResult; _isLoading = false; });

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
              'isPest':         widget.isPest,
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
        '• The affected leaf, stem, fruit or root, OR\n'
        '• The pest (insect, worm, mite) you found on the crop.';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Card(
            color: Colors.teal.shade50,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.teal.shade200)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.camera_alt, color: Colors.teal.shade700, size: 22),
                  const SizedBox(width: 10),
                  Text('AI Photo Diagnosis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _showHistory,
                    icon: Icon(Icons.history, size: 17, color: Colors.teal.shade700),
                    label: Text('History',
                        style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  widget.isPest
                      ? 'Upload a photo of the pest itself OR a crop part showing pest damage. Gemini AI will identify it.'
                      : 'Upload a photo of the affected crop part showing disease symptoms. Gemini AI will identify it.',
                  style: TextStyle(fontSize: 13, color: Colors.teal.shade700, height: 1.4),
                ),
                const SizedBox(height: 8),
                // Photo tips
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.tips_and_updates, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      'For best results: photograph close-up in good light, '
                      'keep the camera steady, and make the damaged area or pest '
                      'fill most of the frame.',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                    )),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // Crop selector
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use  — value: (not initialValue:) is required so this dropdown stays in sync with external state resets (cascading selects / AI prefill).
            value: _selectedCrop,
            decoration: const InputDecoration(
              labelText: 'Crop in the photo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.eco),
            ),
            items: _aiTabCrops
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() { _selectedCrop = v; _result = null; _error = null; }),
          ),
          const SizedBox(height: 12),

          // Camera / gallery
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  side: BorderSide(color: Colors.teal.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _pickImage(ImageSource.camera),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal.shade700,
                  side: BorderSide(color: Colors.teal.shade400),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Photo preview
          if (_imageBytes != null) ...[
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_imageBytes!,
                    width: double.infinity, height: 220, fit: BoxFit.cover),
              ),
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
            const SizedBox(height: 12),
          ],

          // Analyse button
          ElevatedButton.icon(
            icon: _isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search),
            label: Text(_isLoading ? 'Analysing...' : 'Analyse Photo with AI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
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
                padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 20),
            EduAiResultCard(
            result: _result!,
            isPest: widget.isPest,
            selectedCrop: _selectedCrop,
            onUseResult: widget.onPrefill,
          ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }


  // ── Firestore history ────────────────────────────────────────────────────────
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
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Icon(Icons.history, color: Colors.teal.shade700),
              const SizedBox(width: 10),
              Text('My Diagnosis History',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: coll
                  .where('userId', isEqualTo: user.uid)
                  .where('isPest', isEqualTo: widget.isPest)
                  .snapshots(),
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
                      const Text('No diagnoses yet', style: TextStyle(color: Colors.grey)),
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
                      case 'high':   confColor = Colors.green.shade700; break;
                      case 'medium': confColor = Colors.orange.shade700; break;
                      default:       confColor = Colors.red.shade600;
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
                            Icon(d['type'] == 'pest' ? Icons.bug_report : Icons.local_florist,
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
                          Text('Crop: ${d['crop'] ?? ''}',
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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}