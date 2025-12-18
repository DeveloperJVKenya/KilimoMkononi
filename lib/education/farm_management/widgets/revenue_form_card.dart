// lib/education/farm_management/widgets/revenue_form_card.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/services/farm_management_service.dart';

class RevenueFormCard extends StatefulWidget {
  final String classId;
  final String schoolName;

  const RevenueFormCard({
    super.key,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<RevenueFormCard> createState() => _RevenueFormCardState();
}

class _RevenueFormCardState extends State<RevenueFormCard> {
  final _sourceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final _service = FarmManagementService();
  bool _isSaving = false;

  @override
  void dispose() {
    _sourceCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final source = _sourceCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;

    if (source.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter source and valid amount')),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      await _service.saveContent(
        classId: widget.classId,
        schoolName: widget.schoolName,
        type: 'revenue',
        data: {
          'source': source,
          'amount': amount,
          'date': _date.toIso8601String().split('T').first,
        },
      );
      _sourceCtrl.clear();
      _amountCtrl.clear();
      setState(() => _date = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revenue saved!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: ExpansionTile(
        leading: const Icon(Icons.attach_money, color: Color(0xFF003900)),
        title: const Text('Record Revenue', style: TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _sourceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Source (e.g. Maize Sale)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.eco),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Amount (KSH)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Date: ${_date.toLocal().toString().split(' ')[0]}')),
                    TextButton.icon(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _date = d);
                      },
                      icon: const Icon(Icons.calendar_today),
                      label: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003900),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}