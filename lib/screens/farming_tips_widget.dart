import 'package:flutter/material.dart';

class FarmingTipsWidget extends StatefulWidget {
  const FarmingTipsWidget({super.key});

  @override
  FarmingTipsWidgetState createState() => FarmingTipsWidgetState();
}

class FarmingTipsWidgetState extends State<FarmingTipsWidget> {
  String? _selectedCrop; // Used as title
  String _cropTip = '';
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredCrops = [];
  final FocusNode _searchFocusNode = FocusNode();

  // Farming guide tailored for Kenyan conditions
  final Map<String, String> _farmingGuide = {
    'maize': '''
🌱 **Planting Season**  
Plant at the onset of the long rains (March-May) or short rains (October-November) for best yields.  

🌍 **Soil Requirements**  
Use fertile, well-draining soil enriched with compost or manure, pH 5.5-7.0.  

📏 **Spacing**  
Space rows 75cm apart and plants 25cm apart to ensure good growth.  

💧 **Water Needs**  
Requires steady moisture during germination and flowering, about 500-800mm over the season.  

🔧 **Key Care Tips**  
✔️ Add manure or nitrogen fertilizer when plants are 30-45cm tall.  
✔️ Weed regularly in the first 6-8 weeks to reduce competition.  
✔️ Watch for pests like fall armyworm—use neem oil or traps.  
✔️ Rotate with legumes to improve soil fertility.  

🌾 **Harvest**  
Harvest when husks dry and kernels are firm, 90-120 days after planting.  
    ''',
    'beans': '''
🌱 **Planting Season**  
Plant at the start of the long rains (March-May) or short rains (October-November).  

🌍 **Soil Requirements**  
Fertile, well-draining soil with pH 6.0-7.0, enriched with organic matter.  

📏 **Spacing**  
Rows 30cm apart, plants 10cm apart for bush varieties; use poles for climbers.  

💧 **Water Needs**  
Provide consistent moisture, about 25mm weekly, especially during flowering.  

🔧 **Key Care Tips**  
✔️ Avoid watering leaves to prevent fungal diseases.  
✔️ Mulch soil to retain moisture in dry spells.  
✔️ Watch for bean aphids—use soapy water or natural predators.  
✔️ Plant near maize for shade and support.  

🌾 **Harvest**  
Pick snap beans at 50-65 days; dry beans at 85-100 days when pods are brittle.  
    ''',
    'rice': '''
🌱 **Planting Season**  
Start with the long rains (March-May) in lowland areas with water access.  

🌍 **Soil Requirements**  
Heavy clay soil that holds water well, pH 5.0-7.0.  

📏 **Spacing**  
Space plants 15-20cm apart in flooded fields.  

💧 **Water Needs**  
Keep fields flooded with 5-10cm water depth until flowering.  

🔧 **Key Care Tips**  
✔️ Level fields to maintain even water depth.  
✔️ Weed early using water submersion or hand removal.  
✔️ Add manure or urea fertilizer at planting.  
✔️ Watch for rice blast—avoid overcrowding.  

🌾 **Harvest**  
Harvest when grains turn golden, 120-180 days after planting.  
    ''',
    'wheat': '''
🌱 **Planting Season**  
Plant at the start of the cool, dry season (June-August).  

🌍 **Soil Requirements**  
Well-draining loamy soil with pH 6.0-7.0, enriched with compost.  

📏 **Spacing**  
Drill rows 15-20cm apart for uniform growth.  

💧 **Water Needs**  
Needs 450-650mm over the season, especially during tillering.  

🔧 **Key Care Tips**  
✔️ Apply fertilizer when plants start branching.  
✔️ Weed early to avoid competition.  
✔️ Monitor for rust—use resistant varieties if possible.  
✔️ Avoid waterlogging in heavy rains.  

🌾 **Harvest**  
Harvest when plants are golden and dry, about 120 days.  
    ''',
    'potatoes': '''
🌱 **Planting Season**  
Plant before the long rains (February-March) or short rains (September-October).  

🌍 **Soil Requirements**  
Loose, fertile soil with pH 5.0-6.5, mixed with manure.  

📏 **Spacing**  
Rows 75cm apart, plants 30cm apart.  

💧 **Water Needs**  
Keep soil moist, about 25-50mm weekly, until flowering stops.  

🔧 **Key Care Tips**  
✔️ Hill soil around plants to cover tubers.  
✔️ Stop watering when leaves yellow.  
✔️ Watch for blight—remove affected plants quickly.  
✔️ Use certified seed potatoes for better yields.  

🌾 **Harvest**  
Dig up tubers 90-120 days after planting when plants die back.  
    ''',
    'sugarcane': '''
🌱 **Planting Season**  
Plant at the start of the long rains (March-May).  

🌍 **Soil Requirements**  
Fertile, well-draining soil with pH 6.0-7.5.  

📏 **Spacing**  
Rows 1.5m apart, plants 50cm apart.  

💧 **Water Needs**  
Requires regular irrigation, especially in dry months.  

🔧 **Key Care Tips**  
✔️ Apply manure or fertilizer every 3 months.  
✔️ Weed until the canopy closes.  
✔️ Remove dry leaves to reduce pest hiding spots.  
✔️ Watch for borers—use traps or organic sprays.  

🌾 **Harvest**  
Cut stalks 10-12 months after planting when juice content peaks.  
    ''',
    'tomatoes': '''
🌱 **Planting Season**  
Plant before the long rains (February-March) or short rains (September-October).  

🌍 **Soil Requirements**  
Rich, well-draining soil with pH 6.0-6.8, enriched with compost.  

📏 **Spacing**  
Plants 60cm apart, rows 90cm apart.  

💧 **Water Needs**  
Deep watering, 25mm weekly, avoiding leaves.  

🔧 **Key Care Tips**  
✔️ Stake plants to support heavy fruit.  
✔️ Prune lower leaves for airflow.  
✔️ Add ash or lime to prevent rot.  
✔️ Watch for early blight—space plants well.  

🌾 **Harvest**  
Pick fruits 60-80 days after transplanting when red.  
    ''',
    'cabbage': '''
🌱 **Planting Season**  
Plant before the long rains (February-March) or short rains (September-October).  

🌍 **Soil Requirements**  
Rich, well-draining soil with pH 6.0-7.0.  

📏 **Spacing**  
Plants 45cm apart, rows 60cm apart.  

💧 **Water Needs**  
Consistent moisture, 25mm weekly.  

🔧 **Key Care Tips**  
✔️ Add manure for head development.  
✔️ Watch for worms—use organic sprays.  
✔️ Mulch to keep soil cool.  
✔️ Harvest early to avoid cracking.  

🌾 **Harvest**  
Cut heads when firm, 70-120 days after transplanting.  
    ''',
    'cassava': '''
🌱 **Planting Season**  
Plant at the start of the long rains (March-May).  

🌍 **Soil Requirements**  
Sandy or loamy soil with pH 5.5-7.0, well-draining.  

📏 **Spacing**  
1m between rows and plants.  

💧 **Water Needs**  
Needs moisture early, tolerates dry spells later.  

🔧 **Key Care Tips**  
✔️ Use healthy stem cuttings, 20-30cm long.  
✔️ Weed in the first 3 months.  
✔️ Watch for mosaic disease—remove sick plants.  
✔️ intercrop with beans for soil health.  

🌾 **Harvest**  
Dig roots 6-12 months after planting when leaves yellow.  
    ''',
    'kales': '''
🌱 **Planting Season**  
Plant before the long rains (February-March) or short rains (September-October).  

🌍 **Soil Requirements**  
Rich, well-draining soil with pH 6.0-7.5.  

📏 **Spacing**  
Plants 30cm apart, rows 45cm apart.  

💧 **Water Needs**  
Regular watering, 25mm weekly.  

🔧 **Key Care Tips**  
✔️ Add manure for lush leaves.  
✔️ Harvest outer leaves to keep plants growing.  
✔️ Watch for aphids—wash with soapy water.  
✔️ Mulch to retain moisture.  

🌾 **Harvest**  
Pick leaves from 50-65 days, starting with outer ones.  
    ''',
    'carrots': '''
🌱 **Planting Season**  
Plant before the long rains (February-March) or short rains (September-October).  

🌍 **Soil Requirements**  
Deep, loose soil with pH 6.0-6.8, free of stones.  

📏 **Spacing**  
Plants 5cm apart, rows 30cm apart.  

💧 **Water Needs**  
Keep soil moist, never dry, especially early on.  

🔧 **Key Care Tips**  
✔️ Thin seedlings to avoid crowding.  
✔️ Cover shoulders with soil to prevent greening.  
✔️ Add compost for sweet roots.  
✔️ Watch for root flies—use nets if needed.  

🌾 **Harvest**  
Pull roots at 70-80 days when bright orange.  
    ''',
    'general': '''
🌿 **General Farming Tips**  

🌱 **Soil Preparation**  
✔️ Test soil with local extension officers.  
✔️ Mix in manure or compost yearly.  
✔️ Dig trenches for drainage in wet areas.  

🐜 **Pest Management**  
✔️ Rotate crops every season.  
✔️ Plant marigolds to repel pests.  
✔️ Check plants weekly for early signs.  

🦠 **Disease Prevention**  
✔️ Space plants for good air flow.  
✔️ Water at the base, not leaves.  
✔️ Burn or bury sick plants.  

🌍 **Sustainable Practices**  
✔️ Use grass mulch to save water.  
✔️ Trap pests with local methods.  
✔️ Save seeds from strong plants.  
    ''',
  };

@override
  void initState() {
    super.initState();
    _filteredCrops = _farmingGuide.keys.toList();
    _searchController.addListener(_filterCrops);
    _searchFocusNode.addListener(_handleSearchFocus);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterCrops() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCrops = _farmingGuide.keys
          .where((crop) => crop.toLowerCase().contains(query))
          .toList();
    });
  }

  void _handleSearchFocus() {
    if (_searchFocusNode.hasFocus) {
      setState(() {
        _selectedCrop = null;
        _cropTip = '';
      });
    }
  }

  void _showTips(String crop) {
    setState(() {
      _selectedCrop = crop;
      _cropTip = _farmingGuide[crop] ?? 'No tips available for this crop.';
      _searchController.clear();
      _filteredCrops = _farmingGuide.keys.toList();
    });
    _searchFocusNode.unfocus();
  }

  void _submitSearch() {
    final query = _searchController.text.trim().toLowerCase();
    if (_farmingGuide.containsKey(query)) {
      _showTips(query);
    } else {
      _showSnackBar('Crop not found. Try another search.');
    }
    _searchFocusNode.unfocus();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Message as Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1), // Replaced withOpacity
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  '🌾 Welcome to Farming Tips! 🌱\nDiscover expert advice to grow your crops successfully. Search for a crop below to get tailored tips for thriving harvests!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Search Field
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submitSearch(),
                decoration: InputDecoration(
                  hintText: 'Search crops (e.g., maize, beans)...',
                  prefixIcon: const Icon(Icons.search, color: Colors.teal),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.teal),
                          onPressed: () {
                            _searchController.clear();
                            _filterCrops();
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.teal, width: 1.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.teal, width: 2),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 10),

              // Crop Suggestions
              if (_searchController.text.isNotEmpty && _filteredCrops.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3), // Replaced withOpacity
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredCrops.length,
                    itemBuilder: (context, index) {
                      final crop = _filteredCrops[index];
                      return ListTile(
                        title: Text(
                          crop.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.teal,
                            fontSize: 18,
                          ),
                        ),
                        onTap: () => _showTips(crop),
                      );
                    },
                  ),
                )
              else if (_searchController.text.isNotEmpty && _filteredCrops.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'No crops found matching your search.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Selected Crop Title
              if (_selectedCrop != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _selectedCrop!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                ),

              // Tips Display
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState:
                    _cropTip.isEmpty ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _cropTip,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}