// lib/education/primary/primary_fun_fact_box.dart
// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'primary_ai_service.dart';

/// A drop-in replacement for the static amber fun-fact box used in all
/// primary topic cards. It shows the hardcoded [funFact] by default, and
/// offers a "More facts ↻" tap to fetch a new AI-generated one.
///
/// Replace the existing amber Container in each card with:
///
///   PrimaryFunFactBox(
///     itemName: 'Dairy Cow',
///     initialFact: animal.funFact,
///   ),
class PrimaryFunFactBox extends StatefulWidget {
  final String itemName;
  final String initialFact;

  const PrimaryFunFactBox({
    super.key,
    required this.itemName,
    required this.initialFact,
  });

  @override
  State<PrimaryFunFactBox> createState() => _PrimaryFunFactBoxState();
}

class _PrimaryFunFactBoxState extends State<PrimaryFunFactBox> {
  final _service = const PrimaryAiService();

  late String _currentFact;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentFact = widget.initialFact;
  }

  Future<void> _loadNewFact() async {
    if (_loading) return;
    setState(() => _loading = true);
    final newFact = await _service.generateNewFunFact(
      item:         widget.itemName,
      existingFact: _currentFact,
    );
    if (!mounted) return;
    setState(() {
      _loading     = false;
      _currentFact = newFact ?? _currentFact; // fallback to existing if error
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _loading
                  ? const SizedBox(key: ValueKey('spin'), width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.amber)))
                  : const Text('💡', key: ValueKey('emoji'),
                      style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _currentFact,
                  key: ValueKey(_currentFact),
                  style: TextStyle(
                      fontSize: 13, color: Colors.amber.shade900, height: 1.4),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: _loading ? null : _loadNewFact,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade300)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.refresh_rounded,
                      size: 13, color: Colors.amber.shade800),
                  const SizedBox(width: 4),
                  Text('More facts',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: Colors.amber.shade800)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}