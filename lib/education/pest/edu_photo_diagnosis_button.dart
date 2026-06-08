// lib/education/pest/edu_photo_diagnosis_button.dart
//
// Compact "Scan with AI" widget embedded at the top of the pest/disease
// data input forms.
//
// AI logic lives entirely in gemini_vision_helper.dart — do not duplicate
// prompts or API calls here.
//
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kilimomkononi/education/pest/gemini_vision_helper.dart';
import 'package:kilimomkononi/models/education_user.dart';

const List<String> _eduCrops = [
  'Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes',
  'Onions', 'Irish Potatoes',
];

typedef EduPrefillCallback = void Function(Map<String, String> prefill);

// ─────────────────────────────────────────────────────────────────────────────
class EduPhotoDiagnosisButton extends StatefulWidget {
  final bool isPest;
  final EduRole role;
  final EduPrefillCallback onPrefill;

  const EduPhotoDiagnosisButton({
    super.key,
    required this.isPest,
    required this.role,
    required this.onPrefill,
  });

  @override
  State<EduPhotoDiagnosisButton> createState() =>
      _EduPhotoDiagnosisButtonState();
}

class _EduPhotoDiagnosisButtonState extends State<EduPhotoDiagnosisButton> {
  Uint8List? _imageBytes;
  String? _selectedCrop;
  GeminiDiagResult? _result;
  bool _isLoading = false;
  String? _error;
  bool _isExpanded = false;

  bool get _isHeadteacher => widget.role == EduRole.headteacher;

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
    if (_selectedCrop == null) { _snack('Please select the crop in the photo'); return; }

    setState(() { _isLoading = true; _error = null; _result = null; });

    try {
      final result = await runGeminiVisionDiagnosis(
        imageBytes: _imageBytes!,
        crop:       _selectedCrop!,
        isPest:     widget.isPest,
      );

      // Rejected image — show clear reason, do not display as diagnosis
      if (result.isRejected) {
        setState(() {
          _isLoading = false;
          _error = _buildRejectionMessage(result);
        });
        return;
      }

      // Low confidence — show result with warning, do NOT pre-fill the form.
      // Users with basic phones still deserve a best-effort answer.
      setState(() { _result = result; _isLoading = false; });
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
    final reason = r.rejectionReason.isNotEmpty ? r.rejectionReason : '';
    final parts = [if (seen.isNotEmpty) seen, if (reason.isNotEmpty) reason];
    return '${parts.join('\n\n')}\n\nPlease upload a photo of:\n'
        '• The affected leaf, stem, fruit or root, OR\n'
        '• The pest (insect, worm, mite) you found on the crop.';
  }

  void _useSuggestion() {
    if (_result == null || _result!.isHealthy) {
      _snack('Plant appears healthy — no issue to pre-fill.');
      return;
    }
    widget.onPrefill({
      'crop':  _selectedCrop ?? '',
      'stage': '',
      'name':  _result!.name,
      'type':  _result!.type,
    });
    _snack('✓ Form pre-filled: ${_result!.name}');
  }

  @override
  Widget build(BuildContext context) {
    if (_isHeadteacher) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _isExpanded ? Colors.teal.shade300 : Colors.teal.shade200,
          width: _isExpanded ? 2 : 1,
        ),
      ),
      child: Column(children: [
        // ── Collapsible header ──
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(Icons.camera_enhance, color: Colors.teal.shade700, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📸 Scan with AI — identify ${widget.isPest ? 'pest' : 'disease'} from photo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800),
                ),
              ),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.teal.shade600),
              ),
            ]),
          ),
        ),

        if (_isExpanded) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Photo tip
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.tips_and_updates, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    widget.isPest
                        ? 'Upload a photo of the pest itself OR a crop part showing pest damage (holes, chewed edges, etc.).'
                        : 'Upload a photo of the affected crop part showing symptoms (spots, lesions, wilting, discolouration).',
                    style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                  )),
                ]),
              ),

              // Crop selector
              DropdownButtonFormField<String>(
                value: _selectedCrop,
                decoration: const InputDecoration(
                  labelText: 'Crop in the photo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.eco),
                  isDense: true,
                ),
                items: _eduCrops
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() { _selectedCrop = v; _result = null; _error = null; }),
              ),
              const SizedBox(height: 10),

              // Camera / gallery buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.photo_library, size: 16),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ]),

              // Photo preview
              if (_imageBytes != null) ...[
                const SizedBox(height: 10),
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(_imageBytes!,
                        width: double.infinity, height: 160, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() { _imageBytes = null; _result = null; _error = null; }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ]),
              ],

              const SizedBox(height: 10),

              // Analyse button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search, size: 16),
                  label: Text(_isLoading ? 'Analysing...' : 'Analyse Photo with AI'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _analyse,
                ),
              ),

              // Error / rejection
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade700, size: 14),
                      const SizedBox(width: 6),
                      Text('Photo not accepted',
                          style: TextStyle(color: Colors.red.shade700,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                    const SizedBox(height: 4),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ]),
                ),
              ],

              // Result
              if (_result != null) ...[
                const SizedBox(height: 12),
                _buildResultCard(_result!),
              ],
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildResultCard(GeminiDiagResult r) {
    final color = r.isHealthy ? Colors.green : Colors.teal;

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(children: [
            Icon(
              r.isHealthy ? Icons.check_circle
                  : (r.type == 'pest' ? Icons.bug_report : Icons.local_florist),
              color: color.shade700, size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(r.name,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                    color: color.shade900))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: r.confColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: r.confColor.withOpacity(0.4)),
              ),
              child: Text(r.confLabel,
                  style: TextStyle(fontSize: 11, color: r.confColor,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // Medium confidence warning
        if (r.confidence.toLowerCase() == 'medium')
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 13, color: Colors.orange.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Medium confidence — verify with a field expert before applying treatment.',
                style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
              )),
            ]),
          ),

        if (r.description.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(r.description,
                style: const TextStyle(fontSize: 13, height: 1.4)),
          ),

        if (r.recommendation.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
              const SizedBox(width: 6),
              Expanded(child: Text(r.recommendation,
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900,
                      fontStyle: FontStyle.italic, height: 1.4))),
            ]),
          ),
        ],

        if (r.alternatives.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('Also consider: ${r.alternatives.join(', ')}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ),
        ],

        if (!r.isHealthy) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Use This Result — Pre-fill Form',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _useSuggestion,
              ),
            ),
          ),
        ] else
          const SizedBox(height: 12),
      ]),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}