// lib/education/farm_management/utils/extensions.dart
extension StringX on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}