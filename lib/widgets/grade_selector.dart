// lib/education/widgets/grade_selector.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/utils/class_id_notifier.dart';
import 'package:kilimomkononi/utils/education_utils.dart';

enum EducationSystem { cbcPrimary, cbcJunior, cbcSenior, eightFourFour }

class GradeSelector extends StatefulWidget {
  final Function(String? classId) onGradeSelected;
  final String? initialClassId;
  final String schoolName;
  final bool useWhiteText;

  const GradeSelector({
    super.key,
    required this.onGradeSelected,
    this.initialClassId,
    required this.schoolName,
    this.useWhiteText = false,
  });

  @override
  State<GradeSelector> createState() => _GradeSelectorState();
}

class _GradeSelectorState extends State<GradeSelector> {
  late EducationSystem _system;
  String? _selectedGrade;

  final Map<EducationSystem, List<String>> _grades = {
    EducationSystem.cbcPrimary: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
    EducationSystem.cbcJunior: ['Grade 7', 'Grade 8', 'Grade 9'],
    EducationSystem.cbcSenior: ['Grade 10', 'Grade 11', 'Grade 12'],
    EducationSystem.eightFourFour: [
      'Standard 1', 'Standard 2', 'Standard 3', 'Standard 4',
      'Standard 5', 'Standard 6', 'Standard 7', 'Standard 8',
      'Form 1', 'Form 2', 'Form 3', 'Form 4',
    ],
  };

  @override
  void initState() {
    super.initState();
    _parseInitialClassId();
  }

  void _parseInitialClassId() {
    if (widget.initialClassId == null) {
      _system = EducationSystem.cbcPrimary;
      _selectedGrade = null;
      return;
    }

    final fullId = widget.initialClassId!;

    // ----- FULL ID: Kianda_Schooljunior_7 -----
    final match = RegExp(r'_([^_]+)_(\d+)$').firstMatch(fullId);
    if (match != null) {
      final systemPart = match.group(1)!;
      final gradeNum = match.group(2)!;

      _system = switch (systemPart) {
        'primary' => EducationSystem.cbcPrimary,
        'junior' => EducationSystem.cbcJunior,
        'senior' => EducationSystem.cbcSenior,
        'eightfourfour' => EducationSystem.eightFourFour,
        _ => EducationSystem.cbcJunior,
      };

      _selectedGrade = _getGradeText(_system, gradeNum);
      return;
    }

    // ----- FALLBACK: short format 7|cbcJunior -----
    final parts = fullId.split('|');
    final shortId = parts[0];
    if (RegExp(r'^\d+$').hasMatch(shortId)) {
      final systemName = parts.length > 1 ? parts[1] : 'cbcJunior';
      _system = switch (systemName) {
        'cbcPrimary' => EducationSystem.cbcPrimary,
        'cbcJunior' => EducationSystem.cbcJunior,
        'cbcSenior' => EducationSystem.cbcSenior,
        'eightFourFour' => EducationSystem.eightFourFour,
        _ => EducationSystem.cbcJunior,
      };
      final options = _grades[_system]!;
      _selectedGrade = options.firstWhereOrNull((g) => g.split(' ').last == shortId) ?? options.first;
      return;
    }

    // ----- DEFAULT -----
    _system = EducationSystem.cbcPrimary;
    _selectedGrade = null;
  }

  String _getGradeText(EducationSystem system, String number) {
    final grades = _grades[system]!;
    return grades.firstWhere((g) => g.split(' ').last == number, orElse: () => 'Grade $number');
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.useWhiteText ? Colors.white : Colors.black87;
    final bgColor = widget.useWhiteText ? const Color.fromARGB(255, 3, 39, 4) : null;

    return Row(
      children: [
        // ----- SYSTEM DROPDOWN -----
        Expanded(
          child: DropdownButton<EducationSystem>(
            isExpanded: true,
            value: _system,
            dropdownColor: bgColor,
            style: TextStyle(color: textColor, fontSize: 14),
            items: [
              _item(EducationSystem.cbcPrimary, 'CBC Primary'),
              _item(EducationSystem.cbcJunior, 'CBC Junior'),
              _item(EducationSystem.cbcSenior, 'CBC Senior'),
              _item(EducationSystem.eightFourFour, '8-4-4'),
            ],
            onChanged: (v) {
              setState(() {
                _system = v!;
                _selectedGrade = null;
              });
              widget.onGradeSelected(null);
              classIdNotifier.value = null;
            },
          ),
        ),
        const SizedBox(width: 12),

        // ----- GRADE DROPDOWN -----
        Expanded(
          child: DropdownButton<String>(
            isExpanded: true,
            hint: Text('Grade', style: TextStyle(color: textColor)),
            value: _selectedGrade,
            dropdownColor: bgColor,
            style: TextStyle(color: textColor, fontSize: 14),
            items: _grades[_system]!
                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _selectedGrade = v);

              final gradeNumber = v.split(' ').last;
              final systemName = _system.name;

              // BUILD FULL ID – function is now in the imported library
              final fullClassId = buildFullGradeId(widget.schoolName, gradeNumber, systemName);

              widget.onGradeSelected(fullClassId);
              classIdNotifier.value = fullClassId; // FULL ID
            },
          ),
        ),
      ],
    );
  }

  DropdownMenuItem<EducationSystem> _item(EducationSystem value, String label) {
    return DropdownMenuItem(
      value: value,
      child: Text(label, style: TextStyle(color: widget.useWhiteText ? Colors.white : Colors.black87)),
    );
  }
}

// -----------------------------------------------------------------
// Helper extension (kept local to this file)
// -----------------------------------------------------------------
extension _FirstWhereOrNull<E> on List<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}