// lib/education/farm_management/models/farm_cycle.dart
class FarmCycle {
  final String name;
  final List<Map<String, dynamic>> labour;
  final List<Map<String, dynamic>> mechanical;
  final List<Map<String, dynamic>> inputs;
  final List<Map<String, dynamic>> misc;
  final List<Map<String, dynamic>> revenues;
  final List<Map<String, dynamic>> payments;
  final double loanAmount;
  final double interestRate;

  FarmCycle({
    required this.name,
    this.labour = const [],
    this.mechanical = const [],
    this.inputs = const [],
    this.misc = const [],
    this.revenues = const [],
    this.payments = const [],
    this.loanAmount = 0,
    this.interestRate = 0,
  });

  double get totalCost =>
      labour.fold(0.0, (s, i) => s + (double.tryParse(i['cost'] ?? '0') ?? 0)) +
      mechanical.fold(0.0, (s, i) => s + (double.tryParse(i['cost'] ?? '0') ?? 0)) +
      inputs.fold(0.0, (s, i) => s + (double.tryParse(i['cost'] ?? '0') ?? 0)) +
      misc.fold(0.0, (s, i) => s + (double.tryParse(i['cost'] ?? '0') ?? 0));

  double get totalRevenue =>
      revenues.fold(0.0, (s, i) => s + (double.tryParse(i['amount'] ?? '0') ?? 0));

  double get profitLoss => totalRevenue - totalCost;
}