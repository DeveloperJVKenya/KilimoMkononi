import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_management_page.dart';
import 'package:kilimomkononi/screens/pest%20management/photo_diagnosis_page.dart';
import 'package:kilimomkononi/screens/disease%20management/user_disease_history_page.dart';
import 'package:kilimomkononi/screens/analysis/farmer_plot_analysis_screen.dart';
import 'package:kilimomkononi/services/offline_queue_service.dart';
import 'package:kilimomkononi/widgets/offline_sync_banner.dart';

class DiseaseManagementHomePage extends StatefulWidget {
  const DiseaseManagementHomePage({super.key});

  @override
  State<DiseaseManagementHomePage> createState() => _DiseaseManagementHomePageState();
}

class _DiseaseManagementHomePageState extends State<DiseaseManagementHomePage> {
  // Color Constants - All-weather visibility optimized
  static const _darkGreen = Color.fromARGB(255, 3, 39, 4);
  static const _accentGreen = Color(0xFF2A6B2A);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _amber = Color(0xFFFFF8E1);
  static const _amberText = Color(0xFFE65100);
  static const _blue = Color(0xFFE3F2FD);
  static const _blueText = Color(0xFF1565C0);
  static const _teal = Color(0xFFE0F2F1);
  static const _tealText = Color(0xFF00695C);
  static const _pageBg = Color(0xFFF4F6F3);

  late final String _userId;
  int _activeCrops = 0;
  int _flaggedDiseases = 0;
  List<DiseaseIntervention> _recentInterventions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _loadData();
    OfflineQueueService.init();
  }

  Future<void> _loadData() async {
    try {
      // Load active crops from field data
      final fieldDataSnap = await FirebaseFirestore.instance
          .collection('fielddata')
          .where('userId', isEqualTo: _userId)
          .get();

      final uniqueCrops = <String>{};
      for (var doc in fieldDataSnap.docs) {
        final data = doc.data();
        if (data['crops'] is List && (data['crops'] as List).isNotEmpty) {
          final crop = (data['crops'] as List).first;
          if (crop is Map && crop['type'] != null) {
            uniqueCrops.add(crop['type'].toString());
          }
        }
      }

      // Load recent interventions
      final interventionSnap = await FirebaseFirestore.instance
          .collection('diseaseinterventiondata')
          .where('userId', isEqualTo: _userId)
          .where('isDeleted', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();

      if (mounted) {
        setState(() {
          _activeCrops = uniqueCrops.length;
          // Count high-risk diseases (simplified - in production, check disease risk levels)
          _flaggedDiseases = interventionSnap.docs.isNotEmpty ? 2 : 0;
          _recentInterventions = interventionSnap.docs
              .map((doc) =>
                  DiseaseIntervention.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>, null))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      debugPrint('Error loading disease management data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Disease Management',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: _darkGreen,
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            alignment: Alignment.centerLeft,
            child: Text(
              'Season ${DateTime.now().year}  ·  $_activeCrops active crop${_activeCrops == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: _accentGreen,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Offline sync banner (hidden when queue is empty) ──────────
            const OfflineSyncBanner(),
            const SizedBox(height: 4),
            // ── Summary Stats ─────────────────────────────────
            _buildStatsRow(),

            // ── Identify & Protect ──────────────────────────────────
            _sectionLabel('Identify & Protect'),
            _structureCard(
              icon: Icons.healing_rounded,
              iconBg: _lightGreen,
              iconColor: _accentGreen,
              title: 'Manual Diagnosis',
              description: 'Identify disease from leaf symptoms',
              badge: '4 steps',
              badgeColor: const Color(0xFF1B5E20),
              badgeBg: _lightGreen,
              onTap: () => _navigateToManualDiagnosis(),
            ),
            _structureCard(
              icon: Icons.camera_alt_rounded,
              iconBg: _amber,
              iconColor: _amberText,
              title: 'Photo Diagnosis',
              description: 'Use camera for instant AI identification',
              onTap: () => _navigateToPhotoDiagnosis(),
            ),
            _structureCard(
              icon: Icons.shield_rounded,
              iconBg: _blue,
              iconColor: _blueText,
              title: 'Quick Intervention',
              description: 'Directly log a management action',
              onTap: () => _showQuickInterventionDialog(),
            ),

            // ── Flagged Items ──────────────────────────────────
            if (!_isLoading && _recentInterventions.isNotEmpty) ...[
              _sectionLabel('Recent Management'),
              ..._recentInterventions.map((intervention) => _recentInterventionCard(intervention)),
            ],

            // ── Resources ─────────────────────────────────
            _sectionLabel('Resources'),
            _quickCard(
              icon: Icons.history_rounded,
              iconBg: _teal,
              iconColor: _tealText,
              title: 'Management History',
              description: 'All diagnosis & management records',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserDiseaseHistoryPage(),
                ),
              ),
            ),
            _quickCard(
              icon: Icons.warning_amber_rounded,
              iconBg: _amber,
              iconColor: _amberText,
              title: 'Risk Assessment',
              description: 'Seasonal disease risk report & forecast',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FarmerPlotAnalysisScreen(
                    plotId: 'AllCrops',
                    cycleName: 'Season ${DateTime.now().year}',
                  ),
                ),
              ),
            ),
            _quickCard(
              icon: Icons.library_books_rounded,
              iconBg: _lightGreen,
              iconColor: _accentGreen,
              title: 'Disease Guide',
              description: 'Prevention strategies & treatment options',
              onTap: () => _showDiseaseGuide(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              value: _activeCrops.toString(),
              label: 'Crops',
              icon: Icons.grass_rounded,
              color: _accentGreen,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _statCard(
              value: _flaggedDiseases.toString(),
              label: 'Monitored',
              icon: Icons.trending_up_rounded,
              color: _blueText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        color: Colors.black45,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    ),
  );

  Widget _structureCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
    String? badge,
    Color? badgeColor,
    Color? badgeBg,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                color: badgeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentInterventionCard(DiseaseIntervention intervention) {
    final cropLabel = intervention.cropType;
    final diseaseLabel = intervention.diseaseName;
    final dateLabel = _timeAgo(intervention.timestamp.toDate());

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$cropLabel · $diseaseLabel',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Managed',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Stage: ${intervention.cropStage} · $dateLabel',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Action: ${intervention.intervention}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
            if (intervention.dosage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Dosage: ${intervention.dosage} ${intervention.unit ?? ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black26,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  void _navigateToManualDiagnosis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DiseaseManagementPage(),
      ),
    ).then((_) => _loadData());
  }

  void _navigateToPhotoDiagnosis() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhotoDiagnosisPage(),
      ),
    ).then((_) => _loadData());
  }

  void _showQuickInterventionDialog() {
    
    // This should allow selecting crop & disease, then go directly to intervention logging
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quick Intervention feature coming soon')),
    );
  }

  void _showDiseaseGuide() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disease Guide coming soon')),
    );
  }
}