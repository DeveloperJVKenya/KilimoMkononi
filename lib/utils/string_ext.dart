// lib/utils/string_ext.dart
extension StringExt on String {
  String capitalize() => isNotEmpty
      ? '${this[0].toUpperCase()}${substring(1)}'
      : this;
}