// ignore_for_file: invalid_return_type_for_catch_error, unnecessary_underscores, curly_braces_in_flow_control_structures, deprecated_member_use, unused_element_parameter, unused_element, unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';   // ← ADD THIS LINE
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:kilimomkononi/screens/disease%20management/disease_model.dart';
import 'package:kilimomkononi/screens/disease%20management/intervention_page.dart';
import 'package:kilimomkononi/screens/disease%20management/user_disease_history_page.dart';
import 'package:kilimomkononi/models/symptom_model.dart';
import 'package:kilimomkononi/screens/pest%20management/photo_diagnosis_page.dart';
import 'package:kilimomkononi/screens/analysis/farmer_plot_analysis_screen.dart';
import 'package:kilimomkononi/education/pest/gemini_vision_helper.dart';
import 'package:kilimomkononi/services/pest_disease_cost_bridge.dart';
import 'package:kilimomkononi/services/nasa_power_service.dart';
import 'package:kilimomkononi/services/iot_sensor_service.dart';
import 'package:kilimomkononi/screens/Field%20Data%20Input/satellite_data_screen.dart';
//

// ── Step-progress AppBar for disease subpages ─────────────────────────────────
PreferredSizeWidget _diseaseStepHeader(int current, int total) {
  const stepNames = ['Select Crop, Stage & Disease', 'Disease Info & Hints', 'Intervention, Cost & Reminder'];
  final name = (current >= 1 && current <= stepNames.length) ? stepNames[current - 1] : '';
  return PreferredSize(
    preferredSize: const Size.fromHeight(kToolbarHeight + 62),
    child: AppBar(
      backgroundColor: const Color.fromARGB(255, 3, 39, 4),
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text('Disease Management',
          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: Container(
          color: const Color.fromARGB(255, 3, 39, 4),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Step $current of $total  · ',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
              Expanded(child: Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(
              children: List.generate(total, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < current ? Colors.white : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ── Plot loader: SharedPrefs first, Firestore fallback ────────────────────────
Future<List<Map<String, String>>> _loadFarmPlotsForDisease(String uid) async {
  // 1. SharedPreferences (written by FarmManagementScreen._writeLocalPrefs)
  //    DiseaseCostService.loadFarmPlots reads the same ${uid}_v2_plots key
  try {
    final fromPrefs = await DiseaseCostService.loadFarmPlots(uid);
    if (fromPrefs.isNotEmpty) return fromPrefs;
  } catch (_) {}
  try {
    final snap = await FirebaseFirestore.instance
        .collection('farm_management_data').doc(uid).collection('plots').get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => {
        'id': d.id, 'name': (d.data()['name'] as String?) ?? d.id,
      }).toList();
    }
  } catch (_) {}
  try {
    final snap = await FirebaseFirestore.instance
        .collection('farm_management_data').where('userId', isEqualTo: uid).get();
    return snap.docs.map((d) => {
      'id':   (d.data()['plotId'] as String?) ?? d.id,
      'name': (d.data()['name']   as String?) ?? (d.data()['plotId'] as String?) ?? d.id,
    }).where((m) => m['id']!.isNotEmpty).toList();
  } catch (_) {}
  return [];
}

class DiseaseManagementPage extends StatefulWidget {
  final List<Symptom>? selectedSymptoms;

  const DiseaseManagementPage({super.key, this.selectedSymptoms});

  @override
  State<DiseaseManagementPage> createState() => _DiseaseManagementPageState();
}

class _DiseaseManagementPageState extends State<DiseaseManagementPage> {
  // Selection state — shared across subpages via callbacks
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
  DiseaseData? _diseaseData;
  bool _isOrganic = false;
  int _currentStep = 0;  // ← ADDED: Track current step in the workflow
  Key _imageKey = UniqueKey();
  final GlobalKey _hintsKey = GlobalKey();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // AI Disease Advisor state (used by _fetchAiAdvice — kept for compat)
  bool _aiLoading = false;
  String? _aiAdvice;
  static const _kAskGeminiUrl =
      'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision';

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
    if (widget.selectedSymptoms != null && widget.selectedSymptoms!.isNotEmpty) {
      final first = widget.selectedSymptoms!.first;
      _selectedCrop    = first.crop;
      _selectedStage   = first.stage;
      _selectedDisease = first.identity;
      _currentStep     = _selectedDisease != null ? 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateDiseaseDetails());
    }
  }

  Future<void> checkAuth() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  void updateSelections() {
    setState(() {
      _selectedCrop  = _selectedCrop  ?? (_crops.isNotEmpty ? _crops.first : null);
      _selectedStage = _selectedCrop != null && _cropStages[_selectedCrop]!.isNotEmpty
          ? _cropStages[_selectedCrop]!.first : null;
      _selectedDisease = null;
      _diseaseData     = null;
      _imageKey        = UniqueKey();
    });
  }

  Future<void> _updateDiseaseDetails() async {
    if (_selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      setState(() { _diseaseData = null; _imageKey = UniqueKey(); });
      return;
    }
    final key  = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
    final det  = _diseaseDetails[key];
    setState(() {
      _diseaseData = det != null ? DiseaseData(
        name:                 _selectedDisease ?? '',
        imagePath:            det['imagePath'] ?? 'assets/diseases/default.jpg',
        preventionStrategies: List<String>.from(det['preventionStrategies'] ?? det['possibleStrategies'] ?? []),
        activeAgent:          det['activeAgent'] ?? '',
        possibleCauses:       List<String>.from(det['possibleCauses'] ?? []),
        fungicides:           List<String>.from(det['fungicides'] ?? []),
        organicInterventions: List<String>.from(det['organicInterventions'] ?? []),
      ) : null;
      _imageKey = UniqueKey();
    });
  }

  void _scrollToHints() {
    if (_hintsKey.currentContext != null) Scrollable.ensureVisible(_hintsKey.currentContext!);
  }

  void _showOrganicDiseaseGuide() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Organic Disease Management'),
        content: const SingleChildScrollView(
          child: Text('Use crop rotation, resistant varieties, copper-based sprays, Trichoderma, neem products, and proper field sanitation to manage diseases organically.'),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  // ── AI Disease Advisor ────────────────────────────────────────────────────

  Future<void> _fetchAiAdvice() async {
    if (_diseaseData == null || _selectedCrop == null) return;
    setState(() { _aiLoading = true; _aiAdvice = null; });

    final prompt = '''
You are an agronomist advising smallholder farmers in Kenya and East Africa.

Disease: ${_diseaseData!.name}
Crop: $_selectedCrop  |  Stage: ${_selectedStage ?? 'Unknown'}
Active agent: ${_diseaseData!.activeAgent}
Known fungicides: ${_diseaseData!.fungicides.join(', ')}
Known organic interventions: ${_diseaseData!.organicInterventions.join(', ')}

Provide:
1. Brief description of how this disease spreads and damages the crop at this stage (2 sentences).
2. Up to 3 specific fungicide/bactericide interventions available in Kenya — product name (e.g. Ridomil, Dithane, Mancozeb), active ingredient, dosage per litre or per acre, timing and application method.
3. One organic alternative for each chemical.
4. Critical warnings (pre-harvest intervals, resistance management, do not spray in direct sun or rain).
5. Single most urgent action to take today.

Plain English, under 220 words, numbered lists only.
''';

    try {
      final resp = await http.post(
        Uri.parse(_kAskGeminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        if (mounted) setState(() { _aiAdvice = raw.trim().isNotEmpty ? raw.trim() : 'No advice returned. Try again.'; _aiLoading = false; });
      } else {
        if (mounted) setState(() { _aiAdvice = 'AI error (${resp.statusCode}). Try again.'; _aiLoading = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiAdvice = e.toString().contains('Timeout')
              ? 'Request timed out. Check your connection.'
              : 'AI unavailable offline. Use the manual hints below.';
          _aiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F3),
      appBar: AppBar(
        title: const Text('Disease Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Container(
            color: const Color.fromARGB(255, 3, 39, 4),
            padding: const EdgeInsets.only(left: 16, bottom: 10),
            alignment: Alignment.centerLeft,
            child: Text(_progressText(), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Season Analysis',
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => FarmerPlotAnalysisScreen(plotId: _selectedCrop ?? 'Farm', cycleName: 'Season ${DateTime.now().year}'),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [

          // ── AI Photo Diagnosis entry card ──────────────────────────────
          Card(
            color: const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PhotoDiagnosisPage())),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color.fromARGB(255, 3, 39, 4), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('AI Photo Diagnosis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color.fromARGB(255, 3, 39, 4))),
                    SizedBox(height: 2),
                    Text('Take a photo — AI identifies disease instantly', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ])),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black38),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Step tiles — each Navigator.push to a full subpage ────────

          _stepNavTile(
            step: 0, title: 'Select Crop, Stage & Disease',
            badge: _selectedDisease != null ? '${_selectedCrop ?? ''} · ${_selectedStage ?? ''} · $_selectedDisease' : null,
            isComplete: _selectedDisease != null && _diseaseData != null,
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DiseaseStep0Page(
                crops: _crops, cropStages: _cropStages, cropStageDiseases: _cropStageDiseases,
                selectedCrop: _selectedCrop, selectedStage: _selectedStage,
                selectedDisease: _selectedDisease, isOrganic: _isOrganic,
                onSaved: (crop, stage, disease, organic) {
                  setState(() { _selectedCrop = crop; _selectedStage = stage; _selectedDisease = disease; _isOrganic = organic; });
                  _updateDiseaseDetails();
                },
              ),
            )),
          ),

          _stepNavTile(
            step: 1, title: 'Disease Information & Hints',
            badge: _diseaseData != null ? 'Reviewed' : null,
            isComplete: _diseaseData != null,
            onTap: _selectedDisease != null ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _DiseaseStep1Page(
                diseaseData: _diseaseData, selectedDisease: _selectedDisease,
                selectedCrop: _selectedCrop, selectedStage: _selectedStage,
                isOrganic: _isOrganic, imageKey: _imageKey,
              ),
            )) : null,
          ),

          _stepNavTile(
            step: 2, title: 'Log Intervention & History',
            badge: null, isComplete: false,
            onTap: (_selectedDisease != null && _diseaseData != null) ? () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => InterventionPage(
                cropType: _selectedCrop!, cropStage: _selectedStage!,
                diseaseData: _diseaseData!, notificationsPlugin: _notificationsPlugin,
              ),
            )) : null,
          ),

          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _showOrganicDiseaseGuide,
            icon: const Icon(Icons.eco_outlined, size: 16),
            label: const Text('Organic Disease Guide'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2A6B2A)),
          ),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDiseaseHistoryPage())),
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('View All Disease Interventions'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF2A6B2A)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Step nav tile  ─────────────────────────────────────────────────────────

  Widget _stepNavTile({required int step, required String title, String? badge, required bool isComplete, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isComplete ? const Color(0xFF2E7D32) : const Color(0xFFBBBFBA), width: isComplete ? 2 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: isComplete ? const Color(0xFF1B5E20) : (enabled ? const Color.fromARGB(255, 3, 39, 4) : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${step + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: enabled ? const Color(0xFF111A10) : Colors.grey.shade400)),
              if (badge != null && badge.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(badge.length > 40 ? '${badge.substring(0, 40)}…' : badge,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20))),
              ],
            ])),
            Icon(Icons.chevron_right, color: enabled ? const Color(0xFF5C6B5A) : Colors.grey.shade300, size: 20),
          ]),
        ),
      ),
    );
  }

  String _progressText() {
    if (_selectedDisease == null) return 'Select crop and disease to begin';
    if (_diseaseData == null)    return 'Disease not found in library';
    return _selectedDisease!;
  }


  Widget _buildHintCard(String title, String content) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
    ])),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBPAGE 1 — Select Crop, Stage & Disease
