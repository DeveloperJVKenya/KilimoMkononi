// lib/education/farm_management/widgets/cost_form_card.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/services/farm_management_service.dart';

class CostFormCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final String hint;
  final String type;
  final String classId;
  final String schoolName;  // ADDED

  const CostFormCard({
    super.key,
    required this.title,
    required this.icon,
    required this.hint,
    required this.type,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<CostFormCard> createState() => _CostFormCardState();
}

class _CostFormCardState extends State<CostFormCard> {
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  final _service = FarmManagementService();
  bool _isSaving = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final desc = _descCtrl.text.trim();
    final cost = double.tryParse(_costCtrl.text.trim());

    if (desc.isEmpty || cost == null || cost <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill description and valid cost')),
      );
      setState(() => _isSaving = false);
      return;
    }

    try {
      await _service.saveContent(
        classId: widget.classId,
        schoolName: widget.schoolName,  // ADDED
        type: widget.type,
        data: {
          'description': desc,
          'cost': cost,
          'date': _date.toIso8601String().split('T').first,
        },
      );
      _descCtrl.clear();
      _costCtrl.clear();
      setState(() => _date = DateTime.now());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cost saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        leading: Icon(widget.icon, color: const Color(0xFF003900)),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.description),
                    hintText: widget.hint,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _costCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cost (KSH)',
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
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Cost', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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