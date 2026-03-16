// farming_tips_widget.dart - UPDATED WITH Image.asset
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

class FarmingTipsWidget extends StatefulWidget {
  const FarmingTipsWidget({super.key});

  @override
  State<FarmingTipsWidget> createState() => _FarmingTipsWidgetState();
}

class _FarmingTipsWidgetState extends State<FarmingTipsWidget> {
  String? selectedCrop;
  late Future<Map<String, dynamic>> _tipsFuture;

  final Map<String, bool> _expandedCrops = {};

  @override
  void initState() {
    super.initState();
    _tipsFuture = rootBundle
        .loadString('assets/farming_tips/kilimo_farming_tips.json')
        .then((jsonStr) => json.decode(jsonStr) as Map<String, dynamic>);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farming Tips'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _tipsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error loading tips: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color.fromARGB(255, 3, 39, 4)));
          }

          final tipsData = snapshot.data!;

          return Column(
            children: [
              // Crop Selector
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCrop,
                  hint: const Text('Select a crop to view tips', style: TextStyle(fontSize: 16)),
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color.fromARGB(255, 3, 39, 4), width: 2),
                    ),
                  ),
                  items: tipsData.keys.map((crop) {
                    final icon = tipsData[crop]['icon'] ?? 'Seedling';
                    return DropdownMenuItem(
                      value: crop,
                      child: Text('$icon ${crop.capitalize()}', style: const TextStyle(fontSize: 17)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedCrop = value);
                  },
                ),
              ),

              // Tips Content
              Expanded(
                child: selectedCrop == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.menu_book, size: 90, color: const Color.fromARGB(255, 3, 39, 4).withOpacity(0.7)),
                            const SizedBox(height: 24),
                            const Text('Select a crop to view detailed farming guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.grey)),
                            const SizedBox(height: 12),
                            const Text('Rich tips with images and best practices', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (tipsData[selectedCrop] != null) ..._buildCropTips(tipsData[selectedCrop], selectedCrop!),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCropTips(Map<String, dynamic> cropData, String cropKey) {
    final List<Widget> widgets = [];
    final bool isExpanded = _expandedCrops[cropKey] ?? false;

    widgets.add(
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ExpansionTile(
          initiallyExpanded: isExpanded,
          onExpansionChanged: (expanded) => setState(() => _expandedCrops[cropKey] = expanded),
          leading: CircleAvatar(
            backgroundColor: Colors.green.withOpacity(0.1),
            child: Text(cropData['icon'] ?? '🌱', style: const TextStyle(fontSize: 28)),
          ),
          title: Text(
            cropKey.capitalize(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          childrenPadding: const EdgeInsets.all(16),
          children: [
            // General Tips
            if (cropData['general'] != null) ...[
              const Text("General Tips", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 3,39,4))),
              const SizedBox(height: 12),
              if (cropData['image_general'] != null) 
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(  // Changed to Image.asset
                    'assets/${cropData['image_general'] as String}',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, err, _) => Container(
                      height: 180, 
                      color: Colors.grey[200],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image),
                          Text('Failed: $err', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              MarkdownBody(data: cropData['general'].replaceAll('- ', '\n- ')),
              const Divider(height: 40),
            ],

            // Growth Stages
            if (cropData['stages'] != null) ...[
              const Text("Growth Stages", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 3,39,4))),
              const SizedBox(height: 12),
              ...(cropData['stages'] as Map<String, dynamic>).entries.map((stage) {
                final stageName = stage.key;
                final stageData = stage.value as Map<String, dynamic>;
                final tips = stageData['tips'] ?? '';
                final image = stageData['image'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stageName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17, color: Color.fromARGB(255, 3, 39, 4))),
                      const SizedBox(height: 10),
                      if (image != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(  // Changed to Image.asset
                            'assets/$image',
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, err, _) => Container(
                              height: 180, 
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.broken_image),
                                  Text('Failed: $err', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      MarkdownBody(data: tips.replaceAll('- ', '\n- ')),
                    ],
                  ),
                );
              }),
              const Divider(height: 40),
            ],

            // Popular Varieties
            if (cropData['varieties'] != null) ...[
              const Text("Popular Varieties in Kenya", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color.fromARGB(255, 3, 39, 4))),
              const SizedBox(height: 12),
              ...(cropData['varieties'] as Map<String, dynamic>).entries.map((variety) {
                final name = variety.key;
                final data = variety.value as Map<String, dynamic>;
                final bestFor = data['best_for'] ?? '';
                final tips = data['tips'] ?? '';
                final image = data['image'] as String?;

                return Card(
                  color: Colors.green.shade50,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ExpansionTile(
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: bestFor.isNotEmpty
                        ? Text("Best for: $bestFor", style: const TextStyle(color: Colors.green, fontStyle: FontStyle.italic))
                        : null,
                    children: [
                      if (image != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(  // Changed to Image.asset
                              'assets/$image',
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, err, _) => Container(
                                height: 160, 
                                color: Colors.grey[200],
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.broken_image),
                                    Text('Failed: $err', style: TextStyle(color: Colors.red, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: MarkdownBody(data: tips),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );

    return widgets;
  }
}

extension StringExtension on String {
  String capitalize() {
    return isNotEmpty ? '${this[0].toUpperCase()}${substring(1).toLowerCase()}' : this;
  }
}