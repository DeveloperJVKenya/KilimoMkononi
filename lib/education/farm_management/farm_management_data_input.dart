// lib/education/farm_management/farm_management_data_input.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/utils/education_utils.dart'; // This imports buildFullGradeId

const Color primaryGreen = Color(0xFF003900);

final List<String> costCategories = [
  'Labour', 'Equipment & Machinery', 'Seeds & Fertilizer', 'Chemicals & Pesticides',
  'Transport', 'Land Rent/Preparation', 'Irrigation', 'Miscellaneous',
];

final List<String> revenueSources = [
  'Maize Sales', 'Beans Sales', 'Vegetable Sales', 'Livestock',
  'Fruits', 'Value-Added Products', 'Other Crops', 'Grants/Subsidies',
];

extension StringExt on String {
  String capitalize() => isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : this;
}

class FarmManagementDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;

  const FarmManagementDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
  });

  @override
  State<FarmManagementDataInput> createState() => _FarmManagementDataInputState();
}

class _FarmManagementDataInputState extends State<FarmManagementDataInput>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isHeadteacher = false;
  String _normalizedSchoolName = '';

  CollectionReference? _dataCollection;

  List<String> _availableClasses = [];
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _isHeadteacher = widget.role == EduRole.headteacher;
    _normalizedSchoolName = widget.schoolName.trim().replaceAll(' ', '_');

    if (_isHeadteacher) {
      _loadAvailableClasses();
    } else if (widget.classId.isNotEmpty) {
      _selectedClassId = widget.classId;
      _loadDataForClass(widget.classId);
    }
  }

  Future<void> _loadAvailableClasses() async {
    final systemsColl = FirestoreHelper.getSystemsCollection(_normalizedSchoolName);
    final systemsSnap = await systemsColl.get();

    List<String> classes = [];

    for (var systemDoc in systemsSnap.docs) {
      final systemId = systemDoc.id; // e.g., 'junior'
      final gradesColl = FirestoreHelper.getGradesCollection(_normalizedSchoolName, systemId);
      final gradesSnap = await gradesColl.get();

      for (var gradeDoc in gradesSnap.docs) {
        final gradeId = gradeDoc.id; // e.g., '7'

        // Use the SAME function used everywhere else in the app
        final fullClassId = buildFullGradeId(
          widget.schoolName,
          gradeId,
          _mapSystemToEnumName(systemId),
        );

        classes.add(fullClassId);
      }
    }

    setState(() {
      _availableClasses = classes;
      if (classes.isNotEmpty && _selectedClassId == null) {
        _selectedClassId = classes.first;
        _loadDataForClass(_selectedClassId!);
      }
    });
  }

  // Helper to map Firestore system string to the enum name used in buildFullGradeId
  String _mapSystemToEnumName(String systemId) {
    return switch (systemId) {
      'primary' => 'cbcPrimary',
      'junior' => 'cbcJunior',
      'senior' => 'cbcSenior',
      'eightfourfour' => 'eightFourFour',
      _ => 'cbcJunior',
    };
  }

  void _loadDataForClass(String classId) {
    print('DEBUG: Loading classId = $classId');

    final collection = FirestoreHelper.getContentFromClassId(classId, 'farm_management_data');

    print('DEBUG: Collection path = ${collection?.path}');

    if (collection == null) {
      print('ERROR: getContentFromClassId returned null for $classId');
    }

    setState(() {
      _dataCollection = collection;
      _selectedClassId = classId;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = _dataCollection != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isHeadteacher ? 'School Farm Management' : 'Farm Management',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Records'),
            Tab(icon: Icon(Icons.bar_chart), text: 'P&L'),
            Tab(icon: Icon(Icons.account_balance), text: 'Loans'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isHeadteacher && _availableClasses.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonFormField<String>(
                value: _selectedClassId,
                hint: const Text('Select a class'),
                decoration: const InputDecoration(
                  labelText: 'Select Class/Grade',
                  border: OutlineInputBorder(),
                ),
                items: _availableClasses.map((id) {
                  return DropdownMenuItem(
                    value: id,
                    child: Text(id.replaceAll('_', ' ')),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _loadDataForClass(value);
                  }
                },
              ),
            ),
          Expanded(
            child: hasData
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      DashboardTabContent(dataSource: _dataCollection!),
                      RecordsTabContent(
                        dataSource: _dataCollection!,
                        isTeacher: widget.role == EduRole.teacher,
                        isHeadteacher: _isHeadteacher,
                        normalizedSchoolName: _normalizedSchoolName,
                      ),
                      ProfitLossTabContent(dataSource: _dataCollection!),
                      LoansTabContent(
                        dataSource: _dataCollection!,
                        isTeacher: widget.role == EduRole.teacher,
                        isHeadteacher: _isHeadteacher,
                        normalizedSchoolName: _normalizedSchoolName,
                      ),
                    ],
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: _isHeadteacher
                          ? const Text(
                              'Select a class from the dropdown to view farm data',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            )
                          : const Text(
                              'No data available yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ======================== DASHBOARD ========================
class DashboardTabContent extends StatelessWidget {
  final CollectionReference dataSource;

  const DashboardTabContent({super.key, required this.dataSource});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataSource.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryGreen));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No financial data yet', style: TextStyle(fontSize: 18)));
        }

        double totalCost = 0, totalRevenue = 0;
        final costBreakdown = <String, double>{};

        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
          if (data['type'] == 'cost') {
            totalCost += amount;
            final cat = data['category'] ?? 'Other';
            costBreakdown[cat] = (costBreakdown[cat] ?? 0) + amount;
          } else if (data['type'] == 'revenue') {
            totalRevenue += amount;
          }
        }
        final profit = totalRevenue - totalCost;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (costBreakdown.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('Cost Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: PieChart(PieChartData(
                            sections: costBreakdown.entries.map((entry) {
                              return PieChartSectionData(
                                value: entry.value,
                                title: entry.key,
                                color: Colors.primaries[costBreakdown.keys.toList().indexOf(entry.key) % Colors.primaries.length],
                                radius: 70,
                                titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                              );
                            }).toList(),
                            centerSpaceRadius: 30,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _card('Total Revenue', totalRevenue, Icons.trending_up, Colors.green),
              const SizedBox(height: 12),
              _card('Total Costs', totalCost, Icons.trending_down, Colors.red),
              const SizedBox(height: 12),
              _card('Net ${profit >= 0 ? "Profit" : "Loss"}', profit.abs(),
                  profit >= 0 ? Icons.monetization_on : Icons.money_off,
                  profit >= 0 ? Colors.green : Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _card(String title, double amount, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text('KES ${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}

// ======================== RECORDS TAB ========================
class RecordsTabContent extends StatelessWidget {
  final CollectionReference dataSource;
  final bool isTeacher;
  final bool isHeadteacher;
  final String normalizedSchoolName;

  const RecordsTabContent({
    super.key,
    required this.dataSource,
    required this.isTeacher,
    required this.isHeadteacher,
    required this.normalizedSchoolName,
  });

  static const Map<String, List<String>> costSubCategories = {
    'Labour': ['Manual Workers', 'Skilled Labour', 'Supervisor', 'Casual Workers', 'Family Labour'],
    'Equipment & Machinery': ['Tractor Hire', 'Ploughing', 'Harvester', 'Tools Purchase', 'Repairs'],
    'Seeds & Fertilizer': ['Maize Seeds', 'Bean Seeds', 'Fertilizer (DAP/CAN)', 'Manure', 'Lime'],
    'Chemicals & Pesticides': ['Herbicides', 'Insecticides', 'Fungicides', 'Rodenticides'],
    'Transport': ['Produce to Market', 'Input Delivery', 'Worker Transport'],
    'Land Rent/Preparation': ['Land Rent', 'Land Clearing', 'Ploughing Service'],
    'Irrigation': ['Fuel for Pump', 'Pipe Repairs', 'Water Fees'],
    'Miscellaneous': ['Packaging', 'Storage', 'Insurance', 'Licenses', 'Other'],
  };

  static const Map<String, List<String>> revenueSubSources = {
    'Maize Sales': ['Fresh Maize', 'Dry Maize', 'Maize Flour Sales'],
    'Beans Sales': ['Dry Beans', 'Fresh Beans', 'Bean Leaves'],
    'Vegetable Sales': ['Tomatoes', 'Cabbage', 'Onions', 'Kales/Sukuma'],
    'Livestock': ['Milk Sales', 'Eggs', 'Chicken', 'Goats'],
    'Fruits': ['Mangoes', 'Avocado', 'Bananas', 'Oranges'],
    'Value-Added Products': ['Maize Flour', 'Bean Flour', 'Dried Vegetables'],
    'Other Crops': ['Sunflower', 'Groundnuts', 'Sorghum'],
    'Grants/Subsidies': ['Government Support', 'NGO Aid', 'School Funding'],
  };

  String _extractGradeFromPath(String path) {
    final parts = path.split('/');
    if (parts.length >= 8 && parts[parts.length - 4] == 'grades') {
      return parts[parts.length - 2].replaceAll('_', ' ');
    }
    return 'Unknown Grade';
  }

  void _showAddEntryDialog(BuildContext context, String type) {
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    String? selectedCategory;
    String? selectedSubCategory;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add ${type.capitalize()} Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: (type == 'cost' ? costCategories : revenueSources)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = v;
                      selectedSubCategory = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (selectedCategory != null)
                  DropdownButtonFormField<String>(
                    value: selectedSubCategory,
                    decoration: const InputDecoration(labelText: 'Specific Activity'),
                    items: (type == 'cost'
                            ? costSubCategories[selectedCategory] ?? []
                            : revenueSubSources[selectedCategory] ?? [])
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedSubCategory = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. Hired 5 workers for weeding',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (KES)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 || selectedCategory == null) return;

                dataSource.add({
                  'type': type,
                  'category': selectedCategory,
                  'subCategory': selectedSubCategory ?? '',
                  'description': descriptionCtrl.text.trim(),
                  'amount': amount,
                  'schoolName': normalizedSchoolName,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${type.capitalize()} entry added!')),
                );
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _editEntry(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final descriptionCtrl = TextEditingController(text: data['description'] ?? '');
    final amountCtrl = TextEditingController(text: (data['amount'] as num?)?.toString() ?? '');

    String? selectedCategory = data['category'];
    String? selectedSubCategory = data['subCategory'];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit ${data['type'].capitalize()} Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: (data['type'] == 'cost' ? costCategories : revenueSources)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      selectedCategory = v;
                      selectedSubCategory = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (selectedCategory != null)
                  DropdownButtonFormField<String>(
                    value: selectedSubCategory,
                    decoration: const InputDecoration(labelText: 'Specific Activity'),
                    items: (data['type'] == 'cost'
                            ? costSubCategories[selectedCategory] ?? []
                            : revenueSubSources[selectedCategory] ?? [])
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedSubCategory = v),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount (KES)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text) ?? 0;
                if (amount <= 0 || selectedCategory == null) return;

                doc.reference.update({
                  'category': selectedCategory,
                  'subCategory': selectedSubCategory ?? '',
                  'description': descriptionCtrl.text.trim(),
                  'amount': amount,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry updated!')));
              },
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteEntry(BuildContext context, QueryDocumentSnapshot doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await doc.reference.delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entry deleted')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataSource.orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryGreen));
        }

        final docs = snapshot.data?.docs ?? [];
        final costs = docs.where((d) => (d.data() as Map)['type'] == 'cost').toList();
        final revenues = docs.where((d) => (d.data() as Map)['type'] == 'revenue').toList();

        return DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [Tab(text: 'Costs'), Tab(text: 'Revenue')],
                labelColor: primaryGreen,
                indicatorColor: primaryGreen,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildEntryList(costs, 'cost', context),
                    _buildEntryList(revenues, 'revenue', context),
                  ],
                ),
              ),
              if (isTeacher && !isHeadteacher)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddEntryDialog(context, 'cost'),
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Add Cost'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showAddEntryDialog(context, 'revenue'),
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('Add Revenue'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntryList(List<QueryDocumentSnapshot> entries, String type, BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Text('No ${type}s recorded yet', style: const TextStyle(fontSize: 18, color: Colors.grey)),
      );
    }

    Map<String, List<QueryDocumentSnapshot>> groupedByGrade = {};
    if (isHeadteacher) {
      for (var doc in entries) {
        final grade = _extractGradeFromPath(doc.reference.path);
        groupedByGrade.putIfAbsent(grade, () => []);
        groupedByGrade[grade]!.add(doc);
      }
    }

    if (isHeadteacher && groupedByGrade.isNotEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedByGrade.length,
        itemBuilder: (_, i) {
          final grade = groupedByGrade.keys.elementAt(i);
          final gradeEntries = groupedByGrade[grade]!;
          final gradeTotal = gradeEntries.fold<double>(
            0.0,
            (sum, doc) {
              final amount = (doc.data() as Map<String, dynamic>)['amount'] as num?;
              return sum + (amount?.toDouble() ?? 0.0);
            },
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ExpansionTile(
              title: Text('Grade $grade', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              subtitle: Text(
                '${gradeEntries.length} entries • KES ${gradeTotal.toStringAsFixed(0)}',
                style: TextStyle(
                  color: type == 'cost' ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: gradeEntries.map((doc) => _buildEntryCard(doc, type, context)).toList(),
            ),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entries.length,
      itemBuilder: (_, i) => _buildEntryCard(entries[i], type, context),
    );
  }

  Widget _buildEntryCard(QueryDocumentSnapshot doc, String type, BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final date = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(data['category'] ?? 'Unknown'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data['subCategory']?.toString().isNotEmpty == true)
              Text(data['subCategory'], style: const TextStyle(fontWeight: FontWeight.w600)),
            if (data['description']?.toString().isNotEmpty == true)
              Text(data['description'], style: const TextStyle(fontStyle: FontStyle.italic)),
            if (date != null) Text('Date: ${date.day}/${date.month}/${date.year}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'KES ${amount.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: type == 'cost' ? Colors.red : Colors.green,
              ),
            ),
            if (isTeacher && !isHeadteacher) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editEntry(context, doc),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteEntry(context, doc),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================== P&L TAB ========================
class ProfitLossTabContent extends StatelessWidget {
  final CollectionReference dataSource;

  const ProfitLossTabContent({super.key, required this.dataSource});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dataSource.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryGreen));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No financial data yet', style: TextStyle(fontSize: 18)));
        }

        double revenue = 0, cost = 0;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final amount = (data['amount'] as num?)?.toDouble() ?? 0;
          if (data['type'] == 'revenue') revenue += amount;
          if (data['type'] == 'cost') cost += amount;
        }
        final profit = revenue - cost;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _pnlRow('Total Revenue', revenue, Colors.green),
              const SizedBox(height: 12),
              _pnlRow('Total Costs', cost, Colors.red),
              const Divider(height: 32),
              _pnlRow('Net Profit/Loss', profit, profit >= 0 ? Colors.green : Colors.red, bold: true),
            ],
          ),
        );
      },
    );
  }

  Widget _pnlRow(String label, double amount, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 18, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text('KES ${amount.toStringAsFixed(0)}', style: TextStyle(fontSize: 18, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

// ======================== LOANS TAB ========================
class LoansTabContent extends StatelessWidget {
  final CollectionReference dataSource;
  final bool isTeacher;
  final bool isHeadteacher;
  final String normalizedSchoolName;

  const LoansTabContent({
    super.key,
    required this.dataSource,
    required this.isTeacher,
    required this.isHeadteacher,
    required this.normalizedSchoolName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: (isTeacher && !isHeadteacher)
          ? FloatingActionButton.extended(
              backgroundColor: primaryGreen,
              onPressed: () => _showAddLoanDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Loan'),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: dataSource.where('type', isEqualTo: 'loan').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryGreen));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  isHeadteacher ? 'No loans across school yet' : (isTeacher ? 'No loans yet\nTap + to add one' : 'No loan records yet'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (_, i) => LoanCard(doc: snapshot.data!.docs[i], isTeacher: isTeacher && !isHeadteacher),
          );
        },
      ),
    );
  }

  void _showAddLoanDialog(BuildContext context) {
    final lenderCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Loan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: lenderCtrl, decoration: const InputDecoration(labelText: 'Lender')),
              TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (KES)')),
              TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Interest Rate (%)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountCtrl.text) ?? 0;
              if (amount > 0) {
                dataSource.add({
                  'type': 'loan',
                  'lender': lenderCtrl.text.trim().isEmpty ? 'Bank' : lenderCtrl.text.trim(),
                  'amount': amount,
                  'interestRate': double.tryParse(rateCtrl.text) ?? 0,
                  'paid': 0.0,
                  'remaining': amount,
                  'repayments': [],
                  'schoolName': normalizedSchoolName,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Loan added!')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class LoanCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final bool isTeacher;

  const LoanCard({super.key, required this.doc, required this.isTeacher});

  @override
  State<LoanCard> createState() => _LoanCardState();
}

class _LoanCardState extends State<LoanCard> {
  final _payCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final remaining = (data['remaining'] as num?)?.toDouble() ?? 0.0;
    final paid = amount - remaining;

    return Card(
      child: ExpansionTile(
        title: Text(data['lender'] ?? 'Loan', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(remaining > 0 ? 'Remaining: KES ${remaining.toStringAsFixed(0)}' : 'FULLY PAID',
            style: TextStyle(color: remaining > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Amount: KES ${amount.toStringAsFixed(0)}'),
                Text('Interest: ${data['interestRate'] ?? 0}%'),
                Text('Paid: KES ${paid.toStringAsFixed(0)}'),
                Text('Outstanding: KES ${remaining.toStringAsFixed(0)}',
                    style: TextStyle(color: remaining > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                if (widget.isTeacher && remaining > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _payCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Repay Amount'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final pay = double.tryParse(_payCtrl.text) ?? 0;
                          if (pay > 0 && pay <= remaining) {
                            widget.doc.reference.update({
                              'remaining': remaining - pay,
                              'repayments': FieldValue.arrayUnion([{'amount': pay, 'date': FieldValue.serverTimestamp()}]),
                            });
                            _payCtrl.clear();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment recorded!')));
                          }
                        },
                        child: const Text('Pay'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}