// ═══════════════════════════════════════════════════════════════════════════════

class _DiseaseStep0Page extends StatefulWidget {
  final List<String> crops;
  final Map<String, List<String>> cropStages;
  final Map<String, Map<String, List<String>>> cropStageDiseases;
  final String? selectedCrop;
  final String? selectedStage;
  final String? selectedDisease;
  final bool isOrganic;
  final void Function(String? crop, String? stage, String? disease, bool organic) onSaved;

  const _DiseaseStep0Page({
    required this.crops, required this.cropStages, required this.cropStageDiseases,
    this.selectedCrop, this.selectedStage, this.selectedDisease,
    required this.isOrganic, required this.onSaved,
  });

  @override
  State<_DiseaseStep0Page> createState() => _DiseaseStep0PageState();
}

class _DiseaseStep0PageState extends State<_DiseaseStep0Page> {
  late String? _crop;
  late String? _stage;
  late String? _disease;
  late bool _organic;

  @override
  void initState() {
    super.initState();
    _crop    = widget.selectedCrop;
    _stage   = widget.selectedStage;
    _disease = widget.selectedDisease;
    _organic = widget.isOrganic;
  }

  @override
  Widget build(BuildContext context) {
    const darkGreen  = Color.fromARGB(255, 3, 39, 4);
    const accent     = Color(0xFF2A6B2A);
    const lightGreen = Color(0xFFE8F5E9);
    const pageBg     = Color(0xFFF4F6F3);
    final diseases   = widget.cropStageDiseases[_crop]?[_stage] ?? [];

    return Scaffold(
      backgroundColor: pageBg,
      appBar: _diseaseStepHeader(1, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // Crop
          _lbl('SELECT CROP'),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: widget.crops.map((c) => _chip(c, c == _crop, accent, lightGreen, () {
              setState(() { _crop = _crop == c ? null : c; _stage = null; _disease = null; });
            })).toList(),
          ),

          if (_crop != null) ...[
            const SizedBox(height: 18),
            _lbl('SELECT GROWTH STAGE'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8,
              children: (widget.cropStages[_crop] ?? []).map((s) => _chip(s, s == _stage, accent, lightGreen, () {
                setState(() { _stage = _stage == s ? null : s; _disease = null; });
              })).toList(),
            ),
          ],

          if (_crop != null && _stage != null) ...[
            const SizedBox(height: 18),
            _lbl('SELECT DISEASE'),
            const SizedBox(height: 10),
            diseases.isEmpty
                ? Text('No diseases recorded for this crop & stage', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                : Wrap(spacing: 8, runSpacing: 8,
                    children: diseases.map((d) => _chip(d, d == _disease, accent, lightGreen, () {
                      setState(() => _disease = _disease == d ? null : d);
                    })).toList(),
                  ),
          ],

          const SizedBox(height: 18),
          Row(children: [
            Switch(value: _organic, onChanged: (v) => setState(() => _organic = v),
                activeColor: accent, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
            const SizedBox(width: 8),
            const Expanded(child: Text('Show organic interventions only', style: TextStyle(fontSize: 13))),
          ]),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_crop != null && _stage != null && _disease != null) ? () {
                widget.onSaved(_crop, _stage, _disease, _organic);
                Navigator.pop(context);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: darkGreen, foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Confirm Selection', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool sel, Color accent, Color light, VoidCallback onTap) => FilterChip(
    label: Text(label), selected: sel, onSelected: (_) => onTap(),
    backgroundColor: Colors.white, selectedColor: light,
    labelStyle: TextStyle(color: sel ? accent : Colors.black54, fontWeight: sel ? FontWeight.w600 : FontWeight.normal),
    side: BorderSide(color: sel ? accent : Colors.grey.shade300),
  );

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 10, color: Color(0xFF5C6B5A), fontWeight: FontWeight.w700, letterSpacing: 0.8));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SUBPAGE 2 — Disease Information, Manual Hints + AI Advisor + AI Photo
// ═══════════════════════════════════════════════════════════════════════════════

class _DiseaseStep1Page extends StatefulWidget {
  final DiseaseData? diseaseData;
  final String? selectedDisease;
  final String? selectedCrop;
  final String? selectedStage;
  final bool isOrganic;
  final Key imageKey;

  const _DiseaseStep1Page({
    required this.diseaseData,
    this.selectedDisease,
    this.selectedCrop,
    this.selectedStage,
    required this.isOrganic,
    required this.imageKey,
    // Legacy params kept for API compat — no-ops, state is local
    Function? fetchAiAdvice,
    bool aiLoading = false,
    String? aiAdvice,
  });

  @override
  State<_DiseaseStep1Page> createState() => _DiseaseStep1PageState();
}

class _DiseaseStep1PageState extends State<_DiseaseStep1Page> {

  // ── AI state ───────────────────────────────────────────────────────────────
  bool _showAiSection = false;
  bool _usePhoto      = false;
  bool _aiLoading     = false;
  String? _aiAdvice;
  Uint8List? _aiPhoto;
  final ImagePicker _picker = ImagePicker();

  // ── Live condition state ───────────────────────────────────────────────────
  SatelliteReading? _sat;
  IotSensorReading? _iot;
  double _rain7d    = 0;
  bool _condLoading = true;

  // ── Colour tokens (mirrors disease_management_page.dart inline consts) ─────
  static const _darkGreen  = Color.fromARGB(255, 3, 39, 4);
  static const _accent     = Color(0xFF2A6B2A);
  static const _lightGreen = Color(0xFFE8F5E9);
  static const _pageBg     = Color(0xFFF4F6F3);

  @override
  void initState() {
    super.initState();
    _loadConditions();
  }

  // ── Load sat + IoT silently ────────────────────────────────────────────────

  Future<void> _loadConditions() async {
    try {
      final results = await Future.wait([
        NasaPowerService.getToday(),
        NasaPowerService.getHistory(days: 7),
        IotSensorService.getReadingForFarm().catchError((_) => null),
      ]);
      if (!mounted) return;
      final sat     = results[0] as SatelliteReading?;
      final history = results[1] as List<SatelliteReading>;
      final iot     = results[2] as IotSensorReading?;
      setState(() {
        _sat         = sat;
        _iot         = iot;
        _rain7d      = SatelliteReading.totalPrecipitation(history);
        _condLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _condLoading = false);
    }
  }

  // ── Map disease name → relevant risk types ─────────────────────────────────

  List<ConditionRiskType> _relevantRisks(String? name) {
    if (name == null) return [ConditionRiskType.spray];
    final n = name.toLowerCase();

    // All fungal/bacterial diseases show fungal risk
    final isFungal = _anyOf(n, [
      'blight', 'mildew', 'mold', 'mould', 'rust', 'pythium', 'fusarium',
      'rhizoctonia', 'damping', 'anthracnose', 'botrytis', 'sclerotinia',
      'alternaria', 'cercospora', 'gray leaf', 'grey mold', 'downy',
    ]);

    // Diseases driven by wet/saturated soil
    final isWet = _anyOf(n, [
      'pythium', 'damping', 'root rot', 'soft rot', 'bacterial wilt',
      'bacterial stalk rot', 'web blight', 'neck rot', 'basal rot',
    ]);

    // Diseases that worsen under drought / heat stress
    final isDry = _anyOf(n, [
      'mosaic virus', 'streak virus', 'powdery mildew', 'charcoal rot',
      'bacterial leaf streak', 'aster yellows',
    ]);

    final risks = <ConditionRiskType>[ConditionRiskType.spray];
    if (isFungal) risks.add(ConditionRiskType.fungal);
    if (isWet)    risks.add(ConditionRiskType.flood);
    if (isDry)    risks.add(ConditionRiskType.drought);
    return risks;
  }

  bool _anyOf(String haystack, List<String> needles) =>
      needles.any((n) => haystack.contains(n));

  // ── Rich contextual condition card under disease name ─────────────────────
  //
  // Shows a full breakdown of today's conditions as they relate to THIS
  // specific disease — no tooltip, no tap needed, all data visible inline.

  Widget _buildContextNote(String diseaseName) {
    if (_sat == null && _iot == null) return const SizedBox.shrink();
    final risk = computeConditionRisk(sat: _sat, iot: _iot, rain7d: _rain7d);
    final n    = diseaseName.toLowerCase();

    // Decide which condition is most relevant for this disease
    final isFungalDisease  = _anyOf(n, ['blight', 'mildew', 'mold', 'mould',
        'rust', 'pythium', 'fusarium', 'rhizoctonia', 'damping', 'anthracnose',
        'botrytis', 'sclerotinia', 'alternaria', 'cercospora', 'downy']);
    final isWetDisease     = _anyOf(n, ['pythium', 'damping', 'root rot',
        'soft rot', 'bacterial wilt', 'neck rot', 'basal rot', 'web blight']);
    final isDryDisease     = _anyOf(n, ['mosaic virus', 'streak virus',
        'powdery mildew', 'charcoal rot', 'bacterial leaf streak', 'aster yellows']);

    // Build the card title + bullets based on disease type + live conditions
    String title;
    Color  cardColor;
    List<String> bullets;
    IconData cardIcon;

    if (isFungalDisease) {
      final dewDiff    = _sat != null ? (_sat!.airTemp - _sat!.dewPoint).abs() : 99.0;
      final humidity   = _sat?.humidity ?? _iot?.humidity ?? 0;
      final cloudCover = _sat?.cloudCover ?? 0;
      final airTemp    = _sat?.airTemp ?? 0;

      if (risk.fungalRisk == ConditionRisk.critical) {
        title     = '⚠ Conditions are ideal for $diseaseName today';
        cardColor = const Color(0xFFB71C1C);
        cardIcon  = Icons.grain_rounded;
      } else if (risk.fungalRisk == ConditionRisk.high) {
        title     = 'Elevated risk for $diseaseName today';
        cardColor = const Color(0xFFBF360C);
        cardIcon  = Icons.grain_rounded;
      } else if (risk.fungalRisk == ConditionRisk.moderate) {
        title     = 'Moderate conditions — monitor for $diseaseName';
        cardColor = const Color(0xFFE65100);
        cardIcon  = Icons.grain_rounded;
      } else {
        title     = 'Low fungal pressure today';
        cardColor = _accent;
        cardIcon  = Icons.check_circle_outline_rounded;
      }

      bullets = [
        'Humidity: ${humidity.toStringAsFixed(0)}%'
            '${humidity > 80 ? '  ⚠ Above 80% — disease-conducive' : humidity > 70 ? '  — elevated' : '  ✓ Acceptable'}',
        if (_sat != null)
          'Temperature: ${airTemp.toStringAsFixed(1)}°C'
          '${(airTemp > 18 && airTemp < 30) ? '  ⚠ In fungal growth range (18–30°C)' : '  ✓ Outside main fungal range'}',
        if (_sat != null)
          'Dew point gap: ${dewDiff.toStringAsFixed(1)}°C'
          '${dewDiff < 4 ? '  ⚠ Leaves likely wet overnight — ideal for spore germination' : dewDiff < 8 ? '  — moderate leaf wetness risk' : '  ✓ Leaves likely dry at night'}',
        if (_sat != null && cloudCover > 0)
          'Cloud cover: ${cloudCover.toStringAsFixed(0)}%'
          '${cloudCover > 65 ? '  — overcast, slows leaf drying' : '  ✓ Adequate sun'}',
        if (_sat != null)
          'Rain last 7 days: ${_rain7d.toStringAsFixed(1)} mm'
          '${_rain7d > 30 ? '  — wet week increases disease pressure' : ''}',
        if (risk.fungalRisk == ConditionRisk.critical || risk.fungalRisk == ConditionRisk.high)
          'Recommended action: Scout crops now. Consider preventive fungicide before rain.',
        if (risk.fungalRisk == ConditionRisk.low)
          'Conditions do not strongly favour this disease right now.',
      ];

    } else if (isWetDisease) {
      final soilMoisture = _sat?.rootZoneMoisture ?? 0;
      final precipitation = _sat?.precipitation ?? 0;

      if (risk.floodRisk == ConditionRisk.critical || risk.floodRisk == ConditionRisk.high) {
        title     = '⚠ Waterlogged soil favours $diseaseName';
        cardColor = const Color(0xFF0D47A1);
        cardIcon  = Icons.water_rounded;
      } else if (soilMoisture < 0.35) {
        title     = 'Dry soil conditions — lower risk for $diseaseName';
        cardColor = _accent;
        cardIcon  = Icons.check_circle_outline_rounded;
      } else {
        title     = 'Soil moisture within normal range';
        cardColor = _accent;
        cardIcon  = Icons.water_drop_outlined;
      }

      bullets = [
        if (_sat != null)
          'Root zone moisture: ${(soilMoisture * 100).toStringAsFixed(0)}%'
          '${soilMoisture > 0.85 ? '  ⚠ Saturated — $diseaseName thrives here' : soilMoisture > 0.65 ? '  — moist, monitor closely' : '  ✓ Acceptable range'}',
        if (_sat != null)
          'Rain today: ${precipitation.toStringAsFixed(1)} mm'
          '${precipitation > 25 ? '  ⚠ Heavy rain — drainage risk' : precipitation > 10 ? '  — significant' : '  ✓ Minimal'}',
        'Rain last 7 days: ${_rain7d.toStringAsFixed(1)} mm'
            '${_rain7d > 40 ? '  ⚠ Wet week — high soil saturation risk' : ''}',
        if (risk.floodRisk == ConditionRisk.high || risk.floodRisk == ConditionRisk.critical)
          'Recommended action: Check drainage. Delay fungicide — heavy rain will wash it off.',
        if (soilMoisture < 0.35)
          'Current dry conditions reduce the risk of this soil-borne disease.',
      ];

    } else if (isDryDisease) {
      if (risk.droughtRisk == ConditionRisk.high || risk.droughtRisk == ConditionRisk.critical) {
        title     = '⚠ Dry stress conditions may increase $diseaseName pressure';
        cardColor = const Color(0xFFE65100);
        cardIcon  = Icons.wb_sunny_outlined;
      } else {
        title     = 'Adequate moisture — $diseaseName risk is lower today';
        cardColor = _accent;
        cardIcon  = Icons.check_circle_outline_rounded;
      }

      bullets = [
        'Rain last 7 days: ${_rain7d.toStringAsFixed(1)} mm'
            '${_rain7d < 5 ? '  ⚠ Very low — drought stress likely' : '  ✓ Adequate'}',
        if (_sat != null)
          'Root zone moisture: ${(_sat!.rootZoneMoisture * 100).toStringAsFixed(0)}%'
          '${_sat!.rootZoneMoisture < 0.25 ? '  ⚠ Below critical' : '  ✓ Acceptable'}',
        if (_sat != null)
          'Air temperature: ${_sat!.airTemp.toStringAsFixed(1)}°C'
          '${_sat!.airTemp > 30 ? '  — heat stress range' : ''}',
      ];

    } else {
      // Generic: just show spray window since we have no disease-specific match
      return const SizedBox.shrink();
    }

    final bgColor     = cardColor.withOpacity(0.07);
    final borderColor = cardColor.withOpacity(0.22);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(cardIcon, size: 14, color: cardColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: cardColor, height: 1.3)),
            ),
          ]),
          const SizedBox(height: 8),
          ...bullets.where((b) => b.trim().isNotEmpty).map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('• ',
                    style: TextStyle(fontSize: 12.5,
                        color: cardColor.withOpacity(0.6), height: 1.45)),
                Expanded(
                  child: Text(b,
                      style: TextStyle(fontSize: 12.5,
                          color: cardColor.withOpacity(0.85), height: 1.45)),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI ─────────────────────────────────────────────────────────────────────

  GestureTapCallback? get _fetchAiAdvice => null;

  Future<void> _fetchAiText() async {
    if (widget.diseaseData == null || widget.selectedCrop == null) return;
    setState(() { _aiLoading = true; _aiAdvice = null; });

    final prompt = '''
You are an agronomist advising smallholder farmers in Kenya and East Africa.

Disease: ${widget.diseaseData!.name}
Crop: ${widget.selectedCrop}  |  Stage: ${widget.selectedStage ?? 'Unknown'}
Active agent: ${widget.diseaseData!.activeAgent}
Known fungicides: ${widget.diseaseData!.fungicides.join(', ')}
Known organic interventions: ${widget.diseaseData!.organicInterventions.join(', ')}
Possible causes: ${widget.diseaseData!.possibleCauses.join(', ')}

Provide:
1. How this disease spreads and damages the crop at this stage (2 sentences).
2. Up to 3 specific fungicide/bactericide interventions sold in Kenya — product name, active ingredient, dosage per litre/per acre, timing and method.
3. One organic alternative per chemical.
4. Critical warnings (pre-harvest intervals, resistance rotation, no spray in rain).
5. Single most urgent action today.

Plain English, under 220 words, numbered lists only.
''';

    try {
      final resp = await http.post(
        Uri.parse('https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGeminiVision'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 35));

      if (resp.statusCode == 200) {
        final raw = (jsonDecode(resp.body)['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?) ?? '';
        if (mounted) setState(() {
          _aiAdvice  = raw.trim().isNotEmpty ? raw.trim() : 'No advice returned. Try again.';
          _aiLoading = false;
        });
      } else {
        if (mounted) setState(() { _aiAdvice = 'AI error (${resp.statusCode}). Try again.'; _aiLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() {
        _aiAdvice  = e.toString().contains('Timeout')
            ? 'Request timed out. Check connection.'
            : 'AI unavailable offline. Use manual hints.';
        _aiLoading = false;
      });
    }
  }

  Future<void> _pickPhoto(ImageSource src) async {
    final xf = await _picker.pickImage(source: src, imageQuality: 82, maxWidth: 1200);
    if (xf == null) return;
    final bytes = await xf.readAsBytes();
    setState(() { _aiPhoto = bytes; _aiAdvice = null; });
    await _runPhotoAnalysis();
  }

  Future<void> _runPhotoAnalysis() async {
    if (_aiPhoto == null) return;
    setState(() => _aiLoading = true);
    try {
      final r = await runGeminiVisionDiagnosis(
          imageBytes: _aiPhoto!, crop: widget.selectedCrop ?? 'Unknown', isPest: false);
      if (mounted) setState(() {
        _aiAdvice = r.isRejected ? r.rejectionReason
            : r.isHealthy ? 'No disease detected. Continue monitoring.'
            : '${r.name}\n\n${r.description}\n\nWhat to do: ${r.recommendation}';
        _aiLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _aiAdvice = 'AI photo error: $e'; _aiLoading = false; });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final d = widget.diseaseData;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: _diseaseStepHeader(2, 3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── 1. Live condition risk banner ──────────────────────────────────
          if (!_condLoading && (_sat != null || _iot != null))
            ConditionRiskBanner(
              sat:           _sat,
              iot:           _iot,
              rain7d:        _rain7d,
              relevantRisks: _relevantRisks(
                  widget.selectedDisease ?? d?.name),
            ),

          // ── 2. Disease image ───────────────────────────────────────────────
          if (d != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                d.imagePath,
                key: widget.imageKey,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: _lightGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.local_hospital_outlined, size: 52,
                        color: Color(0xFF2A6B2A)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(d.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20))),
            if (d.activeAgent.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Active agent: ${d.activeAgent}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 10),

            // ── 3. Contextual condition note ─────────────────────────────────
            if (!_condLoading && _sat != null)
              _buildContextNote(widget.selectedDisease ?? d.name),

            // ── 4. Manual hint cards ─────────────────────────────────────────
            if (d.possibleCauses.isNotEmpty)
              _hCard('Possible Causes', d.possibleCauses.join('\n')),
            if (d.preventionStrategies.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hCard('Prevention Strategies', d.preventionStrategies.join('\n')),
            ],
            if (!widget.isOrganic && d.fungicides.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hCard('Fungicides / Bactericides', d.fungicides.join('\n')),
            ],
            if (d.organicInterventions.isNotEmpty) ...[
              const SizedBox(height: 10),
              _hCard('Organic Interventions', d.organicInterventions.join('\n')),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBBFBA), width: 1.5),
              ),
              child: Text(
                '${widget.selectedDisease ?? 'This disease'} was not found in '
                'the library. Use the AI hints below for guidance.',
                style: const TextStyle(fontSize: 13, color: Color(0xFF3D4A3C),
                    height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 16),

          // ── 5. AI Advisor section ──────────────────────────────────────────
          _aiSectionWidget(),
          const SizedBox(height: 14),

          // ── 6. Back button ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkGreen,
                side: const BorderSide(color: Color(0xFF2A6B2A)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Back to Disease Selection',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI section widget ──────────────────────────────────────────────────────

  Widget _aiSectionWidget() {
    if (!_showAiSection) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _showAiSection = true),
        icon: const Icon(Icons.psychology_rounded, size: 16),
        label: const Text('Get AI Advice for this disease'),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accent,
          side: BorderSide(color: _accent.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF52B788), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.psychology_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('AI Disease Advisor',
              style: TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          // Toggle text/photo
          GestureDetector(
            onTap: () => setState(() { _usePhoto = !_usePhoto; _aiAdvice = null; }),
            child: Text(_usePhoto ? 'Use text advice' : 'Use photo',
                style: const TextStyle(fontSize: 11, color: Colors.white60,
                    decoration: TextDecoration.underline)),
          ),
        ]),
        const SizedBox(height: 12),

        if (_usePhoto) ...[
          // Photo mode
          if (_aiPhoto != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_aiPhoto!, height: 160, width: double.infinity,
                  fit: BoxFit.cover),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 16),
                label: const Text('Take photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 16),
                label: const Text('Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.15),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ]),
        ] else ...[
          // Text mode
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _aiLoading ? null : _fetchAiText,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _aiLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Get advice',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],

        // AI result
        if (_aiAdvice != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Text(_aiAdvice!,
                style: const TextStyle(color: Colors.white, fontSize: 13,
                    height: 1.55)),
          ),
        ],
      ]),
    );
  }

  // ── Hint card ──────────────────────────────────────────────────────────────

  Widget _hCard(String title, String content) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(content,
            style: const TextStyle(fontSize: 13, height: 1.5)),
      ]),
    ),
  );
}