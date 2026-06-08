// lib/screens/pests_diseases_home.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:kilimomkononi/screens/pest%20management/pest_management_home.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_management_home.dart';
import 'package:kilimomkononi/screens/symptom_checker_page.dart';

const _kGreen = Color.fromARGB(255, 3, 39, 4);

// ── Breakpoints ───────────────────────────────────────────────────────────────
enum _Screen { mobile, tablet, desktop }

_Screen _screenOf(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w >= 1100) return _Screen.desktop;
  if (w >= 650) return _Screen.tablet;
  return _Screen.mobile;
}

// ─────────────────────────────────────────────────────────────────────────────
class PestDiseaseHomePage extends StatelessWidget {
  const PestDiseaseHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screen = _screenOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pest & Disease Management',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[100],
        child: screen == _Screen.mobile
            ? const _MobileLayout()
            : _WideLayout(screen: screen),
      ),
    );
  }
}

// ── Mobile: Vertical Stack ───────────────────────────────────────────────────
class _MobileLayout extends StatelessWidget {
  const _MobileLayout();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
          const _PageHeader(),
          const SizedBox(height: 36),
          _OptionCard(
            title: 'Manage Pests',
            subtitle: 'View pest guides, interventions & history',
            icon: Icons.bug_report,
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PestManagementHomePage()),
            ),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            title: 'Manage Diseases',
            subtitle: 'View disease guides, fungicides & history',
            icon: Icons.local_hospital,
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DiseaseManagementHomePage()),
            ),
          ),
          const SizedBox(height: 16),
          _OptionCard(
            title: 'Symptom Checker',
            subtitle: 'Describe symptoms to identify the issue',
            icon: Icons.search,
            color: const Color(0xFF6A1B9A),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SymptomCheckerPage()),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Tablet & Desktop: Horizontal Layout (3 cards side by side) ───────────────
class _WideLayout extends StatelessWidget {
  final _Screen screen;
  const _WideLayout({required this.screen});

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = screen == _Screen.desktop ? 48.0 : 32.0;
    final maxWidth = screen == _Screen.desktop ? 1200.0 : 900.0;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            children: [
              const _PageHeader(),
              const SizedBox(height: 40),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _OptionCard(
                      title: 'Manage Pests',
                      subtitle: 'View pest guides, interventions & history',
                      icon: Icons.bug_report,
                      color: const Color(0xFF2E7D32),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PestManagementHomePage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _OptionCard(
                      title: 'Manage Diseases',
                      subtitle: 'View disease guides, fungicides & history',
                      icon: Icons.local_hospital,
                      color: const Color(0xFF1565C0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DiseaseManagementHomePage()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _OptionCard(
                      title: 'Symptom Checker',
                      subtitle: 'Describe symptoms to identify the issue',
                      icon: Icons.search,
                      color: const Color(0xFF6A1B9A),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SymptomCheckerPage()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page Header ─────────────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kGreen.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.agriculture, size: 48, color: _kGreen),
        ),
        const SizedBox(height: 16),
        const Text(
          'Pest & Disease Management',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kGreen),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Choose a tool to manage your farm',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Option Card ─────────────────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withOpacity(0.1),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}