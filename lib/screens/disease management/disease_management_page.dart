 import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:kilimomkononi/screens/disease%20management/intervention_page.dart';
import 'package:kilimomkononi/screens/disease%20management/view_disease_interventions_page.dart' as view_interventions;
import 'package:kilimomkononi/screens/disease%20management/user_disease_history_page.dart';
import 'package:kilimomkononi/models/symptom_model.dart'; // ✅ use package import

class DiseaseManagementPage extends StatefulWidget {
  final List<Symptom>? selectedSymptoms;

  const DiseaseManagementPage({super.key, this.selectedSymptoms});

  @override
  State<DiseaseManagementPage> createState() => _DiseaseManagementPageState();
}

class _DiseaseManagementPageState extends State<DiseaseManagementPage> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
  DiseaseData? _diseaseData;
  bool _showDiseaseDetails = false;
  bool _isOrganic = false;
  final GlobalKey _hintsKey = GlobalKey();
  Key _imageKey = UniqueKey();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  final List<String> _crops = [
    'Beans',
    'Maize',
    'Cabbages/Kales',
    'Carrots',
    'Tomatoes',
    'Onions',
    'Irish Potatoes'
  ];
  
  final Map<String, List<String>> _cropStages = {
    'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
    'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
    'Irish Potatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Tuber Formation', 'Maturation', 'Storage'],
  };

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
      'Vegetative Growth/Weeding': ['Gray Leaf Spot', 'Common Rust', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Bacterial Leaf Streak', 'Anthracnose Leaf Blight', "Stewart's Wilt", 'Maize Streak Virus'],
      'Flowering/Reproductive': ['Gray Leaf Spot', 'Common Rust', 'Southern Corn Leaf Blight', 'Northern Corn Leaf Blight', 'Maize Dwarf Mosaic Virus', 'Tar Spot', 'Downy Mildew', 'Maize Streak Virus'],
      'Maturation/Harvesting': ['Maize Lethal Necrosis', 'Head Smut', 'Common Smut', "Goss's Wilt", 'Fusarium Ear Rot', 'Gibberella Ear Rot', 'Diplodia Ear Rot', 'Aspergillus Ear Rot', 'Bacterial Stalk Rot', 'Charcoal Rot'],
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
      'Maturation/Harvesting': ['Sclerotinia White Mold', 'Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Soft Rot','Black Rot'],
      'Storage': ['Post-Harvest Fungal Rot'],
     },
    'Tomatoes': {
      'Germination/Seedling': ['Damping-Off', 'Fusarium Wilt', 'Verticillium Wilt', 'Bacterial Wilt'],
      'Vegetative Growth/Weeding': ['Early Blight', 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Root Knot Nematodes', 'Spotted Wilt Virus', 'Septoria Leaf Spot'],
      'Flowering/Reproductive': ['Early Blight', 'Late Blight','Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Spotted Wilt Virus', 'Gray Mold (Botrytis)', 'Alternaria Stem Canker'],
      'Maturation/Harvesting': ['Late Blight', 'Anthracnose', 'Early Blight', 'Southern Blight', 'Fruit Rot', 'Gray Mold (Botrytis)'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
    'Onions': {
      'Germination/Seedling': ['Pythium Root Rot', 'Fusarium Basal Rot'],
      'Vegetative Growth/Weeding': ['Downy Mildew', 'Powdery Mildew', 'Leaf Blight'],
      'Bulb Formation/Reproductive': ['Purple Blotch', 'Fusarium Basal Rot'],
      'Bulbing/Maturation': [ 'Gray Mold', 'Neck Rot', 'Purple Blotch'],
      'Harvesting/Storage': ['Gray Mold', 'Post-Harvest Fungal Rot'],
    },
    'Irish Potatoes': {
      'Germination/Seedling': ['Pythium Damping-Off'],
      'Vegetative Growth/Weeding': ['Early Blight', 'Late Blight', 'Powdery Scab', 'Black Scurf'],
      'Tuber Formation': ['Early Blight', 'Late Blight', 'Powdery Scab', 'Black Scurf'],
      'Maturation': ['Early Blight', 'Late Blight', 'Powdery Scab', 'Black Scurf'],
      'Storage': ['Post-Harvest Fungal Rot'],
    },
  };

  static const List<String> _organicFungicides = [
    'Trichoderma viride (organic)',
    'Bacillus subtilis (organic)',
    'Neem-based products (organic)',
    'Copper-based fungicides (organic)',
    'Sulfur-based fungicides (organic)',
    'Compost tea (organic)',
    'Potassium bicarbonate (organic)',
  ];

  static const List<String> _organicPreventionStrategies = [
    'Use compost to enhance soil health',
    'Inoculate with beneficial microbes',
    'Apply organic mulch',
    'Use crop rotation',
    'Plant disease-resistant varieties',
    'Encourage beneficial fungi',
    'Improve air circulation',
    'Remove infected plant debris',
  ];


  final Map<String, Map<String, dynamic>> _diseaseDetails = {
  // ===== BEANS DISEASES =====
  // Beans - Germination/Seedling
  'Beans_Germination/Seedling_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/beans_fusarium_root_rot_germination.jpg',
    'possibleCauses': [
      'Caused by Fusarium spp. fungi in soil',
      'Poor soil drainage',
      'Overwatering',
      'Contaminated seeds',
    ],
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
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem-based products as soil drench',
      'Incorporate compost to improve soil health',
      'Apply Bacillus subtilis as a biofungicide',
      'Plant marigolds as a cover crop to suppress fungi',
    ],
  },
  'Beans_Germination/Seedling_Rhizoctonia Root Rot': {
    'imagePath': 'assets/diseases/beans_rhizoctonia_root_rot_germination.jpg',
    'possibleCauses': ['Warm, wet soil', 'Poor drainage', 'Contaminated seeds'],
    'preventionStrategies': [
      'Improve soil drainage',
      'Use treated seeds',
      'Crop rotation',
      'Avoid planting in overly wet conditions',
      'Use well-drained seedbeds',
    ],
    'activeAgent': 'Rhizoctonia solani',
    'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    'organicInterventions': [
      'Apply Trichoderma harzianum to soil',
      'Use compost to enhance soil microbial activity',
      'Apply neem oil as a soil drench',
      'Incorporate mustard cover crops to suppress fungi',
      'Ensure proper soil aeration',
    ],
  },
  'Beans_Germination/Seedling_Pythium Root Rot': {
    'imagePath': 'assets/diseases/beans_pythium_root_rot_germination.jpg',
    'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions', 'Poor drainage'],
    'preventionStrategies': [
      'Use treated seeds',
      'Avoid overwatering',
      'Crop rotation',
      'Improve soil drainage',
      'Use raised beds',
    ],
    'activeAgent': 'Pythium spp.',
    'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Incorporate organic matter to improve soil structure',
      'Use compost teas to enhance soil microbes',
      'Avoid waterlogging by improving drainage',
    ],
  },
  'Beans_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/beans_damping_off_germination.jpg',
    'possibleCauses': ['Wet soil', 'Poor ventilation', 'Fungal pathogens like Pythium and Rhizoctonia'],
    'preventionStrategies': [
      'Use sterile soil',
      'Avoid overwatering',
      'Ensure good drainage',
      'Provide adequate ventilation',
      'Use treated seeds',
    ],
    'activeAgent': 'Pythium spp., Rhizoctonia spp.',
    'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    'organicInterventions': [
      'Apply Trichoderma viride as a seed treatment',
      'Use compost to improve soil health',
      'Apply neem oil to soil',
      'Ensure proper seed spacing for ventilation',
      'Use well-drained, sterile planting medium',
    ],
  },

  // Beans - Vegetative Growth/Weeding
  'Beans_Vegetative Growth/Weeding_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Colletotrichum lindemuthianum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Angular Leaf Spot': {
    'imagePath': 'assets/diseases/beans_angular_leaf_spot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Pseudomonas syringae pv. phaseolicola',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant parts',
      'Use drip irrigation to avoid leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Common Bacterial Blight': {
    'imagePath': 'assets/diseases/beans_common_bacterial_blight_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Xanthomonas axonopodis pv. phaseoli',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant parts',
      'Use drip irrigation to reduce leaf wetness',
      'Practice crop rotation with non-host crops',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Halo Blight': {
    'imagePath': 'assets/diseases/beans_halo_blight_vegetative_growth.jpg',
    'possibleCauses': ['Cool, moist conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Pseudomonas savastanoi pv. phaseolicola',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to minimize leaf wetness',
      'Sanitize tools and equipment',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Bean Rust': {
    'imagePath': 'assets/diseases/beans_rust_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Uromyces appendiculatus',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected leaves',
      'Plant resistant bean varieties',
      'Ensure proper plant spacing for air circulation',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/beans_powdery_mildew_vegetative_growth.jpg',
    'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Erysiphe polygoni',
    'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Ensure adequate plant spacing for ventilation',
      'Apply potassium bicarbonate sprays',
      'Remove infected plant parts',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Bean Common Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_common_mosaic_virus_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
    'possibleCauses': ['Aphid transmission', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control aphids',
      'Crop rotation',
      'Use certified disease-free seeds',
      'Remove infected plants',
    ],
    'activeAgent': 'Bean Common Mosaic Virus (BCMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant bean varieties',
      'Remove and destroy infected plants',
      'Plant certified virus-free seeds',
      'Use reflective mulches to deter aphids',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Bean Golden Yellow Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg',
    'possibleCauses': ['Whitefly transmission', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control whiteflies',
      'Crop rotation',
      'Use certified disease-free seeds',
      'Remove infected plants',
    ],
    'activeAgent': 'Bean Golden Yellow Mosaic Virus (BGYMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control whitefly populations with neem oil sprays',
      'Use resistant bean varieties',
      'Remove and destroy infected plants',
      'Use yellow sticky traps to capture whiteflies',
      'Plant certified virus-free seeds',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'imagePath': 'assets/diseases/beans_root_knot_nematodes_vegetative_growth.jpg',
    'possibleCauses': ['Infected soil', 'Poor crop rotation', 'Warm soil temperatures'],
    'preventionStrategies': [
      'Crop rotation',
      'Use resistant varieties',
      'Soil solarization',
      'Use nematicides',
      'Incorporate organic matter',
    ],
    'activeAgent': 'Meloidogyne spp.',
    'fungicides': ['Furadan (Carbofuran)', 'Vydate (Oxamyl)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant bean varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health',
    ],
  },
  'Beans_Vegetative Growth/Weeding_Bacterial Wilt': {
    'imagePath': 'assets/diseases/beans_bacterial_wilt_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Soil-borne bacteria'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Ralstonia solanacearum',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plants',
      'Use drip irrigation to reduce soil splash',
      'Practice crop rotation with non-host crops',
    ],
  },

  // Beans - Flowering/Reproductive
  'Beans_Flowering/Reproductive_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Colletotrichum lindemuthianum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Beans_Flowering/Reproductive_Angular Leaf Spot': {
    'imagePath': 'assets/diseases/beans_angular_leaf_spot_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Pseudomonas syringae pv. phaseolicola',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Remove and destroy infected plant parts',
      'Use drip irrigation to avoid leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Beans_Flowering/Reproductive_Bean Rust': {
    'imagePath': 'assets/diseases/beans_rust_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Uromyces appendiculatus',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Remove and destroy infected leaves',
      'Plant resistant bean varieties',
      'Ensure proper plant spacing for air circulation',
    ],
  },
  'Beans_Flowering/Reproductive_Powdery Mildew': {
    'imagePath': 'assets/diseases/beans_powdery_mildew_flowering.jpg',
    'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Erysiphe polygoni',
    'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Ensure adequate plant spacing for ventilation',
      'Apply potassium bicarbonate sprays',
      'Remove infected plant parts',
    ],
  },
  'Beans_Flowering/Reproductive_Bean Common Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_common_mosaic_virus_flowering.jpg',
    'fallbackImagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
    'possibleCauses': ['Aphid transmission', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control aphids',
      'Crop rotation',
      'Use certified disease-free seeds',
      'Remove infected plants',
    ],
    'activeAgent': 'Bean Common Mosaic Virus (BCMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant bean varieties',
      'Remove and destroy infected plants',
      'Plant certified virus-free seeds',
      'Use reflective mulches to deter aphids',
    ],
  },
  'Beans_Flowering/Reproductive_Bean Golden Yellow Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_flowering.jpg',
    'fallbackImagePath': 'assets/diseases/beans_anthracnose_flowering.jpg',
    'possibleCauses': ['Whitefly transmission', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control whiteflies',
      'Crop rotation',
      'Use certified disease-free seeds',
      'Remove infected plants',
    ],
    'activeAgent': 'Bean Golden Yellow Mosaic Virus (BGYMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control whitefly populations with neem oil sprays',
      'Use resistant bean varieties',
      'Remove and destroy infected plants',
      'Use yellow sticky traps to capture whiteflies',
      'Plant certified virus-free seeds',
    ],
  },
  'Beans_Flowering/Reproductive_Ascochyta Blight': {
    'imagePath': 'assets/diseases/beans_ascochyta_blight_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Ascochyta phaseolorum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Beans_Flowering/Reproductive_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Dense canopies'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Sclerotinia sclerotiorum',
    'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. as a biofungicide',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Ensure wide plant spacing for air circulation',
      'Use drip irrigation to reduce humidity',
    ],
  },
  'Beans_Flowering/Reproductive_Bacterial Wilt': {
    'imagePath': 'assets/diseases/beans_bacterial_wilt_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Soil-borne bacteria'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Ralstonia solanacearum',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage and pods',
      'Remove and destroy infected plants',
      'Use drip irrigation to reduce soil splash',
      'Practice crop rotation with non-host crops',
    ],
  },

  // Beans - Maturation/Harvesting
  'Beans_Maturation/Harvesting_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Colletotrichum lindemuthianum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on pods',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Beans_Maturation/Harvesting_Ascochyta Blight': {
    'imagePath': 'assets/diseases/beans_ascochyta_blight_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Ascochyta phaseolorum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on pods',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Beans_Maturation/Harvesting_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Dense canopies'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Sclerotinia sclerotiorum',
    'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. as a biofungicide',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Ensure wide plant spacing for air circulation',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Beans_Maturation/Harvesting_Brown Spot': {
    'imagePath': 'assets/diseases/beans_brown_spot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Septoria glycines',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on pods',
      'Remove and destroy infected plant debris',
      'Plant resistant bean varieties',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Beans_Maturation/Harvesting_Fusarium Wilt': {
    'imagePath': 'assets/diseases/beans_fusarium_wilt_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Soil-borne fungi'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Harvest promptly',
    ],
    'activeAgent': 'Fusarium oxysporum',
    'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benlate (Benomyl)'],
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem-based products as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant bean varieties',
      'Harvest promptly to minimize damage',
    ],
  },
  'Beans_Maturation/Harvesting_Web Blight': {
    'imagePath': 'assets/diseases/beans_web_blight_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Dense canopies'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Harvest promptly',
    ],
    'activeAgent': 'Rhizoctonia solani',
    'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    'organicInterventions': [
      'Apply Trichoderma harzianum to soil',
      'Use neem oil sprays on pods',
      'Remove and destroy infected plant debris',
      'Ensure wide plant spacing for air circulation',
      'Harvest promptly to reduce exposure',
    ],
  },

  // Beans - Storage
  'Beans_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/beans_post_harvest_fungal_rot_storage.jpg',
    'possibleCauses': ['High humidity', 'Infected seeds', 'Improper storage conditions'],
    'preventionStrategies': [
      'Store in dry, cool conditions',
      'Use airtight containers',
      'Inspect seeds before storage',
      'Maintain low humidity',
      'Use desiccants',
    ],
    'activeAgent': 'Aspergillus spp., Penicillium spp.',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Store beans in airtight containers with desiccants',
      'Maintain storage temperature at 10-15°C',
      'Use neem powder as a natural fungicide',
      'Inspect and remove infected seeds',
      'Ensure proper ventilation in storage areas',
    ],
  },

  // ===== MAIZE DISEASES =====
  // Maize - Germination/Seedling
  'Maize_Germination/Seedling_Pythium Root Rot': {
    'imagePath': 'assets/diseases/maize_pythium_root_rot_germination.jpg',
    'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions', 'Poor drainage'],
    'preventionStrategies': [
      'Use treated seeds',
      'Avoid overwatering',
      'Crop rotation',
      'Improve soil drainage',
      'Use raised beds',
    ],
    'activeAgent': 'Pythium spp.',
    'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Incorporate organic matter to improve soil structure',
      'Use compost teas to enhance soil microbes',
      'Avoid waterlogging by improving drainage',
    ],
  },
  'Maize_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/maize_damping_off_germination.jpg',
    'possibleCauses': ['Wet soil', 'Poor ventilation', 'Fungal pathogens like Pythium and Rhizoctonia'],
    'preventionStrategies': [
      'Use sterile soil',
      'Avoid overwatering',
      'Ensure good drainage',
      'Provide adequate ventilation',
      'Use treated seeds',
    ],
    'activeAgent': 'Pythium spp., Rhizoctonia spp.',
    'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    'organicInterventions': [
      'Apply Trichoderma viride as a seed treatment',
      'Use compost to improve soil health',
      'Apply neem oil to soil',
      'Ensure proper seed spacing for ventilation',
      'Use well-drained, sterile planting medium',
    ],
  },

  // Maize - Vegetative Growth/Weeding
  'Maize_Vegetative Growth/Weeding_Gray Leaf Spot': {
    'imagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Cercospora zeae-maydis',
    'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Common Rust': {
    'imagePath': 'assets/diseases/maize_common_rust_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Airborne spores', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Puccinia sorghi',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected leaves',
      'Plant resistant maize hybrids',
      'Ensure proper plant spacing for air circulation',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Northern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Cool, wet conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Exserohilum turcicum',
    'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Maize Dwarf Mosaic Virus': {
    'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg',
    'possibleCauses': ['Aphid transmission', 'Infected seeds', 'Weedy hosts'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control aphids',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Maize Dwarf Mosaic Virus (MDMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Control weeds that serve as virus hosts',
      'Plant certified virus-free seeds',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Bacterial Leaf Streak': {
    'imagePath': 'assets/diseases/maize_bacterial_leaf_streak_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Bacterial spread via water', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Xanthomonas vasicola pv. vasculorum',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Anthracnose Leaf Blight': {
    'imagePath': 'assets/diseases/maize_anthracnose_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Colletotrichum graminicola',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Stewart\'s Wilt': {
    'imagePath': 'assets/diseases/maize_stewarts_wilt_vegetative_growth.jpg',
    'possibleCauses': ['Flea beetle transmission', 'Infected seeds', 'Warm conditions'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control flea beetles',
      'Crop rotation',
      'Remove infected debris',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Pantoea stewartii',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control flea beetle populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Use yellow sticky traps to capture flea beetles',
      'Plant certified disease-free seeds',
    ],
  },
  'Maize_Vegetative Growth/Weeding_Maize Streak Virus': {
    'imagePath': 'assets/diseases/maize_streak_virus_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg',
    'possibleCauses': ['Leafhopper transmission', 'Infected seeds', 'Weedy hosts'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control leafhoppers',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Maize Streak Virus (MSV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control leafhopper populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Control weeds that serve as virus hosts',
      'Use yellow sticky traps to capture leafhoppers',
    ],
  },

  // Maize - Flowering/Reproductive
  'Maize_Flowering/Reproductive_Gray Leaf Spot': {
    'imagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Cercospora zeae-maydis',
    'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and tassels',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Flowering/Reproductive_Common Rust': {
    'imagePath': 'assets/diseases/maize_common_rust_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Airborne spores', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Puccinia sorghi',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage and tassels',
      'Remove and destroy infected leaves',
      'Plant resistant maize hybrids',
      'Ensure proper plant spacing for air circulation',
    ],
  },
  'Maize_Flowering/Reproductive_Southern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_southern_corn_leaf_blight_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Bipolaris maydis',
    'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and tassels',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Flowering/Reproductive_Northern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_flowering.jpg',
    'possibleCauses': ['Cool, wet conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Exserohilum turcicum',
    'fungicides': ['Tilt (Propiconazole)', 'Headline (Pyraclostrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and tassels',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Flowering/Reproductive_Maize Dwarf Mosaic Virus': {
    'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_flowering.jpg',
    'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg',
    'possibleCauses': ['Aphid transmission', 'Infected seeds', 'Weedy hosts'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control aphids',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Maize Dwarf Mosaic Virus (MDMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Control weeds that serve as virus hosts',
      'Plant certified virus-free seeds',
    ],
  },
  'Maize_Flowering/Reproductive_Tar Spot': {
    'imagePath': 'assets/diseases/maize_tar_spot_flowering.jpg',
    'possibleCauses': ['Cool, humid conditions', 'Infected crop residue', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Phyllachora maydis',
    'fungicides': ['Headline (Pyraclostrobin)', 'Quadris (Azoxystrobin)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and tassels',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Flowering/Reproductive_Downy Mildew': {
    'imagePath': 'assets/diseases/maize_downy_mildew_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Peronosclerospora spp.',
    'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Flowering/Reproductive_Maize Streak Virus': {
    'imagePath': 'assets/diseases/maize_streak_virus_flowering.jpg',
    'fallbackImagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg',
    'possibleCauses': ['Leafhopper transmission', 'Infected seeds', 'Weedy hosts'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control leafhoppers',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Maize Streak Virus (MSV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control leafhopper populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Control weeds that serve as virus hosts',
      'Use yellow sticky traps to capture leafhoppers',
    ],
  },

  // Maize - Maturation/Harvesting
  'Maize_Maturation/Harvesting_Maize Lethal Necrosis': {
    'imagePath': 'assets/diseases/maize_lethal_necrosis_harvesting.jpg',
    'possibleCauses': ['Virus transmission by aphids', 'Infected seeds', 'Multiple viral infections'],
    'preventionStrategies': [
      'Use resistant hybrids',
      'Control insect vectors',
      'Crop rotation',
      'Use certified disease-free seeds',
      'Remove infected plants',
    ],
    'activeAgent': 'Combination of MCMV and MDMV or SCMV',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant maize hybrids',
      'Remove and destroy infected plants',
      'Plant certified virus-free seeds',
      'Use reflective mulches to deter aphids',
    ],
  },
  'Maize_Maturation/Harvesting_Head Smut': {
    'imagePath': 'assets/diseases/maize_head_smut_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Soil-borne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Use treated seeds',
      'Avoid overhead irrigation',
    ],
    'activeAgent': 'Sporisorium reilianum',
    'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use certified disease-free seeds',
    ],
  },
  'Maize_Maturation/Harvesting_Common Smut': {
    'imagePath': 'assets/diseases/maize_common_smut_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Injured plants', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid mechanical injury',
      'Apply fungicides early',
    ],
    'activeAgent': 'Ustilago maydis',
    'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Plant resistant maize hybrids',
      'Avoid mechanical damage to plants',
    ],
  },
  'Maize_Maturation/Harvesting_Goss\'s Wilt': {
    'imagePath': 'assets/diseases/maize_goss_wilt_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected crop residue', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Clavibacter michiganensis subsp. nebraskensis',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Maize_Maturation/Harvesting_Fusarium Ear Rot': {
    'imagePath': 'assets/diseases/maize_fusarium_ear_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Insect damage', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Control insect pests',
      'Harvest promptly',
    ],
    'activeAgent': 'Fusarium verticillioides',
    'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem oil sprays on ears',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Maize_Maturation/Harvesting_Gibberella Ear Rot': {
    'imagePath': 'assets/diseases/maize_giberella_ear_rot_harvesting.jpg',
    'possibleCauses': ['Cool, wet conditions', 'Insect damage', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Control insect pests',
      'Harvest promptly',
    ],
    'activeAgent': 'Fusarium graminearum',
    'fungicides': ['Proline (Prothioconazole)', 'Tilt (Propiconazole)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem oil sprays on ears',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Maize_Maturation/Harvesting_Diplodia Ear Rot': {
    'imagePath': 'assets/diseases/maize_diplodia_ear_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Insect damage', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Control insect pests',
      'Harvest promptly',
    ],
    'activeAgent': 'Stenocarpella maydis',
    'fungicides': ['Bavistin (Carbendazim)', 'Mancozeb'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem oil sprays on ears',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Maize_Maturation/Harvesting_Aspergillus Ear Rot': {
    'imagePath': 'assets/diseases/maize_aspergillus_ear_rot_harvesting.jpg',
    'possibleCauses': ['Warm, dry conditions', 'Insect damage', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Control insect pests',
      'Harvest promptly',
    ],
    'activeAgent': 'Aspergillus flavus',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem oil sprays on ears',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Maize_Maturation/Harvesting_Bacterial Stalk Rot': {
    'imagePath': 'assets/diseases/maize_bacterial_stalk_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Injured plants', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Avoid mechanical injury',
    ],
    'activeAgent': 'Erwinia chrysanthemi pv. zeae',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on stalks',
      'Remove and destroy infected plant debris',
      'Plant resistant maize hybrids',
      'Use drip irrigation to reduce wetness',
    ],
  },
  'Maize_Maturation/Harvesting_Charcoal Rot': {
    'imagePath': 'assets/diseases/maize_charcoal_rot_harvesting.jpg',
    'possibleCauses': ['Warm, dry conditions', 'Drought stress', 'Infected crop residue'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Maintain adequate irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Macrophomina phaseolina',
    'fungicides': ['Quadris (Azoxystrobin)', 'Amistar (Azoxystrobin)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Remove and destroy infected plant debris',
      'Maintain soil moisture to reduce stress',
      'Plant resistant maize hybrids',
    ],
  },

  // Maize - Storage
  'Maize_Storage_Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)': {
    'imagePath': 'assets/diseases/maize_post_harvest_mycotoxins_storage.jpg',
    'possibleCauses': ['High humidity', 'Infected seeds', 'Improper storage conditions'],
    'preventionStrategies': [
      'Store in dry, cool conditions',
      'Use airtight containers',
      'Inspect seeds before storage',
      'Maintain low humidity',
      'Use desiccants',
    ],
    'activeAgent': 'Aspergillus flavus, Fusarium verticillioides',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Store maize in airtight containers with desiccants',
      'Maintain storage temperature at 10-15°C',
      'Use neem powder as a natural fungicide',
      'Inspect and remove infected kernels',
      'Ensure proper ventilation in storage areas',
    ],
  },
  'Maize_Storage_Storage Rot': {
    'imagePath': 'assets/diseases/maize_storage_rot_storage.jpg',
    'possibleCauses': ['High humidity', 'Infected seeds', 'Improper storage conditions'],
    'preventionStrategies': [
      'Store in dry, cool conditions',
      'Use airtight containers',
      'Inspect seeds before storage',
      'Maintain low humidity',
      'Use desiccants',
    ],
    'activeAgent': 'Aspergillus spp., Penicillium spp.',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Store maize in airtight containers with desiccants',
      'Maintain storage temperature at 10-15°C',
      'Use neem powder as a natural fungicide',
      'Inspect and remove infected kernels',
      'Ensure proper ventilation in storage areas',
    ],
  },

 // ===== CABBAGES/KALES DISEASES =====
  // Cabbages/Kales - Germination/Seedling
  'Cabbages/Kales_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/cabbage_damping_off_germination.jpg',
    'possibleCauses': ['Wet soil', 'Poor ventilation', 'Fungal pathogens like Pythium and Rhizoctonia'],
    'preventionStrategies': [
      'Use sterile soil',
      'Avoid overwatering',
      'Ensure good drainage',
      'Provide adequate ventilation',
      'Use treated seeds',
    ],
    'activeAgent': 'Pythium spp., Rhizoctonia spp.',
    'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    'organicInterventions': [
      'Apply Trichoderma viride as a seed treatment',
      'Use compost to improve soil health',
      'Apply neem oil to soil',
      'Ensure proper seed spacing for ventilation',
      'Use well-drained, sterile planting medium',
    ],
  },
  'Cabbages/Kales_Germination/Seedling_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_germination.jpg',
    'possibleCauses': ['Warm, wet conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use certified disease-free seeds',
      'Crop rotation',
      'Remove plant debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Xanthomonas campestris pv. campestris',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on seedlings',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Cabbages/Kales_Germination/Seedling_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_germination.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Peronospora parasitica',
    'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on seedlings',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },

  // Cabbages/Kales - Vegetative Growth/Weeding
  'Cabbages/Kales_Vegetative Growth/Weeding_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, wet conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use certified disease-free seeds',
      'Crop rotation',
      'Remove plant debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Xanthomonas campestris pv. campestris',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Peronospora parasitica',
    'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/cabbage_powdery_mildew_vegetative_growth.jpg',
    'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Erysiphe cruciferarum',
    'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Ensure adequate plant spacing for ventilation',
      'Apply potassium bicarbonate sprays',
      'Remove infected plant parts',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Alternaria Leaf Spot': {
    'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected leaves',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Alternaria brassicicola, Alternaria brassicae',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected leaves',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Ring Spot': {
    'imagePath': 'assets/diseases/cabbage_ring_spot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Mycosphaerella brassicicola',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Bacterial Soft Rot': {
    'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Injured plants', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Avoid mechanical injury',
    ],
    'activeAgent': 'Erwinia carotovora',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce wetness',
      'Avoid wounding plants during cultivation',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Fusarium Yellows': {
    'imagePath': 'assets/diseases/cabbage_fusarium_yellows_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected soil', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Use treated seeds',
    ],
    'activeAgent': 'Fusarium oxysporum f.sp. conglutinans',
    'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem-based products as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant varieties',
      'Improve soil drainage to reduce fungal spread',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_White Rust': {
    'imagePath': 'assets/diseases/cabbage_white_rust_vegetative_growth.jpg',
    'possibleCauses': ['Cool, wet conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Albugo candida',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Leaf Blight': {
    'imagePath': 'assets/diseases/cabbage_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Alternaria spp.',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Vegetative Growth/Weeding_Black Leg': {
    'imagePath': 'assets/diseases/cabbage_black_leg_vegetative_growth.jpg',
    'possibleCauses': ['Cool, wet conditions', 'Infected seeds', 'Soil-borne fungi'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Use treated seeds',
      'Improve soil drainage',
    ],
    'activeAgent': 'Phoma lingam',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce wetness',
    ],
  },

  // Cabbages/Kales - Flowering/Reproductive
  'Cabbages/Kales_Flowering/Reproductive_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Peronospora parasitica',
    'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and flower heads',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Flowering/Reproductive_Powdery Mildew': {
    'imagePath': 'assets/diseases/cabbage_powdery_mildew_flowering.jpg',
    'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Erysiphe cruciferarum',
    'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage and flower heads',
      'Ensure adequate plant spacing for ventilation',
      'Apply potassium bicarbonate sprays',
      'Remove infected plant parts',
    ],
  },
  'Cabbages/Kales_Flowering/Reproductive_Alternaria Leaf Spot': {
    'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected leaves',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Alternaria brassicicola, Alternaria brassicae',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and flower heads',
      'Remove and destroy infected leaves',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Cabbages/Kales_Flowering/Reproductive_Sclerotinia Stem Rot (White Mold)': {
    'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Dense canopies'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Sclerotinia sclerotiorum',
    'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. as a biofungicide',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Ensure wide plant spacing for air circulation',
      'Use drip irrigation to reduce humidity',
    ],
  },
  'Cabbages/Kales_Flowering/Reproductive_Anthracnose': {
    'imagePath': 'assets/diseases/cabbage_anthracnose_flowering.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Colletotrichum higginsianum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage and flower heads',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },

  // Cabbages/Kales - Maturation/Harvesting
  'Cabbages/Kales_Maturation/Harvesting_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_harvesting.jpg',
    'possibleCauses': ['Warm, wet conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use certified disease-free seeds',
      'Crop rotation',
      'Remove plant debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Xanthomonas campestris pv. campestris',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on heads',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce leaf wetness',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Cabbages/Kales_Maturation/Harvesting_Sclerotinia Stem Rot (White Mold)': {
    'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Dense canopies'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Sclerotinia sclerotiorum',
    'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. as a biofungicide',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Ensure wide plant spacing for air circulation',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Cabbages/Kales_Maturation/Harvesting_Bacterial Soft Rot': {
    'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Injured plants', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Avoid mechanical injury',
    ],
    'activeAgent': 'Erwinia carotovora',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on heads',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce wetness',
      'Avoid wounding plants during harvest',
    ],
  },
  'Cabbages/Kales_Maturation/Harvesting_Anthracnose': {
    'imagePath': 'assets/diseases/cabbage_anthracnose_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Colletotrichum higginsianum',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on heads',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Harvest promptly to reduce exposure',
    ],
  },

  // Cabbages/Kales - Storage
  'Cabbages/Kales_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/cabbage_post_harvest_fungal_rot_storage.jpg',
    'possibleCauses': ['High humidity', 'Infected heads', 'Improper storage conditions'],
    'preventionStrategies': [
      'Store in dry, cool conditions',
      'Use airtight containers',
      'Inspect heads before storage',
      'Maintain low humidity',
      'Use desiccants',
    ],
    'activeAgent': 'Aspergillus spp., Penicillium spp.',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Store in cool, dry conditions (0-2°C)',
      'Use neem powder as a natural fungicide',
      'Inspect and remove infected heads',
      'Ensure proper ventilation in storage areas',
      'Use desiccants to reduce humidity',
    ],
  },

  // ===== CARROTS DISEASES =====
  // Carrots - Germination/Seedling
  'Carrots_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/carrots_damping_off_germination.jpg',
    'possibleCauses': ['Wet soil', 'Poor ventilation', 'Fungal pathogens like Pythium and Rhizoctonia'],
    'preventionStrategies': [
      'Use sterile soil',
      'Avoid overwatering',
      'Ensure good drainage',
      'Provide adequate ventilation',
      'Use treated seeds',
    ],
    'activeAgent': 'Pythium spp., Rhizoctonia spp.',
    'fungicides': ['Captan 50WP (Captan)', 'Thiram (Thiram)'],
    'organicInterventions': [
      'Apply Trichoderma viride as a seed treatment',
      'Use compost to improve soil health',
      'Apply neem oil to soil',
      'Ensure proper seed spacing for ventilation',
      'Use well-drained, sterile planting medium',
    ],
  },
  'Carrots_Germination/Seedling_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/carrots_fusarium_root_rot_germination.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected soil', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Use treated seeds',
    ],
    'activeAgent': 'Fusarium spp.',
    'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem-based products as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant varieties',
      'Improve soil drainage to reduce fungal spread',
    ],
  },
  'Carrots_Germination/Seedling_Rhizoctonia Root Rot': {
    'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_germination.jpg',
    'possibleCauses': ['Warm, wet soil', 'Poor drainage', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Use treated seeds',
    ],
    'activeAgent': 'Rhizoctonia solani',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply Trichoderma harzianum to soil',
      'Use neem oil as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant varieties',
      'Improve soil drainage to reduce fungal spread',
    ],
  },
  'Carrots_Germination/Seedling_Pythium Root Rot': {
    'imagePath': 'assets/diseases/carrots_pythium_root_rot_germination.jpg',
    'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions', 'Poor drainage'],
    'preventionStrategies': [
      'Use treated seeds',
      'Avoid overwatering',
      'Crop rotation',
      'Improve soil drainage',
      'Use raised beds',
    ],
    'activeAgent': 'Pythium spp.',
    'fungicides': ['Ridomil Gold (Mefenoxam)', 'Apron XL (Mefenoxam)'],
    'organicInterventions': [
      'Apply Trichoderma spp. to soil',
      'Use neem-based products as a soil drench',
      'Incorporate organic matter to improve soil structure',
      'Use compost teas to enhance soil microbes',
      'Avoid waterlogging by improving drainage',
    ],
  },

  // Carrots - Vegetative Growth/Weeding
  'Carrots_Vegetative Growth/Weeding_Alternaria Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Humid conditions', 'Dense foliage', 'Infected crop residue'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove plant debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Alternaria dauci',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Cercospora Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_cercospora_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Rain splash'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected leaves',
      'Ensure proper spacing',
      'Avoid overhead irrigation',
      'Use resistant varieties',
    ],
    'activeAgent': 'Cercospora carotae',
    'fungicides': ['Dithane (Mancozeb)', 'Manzate (Mancozeb)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected leaves',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/carrots_powdery_mildew_vegetative_growth.jpg',
    'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Apply fungicides early',
    ],
    'activeAgent': 'Erysiphe heraclei',
    'fungicides': ['Microthiol (Sulfur)', 'Thiovit (Sulfur)'],
    'organicInterventions': [
      'Apply sulfur-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Ensure adequate plant spacing for ventilation',
      'Apply potassium bicarbonate sprays',
      'Remove infected plant parts',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Downy Mildew': {
    'imagePath': 'assets/diseases/carrots_downy_mildew_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Airborne spores'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Ensure good air circulation',
    ],
    'activeAgent': 'Peronospora farinosa',
    'fungicides': ['Ridomil Gold (Metalaxyl)', 'Subdue MAXX (Mefenoxam)'],
    'organicInterventions': [
      'Apply copper-based fungicides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Plant resistant varieties',
      'Use drip irrigation to reduce leaf wetness',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Bacterial Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_bacterial_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Sanitize tools',
    ],
    'activeAgent': 'Xanthomonas campestris pv. carotae',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on foliage',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce leaf wetness',
      'Sanitize equipment to prevent spread',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'imagePath': 'assets/diseases/carrots_root_knot_nematodes_vegetative_growth.jpg',
    'possibleCauses': ['Warm, moist soil conditions', 'Infected soil', 'Poor crop rotation'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Soil solarization',
      'Use nematicides',
      'Incorporate organic matter',
    ],
    'activeAgent': 'Meloidogyne spp.',
    'fungicides': ['Furadan (Carbofuran)', 'Vydate (Oxamyl)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Carrot Mosaic Virus': {
    'imagePath': 'assets/diseases/carrots_mosaic_virus_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Aphid transmission', 'Infected seeds', 'Weedy hosts'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control aphids',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Carrot Mosaic Virus (CaMV)',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control aphid populations with neem oil sprays',
      'Use resistant varieties',
      'Remove and destroy infected plants',
      'Control weeds that serve as virus hosts',
      'Plant certified virus-free seeds',
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Aster Yellows': {
    'imagePath': 'assets/diseases/carrots_aster_yellows_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg',
    'possibleCauses': ['Leafhopper transmission', 'Infected weeds', 'Phytoplasma spread'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Control leafhoppers',
      'Crop rotation',
      'Remove weed hosts',
      'Use certified disease-free seeds',
    ],
    'activeAgent': 'Aster Yellows Phytoplasma',
    'fungicides': ['None'],
    'organicInterventions': [
      'Control leafhopper populations with neem oil sprays',
      'Use resistant varieties',
      'Remove and destroy infected plants',
      'Control weeds that serve as phytoplasma hosts',
      'Use yellow sticky traps to capture leafhoppers',
    ],
  },

  // Carrots - Maturation/Harvesting
    'Carrots_Maturation/Harvesting_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/carrots_sclerotinia_white_mold_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Dense canopies'],
    'preventionStrategies': [
      'Crop rotation',
      'Remove infected debris',
      'Ensure good air circulation',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Sclerotinia sclerotiorum',
    'fungicides': ['Endura (Boscalid)', 'Switch (Cyprodinil + Fludioxonil)'],
    'organicInterventions': [
      'Apply Trichoderma spp. as a biofungicide',
      'Use neem oil sprays on affected areas',
      'Remove and destroy infected plant parts',
      'Ensure wide plant spacing for air circulation',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Carrots_Maturation/Harvesting_Black Rot': {
    'imagePath': 'assets/diseases/carrots_black_rot_harvesting.jpg',
    'possibleCauses': ['Warm, wet conditions', 'Infected seeds', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use certified disease-free seeds',
      'Crop rotation',
      'Remove plant debris',
      'Avoid overhead irrigation',
      'Harvest promptly',
    ],
    'activeAgent': 'Xanthomonas campestris pv. carotae',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on roots',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce wetness',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Carrots_Maturation/Harvesting_Soft Rot': {
    'imagePath': 'assets/diseases/carrots_soft_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Injured roots', 'Bacterial spread via water'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Avoid overhead irrigation',
      'Avoid mechanical injury',
    ],
    'activeAgent': 'Erwinia carotovora',
    'fungicides': ['Kocide (Copper hydroxide)', 'Champ (Copper hydroxide)'],
    'organicInterventions': [
      'Apply copper-based bactericides (organic)',
      'Use neem oil sprays on roots',
      'Remove and destroy infected plant debris',
      'Use drip irrigation to reduce wetness',
      'Avoid wounding roots during harvest',
    ],
  },
  'Carrots_Maturation/Harvesting_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/carrots_fusarium_root_rot_harvesting.jpg',
    'possibleCauses': ['Warm, humid conditions', 'Infected soil', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Harvest promptly',
    ],
    'activeAgent': 'Fusarium spp.',
    'fungicides': ['Topsin-M (Thiophanate-methyl)', 'Benomyl'],
    'organicInterventions': [
      'Apply Trichoderma viride to soil',
      'Use neem-based products as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant varieties',
      'Harvest promptly to reduce exposure',
    ],
  },
  'Carrots_Maturation/Harvesting_Rhizoctonia Root Rot': {
    'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_harvesting.jpg',
    'possibleCauses': ['Warm, wet soil', 'Poor drainage', 'Infected seeds'],
    'preventionStrategies': [
      'Use resistant varieties',
      'Crop rotation',
      'Remove infected debris',
      'Improve soil drainage',
      'Harvest promptly',
    ],
    'activeAgent': 'Rhizoctonia solani',
    'fungicides': ['Bravo (Chlorothalonil)', 'Daconil (Chlorothalonil)'],
    'organicInterventions': [
      'Apply Trichoderma harzianum to soil',
      'Use neem oil as a soil drench',
      'Incorporate compost to improve soil health',
      'Plant resistant varieties',
      'Harvest promptly to reduce exposure',
    ],
  },
  // Carrots - Storage
  'Carrots_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/carrots_post_harvest_fungal_rot_storage.jpg',
    'possibleCauses': ['High humidity', 'Infected roots', 'Improper storage conditions'],
    'preventionStrategies': [
      'Store in dry, cool conditions',
      'Use airtight containers',
      'Inspect roots before storage',
      'Maintain low humidity',
      'Use desiccants',
    ],
    'activeAgent': 'Aspergillus spp., Penicillium spp.',
    'fungicides': ['Propiconazole', 'Azoxystrobin'],
    'organicInterventions': [
      'Store in cool, dry conditions (0-2°C)',
      'Use neem powder as a natural fungicide',
      'Inspect and remove infected roots',
      'Ensure proper ventilation in storage areas',
      'Use desiccants to reduce humidity',
    ],
  },

      // ===== TOMATOES DISEASES =====
    // Tomatoes - Germination/Seedling
    'Tomatoes_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/tomato_damping_off_germination.jpg',
      'possibleCauses': ['Wet soil', 'Poor ventilation', 'Infected seeds', 'High humidity'],
      'possibleStrategies': [
        'Use sterile soil or organic compost',
        'Avoid overwatering',
        'Ensure good drainage with organic amendments',
        'Apply biofungicides like Trichoderma spp.',
        'Improve air circulation around seedlings',
      ],
      'intervention': 'Fungicide (Captan)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Captan 50WP (Captan)',
      ],
      'organicInterventions': [
        'Use sterile organic compost',
        'Apply Trichoderma harzianum to soil',
        'Avoid overwatering seedlings',
        'Ensure good drainage with compost amendments',
        'Improve air circulation around seedlings',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Bacterial Wilt': {
      'imagePath': 'assets/diseases/tomato_bacterial_wilt_germination.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Contaminated soil', 'Poor sanitation'],
      'possibleStrategies': [
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Bactericide (Copper hydroxide)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Kocide (Copper hydroxide)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to soil',
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts like cereals',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Fusarium Wilt': {
      'imagePath': 'assets/diseases/tomato_fusarium_wilt_germination.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'fungicides': [
        'Trichoderma viride (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Topsin-M (Thiophanate-methyl)',
      ],
      'organicInterventions': [
        'Apply Trichoderma viride to soil',
        'Use resistant tomato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Remove infected debris and compost',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Verticillium Wilt': {
      'imagePath': 'assets/diseases/tomato_verticillium_wilt_germination.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Thiophanate-methyl)',
      'fungicides': [
        'Trichoderma viride (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Topsin-M (Thiophanate-methyl)',
      ],
      'organicInterventions': [
        'Apply Trichoderma viride to soil',
        'Use resistant tomato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Remove infected debris and compost',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_germination.jpg',
    },

    // Tomatoes - Vegetative Growth/Weeding
    'Tomatoes_Vegetative Growth/Weeding_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg',
      'possibleCauses': ['Warm, wet weather', 'Infected plant debris', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected leaves',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_vegetative_growth.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Poor sanitation', 'Water splash'],
      'possibleStrategies': [
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Bactericide (Copper hydroxide)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Kocide (Copper hydroxide)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts like cereals',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_vegetative_growth.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Poor sanitation', 'Mechanical injury'],
      'possibleStrategies': [
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Bactericide (Copper hydroxide)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Kocide (Copper hydroxide)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts like cereals',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_vegetative_growth.jpg',
      'possibleCauses': ['Aphid transmission', 'Infected seeds', 'Contaminated tools', 'Human handling'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control aphids with organic methods (e.g., neem oil, ladybugs)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter aphids',
      ],
      'intervention': 'Organic aphid control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control aphids',
        'Introduce ladybugs to control aphid population',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter aphids',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_vegetative_growth.jpg',
      'possibleCauses': ['Whitefly transmission', 'Infected seeds', 'Nearby host plants', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control whiteflies with organic methods (e.g., neem oil, parasitic wasps)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter whiteflies',
      ],
      'intervention': 'Organic whitefly control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control whiteflies',
        'Introduce parasitic wasps to control whiteflies',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter whiteflies',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Septoria Leaf Spot': {
      'imagePath': 'assets/diseases/tomato_septoria_leaf_spot_vegetative_growth.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected leaves',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_vegetative_growth.jpg',
      'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Ensure good air circulation by proper spacing',
        'Rotate crops with non-hosts',
        'Apply organic mulch to maintain soil moisture',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide (Sulfur)',
      'fungicides': [
        'Sulfur-based fungicides (organic)',
        'Neem-based products (organic)',
        'Bacillus subtilis (organic)',
        'Microthiol (Sulfur)',
      ],
      'organicInterventions': [
        'Apply sulfur-based fungicides to foliage',
        'Use resistant tomato varieties',
        'Ensure proper plant spacing for air circulation',
        'Apply neem-based products to leaves',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Root Knot Nematodes': {
      'imagePath': 'assets/diseases/tomato_root_knot_nematodes_vegetative_growth.jpg',
      'possibleCauses': ['Warm, moist soil conditions', 'Infected soil', 'Poor crop rotation', 'Nearby host plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate with non-host crops (e.g., marigolds)',
        'Apply organic soil amendments (e.g., neem cake)',
        'Practice soil solarization',
        'Incorporate beneficial microbes',
      ],
      'intervention': 'Nematicide (Carbofuran)',
      'fungicides': [
        'Neem cake (organic)',
        'Paecilomyces lilacinus (organic)',
        'Bacillus firmus (organic)',
        'Furadan (Carbofuran)',
      ],
      'organicInterventions': [
        'Apply neem cake to soil',
        'Use resistant tomato varieties',
        'Rotate with marigolds to suppress nematodes',
        'Practice soil solarization before planting',
        'Incorporate Paecilomyces lilacinus into soil',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_vegetative_growth.jpg',
      'possibleCauses': ['Thrips transmission', 'Infected seeds', 'Nearby host plants', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control thrips with organic methods (e.g., neem oil, predatory mites)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter thrips',
      ],
      'intervention': 'Organic thrips control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control thrips',
        'Introduce predatory mites to control thrips',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_vegetative.jpg',
    },

    // Tomatoes - Flowering/Reproductive
    'Tomatoes_Flowering/Reproductive_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_flowering.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected leaves',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_flowering.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected leaves',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_flowering.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Poor sanitation', 'Water splash'],
      'possibleStrategies': [
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Bactericide (Copper hydroxide)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Kocide (Copper hydroxide)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts like cereals',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_flowering.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Poor sanitation', 'Mechanical injury'],
      'possibleStrategies': [
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Bactericide (Copper hydroxide)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Kocide (Copper hydroxide)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use certified disease-free seeds',
        'Rotate crops with non-hosts like cereals',
        'Remove and destroy infected debris',
        'Apply organic mulch to prevent splash',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_flowering.jpg',
      'possibleCauses': ['Aphid transmission', 'Infected seeds', 'Contaminated tools', 'Human handling'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control aphids with organic methods (e.g., neem oil, ladybugs)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter aphids',
      ],
      'intervention': 'Organic aphid control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control aphids',
        'Introduce ladybugs to control aphid population',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter aphids',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_flowering.jpg',
      'possibleCauses': ['Whitefly transmission', 'Infected seeds', 'Nearby host plants', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control whiteflies with organic methods (e.g., neem oil, parasitic wasps)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter whiteflies',
      ],
      'intervention': 'Organic whitefly control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control whiteflies',
        'Introduce parasitic wasps to control whiteflies',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter whiteflies',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_flowering.jpg',
      'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Ensure good air circulation by proper spacing',
        'Rotate crops with non-hosts',
        'Apply organic mulch to maintain soil moisture',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide (Sulfur)',
      'fungicides': [
        'Sulfur-based fungicides (organic)',
        'Neem-based products (organic)',
        'Bacillus subtilis (organic)',
        'Microthiol (Sulfur)',
      ],
      'organicInterventions': [
        'Apply sulfur-based fungicides to foliage',
        'Use resistant tomato varieties',
        'Ensure proper plant spacing for air circulation',
        'Apply neem-based products to flowers',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_flowering.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Rotate crops with non-hosts (e.g., cereals)',
        'Remove infected debris and compost',
        'Ensure good air circulation by proper spacing',
        'Apply organic mulch to reduce soil moisture',
        'Use biofungicides like Coniothyrium minitans',
      ],
      'intervention': 'Fungicide (Boscalid)',
      'fungicides': [
        'Coniothyrium minitans (organic)',
        'Bacillus subtilis (organic)',
        'Copper-based fungicides (organic)',
        'Endura (Boscalid)',
      ],
      'organicInterventions': [
        'Apply Coniothyrium minitans to foliage',
        'Remove and compost infected debris',
        'Ensure proper plant spacing for air circulation',
        'Apply organic mulch to reduce soil moisture',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_flowering.jpg',
      'possibleCauses': ['Thrips transmission', 'Infected seeds', 'Nearby host plants', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Control thrips with organic methods (e.g., neem oil, predatory mites)',
        'Rotate crops with non-hosts',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter thrips',
      ],
      'intervention': 'Organic thrips control and resistant varieties',
      'fungicides': ['None'],
      'organicInterventions': [
        'Use resistant tomato varieties',
        'Apply neem oil to control thrips',
        'Introduce predatory mites to control thrips',
        'Remove and destroy infected plants',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Alternaria Stem Canker': {
      'imagePath': 'assets/diseases/tomato_alternaria_stem_canker_flowering.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to stems',
        'Remove and compost infected debris',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_flowering.jpg',
    },

    // Tomatoes - Maturation/Harvesting
    'Tomatoes_Maturation/Harvesting_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_harvesting.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected debris',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_harvesting.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected debris',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_harvesting.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Rotate crops with non-hosts (e.g., cereals)',
        'Remove infected debris and compost',
        'Ensure good air circulation by proper spacing',
        'Apply organic mulch to reduce soil moisture',
        'Use biofungicides like Coniothyrium minitans',
      ],
      'intervention': 'Fungicide (Boscalid)',
      'fungicides': [
        'Coniothyrium minitans (organic)',
        'Bacillus subtilis (organic)',
        'Copper-based fungicides (organic)',
        'Endura (Boscalid)',
      ],
      'organicInterventions': [
        'Apply Coniothyrium minitans to foliage',
        'Remove and compost infected debris',
        'Ensure proper plant spacing for air circulation',
        'Apply organic mulch to reduce soil moisture',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Southern Blight': {
      'imagePath': 'assets/diseases/tomato_southern_blight_harvesting.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Rotate crops with non-hosts (e.g., cereals)',
        'Remove infected debris and compost',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
        'Practice soil solarization',
      ],
      'intervention': 'Fungicide (Boscalid)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Endura (Boscalid)',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Remove and compost infected debris',
        'Use crop rotation with non-hosts',
        'Incorporate compost teas into soil',
        'Practice soil solarization',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Anthracnose': {
      'imagePath': 'assets/diseases/tomato_anthracnose_harvesting.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to fruits',
        'Use resistant tomato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Fruit Rot': {
      'imagePath': 'assets/diseases/tomato_fruit_rot_harvesting.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor sanitation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to fruits',
        'Use resistant tomato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_harvesting.jpg',
    },

    // Tomatoes - Storage
    'Tomatoes_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/tomato_post_harvest_fungal_rot_storage.jpg',
      'possibleCauses': ['High humidity', 'Infected seeds', 'Poor storage conditions', 'Mechanical injury'],
      'possibleStrategies': [
        'Store in dry, cool conditions',
        'Use airtight containers with desiccants',
        'Apply organic seed treatments before storage',
        'Ensure proper ventilation in storage areas',
        'Use diatomaceous earth (organic)',
      ],
      'intervention': 'Fungicide (Propiconazole)',
      'fungicides': [
        'Diatomaceous earth (organic)',
        'Neem-based products (organic)',
        'Copper-based fungicides (organic)',
        'Propiconazole',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored tomatoes',
        'Use neem-based treatments before storage',
        'Store in dry, cool, well-ventilated conditions',
        'Use airtight containers with desiccants',
        'Inspect and remove damaged fruits',
      ],
      'fallbackImagePath': 'assets/diseases/tomato_default_storage.jpg',
    },

    // ===== ONIONS DISEASES =====
    // Onions - Germination/Seedling
    'Onions_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/onions_pythium_root_rot_germination.jpg',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions', 'Infected seeds', 'Poor drainage'],
      'possibleStrategies': [
        'Use seeds treated with organic fungicides',
        'Avoid overwatering',
        'Incorporate organic matter for better drainage',
        'Rotate crops with non-hosts',
        'Apply biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Mefenoxam)',
      'fungicides': [
        'Trichoderma viride (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Ridomil Gold (Mefenoxam)',
      ],
      'organicInterventions': [
        'Apply Trichoderma viride to soil',
        'Use seeds treated with neem-based products',
        'Avoid overwatering seedlings',
        'Incorporate organic matter for drainage',
        'Rotate crops with non-hosts like cereals',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_germination.jpg',
    },
    'Onions_Germination/Seedling_Fusarium Basal Rot': {
      'imagePath': 'assets/diseases/onions_fusarium_basal_rot_germination.jpg',
      'possibleCauses': ['Waterlogging', 'Contaminated soil', 'Poor soil health', 'Infected planting material'],
      'possibleStrategies': [
        'Use disease-free planting material',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicides like carbendazim',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Carbendazim',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use disease-free planting material',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_germination.jpg',
    },

    // Onions - Vegetative Growth/Weeding
    'Onions_Vegetative Growth/Weeding_Downy Mildew': {
      'imagePath': 'assets/diseases/onions_downy_mildew_vegetative_growth.jpg',
      'possibleCauses': ['High humidity', 'Cool temperatures', 'Poor drainage', 'Overcrowded plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Improve field ventilation by proper spacing',
        'Avoid overhead watering',
        'Rotate crops with non-hosts',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide sprays like metalaxyl or mancozeb',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Metalaxyl',
        'Mancozeb',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant onion varieties',
        'Avoid overhead watering to reduce humidity',
        'Ensure proper plant spacing for ventilation',
        'Rotate crops with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_vegetative.jpg',
    },
    'Onions_Vegetative Growth/Weeding_Leaf Blight': {
      'imagePath': 'assets/diseases/onions_leaf_blight_vegetative_growth.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seeds', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Remove and compost infected leaves',
        'Use crop rotation with non-hosts',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_vegetative.jpg',
    },
    'Onions_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/onions_powdery_mildew_vegetative_growth.jpg',
      'possibleCauses': ['Warm, dry conditions', 'High humidity', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Ensure good air circulation by proper spacing',
        'Rotate crops with non-hosts',
        'Apply organic mulch to maintain soil moisture',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Fungicide (Sulfur)',
      'fungicides': [
        'Sulfur-based fungicides (organic)',
        'Neem-based products (organic)',
        'Bacillus subtilis (organic)',
        'Microthiol (Sulfur)',
      ],
      'organicInterventions': [
        'Apply sulfur-based fungicides to foliage',
        'Use resistant onion varieties',
        'Ensure proper plant spacing for air circulation',
        'Apply neem-based products to leaves',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_vegetative.jpg',
    },

    // Onions - Bulb Formation/Reproductive
    'Onions_Bulb Formation/Reproductive_Fusarium Basal Rot': {
      'imagePath': 'assets/diseases/onions_fusarium_basal_rot_bulb_formation.jpg',
      'possibleCauses': ['Waterlogging', 'Contaminated soil', 'Poor soil health', 'Infected planting material'],
      'possibleStrategies': [
        'Use disease-free planting material',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicides like carbendazim',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Carbendazim',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use disease-free planting material',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_bulb_formation.jpg',
    },
    'Onions_Bulb Formation/Reproductive_Purple Blotch': {
      'imagePath': 'assets/diseases/onions_purple_blotch_bulb_formation.jpg',
      'possibleCauses': ['High humidity', 'Poor sanitation', 'Water splash', 'Infected seeds'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Remove infected plant debris and compost',
        'Improve airflow by proper spacing',
        'Apply organic mulch to reduce splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Spray with copper-based fungicides',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Copper oxychloride',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant onion varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for airflow',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_bulb_formation.jpg',
    },

    // Onions - Bulbing/Maturation
    'Onions_Bulbing/Maturation_Neck Rot': {
      'imagePath': 'assets/diseases/onions_neck_rot_bulbing.jpg',
      'possibleCauses': ['Overwatering', 'Poor curing', 'Contaminated soil', 'High humidity'],
      'possibleStrategies': [
        'Proper curing of bulbs',
        'Avoid watering during maturity',
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Application of fungicides like thiabendazole during curing',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Thiabendazole',
      ],
      'organicInterventions': [
        'Properly cure bulbs in dry conditions',
        'Apply copper-based fungicides before harvest',
        'Use resistant onion varieties',
        'Rotate crops with non-hosts',
        'Avoid watering during bulb maturation',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_bulbing.jpg',
    },
    'Onions_Bulbing/Maturation_Purple Blotch': {
      'imagePath': 'assets/diseases/onions_purple_blotch_bulbing.jpg',
      'possibleCauses': ['High humidity', 'Poor sanitation', 'Water splash', 'Infected seeds'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Remove infected plant debris and compost',
        'Improve airflow by proper spacing',
        'Apply organic mulch to reduce splash',
        'Use biofungicides like Bacillus subtilis',
      ],
      'intervention': 'Spray with copper-based fungicides',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Copper oxychloride',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant onion varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for airflow',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_bulbing.jpg',
    },
    'Onions_Bulbing/Maturation_Gray Mold': {
      'imagePath': 'assets/diseases/onions_gray_mold_bulbing.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected debris', 'Poor air circulation', 'Overcrowded plants'],
      'possibleStrategies': [
        'Rotate crops with non-hosts (e.g., cereals)',
        'Remove infected debris and compost',
        'Ensure good air circulation by proper spacing',
        'Apply organic mulch to reduce soil moisture',
        'Use biofungicides like Coniothyrium minitans',
      ],
      'intervention': 'Fungicide (Boscalid)',
      'fungicides': [
        'Coniothyrium minitans (organic)',
        'Bacillus subtilis (organic)',
        'Copper-based fungicides (organic)',
        'Endura (Boscalid)',
      ],
      'organicInterventions': [
        'Apply Coniothyrium minitans to foliage',
        'Remove and compost infected debris',
        'Ensure proper plant spacing for air circulation',
        'Apply organic mulch to reduce soil moisture',
        'Use crop rotation with non-hosts',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_bulbing.jpg',
    },

    // Onions - Harvesting/Storage
    'Onions_Harvesting/Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/onions_post_harvest_fungal_rot_storage.jpg',
      'possibleCauses': ['High humidity', 'Infected seeds', 'Poor storage conditions', 'Mechanical injury'],
      'possibleStrategies': [
        'Store in dry, cool conditions',
        'Use airtight containers with desiccants',
        'Apply organic seed treatments before storage',
        'Ensure proper ventilation in storage areas',
        'Use diatomaceous earth (organic)',
      ],
      'intervention': 'Fungicide (Propiconazole)',
      'fungicides': [
        'Diatomaceous earth (organic)',
        'Neem-based products (organic)',
        'Copper-based fungicides (organic)',
        'Propiconazole',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored onions',
        'Use neem-based treatments before storage',
        'Store in dry, cool, well-ventilated conditions',
        'Use airtight containers with desiccants',
        'Inspect and remove damaged bulbs',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_storage.jpg',
    },
    'Onions_Harvesting/Storage_Gray Mold': {
      'imagePath': 'assets/diseases/onions_gray_mold_storage.jpg',
      'possibleCauses': ['High humidity', 'Infected seeds', 'Poor storage conditions', 'Mechanical injury'],
      'possibleStrategies': [
        'Store in dry, cool conditions',
        'Use airtight containers with desiccants',
        'Apply organic seed treatments before storage',
        'Ensure proper ventilation in storage areas',
        'Use biofungicides like Coniothyrium minitans',
      ],
      'intervention': 'Fungicide (Boscalid)',
      'fungicides': [
        'Coniothyrium minitans (organic)',
        'Bacillus subtilis (organic)',
        'Copper-based fungicides (organic)',
        'Endura (Boscalid)',
      ],
      'organicInterventions': [
        'Apply Coniothyrium minitans before storage',
        'Use neem-based treatments before storage',
        'Store in dry, cool, well-ventilated conditions',
        'Use airtight containers with desiccants',
        'Inspect and remove damaged bulbs',
      ],
      'fallbackImagePath': 'assets/diseases/onions_default_storage.jpg',
    },

    // ===== IRISH POTATOES DISEASES =====
    // Irish Potatoes - Early Growth
    'Irish Potatoes_Germination/Seedling_Pythium Damping-Off': {
      'imagePath': 'assets/diseases/irish_potatoes_pythium_damping_off_germination.jpg',
      'possibleCauses': ['Excessive soil moisture', 'Cool, wet conditions', 'Infected seeds', 'Poor drainage'],
      'possibleStrategies': [
        'Use seeds treated with organic fungicides',
        'Avoid overwatering',
        'Incorporate organic matter for better drainage',
        'Rotate crops with non-hosts',
        'Apply biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Mefenoxam)',
      'fungicides': [
        'Trichoderma viride (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Ridomil Gold (Mefenoxam)',
      ],
      'organicInterventions': [
        'Apply Trichoderma viride to soil',
        'Use seeds treated with neem-based products',
        'Avoid overwatering seedlings',
        'Incorporate organic matter for drainage',
        'Rotate crops with non-hosts like cereals',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_early_growth.jpg',
    },

    //Irish Potatoes - Vegetative Growth
    'Irish Potatoes_Vegetative Growth/Weeding_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_vegetative_growth.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_vegetative_growth.jpg',
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_vegetative_growth.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_vegetative.jpg',
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_vegetative_growth.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor drainage'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_vegetative.jpg',
    },
    'Irish Potatoes_Vegetative Growth/Weeding_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_vegetative_growth.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_vegetative.jpg',
    },

    // Irish Potatoes - Tuber Formation
    'Irish Potatoes_Tuber Formation_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_tuber_formation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_tuber_initiation.jpg',
    },
    'Irish Potatoes_Tuber Formation_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_tuber_formation.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_tuber_initiation.jpg',
    },
    'Irish Potatoes_Tuber Formation_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_tuber_formation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor drainage'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_tuber_initiation.jpg',
    },
    'Irish Potatoes_Tuber Formation_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_tuber_formation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Bravo (Chlorothalonil)',
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_tuber_initiation.jpg',
    },

    // Irish Potatoes - Maturation
    'Irish Potatoes_Maturation_Late Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_late_blight_maturation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_maturation.jpg',
    },
    'Irish Potatoes_Maturation_Early Blight': {
      'imagePath': 'assets/diseases/irish_potatoes_early_blight_maturation.jpg',
      'possibleCauses': ['Warm, humid conditions', 'Infected seed tubers', 'Water splash', 'Poor air circulation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Remove infected debris and compost',
        'Apply organic mulch to reduce splash',
        'Ensure good air circulation by proper spacing',
      ],
      'intervention': 'Fungicide (Mancozeb)',
      'fungicides': [
        'Copper-based fungicides (organic, e.g., Bordeaux mixture)',
        'Sulfur-based fungicides (organic)',
        'Bacillus subtilis (organic)',
        'Dithane (Mancozeb)',
      ],
      'organicInterventions': [
        'Apply copper-based fungicides to foliage',
        'Use resistant potato varieties',
        'Remove and compost infected debris',
        'Apply organic mulch to reduce splash',
        'Ensure proper plant spacing for air circulation',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_maturation.jpg',
    },
    'Irish Potatoes_Maturation_Powdery Scab': {
      'imagePath': 'assets/diseases/irish_potatoes_powdery_scab_maturation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor drainage'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Bravo (Chlorothalonil)',
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_maturation.jpg',
    },
    'Irish Potatoes_Maturation_Black Scurf': {
      'imagePath': 'assets/diseases/irish_potatoes_black_scurf_maturation.jpg',
      'possibleCauses': ['Cool, wet conditions', 'Infected seed tubers', 'Contaminated soil', 'Poor crop rotation'],
      'possibleStrategies': [
        'Use resistant varieties',
        'Rotate crops with non-hosts',
        'Improve soil drainage with organic amendments',
        'Apply organic soil amendments (e.g., compost teas)',
        'Use biofungicides like Trichoderma spp.',
      ],
      'intervention': 'Fungicide (Chlorothalonil)',
      'fungicides': [
        'Bravo (Chlorothalonil)',
        'Trichoderma harzianum (organic)',
        'Bacillus subtilis (organic)',
        'Neem-based products (organic)',
        
      ],
      'organicInterventions': [
        'Apply Trichoderma harzianum to soil',
        'Use resistant potato varieties',
        'Rotate crops with non-hosts like cereals',
        'Incorporate compost teas into soil',
        'Improve soil drainage with organic amendments',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_maturation.jpg',
    },

    // Irish Potatoes - Storage
    'Irish Potatoes_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/irish_potatoes_post_harvest_fungal_rot_storage.jpg',
      'possibleCauses': ['High humidity', 'Infected seed tubers', 'Poor storage conditions', 'Mechanical injury'],
      'possibleStrategies': [
        'Store in dry, cool conditions',
        'Use airtight containers with desiccants',
        'Apply organic seed treatments before storage',
        'Ensure proper ventilation in storage areas',
        'Use diatomaceous earth (organic)',
      ],
      'intervention': 'Fungicide (Propiconazole)',
      'fungicides': [
        'Propiconazole',
        'Azoxystrobin',
        'Diatomaceous earth (organic)',
        'Neem-based products (organic)',
        'Copper-based fungicides (organic)',
        
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored potatoes',
        'Use neem-based treatments before storage',
        'Store in dry, cool, well-ventilated conditions',
        'Use airtight containers with desiccants',
        'Inspect and remove damaged tubers',
      ],
      'fallbackImagePath': 'assets/diseases/irish_potatoes_default_storage.jpg',
    },
  };

  @override
  void initState() {
    super.initState();
    checkAuth();

    // ✅ Debugging Prefill
    debugPrint("➡️ Prefill symptoms: ${widget.selectedSymptoms}");
    if (widget.selectedSymptoms != null &&
        widget.selectedSymptoms!.isNotEmpty) {
      final first = widget.selectedSymptoms!.first;
      debugPrint(
          "Prefill Crop=${first.crop}, Stage=${first.stage}, Identity=${first.identity}");

      setState(() {
        _selectedCrop = first.crop;
        _selectedStage = first.stage;
        _selectedDisease = first.identity; // assumed disease name
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updateDiseaseDetails());
    }
  }

  Future<void> checkAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  void updateSelections() {
    setState(() {
      _selectedCrop =
          _selectedCrop ?? (_crops.isNotEmpty ? _crops.first : null);
      _selectedStage = _selectedCrop != null &&
              _cropStages[_selectedCrop]!.isNotEmpty
          ? _cropStages[_selectedCrop]!.first
          : null;
      _selectedDisease = null;
      _diseaseData = null;
      _imageKey = UniqueKey();
      _showDiseaseDetails = false;
    });
  }

  Future<void> _updateDiseaseDetails() async {
    try {
      if (_selectedCrop == null ||
          _selectedStage == null ||
          _selectedDisease == null) {
        setState(() {
          _diseaseData = null;
          _imageKey = UniqueKey();
          _showDiseaseDetails = false;
        });
        return;
      }

      final diseaseKey = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
      final diseaseDetails = _diseaseDetails[diseaseKey];

      setState(() {
        _diseaseData = diseaseDetails != null
            ? DiseaseData(
                name: _selectedDisease ?? '',
                imagePath:
                    diseaseDetails['imagePath'] ?? 'assets/diseases/default.jpg',
                preventionStrategies: List<String>.from(
                    diseaseDetails['preventionStrategies'] ?? []),
                activeAgent: diseaseDetails['activeAgent'] ?? '',
                possibleCauses:
                    List<String>.from(diseaseDetails['possibleCauses'] ?? []),
                fungicides:
                    List<String>.from(diseaseDetails['fungicides'] ?? []),
                organicInterventions: List<String>.from(
                    diseaseDetails['organicInterventions'] ?? []),
              )
            : null;
        _imageKey = UniqueKey();
      });
    } catch (e) {
      debugPrint('Error updating disease details: $e');
      setState(() {
        _diseaseData = null;
        _imageKey = UniqueKey();
        _showDiseaseDetails = false;
      });
    }
  }

  void _scrollToHints() {
    if (_hintsKey.currentContext != null) {
      Scrollable.ensureVisible(_hintsKey.currentContext!);
    }
  }

  void _showOrganicDiseaseGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organic Disease Management Tips'),
        content: const SingleChildScrollView(
          child: Text("Use crop rotation, resistant varieties, pruning, neem..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disease Management'),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDropdown('Select Crop', _crops, _selectedCrop, (val) {
                setState(() {
                  _selectedCrop = val;
                  _selectedStage = null;
                  _selectedDisease = null;
                  _diseaseData = null;
                  _imageKey = UniqueKey();
                  _showDiseaseDetails = false;
                  updateSelections();
                });
              }),
              const SizedBox(height: 16),

              _buildDropdown(
                'Select Stage',
                _selectedCrop != null ? _cropStages[_selectedCrop]! : [],
                _selectedStage,
                (val) {
                  setState(() {
                    _selectedStage = val;
                    _selectedDisease = null;
                    _diseaseData = null;
                    _imageKey = UniqueKey();
                    _showDiseaseDetails = false;
                    _updateDiseaseDetails();
                  });
                },
              ),
              const SizedBox(height: 16),

              _buildDropdown(
                'Select Disease',
                _selectedCrop != null && _selectedStage != null
                    ? _cropStageDiseases[_selectedCrop]![_selectedStage] ?? []
                    : [],
                _selectedDisease,
                (val) {
                  setState(() {
                    _selectedDisease = val;
                    _diseaseData = null;
                    _imageKey = UniqueKey();
                    _showDiseaseDetails = false;
                    _updateDiseaseDetails();
                  });
                },
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Show Organic Interventions Only'),
                value: _isOrganic,
                onChanged: (value) {
                  setState(() {
                    _isOrganic = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () {
                  if (_diseaseData != null) {
                    setState(() {
                      _showDiseaseDetails = !_showDiseaseDetails;
                      if (_showDiseaseDetails) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToHints());
                      }
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text('Please select a disease first')));
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

              if (_diseaseData != null) ...[
                const SizedBox(height: 16),
                _buildImageCard(_diseaseData!.imagePath),
              ],

              if (_showDiseaseDetails && _diseaseData != null) ...[
                const SizedBox(height: 16),
                Column(
                  key: _hintsKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isOrganic) ...[
                      _buildHintCard('Possible Causes',
                          _diseaseData!.possibleCauses.join('\n')),
                      const SizedBox(height: 16),
                      _buildHintCard('Prevention Strategies',
                          _diseaseData!.preventionStrategies.join('\n')),
                      const SizedBox(height: 16),
                      _buildHintCard('Active Agent', _diseaseData!.activeAgent),
                      const SizedBox(height: 16),
                      _buildHintCard(
                          'Fungicides', _diseaseData!.fungicides.join('\n')),
                    ],
                    if (_diseaseData!.organicInterventions.isNotEmpty) ...[
                      _buildHintCard('Organic Interventions',
                          _diseaseData!.organicInterventions.join('\n')),
                    ],
                    if (_diseaseData!.organicInterventions.isEmpty &&
                        _isOrganic)
                      _buildHintCard(
                          'Organic Interventions', 'No organic interventions'),

                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () {
                        if (_selectedCrop != null &&
                            _selectedStage != null &&
                            _diseaseData != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InterventionPage(
                                cropType: _selectedCrop!,
                                cropStage: _selectedStage!,
                                diseaseData: _diseaseData!,
                                notificationsPlugin: _notificationsPlugin,
                              ),
                            ),
                          );
                        } else {
                          scaffoldMessenger.showSnackBar(const SnackBar(
                              content: Text(
                                  "Please select crop, stage and disease first")));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Add Intervention'),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  if (_diseaseData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            view_interventions.ViewDiseaseInterventionsPage(
                          diseaseData: _diseaseData!,
                          notificationsPlugin: _notificationsPlugin,
                        ),
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text("Please select a disease first")));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Interventions'),
              ),

              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UserDiseaseHistoryPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('View History'),
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Organic Disease Guide',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    onPressed: _showOrganicDiseaseGuide,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value,
      ValueChanged<String?> onChanged) {
    final uniqueItems = items.toSet().toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          initialValue: uniqueItems.contains(value) ? value : null,
          items: uniqueItems
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label),
        ),
      ),
    );
  }

  Widget _buildImageCard(String imagePath) {
    return Image.asset(imagePath, key: _imageKey, errorBuilder:
        (context, error, stackTrace) {
      return const Icon(Icons.image_not_supported, size: 150);
    });
  }

  Widget _buildHintCard(String title, String content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content),
        ]),
      ),
    );
  }
}