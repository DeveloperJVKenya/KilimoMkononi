// lib/education/pest/pest_disease_home.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'pest_home.dart';
import 'disease_home.dart';
import 'symptom_checker_page.dart';

class PestDiseaseHome extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const PestDiseaseHome({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<PestDiseaseHome> createState() => _PestDiseaseHomeState();
}

class _PestDiseaseHomeState extends State<PestDiseaseHome> {
  int _selected = 0;
  Map<String, String>? _prefillData;

  bool get _isHeadteacher => widget.role == EduRole.headteacher;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pest & Disease Management'),
        backgroundColor: const Color(0xFF032704),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _selected == 0
          ? _buildThreeCardsClean()
          : _buildSelectedContent(),
    );
  }

  Widget _buildThreeCardsClean() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildCard('Pest Management', Colors.green[800]!, () => setState(() => _selected = 1)),
            const SizedBox(height: 30),
            _buildCard('Disease Management', Colors.green[700]!, () => setState(() => _selected = 2)),
            if (!_isHeadteacher) ...[
              const SizedBox(height: 30),
              _buildCard('Symptom Checker', Colors.green[600]!, () => setState(() => _selected = 3)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 140,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 12,
          shadowColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSelectedContent() {
    late Widget content;

    if (_selected == 1) {
      content = PestHome(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        prefillData: _prefillData,
      );
    } else if (_selected == 2) {
      content = DiseaseHome(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        prefillData: _prefillData,
      );
    } else if (_selected == 3) {
      content = SymptomCheckerPage(
        role: widget.role,
        schoolName: widget.schoolName,
        classId: widget.classId,
        isEmbedded: true,
        onGoToManagement: (data) {
          setState(() {
            _prefillData = data;
            _selected = data['type'] == 'Pest' ? 1 : 2;
          });
        },
      );
    }

    return Stack(
      children: [
        content,
        Positioned(
          top: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            mini: true,
            onPressed: () {
              setState(() {
                _selected = 0;
                _prefillData = null;
              });
            },
            child: const Icon(Icons.close, color: Color(0xFF032704)),
          ),
        ),
      ],
    );
  }
}