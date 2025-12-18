// lib/education/farm_management/widgets/loan_form_card.dart
import 'package:flutter/material.dart';
import 'package:kilimomkononi/education/farm_management/services/farm_management_service.dart';

class LoanFormCard extends StatefulWidget {
  final String classId;
  final String schoolName;

  const LoanFormCard({
    super.key,
    required this.classId,
    required this.schoolName,
  });

  @override
  State<LoanFormCard> createState() => _LoanFormCardState();
}

class _LoanFormCardState extends State<LoanFormCard> {
  final _amountCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  final _totalRepaymentCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();
  final _paymentCtrl = TextEditingController();

  DateTime _paymentDate = DateTime.now();
  final _service = FarmManagementService();

  double _principal = 0;
  double _interestRate = 0;
  double _interest = 0;
  double _totalPayable = 0;
  double _remaining = 0;

  @override
  void initState() {
    super.initState();
    _loadLoanData();
    _amountCtrl.addListener(_updateCalculations);
    _rateCtrl.addListener(_updateCalculations);
  }

  Future<void> _loadLoanData() async {
    try {
      final loans = await _service.getContent(
        classId: widget.classId,
        schoolName: widget.schoolName,
        type: 'loan',
      );
      if (loans.isNotEmpty) {
        final d = loans.first['data'] as Map<String, dynamic>;
        setState(() {
          _principal = double.tryParse(d['amount']?.toString() ?? '0') ?? 0;
          _interestRate = double.tryParse(d['interestRate']?.toString() ?? '0') ?? 0;
          _interest = double.tryParse(d['interest']?.toString() ?? '0') ?? 0;
          _totalPayable = double.tryParse(d['totalPayable']?.toString() ?? '0') ?? 0;
          _remaining = double.tryParse(d['remaining']?.toString() ?? '0') ?? _totalPayable;

          _amountCtrl.text = _principal.toStringAsFixed(2);
          _rateCtrl.text = _interestRate.toStringAsFixed(2);
          _interestCtrl.text = _interest.toStringAsFixed(2);
          _totalRepaymentCtrl.text = _totalPayable.toStringAsFixed(2);
          _remainingCtrl.text = _remaining.toStringAsFixed(2);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading loan: $e')),
      );
    }
  }

  void _updateCalculations() {
    final principal = double.tryParse(_amountCtrl.text) ?? 0;
    final rate = double.tryParse(_rateCtrl.text) ?? 0;
    final interest = principal * (rate / 100);
    final total = principal + interest;

    setState(() {
      _principal = principal;
      _interestRate = rate;
      _interest = interest;
      _totalPayable = total;
      _interestCtrl.text = interest.toStringAsFixed(2);
      _totalRepaymentCtrl.text = total.toStringAsFixed(2);
      _remainingCtrl.text = total.toStringAsFixed(2);
    });
  }

  Future<void> _saveLoan() async {
    try {
      final data = {
        'amount': _principal,
        'interestRate': _interestRate,
        'interest': _interest,
        'totalPayable': _totalPayable,
        'remaining': _totalPayable,
      };

      await _service.saveContent(
        classId: widget.classId,
        schoolName: widget.schoolName,
        type: 'loan',
        data: data,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan saved!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving loan: $e')),
      );
    }
  }

  Future<void> _makePayment() async {
    final payment = double.tryParse(_paymentCtrl.text) ?? 0;
    if (payment <= 0 || payment > _remaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid payment amount')),
      );
      return;
    }

    try {
      await _service.updateLoanRemaining(
        classId: widget.classId,
        schoolName: widget.schoolName,
        docId: 'fixed-loan-doc-id',  // Use a fixed ID for loan document
        remaining: _remaining - payment,
      );

      setState(() {
        _remaining -= payment;
        _remainingCtrl.text = _remaining.toStringAsFixed(2);
      });

      _paymentCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error recording payment: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Loan Application', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Loan Amount (KSH)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rateCtrl,
              decoration: const InputDecoration(
                labelText: 'Interest Rate (%)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _interestCtrl,
              decoration: const InputDecoration(
                labelText: 'Interest (KSH)',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _totalRepaymentCtrl,
              decoration: const InputDecoration(
                labelText: 'Total Repayment (KSH)',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remainingCtrl,
              decoration: const InputDecoration(
                labelText: 'Remaining (KSH)',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _principal > 0 ? _saveLoan : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 52),
              ),
              child: const Text('Save Loan Details', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),

            const Divider(height: 40),

            // FIXED: Proper spread operator
            if (_principal > 0) ...[
              const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              TextField(
                controller: _paymentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Payment Amount (KSH)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Text('Date: ${_paymentDate.toLocal().toString().split(' ')[0]}'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _paymentDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setState(() => _paymentDate = d);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _makePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('Record Payment', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}