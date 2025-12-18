import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/screens/disease management/disease_model.dart';
import 'package:kilimomkononi/screens/disease%20management/intervention_page.dart';
import 'package:kilimomkononi/screens/disease%20management/view_disease_interventions_page.dart';

class DiseaseManagementPage extends StatefulWidget {
  const DiseaseManagementPage({super.key});

  @override
  State<DiseaseManagementPage> createState() => _DiseaseManagementPageState();
}

class _DiseaseManagementPageState extends State<DiseaseManagementPage> {
  // Removed duplicate declaration of _notificationsPlugin
  final ScrollController _scrollController = ScrollController();
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
  DiseaseData? _diseaseData;
  bool _showDiseaseDetails = false;
  final GlobalKey _hintsKey = GlobalKey();
  
  // Add a key to force image widget rebuild
  Key _imageKey = UniqueKey();

  // Updated crop list
  final List<String> _crops = ['Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes', 'Onions', "Irish Potatoes"];

  // Crop-specific stages
  final Map<String, List<String>> _cropStages = {
    'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
    'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
    'Irish Potatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Tuber Formation', 'Maturation', 'Storage'],};

  // Nested map for diseases by crop and stage
  final Map<String, Map<String, List<String>>> _cropStageDiseases = {
    'Beans': {
      'Germination/Seedling': ['Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Pythium Root Rot', 'Damping-Off'],
      'Vegetative Growth/Weeding': ['Anthracnose', 'Angular Leaf Spot', 'Common Bacterial Blight', 'Halo Blight', 'Bean Rust', 'Powdery Mildew', 'Bean Common Mosaic Virus', 'Bean Golden Yellow Mosaic Virus', 'Root Knot Nematodes', 'Bacterial Wilt'],
      'Flowering/Reproductive': ['Anthracnose', 'Angular Leaf Spot', 'Bean Rust', 'Powdery Mildew', 'Bean Common Mosaic Virus', 'Bean Golden Yellow Mosaic Virus', 'Ascochyta Blight', 'Sclerotinia White Mold', 'Bacterial Wilt'],
      'Maturation/Harvesting': ['Anthracnose', 'Ascochyta Blight', 'Sclerotinia White Mold', 'Brown Spot', 'Fusarium Wilt', 'Web Blight'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
    'Maize': {
      'Germination/Seedling': ['Pythium Root Rot', 'Damping-Off'],
      'Vegetative Growth/Weeding': ['Gray Leaf Spot', 'Common Rust', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Bacterial Leaf Streak', 'Anthracnose Leaf Blight', 'Stewart\'s Wilt', 'Maize Streak Virus'],
      'Flowering/Reproductive': ['Gray Leaf Spot', 'Common Rust', 'Southern Corn Leaf Blight', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Tar Spot', 'Downy Mildew', 'Maize Streak Virus'],
      'Maturation/Harvesting': ['Maize Lethal Necrosis', 'Head Smut', 'Common Smut', 'Goss\'s Wilt', 'Fusarium Ear Rot', 'Gibberella Ear Rot', 'Diplodia Ear Rot', 'Aspergillus Ear Rot', 'Bacterial Stalk Rot', 'Charcoal Rot'],
      'Storage': ['Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)', 'Storage Rot'],
    },
    'Cabbages/Kales': {
      'Germination/Seedling': ['Damping-Off', 'Black Rot', 'Downy Mildew'],
      'Vegetative Growth/Weeding': ['Black Rot', 'Downy Mildew', 'Powdery Mildew', 'Alternaria Leaf Spot', 'Ring Spot', 'Bacterial Soft Rot', 'Fusarium Yellows', 'White Rust', 'Leaf Blight', 'Black Leg'],
      'Flowering/Reproductive': ['Downy Mildew', 'Powdery Mildew', 'Alternaria Leaf Spot', 'Sclerotinia Stem Rot (White Mold)', 'Anthracnose'],
      'Maturation/Harvesting': ['Black Rot', 'Sclerotinia Stem Rot (White Mold)', 'Bacterial Soft Rot', 'Anthracnose'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
    'Carrots': {
      'Germination/Seedling': ['Damping-Off', 'Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Pythium Root Rot'],
      'Vegetative Growth/Weeding': ['Alternaria Leaf Blight', 'Cercospora Leaf Blight', 'Powdery Mildew', 'Downy Mildew', 'Bacterial Leaf Blight', 'Root Knot Nematodes', 'Carrot Mosaic Virus', 'Aster Yellows'],
      'Maturation/Harvesting': ['Sclerotinia White Mold', 'Black Rot', 'Soft Rot', 'Fusarium Root Rot', 'Rhizoctonia Root Rot'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
    'Tomatoes': {
      'Germination/Seedling': ['Damping-Off', 'Bacterial Wilt', 'Fusarium Wilt', 'Verticillium Wilt'],
      'Vegetative Growth/Weeding': ['Early Blight', 'Bacterial Spot', 'Bacterial Canker', 'Tomato Mosaic Virus', 'Tomato Yellow Leaf Curl Virus', 'Septoria Leaf Spot', 'Powdery Mildew', 'Root Knot Nematodes', 'Tomato Spotted Wilt Virus'],
      'Flowering/Reproductive': ['Early Blight', 'Late Blight', 'Bacterial Spot', 'Bacterial Canker', 'Tomato Mosaic Virus', 'Tomato Yellow Leaf Curl Virus', 'Powdery Mildew', 'Gray Mold (Botrytis)', 'Tomato Spotted Wilt Virus', 'Alternaria Stem Canker'],
      'Maturation/Harvesting': ['Early Blight', 'Late Blight', 'Gray Mold (Botrytis)', 'Southern Blight', 'Anthracnose', 'Fruit Rot'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
    'Onions': {
  'Germination/Seedling': ['Fusarium Basal Rot', 'Pythium Root Rot'],
  'Vegetative Growth/Weeding': ['Downy Mildew', 'Leaf blight', 'Powdery Mildew'],
  'Bulb Formation/Reproductive':  ['Fusarium Basal Rot', 'Purple Blotch'],
  'Bulbing/Maturation': ['Neck Rot', 'Gray Mold', 'Purple Blotch'],
  'Harvesting/Storage': ['Post-harvest Fungal Rot', 'Gray Mold'],
     },
    'Irish Potatoes': {
      'Germination/Seedling': ['Pythium Damping Off'],
      'Vegetative Growth/Weeding': ['Late Blight', 'Early Blight', 'Powdery Scab', 'Black Scurf'],
      'Tuber Formation': ['Late Blight', 'Early Blight', 'Powdery Scab', 'Black Scurf'],
      'Maturation': ['Late Blight', 'Early Blight', 'Powdery Scab', 'Black Scurf'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },

  };

  // COMPLETE Disease details with stage-specific keys for all diseases
  final Map<String, Map<String, dynamic>> _diseaseDetails = {
    // ===== BEANS DISEASES =====
    // Beans - Germination/Seedling
    'Beans_Germination/Seedling_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/beans_fusarium_root_rot_germination.jpg',
    'possibleCauses': ['Caused by Fusarium spp. fungi in soil', 'Poor soil drainage', 'Overwatering', 'Contaminated seeds'],
    'preventionStrategies': [
      'Use certified disease-free seeds',
      'Improve soil drainage',
      'Rotate crops',
      'Apply organic mulch',
      'Use compost to enhance soil health',
      'Plant disease-resistant varieties',
      'Avoid overwatering',
      'Inoculate with beneficial microbes',
    ],
    'activeAgent': 'Fusarium spp.',
    'fungicides': [
      'Trichoderma viride (organic)',
      'Bacillus subtilis (organic)',
      'Neem-based products (organic)',
      'Copper-based fungicides (organic)',
      'Sulfur-based fungicides (organic)',
      'Benomyl',
      'Captan',
    ],
  },
    'Beans_Germination/Seedling_Rhizoctonia Root Rot': {
      'imagePath': 'assets/diseases/beans_rhizoctonia_root_rot_germination.jpg',
      'possibleStrategies': [
        'Improve soil drainage', 
        'Use treated seeds',
         'Crop rotation'
         ],
      'intervention': 'Fungicide (Azoxystrobin)',
      'possibleCauses': ['Warm, wet soil', 'Poor drainage'],
      'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    },
    'Beans_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/beans_pythium_root_rot_germination.jpg',
      'possibleStrategies': ['Use treated seeds', 'Avoid overwatering', 'Crop rotation'],
      'intervention': 'Fungicide (Mefenoxam)',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions'],
      'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    },
    'Beans_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/beans_damping_off_germination.jpg',
      'possibleStrategies': ['Use sterile soil', 'Avoid overwatering', 'Ensure good drainage'],
      'intervention': 'Fungicide (Captan)',
      'possibleCauses': ['Wet soil', 'Poor ventilation'],
      'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    },
    
    // Beans - Vegetative Growth/Weeding
    'Beans_Vegetative Growth/Weeding_Anthracnose': {
      'imagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Beans_Vegetative Growth/Weeding_Angular Leaf Spot': {
      'imagePath': 'assets/diseases/beans_angular_leaf_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Beans_Vegetative Growth/Weeding_Common Bacterial Blight': {
      'imagePath': 'assets/diseases/beans_common_bacterial_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Beans_Vegetative Growth/Weeding_Halo Blight': {
      'imagePath': 'assets/diseases/beans_halo_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Beans_Vegetative Growth/Weeding_Bean Rust': {
      'imagePath': 'assets/diseases/beans_rust_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Beans_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/beans_powdery_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Beans_Vegetative Growth/Weeding_Bean Common Mosaic Virus': {
      'imagePath': 'assets/diseases/beans_common_mosaic_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Beans_Vegetative Growth/Weeding_Bean Golden Yellow Mosaic Virus': {
      'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Beans_Vegetative Growth/Weeding_Root Knot Nematodes': {
      'imagePath': 'assets/diseases/beans_root_knot_nematodes_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Use resistant varieties', 'Soil solarization'],
      'intervention': 'Nematicide (Carbofuran)',
      'possibleCauses': ['Infected soil', 'Poor crop rotation'],
      'fungicides': ['Furadan (Carbofuran)', 'Vydate (Oxamyl)'],
    },
    'Beans_Vegetative Growth/Weeding_Bacterial Wilt': {
      'imagePath': 'assets/diseases/beans_bacterial_wilt_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    
    // Beans - Flowering/Reproductive
    'Beans_Flowering/Reproductive_Anthracnose': {
      'imagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Beans_Flowering/Reproductive_Angular Leaf Spot': {
      'imagePath': 'assets/diseases/beans_angular_leaf_spot_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Beans_Flowering/Reproductive_Bean Rust': {
      'imagePath': 'assets/diseases/beans_rust_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Beans_Flowering/Reproductive_Powdery Mildew': {
      'imagePath': 'assets/diseases/beans_powdery_mildew_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Beans_Flowering/Reproductive_Bean Common Mosaic Virus': {
      'imagePath': 'assets/diseases/beans_common_mosaic_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Beans_Flowering/Reproductive_Bean Golden Yellow Mosaic Virus': {
      'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Leafhopper transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Beans_Flowering/Reproductive_Ascochyta Blight': {
      'imagePath': 'assets/diseases/beans_ascochyta_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Beans_Flowering/Reproductive_Sclerotinia White Mold': {
      'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Beans_Flowering/Reproductive_Bacterial Wilt': {
      'imagePath': 'assets/diseases/beans_bacterial_wilt_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    
    // Beans - Maturation/Harvesting
    'Beans_Maturation/Harvesting_Anthracnose': {
      'imagePath': 'assets/diseases/beans_anthracnose_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Beans_Maturation/Harvesting_Ascochyta Blight': {
      'imagePath': 'assets/diseases/beans_ascochyta_blight_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Beans_Maturation/Harvesting_Sclerotinia White Mold': {
      'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Beans_Maturation/Harvesting_Brown Spot': {
      'imagePath': 'assets/diseases/beans_brown_spot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Beans_Maturation/Harvesting_Fusarium Wilt': {
      'imagePath': 'assets/diseases/beans_fusarium_wilt_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benlate (Benomyl)'],
    },
    'Beans_Maturation/Harvesting_Web Blight': {
      'imagePath': 'assets/diseases/beans_web_blight_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Carbendazim)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    },
    
    // Beans - Storage
    'Beans_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/beans_post_harvest_fungal_rot_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },

    // ===== MAIZE DISEASES =====
    // Maize - Germination/Seedling
    'Maize_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/maize_pythium_root_rot_germination.jpg',
      'possibleStrategies': ['Use treated seeds', 'Avoid overwatering', 'Crop rotation'],
      'intervention': 'Fungicide (Mefenoxam)',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions'],
      'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    },
    'Maize_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/maize_damping_off_germination.jpg',
      'possibleStrategies': ['Use sterile soil', 'Avoid overwatering', 'Ensure good drainage'],
      'intervention': 'Fungicide (Captan)',
      'possibleCauses': ['Wet soil', 'Poor ventilation'],
      'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    },
    
    // Maize - Vegetative Growth/Weeding
    'Maize_Vegetative Growth/Weeding_Gray Leaf Spot': {
      'imagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Azoxystrobin)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    },
    'Maize_Vegetative Growth/Weeding_Common Rust': {
      'imagePath': 'assets/diseases/maize_common_rust_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Maize_Vegetative Growth/Weeding_Northern Corn Leaf Blight': {
      'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    },
    'Maize_Vegetative Growth/Weeding_Maize Dwarf Mosaic Virus': {
      'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_vegetative_growth.jpg',
      
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Maize_Vegetative Growth/Weeding_Bacterial Leaf Streak': {
      'imagePath': 'assets/diseases/maize_bacterial_leaf_streak_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Maize_Vegetative Growth/Weeding_Anthracnose Leaf Blight': {
      'imagePath': 'assets/diseases/maize_anthracnose_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Maize_Vegetative Growth/Weeding_Stewart\'s Wilt': {
      'imagePath': 'assets/diseases/maize_stewarts_wilt_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control flea beetles', 'Crop rotation'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Flea beetle transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Maize_Vegetative Growth/Weeding_Maize Streak Virus': {
      'imagePath': 'assets/diseases/maize_streak_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control leafhoppers', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Leafhopper transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    
    // Maize - Flowering/Reproductive
    'Maize_Flowering/Reproductive_Gray Leaf Spot': {
      'imagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Azoxystrobin)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    },
    'Maize_Flowering/Reproductive_Common Rust': {
      'imagePath': 'assets/diseases/maize_common_rust_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Maize_Flowering/Reproductive_Southern Corn Leaf Blight': {
      'imagePath': 'assets/diseases/maize_southern_corn_leaf_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    },
    'Maize_Flowering/Reproductive_Northern Corn Leaf Blight': {
      'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    },
    'Maize_Flowering/Reproductive_Maize Dwarf Mosaic Virus': {
      'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_flowering.jpg',
      
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Maize_Flowering/Reproductive_Tar Spot': {
      'imagePath': 'assets/diseases/maize_tar_spot_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Trifloxystrobin)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Headline (Pyraclostrobin)', 'Quadris (Azoxystrobin)'],
    },
    'Maize_Flowering/Reproductive_Downy Mildew': {
      'imagePath': 'assets/diseases/maize_downy_mildew_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Metalaxyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    },
    'Maize_Flowering/Reproductive_Maize Streak Virus': {
      'imagePath': 'assets/diseases/maize_streak_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control leafhoppers', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Leafhopper transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    
    // Maize - Maturation/Harvesting
    'Maize_Maturation/Harvesting_Maize Lethal Necrosis': {
      'imagePath': 'assets/diseases/maize_lethal_necrosis_harvesting.jpg',
      'possibleStrategies': ['Use resistant hybrids', 'Control insect vectors', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Virus transmission by aphids', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Maize_Maturation/Harvesting_Head Smut': {
      'imagePath': 'assets/diseases/maize_head_smut_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Carbendazim)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    },
    'Maize_Maturation/Harvesting_Common Smut': {
      'imagePath': 'assets/diseases/maize_common_smut_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Carbendazim)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    },
    'Maize_Maturation/Harvesting_Goss\'s Wilt': {
      'imagePath': 'assets/diseases/maize_goss_wilt_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Maize_Maturation/Harvesting_Fusarium Ear Rot': {
      'imagePath': 'assets/diseases/maize_fusarium_ear_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    'Maize_Maturation/Harvesting_Gibberella Ear Rot': {
      'imagePath': 'assets/diseases/maize_giberella_ear_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Prothioconazole)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Proline (Prothioconazole)', 'Tilt (Propiconazole)'],
    },
    'Maize_Maturation/Harvesting_Diplodia Ear Rot': {
      'imagePath': 'assets/diseases/maize_diplodia_ear_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Carbendazim)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    },
    'Maize_Maturation/Harvesting_Aspergillus Ear Rot': {
      'imagePath': 'assets/diseases/maize_aspergillus_ear_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },
    'Maize_Maturation/Harvesting_Bacterial Stalk Rot': {
      'imagePath': 'assets/diseases/maize_bacterial_stalk_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Maize_Maturation/Harvesting_Charcoal Rot': {
      'imagePath': 'assets/diseases/maize_charcoal_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Azoxystrobin)',
      'possibleCauses': ['Warm, dry conditions', 'Infected seeds'],
      'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    },
    
    // Maize - Storage
    'Maize_Storage_Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)': {
      'imagePath': 'assets/diseases/maize_post_harvest_mycotoxins_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },
    'Maize_Storage_Storage Rot': {
      'imagePath': 'assets/diseases/maize_storage_rot.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },

    // ===== CABBAGES/KALES DISEASES =====
    // Cabbages/Kales - Germination/Seedling
    'Cabbages/Kales_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/cabbage_damping_off_germination.jpg',
      'possibleStrategies': ['Use sterile soil', 'Avoid overwatering', 'Ensure good drainage'],
      'intervention': 'Fungicide (Captan)',
      'possibleCauses': ['Wet soil', 'Poor ventilation'],
      'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    },
    'Cabbages/Kales_Germination/Seedling_Black Rot': {
      'imagePath': 'assets/diseases/cabbage_black_rot_germination.jpg',
      'possibleStrategies': ['Use certified seeds', 'Crop rotation', 'Remove plant debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, wet conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Cabbages/Kales_Germination/Seedling_Downy Mildew': {
      'imagePath': 'assets/diseases/cabbage_downy_mildew_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Metalaxyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    },
    
    // Cabbages/Kales - Vegetative Growth/Weeding
    'Cabbages/Kales_Vegetative Growth/Weeding_Black Rot': {
      'imagePath': 'assets/diseases/cabbage_black_rot_vegetative_growth.jpg',
      'possibleStrategies': ['Use certified seeds', 'Crop rotation', 'Remove plant debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, wet conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Downy Mildew': {
      'imagePath': 'assets/diseases/cabbage_downy_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Metalaxyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/cabbage_powdery_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Alternaria Leaf Spot': {
      'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Ring Spot': {
      'imagePath': 'assets/diseases/cabbage_ring_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Bacterial Soft Rot': {
      'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Fusarium Yellows': {
      'imagePath': 'assets/diseases/cabbage_fusarium_yellows_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_White Rust': {
      'imagePath': 'assets/diseases/cabbage_white_rust_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Leaf Blight': {
      'imagePath': 'assets/diseases/cabbage_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Black Leg': {
      'imagePath': 'assets/diseases/cabbage_black_leg_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    
    // Cabbages/Kales - Flowering/Reproductive
    'Cabbages/Kales_Flowering/Reproductive_Downy Mildew': {
      'imagePath': 'assets/diseases/cabbage_downy_mildew_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Metalaxyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    },
    'Cabbages/Kales_Flowering/Reproductive_Powdery Mildew': {
      'imagePath': 'assets/diseases/cabbage_powdery_mildew_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Cabbages/Kales_Flowering/Reproductive_Alternaria Leaf Spot': {
      'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Cabbages/Kales_Flowering/Reproductive_Sclerotinia Stem Rot (White Mold)': {
      'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Cabbages/Kales_Flowering/Reproductive_Anthracnose': {
      'imagePath': 'assets/diseases/cabbage_anthracnose_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    
    // Cabbages/Kales - Maturation/Harvesting
    'Cabbages/Kales_Maturation/Harvesting_Black Rot': {
      'imagePath': 'assets/diseases/cabbage_black_rot_harvesting.jpg',
      'possibleStrategies': ['Use certified seeds', 'Crop rotation', 'Remove plant debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, wet conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Cabbages/Kales_Maturation/Harvesting_Sclerotinia Stem Rot (White Mold)': {
      'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Cabbages/Kales_Maturation/Harvesting_Bacterial Soft Rot': {
      'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Cabbages/Kales_Maturation/Harvesting_Anthracnose': {
      'imagePath': 'assets/diseases/cabbage_anthracnose_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    
    // Cabbages/Kales - Storage
    'Cabbages/Kales_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/cabbage_post_harvest_fungal_rot_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },

    // ===== CARROTS DISEASES =====
    // Carrots - Germination/Seedling
    'Carrots_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/carrots_damping_off_germination.jpg',
      'possibleStrategies': ['Use sterile soil', 'Avoid overwatering', 'Ensure good drainage'],
      'intervention': 'Fungicide (Captan)',
      'possibleCauses': ['Wet soil', 'Poor ventilation'],
      'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    },
    'Carrots_Germination/Seedling_Fusarium Root Rot': {
      'imagePath': 'assets/diseases/carrots_fusarium_root_rot_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    'Carrots_Germination/Seedling_Rhizoctonia Root Rot': {
      'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Carrots_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/carrots_pythium_root_rot_germination.jpg',
      'possibleStrategies': ['Use treated seeds', 'Avoid overwatering', 'Crop rotation'],
      'intervention': 'Fungicide (Mefenoxam)',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions'],
      'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    },
    
    // Carrots - Vegetative Growth/Weeding
    'Carrots_Vegetative Growth/Weeding_Alternaria Leaf Blight': {
      'imagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove plant debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Humid conditions', 'Dense foliage'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Carrots_Vegetative Growth/Weeding_Cercospora Leaf Blight': {
      'imagePath': 'assets/diseases/carrots_cercospora_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Carrots_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/carrots_powdery_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Carrots_Vegetative Growth/Weeding_Downy Mildew': {
      'imagePath': 'assets/diseases/carrots_downy_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Metalaxyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    },
    'Carrots_Vegetative Growth/Weeding_Bacterial Leaf Blight': {
      'imagePath': 'assets/diseases/carrots_bacterial_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Carrots_Vegetative Growth/Weeding_Root Knot Nematodes': {
      'imagePath': 'assets/diseases/carrots_root_knot_nematodes_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Soil solarization'],
      'intervention': 'Nematicide (Carbofuran)',
      'possibleCauses': ['Warm, moist soil conditions', 'Infected soil'],
      'fungicides': ['Furadan (Carbofuran)', 'Vydate (Oxamyl)'],
    },
    'Carrots_Vegetative Growth/Weeding_Carrot Mosaic Virus': {
      'imagePath': 'assets/diseases/carrots_mosaic_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Carrots_Vegetative Growth/Weeding_Aster Yellows': {
      'imagePath': 'assets/diseases/carrots_aster_yellows_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control leafhoppers', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Leafhopper transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    
    // Carrots - Maturation/Harvesting
    'Carrots_Maturation/Harvesting_Sclerotinia White Mold': {
      'imagePath': 'assets/diseases/carrots_sclerotinia_white_mold_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Carrots_Maturation/Harvesting_Black Rot': {
      'imagePath': 'assets/diseases/carrots_black_rot_harvesting.jpg',
      'possibleStrategies': ['Use certified seeds', 'Crop rotation', 'Remove plant debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, wet conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Carrots_Maturation/Harvesting_Soft Rot': {
      'imagePath': 'assets/diseases/carrots_soft_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Carrots_Maturation/Harvesting_Fusarium Root Rot': {
      'imagePath': 'assets/diseases/carrots_fusarium_root_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    'Carrots_Maturation/Harvesting_Rhizoctonia Root Rot': {
      'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    
    // Carrots - Storage
    'Carrots_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/carrots_post_harvest_fungal_rot_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },

    // ===== TOMATOES DISEASES =====
    // Tomatoes - Germination/Seedling
    'Tomatoes_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/tomato_damping_off_germination.jpg',
      'possibleStrategies': ['Use sterile soil', 'Avoid overwatering', 'Ensure good drainage'],
      'intervention': 'Fungicide (Captan)',
      'possibleCauses': ['Wet soil', 'Poor ventilation'],
      'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    },
    'Tomatoes_Germination/Seedling_Bacterial Wilt': {
      'imagePath': 'assets/diseases/tomato_bacterial_wilt_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Tomatoes_Germination/Seedling_Fusarium Wilt': {
      'imagePath': 'assets/diseases/tomato_fusarium_wilt_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    'Tomatoes_Germination/Seedling_Verticillium Wilt': {
      'imagePath': 'assets/diseases/tomato_verticillium_wilt_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    },
    
    // Tomatoes - Vegetative Growth/Weeding
    'Tomatoes_Vegetative Growth/Weeding_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, wet weather', 'Infected plant debris'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Tomato Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Tomato Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control whiteflies', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Whitefly transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Septoria Leaf Spot': {
      'imagePath': 'assets/diseases/tomato_septoria_leaf_spot_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Root Knot Nematodes': {
      'imagePath': 'assets/diseases/tomato_root_knot_nematodes_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Soil solarization'],
      'intervention': 'Nematicide (Carbofuran)',
      'possibleCauses': ['Warm, moist soil conditions', 'Infected soil'],
      'fungicides': ['Furadan (Carbofuran)', 'Vydate (Oxamyl)'],
    },
    'Tomatoes_Vegetative Growth/Weeding_Tomato Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_vegetative_growth.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control thrips', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Thrips transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    
    // Tomatoes - Flowering/Reproductive
    'Tomatoes_Flowering/Reproductive_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Flowering/Reproductive_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Flowering/Reproductive_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Tomatoes_Flowering/Reproductive_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Bactericide (Copper hydroxide)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    },
    'Tomatoes_Flowering/Reproductive_Tomato Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control aphids', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Aphid transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Tomatoes_Flowering/Reproductive_Tomato Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control whiteflies', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Whitefly transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Tomatoes_Flowering/Reproductive_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Sulfur)',
      'possibleCauses': ['Warm, dry conditions', 'High humidity'],
      'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    },
    'Tomatoes_Flowering/Reproductive_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Tomatoes_Flowering/Reproductive_Tomato Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_flowering.jpg',
      'fallbackImagePath': 'assets/diseases/tomato_early_blight_flowering.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Control thrips', 'Crop rotation'],
      'intervention': 'No chemical control',
      'possibleCauses': ['Thrips transmission', 'Infected seeds'],
      'fungicides': ['None'],
    },
    'Tomatoes_Flowering/Reproductive_Alternaria Stem Canker': {
      'imagePath': 'assets/diseases/tomato_alternaria_stem_canker_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    
    // Tomatoes - Maturation/Harvesting
    'Tomatoes_Maturation/Harvesting_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Maturation/Harvesting_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    },
    'Tomatoes_Maturation/Harvesting_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Tomatoes_Maturation/Harvesting_Southern Blight': {
      'imagePath': 'assets/diseases/tomato_southern_blight_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
      'intervention': 'Fungicide (Boscalid)',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
      'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    },
    'Tomatoes_Maturation/Harvesting_Anthracnose': {
      'imagePath': 'assets/diseases/tomato_anthracnose_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    'Tomatoes_Maturation/Harvesting_Fruit Rot': {
      'imagePath': 'assets/diseases/tomato_fruit_rot_harvesting.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Remove infected debris'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    },
    
    // Tomatoes - Storage
    'Tomatoes_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/tomato_post_harvest_fungal_rot_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicides': ['Propiconazole', 'Azoxystrobin'],
    },

    // ===== ONIONS DISEASES =====
    // Onions - Germination/Seedling
    'Onions_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/onions_pythium_root_rot_germination.jpg',
      'possibleStrategies': ['Use treated seeds', 'Avoid overwatering', 'Crop rotation'],
      'intervention': 'Fungicide (Mefenoxam)',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions'],
      'herbicidesPesticides': ['Ridomil Gold', 'Apron XL']
    },
    'Onions_Germination/Seedling_Fusarium Basal Rot': {
      'imagePath': 'assets/diseases/onions_fusarium_basal_rot_germination.jpg',
      'possibleStrategies': ['Use disease-free planting material', 'Crop rotation', 'Improve soil drainage'],
      'intervention': 'Fungicides like carbendazim',
      'possibleCauses': ['Waterlogging', 'Contaminated soil', 'Poor soil health'],
      'herbicidesPesticides': ['Carbendazim']
    },
    // Onions - Vegetative Growth/Weeding
  'Onions_vegetative Growth/Weeding_Downy Mildew': {
  'imagePath': 'assets/diseases/onions_downy_mildew_vegetative_growth.jpg',
  'possibleStrategies': ['Improve field ventilation', 'Avoid overhead watering', 'Use resistant varieties'],
  'intervention': 'Fungicide sprays like metalaxyl or mancozeb',
  'possibleCauses': ['High humidity', 'Cool temperatures', 'Poor drainage'],
  'herbicidesPesticides': ['Metalaxyl', 'Mancozeb']
},
'Onions_Vegetative Growth/Weeding_Leaf Blight': {
  'imagePath': 'assets/diseases/onions_leaf_blight_vegetative_growth.jpg',
  'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
  'intervention': 'Fungicide (Mancozeb)',
  'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
  'herbicidesPesticides': ['Dithane', 'Manzate']
},
'Onions_Vegetative Growth/Weeding_Powdery Mildew': {
  'imagePath': 'assets/diseases/onions_powdery_mildew_vegetative_growth.jpg',
  'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good air circulation'],
  'intervention': 'Fungicide (Sulfur)',
  'possibleCauses': ['Warm, dry conditions', 'High humidity'],
  'herbicidesPesticides': ['Microthiol', 'Thiovit']
},
// Onions - Bulb Formation/Reproductive
'Onions_Bulb Formation/Reproductive_Fusarium Basal Rot': {
  'imagePath': 'assets/diseases/onions_fusarium_basal_rot_bulb_formation.jpg',
  'possibleStrategies': ['Use disease-free planting material', 'Crop rotation', 'Improve soil drainage'],
  'intervention': 'Fungicides like carbendazim', 
  'possibleCauses': ['Waterlogging', 'Contaminated soil', 'Poor soil health'],
  'herbicidesPesticides': ['Carbendazim']
},
'Onions_Bulb Formation/Reproductive_Purple Blotch': {
  'imagePath': 'assets/diseases/onions_purple_blotch_bulb_formation.jpg',
  'possibleStrategies': ['Use resistant varieties', 'Remove infected plant debris', 'Improve airflow'],
  'intervention': 'Spray with copper-based fungicides',
  'possibleCauses': ['High humidity', 'Poor sanitation'],
  'herbicidesPesticides': ['Copper oxychloride', 'Copper hydroxide']
},
// Onions Bulbing/Maturation
'Onions_Bulbing/Maturation_Neck Rot': {
  'imagePath': 'assets/diseases/onions_neck_rot_bulbing.jpg',
  'possibleStrategies': ['Proper curing of bulbs', 'Avoid watering during maturity', 'Use resistant varieties'],
  'intervention': 'Application of fungicides like thiabendazole during curing',
  'possibleCauses': ['Overwatering', 'Poor curing', 'Contaminated soil'],
  'herbicidesPesticides': ['Thiabendazole']
},
'Onions_Bulbing/Maturation_Purple Blotch': {
  'imagePath': 'assets/diseases/onions_purple_blotch_bulbing.jpg',
  'possibleStrategies': ['Use resistant varieties', 'Remove infected plant debris', 'Improve airflow'],
  'intervention': 'Spray with copper-based fungicides',
  'possibleCauses': ['High humidity', 'Poor sanitation'],
  'herbicidesPesticides': ['Copper oxychloride', 'Copper hydroxide']
},
'Onions_Builbing/Maturation_Gray Mold (Botrytis)': {
  'imagePath': 'assets/diseases/onions_gray_mold_bulbing.jpg',
  'possibleStrategies': ['Crop rotation', 'Remove infected debris', 'Ensure good air circulation'],
  'intervention': 'Fungicide (Boscalid)',
  'possibleCauses': ['Warm, humid conditions', 'Infected debris'],
  'herbicidesPesticides': ['Endura', 'Switch']
},
// Onions - Storage
'Onions_Storage_Post-Harvest Fungal Rot': {
  'imagePath': 'assets/diseases/onions_post_harvest_fungal_rot_storage.jpg',
  'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
  'intervention': 'Fungicide (Propiconazole)',
  'possibleCauses': ['High humidity', 'Infected seeds'],
  'herbicidesPesticides': ['Propiconazole', 'Azoxystrobin']
},
'Onions_Storage_Gray Mold (Botrytis)': {
  'imagePath': 'assets/diseases/onions_gray_mold_storage.jpg',
  'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
  'intervention': 'Fungicide (Boscalid)',
  'possibleCauses': ['High humidity', 'Infected seeds'],
  'herbicidesPesticides': ['Endura', 'Switch']
},

// IRISH POTATOES DISEASES
// Irish Potatoes - Germination/Seedling
    'Irish Potatoes_Germination/Seedling_Pythium Damping Off': {
      'imagePath': 'assets/diseases/irish_potatoes_pythium_damping_off_germination.jpg',
      'possibleStrategies': ['Use treated seeds', 'Avoid overwatering', 'Crop rotation'],
      'intervention': 'Fungicide (Mefenoxam)',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions'],
      'fungicidesPesticides': ['Ridomil Gold', 'Apron XL']
    },
    // Irish Potatoes - Vegetative Growth/Weeding
    'Irish Potatoes_Vegetative Growth/Weeding_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_vegetative_growth.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },
    // Irish Potatoes - Tuber Formation/Reproductive
    'Irish Potatoes_Tuber Formation_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_tuber_formation.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
    'Irish Potatoes_Tuber Formation_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_tuber_formation.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
    'Irish Potatoes_Tuber Formation_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_tuber_formation.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },
    'Irish Potatoes_Tuber Formation_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_tuber_formation.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },

    // Irish Potatoes - Maturation/Harvesting
    'Irish Potatoes_Maturation_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_maturation.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
    'Irish Potatoes_Maturation_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_maturation.jpg',
      'possibleStrategies': ['Crop rotation', 'Remove infected leaves', 'Ensure proper spacing'],
      'intervention': 'Fungicide (Mancozeb)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Dithane', 'Manzate']
    },
     'Irish Potatoes_Maturation_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_maturation.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },
     'Irish Potatoes_Maturation_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_maturation.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Ensure good soil drainage'],
      'intervention': 'Fungicide (Chlorothalonil)',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds'],
      'fungicidesPesticides': ['Bravo', 'Daconil']
    },

    // Irish Potatoes - Storage
    'Irish Potatoes_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/irish_potatoes_post_harvest_fungal_rot_storage.jpg',
      'possibleStrategies': ['Store in dry, cool conditions', 'Use airtight containers'],
      'intervention': 'Fungicide (Propiconazole)',
      'possibleCauses': ['High humidity', 'Infected seeds'],
      'fungicidesPesticides': ['Propiconazole', 'Azoxystrobin']
    },

  };

  // Removed duplicate _cropStageDiseases definition to fix naming conflict and unused field error.

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

// Removed duplicate build method to fix shadowing and method not found error.


  @override
  void initState() {
    super.initState();
    _initializeNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // FIXED: Updated method with stage-specific key generation
  void _updateDiseaseDetails() {
    if (_selectedDisease != null && _selectedCrop != null && _selectedStage != null) {
      // Create a unique key using crop, stage, and disease name
      String diseaseKey = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
      
      // Clear previous image by generating new key
      _imageKey = UniqueKey();
      
      // Check if the disease exists for this specific crop and stage
      if (_diseaseDetails.containsKey(diseaseKey)) {
        final diseaseInfo = _diseaseDetails[diseaseKey]!;
        setState(() {
          _diseaseData = DiseaseData.fromMap({
            'name': _selectedDisease!,
            'imagePath': diseaseInfo['imagePath'],
            'preventionStrategies': diseaseInfo['possibleStrategies'],
            'activeAgent': diseaseInfo['intervention'].contains('(') 
                ? diseaseInfo['intervention'].split('(')[1].replaceAll(')', '')
                : 'No chemical control',
            'possibleCauses': diseaseInfo['possibleCauses'],
            'fungicides': diseaseInfo['fungicides'],
          });
        });
      } else {
        // Fallback: try without stage if stage-specific key doesn't exist
        String fallbackKey = '${_selectedCrop}_$_selectedDisease';
        if (_diseaseDetails.containsKey(fallbackKey)) {
          final diseaseInfo = _diseaseDetails[fallbackKey]!;
          setState(() {
            _diseaseData = DiseaseData.fromMap({
              'name': _selectedDisease!,
              'imagePath': diseaseInfo['imagePath'],
              'preventionStrategies': diseaseInfo['possibleStrategies'],
              'activeAgent': diseaseInfo['intervention'].contains('(') 
                  ? diseaseInfo['intervention'].split('(')[1].replaceAll(')', '')
                  : 'No chemical control',
              'possibleCauses': diseaseInfo['possibleCauses'],
              'fungicides': diseaseInfo['fungicides'],
            });
          });
        } else {
          // Show error message if disease not found
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Disease data not found for $_selectedDisease in $_selectedCrop at $_selectedStage stage'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _scrollToHints() {
    if (_showDiseaseDetails && _hintsKey.currentContext != null) {
      final RenderBox box = _hintsKey.currentContext!.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero).dy + _scrollController.offset - 100;
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: Colors.grey[200],
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdown('Crop Type', _cropStageDiseases.keys.toList(), _selectedCrop, (val) {
                setState(() {
                  _selectedCrop = val;
                  _selectedStage = null;
                  _selectedDisease = null;
                  _diseaseData = null;
                  _showDiseaseDetails = false;
                  _imageKey = UniqueKey(); // Reset image key
                });
              }),
              const SizedBox(height: 16),
              _buildDropdown('Crop Stage', _selectedCrop != null ? _cropStageDiseases[_selectedCrop]!.keys.toList() : [], _selectedStage, (val) {
                setState(() {
                  _selectedStage = val;
                  _selectedDisease = null;
                  _diseaseData = null;
                  _showDiseaseDetails = false;
                  _imageKey = UniqueKey(); // Reset image key
                });
              }),
              const SizedBox(height: 16),
              _buildDropdown('Select Disease', _selectedCrop != null && _selectedStage != null ? _cropStageDiseases[_selectedCrop]![_selectedStage]! : [], _selectedDisease, (val) {
                setState(() {
                  _selectedDisease = val;
                  _updateDiseaseDetails();
                  _showDiseaseDetails = false;
                });
              }),
              if (_diseaseData != null) ...[
                const SizedBox(height: 16),
                _buildImageCard(_diseaseData!.imagePath),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    if (_diseaseData != null) {
                      setState(() {
                        _showDiseaseDetails = !_showDiseaseDetails;
                        if (_showDiseaseDetails) {
                          WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHints());
                        }
                      });
                    } else {
                      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please select a disease first')));
                    }
                  },
                  child: const Text(
                    'View Disease Management Hints',
                    style: TextStyle(
                      color: Color.fromARGB(255, 3, 39, 4),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewDiseaseInterventionsPage(
                          diseaseData: _diseaseData!,
                          notificationsPlugin: _notificationsPlugin,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('View My Disease History'),
                ),
                if (_showDiseaseDetails && _diseaseData != null) ...[
                  const SizedBox(height: 8),
                  Column(
                    key: _hintsKey,
                    crossAxisAlignment: CrossAxisAlignment.start, // FIXED: Align cards to left
                    children: [
                      _buildHintCard('Prevention Strategies', _diseaseData!.preventionStrategies.join('\n')),
                      _buildHintCard('Possible Intervention(Active Ingredient)', 'Chemical control with ${_diseaseData!.activeAgent}'),
                      _buildHintCard('Possible Causes', _diseaseData!.possibleCauses.join('\n')),
                      _buildHintCard('Fungicides', _diseaseData!.fungicides.join('\n')),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InterventionPage(
                                  cropType: _selectedCrop!,
                                  cropStage: _selectedStage ?? '',
                                  
                                  
                                  notificationsPlugin: _notificationsPlugin,
                                  diseaseData: _diseaseData!,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Manage Disease'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    // Ensure no duplicate items and handle case sensitivity
    final uniqueItems = items.toSet().toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          initialValue: uniqueItems.contains(value) ? value : null, // Ensure value exists in items
          items: uniqueItems.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // FIXED: Image card with better error handling and stage-specific fallback support
  Widget _buildImageCard(String imagePath) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 56,
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: FutureBuilder<Size>(
            future: _getImageSize(imagePath),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
                return const SizedBox(height: 150, child: Center(child: CircularProgressIndicator()));
              }
              final imageSize = snapshot.data!;
              return AspectRatio(
                aspectRatio: imageSize.width / imageSize.height,
                child: Image.asset(
                  imagePath,
                  key: _imageKey, // Force rebuild with new key
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Try fallback image if available
                    String diseaseKey = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
                    if (_diseaseDetails.containsKey(diseaseKey) && 
                        _diseaseDetails[diseaseKey]!.containsKey('fallbackImagePath')) {
                      return Image.asset(
                        _diseaseDetails[diseaseKey]!['fallbackImagePath'],
                        key: UniqueKey(),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => 
                            const Icon(Icons.image_not_supported, size: 150),
                      );
                    }
                    return const Icon(Icons.image_not_supported, size: 150);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<Size> _getImageSize(String imagePath) async {
    final Completer<Size> completer = Completer();
    final Image image = Image.asset(imagePath);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          completer.complete(Size(info.image.width.toDouble(), info.image.height.toDouble()));
        },
        onError: (exception, stackTrace) {
          completer.complete(const Size(150, 150));
        },
      ),
    );
    return completer.future;
  }

  // FIXED: Improved hint card with better alignment and responsive sizing
  Widget _buildHintCard(String title, String content) {
    return Container(
      width: double.infinity, // FIXED: Full width to fit screen
      margin: const EdgeInsets.only(bottom: 12.0), // FIXED: Consistent spacing
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0), // FIXED: Increased padding for better readability
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // FIXED: Left alignment
            children: [
              Text(
                title, 
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 3, 39, 4), // FIXED: Consistent color theme
                ),
              ),
              const SizedBox(height: 8),
              Text(
                content, 
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4, // FIXED: Better line spacing for readability
                ),
                textAlign: TextAlign.left, // FIXED: Left alignment
              ),
            ],
          ),
        ),
      ),
    );
  }
}
