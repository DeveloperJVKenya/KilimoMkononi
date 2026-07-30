// lib/education/primary/primary_language_toggle.dart

import 'package:flutter/material.dart';
import 'primary_ai_service.dart';

/// A compact flag-style toggle that switches between English and Swahili.
/// Used in PrimaryAiTooltip, PrimaryFarmingStoryScreen, and any other
/// AI feature that supports the [PrimaryLanguage] parameter.
///
/// Usage:
///   PrimaryLanguageToggle(
///     value: _language,
///     onChanged: (lang) => setState(() => _language = lang),
///   )
class PrimaryLanguageToggle extends StatelessWidget {
  final PrimaryLanguage value;
  final ValueChanged<PrimaryLanguage> onChanged;

  const PrimaryLanguageToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSwahili = value == PrimaryLanguage.swahili;
    return GestureDetector(
      onTap: () => onChanged(isSwahili ? PrimaryLanguage.english : PrimaryLanguage.swahili),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSwahili
              ? const Color(0xFF006600).withValues(alpha: 0.12)
              : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSwahili ? const Color(0xFF006600).withValues(alpha: 0.3) : Colors.blue.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(isSwahili ? '🇰🇪' : '🇬🇧', style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(
            isSwahili ? 'Kiswahili' : 'English',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isSwahili ? const Color(0xFF006600) : Colors.blue.shade700,
            ),
          ),
        ]),
      ),
    );
  }
}