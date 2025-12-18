import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/models/pest_disease_model.dart';
import 'package:kilimomkononi/models/symptom_model.dart';
import 'package:kilimomkononi/screens/pest%20management/intervention_page.dart';
import 'package:kilimomkononi/screens/pest%20management/user_pest_history_page.dart';
import 'package:kilimomkononi/screens/pest%20management/view_interventions_page.dart';

class PestManagementPage extends StatefulWidget {
  final List<Symptom>? selectedSymptoms; // ✅ make optional

  const PestManagementPage({super.key, this.selectedSymptoms}); // ✅ no longer required

  @override
  State<PestManagementPage> createState() => _PestManagementPageState();
}

class _PestManagementPageState extends State<PestManagementPage> {
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedPest;
  PestData? _pestData;
  bool _showPestDetails = false;
  bool _isOrganic = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _hintsKey = GlobalKey();
  Key _imageKey = UniqueKey();

  final List<String> _crops = ['Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes', 'Onions', 'Irish Potatoes'];

  final Map<String, List<String>> _cropStages = {
    'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
    'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
    'Irish Potatoes': ['Early Growth', 'Tuber Initiation', 'Tuber Bulking', 'Maturation/Harvesting'],
  };

  final Map<String, Map<String, List<String>>> _cropStagePests = {
    'Beans': {
      'Germination/Seedling': ['Bean Fly', 'Cutworms', 'Rodents', 'Termites'],
      'Vegetative Growth/Weeding': ['Aphids', 'Leafhoppers', 'Thrips', 'Whiteflies', 'Beetles', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Leafhoppers', 'Thrips', 'Pod Borers', 'Whiteflies'],
      'Maturation/Harvesting': ['Pod Borers', 'Beetles', 'Bean Weevil', 'Bruchid Beetles', 'Rodents'],
      'Storage': ['Bean Weevil', 'Bruchid Beetles', 'Rodents'],
    },
    'Maize': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Maize Shoot Fly', 'Rodents'],
      'Vegetative Growth/Weeding': ['Aphids', 'Stem Borers', 'Armyworms', 'Leafhoppers', 'Grasshoppers', 'Thrips', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Stem Borers', 'Armyworms', 'Leafhoppers', 'Grasshoppers', 'Earworms', 'Thrips', 'Birds'],
      'Maturation/Harvesting': ['Earworms', 'Weevils', 'Birds', 'Rodents'],
      'Storage': ['Larger Grain Borer', 'Angoumois Grain Moth', 'Weevils', 'Rodents'],
    },
    'Cabbages/Kales': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Root Maggots', 'Flea Beetles',],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Cross Stripped Cabbageworm', 'Diamondback Moth', 'Cabbage Looper', 'Cutworms', 'Flea Beetles', 'Cabbage Webworm', 'Armyworms', 'Cabbage Root Maggot', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrip', 'Diamondback Moth', 'Cabbage Looper', 'Armyworm', 'Stink Bug'],
      'Maturation/Harvesting': ['Diamondback Moth', 'Cabbage Looper', 'Leafminers', 'Flea Beetle', 'Cabbage Webworm', 'Armyworm', 'Stink Bug', 'Rodent'],
      'Storage': ['Rodents', 'Aphids', 'Whiteflies'],
    },
    'Carrots': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Rodents'],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leaf Loopers', 'Leafminers', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
      'Maturation/Harvesting': ['Aphids', 'White Flies', 'Thrips', 'Leaf Loopers', 'Leaf Miners', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
      'Storage': ['Carrot Rust Fly', 'Nematodes', 'Rodents', 'Aphids'],
    },
    'Tomatoes': {
      'Germination/Seedling': ['Cutworms', 'Termites', 'Rodents', 'Nematodes'],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Spider Mites', 'Tomato Hornworms', 'Beet Armyworm', 'Nematodes', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Spider Mites', 'Tomato Hornworms', 'Stink Bugs', 'Beet Armyworm', 'Nematodes', 'Rodents', 'Fruit Borers', 'Bollworms'],
      'Maturation/Harvesting': ['Fruitflies', 'Stink Bugs', 'Rodents', 'Fruit Borers', 'Bollworms', 'Beet Armyworm', 'Leafminers', 'Aphids', 'Whiteflies', 'Thrips', 'Spider Mites', 'Nematodes', 'Tomato Hornworms'],
      'Storage': ['Fruit Flies', 'Fruit Borers','Stink Bugs','Rodents'],
    },
    'Onions': {
      'Germination/Seedling': ['Aphids', 'Thrips'],
      'Vegetative Growth/Weeding': ['Thrips', 'Aphids'],
      'Bulb Formation/Reproductive': [ 'Bulb Fly', 'Maggots'],
      'Bulbing/Maturation': ['Maggots', 'Thrips', 'Bulb Fly'],
      'Harvesting/Storage': ['Maggots', 'Rodents', 'Bulb Fly'],
    },
    'Irish Potatoes': {
      'Early Growth': ['Wireworms', 'Cutworms'],
      'Tuber Initiation': ['Colorado Potato Beetle', 'Aphids',  'Spider Mites'],
      'Tuber Bulking': ['Aphids', 'Leaf Hoppers', 'Flea Beetles', 'Spider Mites'],
      'Maturation/Harvesting': ['Colorado Potato Beetle', 'Aphids', 'Wireworms', 'Cutworms', 'Spider Mites'],
    },
  };

  static const List<String> _organicPesticides = [
    'Pyrethrin (organic)',
    'Neem oil (organic)',
    'Diatomaceous earth (organic)',
    'Spinosad (organic)',
    'Beneficial nematodes (organic)',
    'Bacillus thuringiensis (Bt) (organic)',
    'Garlic extract (organic)',
  ];

  static const List<String> _organicPreventionStrategies = [
    'Introduce beneficial insects (e.g., ladybugs, predatory wasps)',
    'Use neem oil sprays',
    'Apply organic mulch',
    'Use crop rotation',
    'Plant trap crops',
    'Use row covers',
    'Hand-pick pests',
    'Plant companion crops (e.g., marigolds)',
  ];

  final Map<String, Map<String, dynamic>> _pestDetails = {
    // ===== BEANS PESTS =====
    // Beans - Germination/Seedling
    'Beans_Germination/Seedling_Bean Fly': {
      'imagePath': 'assets/pests/beans_bean_fly_germination.jpg',
      'possibleStrategies': [
        'Use crop rotation',
        'Use row covers',
        'Monitor seedlings for early damage',
        'Plant trap crops like cowpeas',
        'Apply organic soil treatments',
      ],
      'intervention': 'Ophiomyia phaseoli',
      'possibleCauses': [
        'Warm, moist soil conditions',
        'Infested soil from previous crops',
        'Proximity to host plants',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Thiamethoxam',
        'Cypermethrin',
        'Lambda-cyhalothrin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Diatomaceous earth (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Use lightweight row covers during egg-laying',
        'Introduce beneficial nematodes to soil',
        'Plant trap crops like cowpeas',
        'Apply diatomaceous earth around plant base',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/beans_cutworms_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators like cats',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Availability of food sources',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Set mechanical traps around fields',
        'Use garlic extract as a repellent',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },
    'Beans_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/beans_termites_germination.jpg',
      'possibleStrategies': [
        'Treat soil with organic amendments',
        'Remove wood debris',
        'Use treated seeds',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
      ],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': [
        'Presence of dry wood or debris',
        'Warm, dry soil conditions',
        'Lack of soil treatment',
        'Previous termite infestations',
      ],
      'herbicidesPesticides': [
        'Termidor (Fipronil)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Diatomaceous earth (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Introduce beneficial nematodes to soil',
        'Use diatomaceous earth as a soil barrier',
        'Plant repellent crops like marigolds',
        'Maintain moist soil to deter termites',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_germination.jpg',
    },

    // Beans - Vegetative Growth/Weeding
    'Beans_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative_growth.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor plant damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Confidor (Imidacloprid)',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected leaves',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during peak activity',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Admire (Imidacloprid)',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick beetles',
        'Use row covers',
        'Apply organic sprays',
        'Plant trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Insecticide (Pyrethrins)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'PyGanic (Pyrethrins)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Hand-pick beetles and larvae',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce predatory beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },
    'Beans_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_vegetative.jpg',
    },

    // Beans - Flowering/Reproductive
    'Beans_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor flower buds',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor flower damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Confidor (Imidacloprid)',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected flowers',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected flowers',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borer_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Monitor pods for entry holes',
        'Introduce beneficial insects',
        'Use row covers',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Crop residue',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Hand-pick larvae from pods',
        'Use row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },
    'Beans_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_flowering.jpg',
    },

    // Beans - Maturation/Harvesting
    'Beans_Maturation/Harvesting_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borers_harvesting.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Hand-pick larvae',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to pods',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Hand-pick larvae from pods',
        'Remove infested pods',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick beetles',
        'Use row covers',
        'Apply organic sprays',
        'Plant trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Insecticide (Pyrethrins)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'PyGanic (Pyrethrins)',
        'Carbaryl',
        'Permethrin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Hand-pick beetles and larvae',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce predatory beetles',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_harvesting.jpg',
      'possibleStrategies': [
        'Harvest beans early',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Fumitoxin (Phosphine)',
        'Malathion',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Harvest beans early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_harvesting.jpg',
      'possibleStrategies': [
        'Harvest beans early',
        'Apply organic sprays',
        'Monitor pods for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Fumitoxin (Phosphine)',
        'Malathion',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected pods',
        'Harvest beans early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like cowpeas',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },
    'Beans_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Ripe beans as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_maturation.jpg',
    },

    // Beans - Storage
    'Beans_Storage_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored beans',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Infested seeds',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored beans',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze beans to kill larvae',
        'Regularly inspect stored beans',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },
    'Beans_Storage_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored beans',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Infested seeds',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored beans',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze beans to kill larvae',
        'Regularly inspect stored beans',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },
    'Beans_Storage_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/beans_default_storage.jpg',
    },

    // ===== MAIZE PESTS =====
    // Maize - Germination/Seedling
    'Maize_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/maize_termites_germination.jpg',
      'possibleStrategies': [
        'Treat soil with organic amendments',
        'Remove wood debris',
        'Use treated seeds',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
      ],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': [
        'Presence of dry wood or debris',
        'Warm, dry soil conditions',
        'Lack of soil treatment',
        'Previous termite infestations',
      ],
      'herbicidesPesticides': [
        'Termidor (Fipronil)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Diatomaceous earth (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Introduce beneficial nematodes to soil',
        'Use diatomaceous earth as a soil barrier',
        'Plant repellent crops like marigolds',
        'Maintain moist soil to deter termites',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/maize_cutworm_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Maize Shoot Fly': {
      'imagePath': 'assets/pests/maize_shoot_fly_germination.jpg',
      'possibleStrategies': [
        'Use treated seeds',
        'Apply organic soil treatments',
        'Use row covers',
        'Plant early to avoid peak fly activity',
        'Monitor seedlings',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Warm, moist soil',
        'Crop residue',
        'Lack of predators',
        'Delayed planting',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Thiamethoxam',
        'Fastac (Cypermethrin)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Diatomaceous earth (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to soil around seedlings',
        'Use lightweight row covers',
        'Plant early to avoid peak fly activity',
        'Introduce beneficial nematodes',
        'Apply diatomaceous earth around plant base',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },
    'Maize_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_germination.jpg',
    },

    // Maize - Vegetative Growth/Weeding
    'Maize_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/maize_leaf_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Destroy crop residue',
        'Monitor stems for entry holes',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to stems',
        'Use neem oil sprays',
        'Plant trap crops like napier grass',
        'Introduce parasitic wasps',
        'Destroy infested crop residue',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plant damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor plant damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Imidacloprid',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected leaves',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during peak activity',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Use trap crops',
        'Maintain weed-free fields',
        'Use row covers',
      ],
      'intervention': 'Insecticide (Malathion)',
      'possibleCauses': [
        'Dry, warm conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory birds',
        'Plant trap crops like millet',
        'Use row covers during peak activity',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },
    'Maize_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_vegetative.jpg',
    },

    // Maize - Flowering/Reproductive
    'Maize_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/maize_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor tassels and silks',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected tassels',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to tassels',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Destroy crop residue',
        'Monitor stems for entry holes',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to stems',
        'Use neem oil sprays',
        'Plant trap crops like napier grass',
        'Introduce parasitic wasps',
        'Destroy infested crop residue',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor tassels for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to tassels',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Introduce beneficial insects',
        'Plant trap crops',
        'Apply organic sprays',
        'Monitor tassels for damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Nearby weed hosts',
        'Lack of predators',
        'Crop monoculture',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Confidor (Imidacloprid)', 
        'Gaucho (Imidacloprid)',
        'Pyrethrin (organic)',
        'Neem oil (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray pyrethrin on affected tassels',
        'Introduce predatory wasps',
        'Plant trap crops like alfalfa',
        'Use neem oil sprays',
        'Apply row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Use trap crops',
        'Maintain weed-free fields',
        'Use row covers',
      ],
      'intervention': 'Insecticide (Malathion)',
      'possibleCauses': [
        'Dry, warm conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Malathion 57 (Malathion)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected tassels',
        'Introduce predatory birds',
        'Plant trap crops like millet',
        'Use row covers during flowering',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor ears for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to silks',
        'Use neem oil sprays on ears',
        'Plant trap crops like sorghum',
        'Hand-pick larvae from ears',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected tassels',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },
    'Maize_Flowering/Reproductive_Birds': {
      'imagePath': 'assets/pests/maize_birds_flowering.jpg',
      'possibleStrategies': [
        'Use bird netting',
        'Install scare devices',
        'Plant decoy crops',
        'Harvest early',
        'Introduce predators',
      ],
      'intervention': 'Install bird netting',
      'possibleCauses': [
        'Ripe kernels',
        'Lack of deterrents',
        'Nearby nesting sites',
        'Food scarcity',
      ],
      'herbicidesPesticides': [],
      'organicInterventions': [
        'Install bird netting over plants',
        'Use reflective tape or scarecrows',
        'Plant decoy crops like sunflowers',
        'Introduce predatory birds',
        'Harvest ears early',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_flowering.jpg',
    },

    // Maize - Maturation/Harvesting
    'Maize_Maturation/Harvesting_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor ears for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to ears',
        'Use neem oil sprays on ears',
        'Plant trap crops like sorghum',
        'Hand-pick larvae from ears',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_harvesting.jpg',
      'possibleStrategies': [
        'Harvest ears early',
        'Apply organic sprays',
        'Monitor ears for damage',
        'Use trap crops',
        'Introduce beneficial insects',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Infested seeds',
        'Lack of predators',
        'Delayed harvesting',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected ears',
        'Harvest maize early to avoid infestation',
        'Use neem oil sprays',
        'Plant trap crops like sorghum',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Birds': {
      'imagePath': 'assets/pests/maize_birds_harvesting.jpg',
      'possibleStrategies': [
        'Use bird netting',
        'Install scare devices',
        'Plant decoy crops',
        'Harvest early',
        'Introduce predators',
      ],
      'intervention': 'Install bird netting',
      'possibleCauses': [
        'Ripe kernels',
        'Lack of deterrents',
        'Nearby nesting sites',
        'Food scarcity',
      ],
      'herbicidesPesticides': [],
      'organicInterventions': [
        'Install bird netting over plants',
        'Use reflective tape or scarecrows',
        'Plant decoy crops like sunflowers',
        'Introduce predatory birds',
        'Harvest ears early',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },
    'Maize_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Ripe kernels as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_maturation.jpg',
    },

    // Maize - Storage
    'Maize_Storage_Larger Grain Borer': {
      'imagePath': 'assets/pests/maize_larger_grain_borer_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Angoumois Grain Moth': {
      'imagePath': 'assets/pests/maize_angoumois_grain_moth_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_storage.jpg',
      'possibleStrategies': [
        'Store in airtight containers',
        'Use diatomaceous earth',
        'Apply organic treatments',
        'Ensure proper drying before storage',
        'Monitor stored maize',
      ],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': [
        'Infested kernels',
        'High humidity in storage',
        'Poor storage conditions',
        'Lack of inspection',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Fumitoxin (Phosphine)',
        'Diatomaceous earth (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply diatomaceous earth to stored maize',
        'Use neem oil-treated containers',
        'Store in airtight containers with desiccants',
        'Freeze maize to kill larvae',
        'Regularly inspect stored maize',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
    'Maize_Storage_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/maize_default_storage.jpg',
    },
  
   // ===== CABBAGES/KALES PESTS =====
    // Cabbages/Kales - Germination/Seedling
    'Cabbages/Kales_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_germination.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic mulch',
        'Introduce beneficial insects',
        'Monitor seedling damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply neem oil to affected seedlings',
        'Use row covers during early growth',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth around seedlings',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Root Maggots': {
      'imagePath': 'assets/pests/cabbage_kale_root_maggots_germination.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
        'Rotate crops',
        'Remove crop debris',
      ],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': [
        'Cool, wet soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Lorsban (Chlorpyrifos)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around seedlings',
        'Use row covers at planting',
        'Remove crop debris after harvest',
        'Rotate crops to non-host plants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },
    'Cabbages/Kales_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/cabbage_kale_termites_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use organic mulch',
        'Apply natural repellents',
        'Introduce beneficial insects',
        'Maintain dry soil conditions',
      ],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': [
        'Moist, warm soil',
        'Presence of wood or plant debris',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Termidor (Fipronil)',
        'Bifenthrin',
        'Imidacloprid',
        'Neem oil (organic)',
        'Orange oil (organic)',
      ],
      'organicInterventions': [
        'Apply orange oil or neem oil to soil around seedlings',
        'Remove wood and plant debris from field',
        'Use organic mulch sparingly to avoid moisture retention',
        'Introduce predatory insects like ants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_germination.jpg',
    },

    // Cabbages/Kales - Vegetative Growth/Weeding
    'Cabbages/Kales_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
      'Cabbages/Kales_Vegetative Growth/Weeding_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor leaves for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during egg-laying',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor leaf damage',
      ],
      'intervention': 'Apply neem oil to foliage',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Use row covers during vegetative growth',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor leaves for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cross Stripped Cabbageworm': {
      'imagePath': 'assets/pests/cabbage_kale_cross_stripped_cabbageworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae from leaves',
        'Use neem oil sprays',
        'Use row covers during vegetative growth',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae from leaves',
        'Use neem oil sprays',
        'Use row covers during vegetative growth',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_vegetative_growth.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around plants',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor leaves for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },
    'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Root Maggot': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_root_maggots_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Apply organic mulch',
        'Introduce beneficial nematodes',
        'Rotate crops',
        'Remove crop debris',
      ],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': [
        'Cool, wet soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Lorsban (Chlorpyrifos)',
        'Dursban (Chlorpyrifos)',
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Beneficial nematodes (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use row covers at planting',
        'Remove crop debris after harvest',
        'Rotate crops to non-host plants',
        'Maintain well-drained soil conditions',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_vegetative.jpg',
    },

    // Cabbages/Kales - Flowering/Reproductive
    'Cabbages/Kales_Flowering/Reproductive_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_flowering.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor flowers for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during flowering',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Thrip': {
      'imagePath': 'assets/pests/cabbage_kale_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce predatory mites',
        'Use reflective mulches around plants',
        'Plant companion crops like marigolds',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
      'Cabbages/Kales_Flowering/Reproductive_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },
    'Cabbages/Kales_Flowering/Reproductive_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor flowers for damage',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Fastac (Cypermethrin)',
        'Imidacloprid',
        'Bifenthrin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_flowering.jpg',
    },

    // Cabbages/Kales - Maturation/Harvesting
    'Cabbages/Kales_Maturation/Harvesting_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae from heads',
        'Use neem oil sprays',
        'Use row covers during maturation',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_harvesting.jpg',
      'possibleStrategies': [
        'Use trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor heads for larvae',
        'Use row covers',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Crop residue',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Lambda-cyhalothrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Use neem oil sprays',
        'Plant trap crops like mustard',
        'Introduce parasitic wasps',
        'Use row covers during maturation',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Rodent': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Mature heads as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },

    'Cabbages/Kales_Maturation/Harvesting_Flea Beetle': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_harvesting.jpg',
      'possibleStrategies': [
        'Use row covers',
        'Plant trap crops',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor head damage',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby crucifer crops',
      ],
      'herbicidesPesticides': [
        'Admire (Imidacloprid)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Use row covers during maturation',
        'Plant trap crops like radish',
        'Introduce predatory beetles',
        'Apply diatomaceous earth to heads',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/cabbage_kale_leafminers_harvesting.jpg',
      'possibleStrategies': [
        'Remove affected leaves',
        'Introduce beneficial insects',
        'Use row covers',
        'Apply organic sprays',
        'Monitor heads for damage',
      ],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': [
        'Warm weather',
        'Presence of crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Agri-Mek (Abamectin)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Introduce parasitic wasps',
        'Use row covers during maturation',
        'Remove and destroy affected leaves',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor heads for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to heads',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    'Cabbages/Kales_Maturation/Harvesting_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Monitor heads for damage',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Fastac (Cypermethrin)',
        'Imidacloprid',
        'Bifenthrin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected heads',
        'Hand-pick stink bugs from plants',
        'Use row covers during maturation',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_maturation.jpg',
    },
    // Cabbages/Kales - Storage
    'Cabbages/Kales_Storage_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },
    'Cabbages/Kales_Storage_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_storage.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Ensure proper ventilation',
        'Monitor stored produce',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Poor ventilation',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Use yellow sticky traps in storage areas',
        'Introduce parasitic wasps if feasible',
        'Ensure good ventilation to reduce humidity',
        'Regularly inspect stored produce for damage',
        'Apply garlic extract spray if needed',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },
    'Cabbages/Kales_Storage_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_storage.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Ensure proper storage conditions',
        'Monitor stored produce',
        'Maintain cleanliness',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm conditions',
        'Poor storage hygiene',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected stored produce',
        'Introduce ladybugs if feasible',
        'Maintain cleanliness in storage areas',
        'Ensure good ventilation to reduce humidity',
        'Apply garlic extract spray if needed',
      ],
      'fallbackImagePath': 'assets/pests/cabbages_default_storage.jpg',
    },

    // ===== TOMATOES PESTS =====
    // Tomatoes - Germination/Seedling
    'Tomatoes_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/tomatoes_cutworm_germination.jpg',
      'possibleStrategies': [
        'Remove crop debris',
        'Use row covers',
        'Apply organic mulch',
        'Hand-pick pests at night',
        'Introduce beneficial insects',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Moist, undisturbed soil',
        'Presence of crop residue',
        'Weedy fields',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Permethrin',
        'Bacillus thuringiensis (Bt) (organic)',
        'Spinosad (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to soil',
        'Use row covers at planting',
        'Hand-pick cutworms at night',
        'Apply diatomaceous earth around seedlings',
        'Introduce predatory insects like ground beetles',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_germination.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators like cats',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Availability of food sources',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_germination.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Vydate (Oxamyl)',
        'Nemacur (Fenamiphos)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around seedlings',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },
    'Tomatoes_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/tomatoes_termites_germination.jpg',
      'possibleStrategies': [
        'Remove wood debris',
        'Use bait stations',
        'Apply natural repellents',
        'Maintain dry soil conditions',
        'Introduce predators',
      ],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': [
        'Presence of wood debris',
        'Moist soil conditions',
        'Nearby termite colonies',
        'Lack of natural predators',
      ],
      'herbicidesPesticides': [
        'Termiticides like Fipronil',
        'Bait stations (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Set up termite bait stations around fields',
        'Remove wood debris from planting areas',
        'Maintain dry soil conditions to deter termites',
        'Introduce natural predators like ants',
        'Use neem oil as a repellent if needed',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_germination.jpg',
    },

    // Tomatoes - Vegetative Growth/Weeding
    'Tomatoes_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches',
        'Monitor plant health',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce ladybugs to control aphid population',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick hornworms from leaves',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor leaves for webbing',
      ],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Abamectin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_vegetative_growth.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Ratoxin (Bromadiolone)',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce predatory insects like minute pirate bugs',
        'Use reflective mulches around plants',
        'Maintain plant health with proper fertilization',
        'Rotate crops to disrupt thrip life cycle',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Spidermites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor leaves for webbing',
      ],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Agri_Mek (Abamectin)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected leaves',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to leaves',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_vegetative_growth.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },
    'Tomatoes_Vegetative Growth/Weeding_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_vegetative_growth.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Vydate (Oxamyl)',
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_vegetative.jpg',
    },

    // Tomatoes - Flowering/Reproductive
    'Tomatoes_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor flower buds',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Azadirachtin (Neem Oil)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Admire (Imidacloprid)',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Hand-pick hornworms from flowers',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_flowering.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor flowers for webbing',
      ],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Agri-Mek (Abamectin)',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to flowers',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_flowering.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected flowers',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_flowering.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Agri-Mek (Abamectin)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_flowering.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use garlic extract as a repellent',
        'Set mechanical traps around fields',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_flowering.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Vydate (Oxamyl)',
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_flowering.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
        'Fastac (Cypermethrin)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected flowers',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays on flowers',
        'Plant trap crops like corn',
        'Hand-pick larvae from flowers',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },
    'Tomatoes_Flowering/Reproductive_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_flowering.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor flowers for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to flowers',
        'Use neem oil sprays on flowers',
        'Plant trap crops like corn',
        'Hand-pick larvae from flowers',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_flowering.jpg',
    },

    // Tomatoes - Maturation/Harvesting
    'Tomatoes_Maturation/Harvesting_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_harvesting.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Use neem oil sprays',
        'Plant companion crops',
        'Use reflective mulches',
        'Monitor fruits for aphids',
      ],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': [
        'Warm weather',
        'Overcrowded plants',
        'Lack of natural predators',
        'Excess nitrogen in soil',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Garlic extract (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce ladybugs to control aphids',
        'Use garlic extract spray',
        'Plant marigolds as companion crops',
        'Apply diatomaceous earth to fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_harvesting.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Plant companion crops',
        'Use reflective mulches',
      ],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Overcrowded plants',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Imidacloprid',
        'Pyriproxyfen',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Spinosad (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Plant marigolds as companion crops',
        'Apply garlic extract spray',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_harvesting.jpg',
      'possibleStrategies': [
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain adequate irrigation',
        'Use reflective mulches',
        'Monitor fruits for webbing',
      ],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': [
        'Hot, dry conditions',
        'Dust on leaves',
        'Lack of predators',
        'Overcrowded plants',
      ],
      'herbicidesPesticides': [
        'Abamectin',
        'Spinosad (organic)',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Introduce predatory mites',
        'Use garlic extract spray',
        'Maintain high humidity around plants',
        'Apply diatomaceous earth to fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_harvesting.jpg',
      'possibleStrategies': [
        'Set mechanical traps',
        'Clear vegetation around fields',
        'Use natural repellents',
        'Introduce predators',
        'Use fencing',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Ripe fruits as food source',
        'Nearby nesting sites',
        'Unprotected fields',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Set mechanical traps around fields',
        'Use garlic extract as a repellent',
        'Plant repellent crops like mint',
        'Clear debris to reduce nesting sites',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_harvesting.jpg',
      'possibleStrategies': [
        'Use reflective mulches',
        'Introduce beneficial insects',
        'Apply organic sprays',
        'Maintain plant health',
        'Use crop rotation',
      ],
      'intervention': 'Apply insecticide spinosad to fruits',
      'possibleCauses': [
        'Hot, dry conditions',
        'Weedy fields',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected fruits',
        'Introduce predatory mites',
        'Use neem oil sprays',
        'Plant companion crops like marigolds',
        'Use reflective mulches to deter thrips',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_harvesting.jpg',
      'possibleStrategies': [
        'Use yellow sticky traps',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Remove affected leaves',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide spinosad to foliage',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Abamectin',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Apply spinosad to affected leaves',
        'Introduce parasitic wasps',
        'Use yellow sticky traps',
        'Remove and destroy affected leaves',
        'Plant trap crops like marigolds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor plants for damage',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm, humid conditions',
        'Weedy fields',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Carbaryl',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to foliage',
        'Hand-pick larvae at night',
        'Use neem oil sprays',
        'Plant trap crops like millet',
        'Introduce predatory birds',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_harvesting.jpg',
      'possibleStrategies': [
        'Use nematode-resistant varieties',
        'Apply beneficial nematodes',
        'Rotate crops',
        'Solarize soil',
        'Maintain healthy soil',
      ],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': [
        'Infested soil',
        'Warm soil temperatures',
        'Poor crop rotation',
        'Susceptible plant varieties',
      ],
      'herbicidesPesticides': [
        'Fumigants like 1,3-Dichloropropene',
        'Beneficial nematodes (organic)',
        'Neem oil (organic)',
        'Nemacur (Fenamiphos)',
        'Vydate (Oxamyl)',
      ],
      'organicInterventions': [
        'Apply beneficial nematodes to soil around plants',
        'Use solarization to reduce nematode populations',
        'Rotate crops to non-host plants',
        'Maintain healthy soil with organic matter',
        'Plant nematode-resistant tomato varieties',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick bugs',
        'Use row covers',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Plant trap crops',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Weedy fields',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
        'Decis (Deltamethrin)',
        'Fastac (Cypermethrin)',
      ],
      'organicInterventions': [
        'Spray neem oil on affected fruits',
        'Hand-pick stink bugs from plants',
        'Use row covers during flowering',
        'Introduce predatory insects like parasitic wasps',
        'Plant trap crops to divert stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor fruits for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Use neem oil sprays on fruits',
        'Plant trap crops like corn',
        'Hand-pick larvae from fruits',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_harvesting.jpg',
      'possibleStrategies': [
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use trap crops',
        'Monitor fruits for damage',
        'Hand-pick larvae',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Crop residue',
        'Lack of predators',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Use neem oil sprays on fruits',
        'Plant trap crops like corn',
        'Hand-pick larvae from fruits',
        'Introduce parasitic wasps',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Fruitflies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_harvesting.jpg',
      'possibleStrategies': [
        'Use baited traps',
        'Remove fallen fruits',
        'Introduce beneficial insects',
        'Use row covers',
        'Monitor fruits for damage',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Warm weather',
        'Ripe fruits',
        'Nearby host plants',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Set baited traps with spinosad',
        'Remove and destroy fallen fruits promptly',
        'Introduce parasitic wasps',
        'Use row covers to protect fruits',
        'Apply neem oil sprays on fruits',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },
    'Tomatoes_Maturation/Harvesting_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_harvesting.jpg',
      'possibleStrategies': [
        'Hand-pick larvae',
        'Apply organic sprays',
        'Introduce beneficial insects',
        'Use row covers',
        'Plant trap crops',
      ],
      'intervention': 'Apply Insecticide Bacillus thuringiensis (Bt)',
      'possibleCauses': [
        'Warm weather',
        'Nearby host plants',
        'Lack of predators',
        'Crop residue',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Apply Bacillus thuringiensis (Bt) to fruits',
        'Hand-pick hornworms from fruits',
        'Use neem oil sprays',
        'Introduce parasitic wasps',
        'Plant trap crops like dill',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_maturation.jpg',
    },

    // Tomatoes - Storage
    'Tomatoes_Storage_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_storage.jpg',
      'possibleStrategies': [
        'Store in rodent-proof containers',
        'Set mechanical traps',
        'Use natural repellents',
        'Ensure proper storage conditions',
        'Introduce predators',
      ],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': [
        'Food availability',
        'Poor storage facilities',
        'Nearby nesting sites',
        'Lack of predators',
      ],
      'herbicidesPesticides': [
        'Bromadiolone',
        'Zinc phosphide',
        'Garlic extract (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Use rodent-proof containers for storage',
        'Use garlic extract as a repellent',
        'Store in metal or rodent-proof containers',
        'Set mechanical traps in storage areas',
        'Clear debris around storage',
        'Introduce natural predators like cats',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Fruit Flies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_storage.jpg',
      'possibleStrategies': [
        'Use baited traps',
        'Maintain proper hygiene',
        'Store in sealed containers',
        'Monitor storage areas',
        'Introduce beneficial insects',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Ripe or overripe fruits',
        'Poor sanitation',
        'Warm storage conditions',
        'Nearby host plants',
      ],
      'herbicidesPesticides': [
        'Spinosad (organic)',
        'Malathion',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
      ],
      'organicInterventions': [
        'Set baited traps with spinosad in storage areas',
        'Maintain cleanliness and remove spoiled fruits',
        'Store tomatoes in sealed containers',
        'Introduce parasitic wasps if feasible',
        'Apply neem oil sprays around storage area',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_storage.jpg',
      'possibleStrategies': [
        'Inspect fruits before storage',
        'Use sealed containers',
        'Maintain proper hygiene',
        'Monitor storage areas',
        'Apply organic treatments if needed',
      ],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': [
        'Infested fruits',
        'Poor storage conditions',
        'Warm, humid environment',
        'Lack of monitoring',
      ],
      'herbicidesPesticides': [
        'Carbaryl',
        'Spinosad (organic)',
        'Bacillus thuringiensis (Bt) (organic)',
        'Neem oil (organic)',
      ],
      'organicInterventions': [
        'Inspect and remove any infested fruits before storage',
        'Store tomatoes in sealed containers',
        'Maintain cleanliness in storage areas',
        'Apply neem oil sprays around storage area if needed',
        'Monitor regularly for signs of infestation',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },
    'Tomatoes_Storage_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_storage.jpg',
      'possibleStrategies': [
        'Store in sealed containers',
        'Set mechanical traps',
        'Maintain proper hygiene',
        'Use natural repellents',
        'Monitor storage areas',
      ],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': [
        'Infested fruits',
        'Poor storage conditions',
        'Warm, humid environment',
        'Lack of monitoring',
      ],
      'herbicidesPesticides': [
        'Malathion',
        'Imidacloprid',
        'Neem oil (organic)',
        'Pyrethrin (organic)',
        'Carbaryl',
      ],
      'organicInterventions': [
        'Store tomatoes in sealed containers to prevent stink bug access',
        'Set mechanical traps around storage areas',
        'Maintain cleanliness and remove any infested fruits',
        'Use garlic extract as a repellent around storage area',
        'Monitor regularly for signs of stink bugs',
      ],
      'fallbackImagePath': 'assets/pests/tomatoes_default_storage.jpg',
    },

    // ===== CARROTS PESTS =====
     // Carrots - Germination/Seedling
  'Carrots_Germination/Seedling_Termites': {
    'imagePath': 'assets/pests/carrots_termites_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Soil treatment', 'Use treated seeds', 'Remove debris'],
    'activeAgent': 'Insecticide (Fipronil)',
    'possibleCauses': ['Dry soil', 'Organic matter'],
    'pesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil to soil around seedlings',
      'Introduce beneficial nematodes to soil',
      'Use diatomaceous earth as a soil barrier',
      'Plant repellent crops like marigolds',
      'Maintain moist soil to deter termites'
    ],
  },
  'Carrots_Germination/Seedling_Cutworms': {
    'imagePath': 'assets/pests/carrots_cutworm_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around seedling stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Use insecticidal soap sprays'
    ],
  },
  'Carrots_Germination/Seedling_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use row covers', 'Monitor seedlings'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Carrot fields'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use lightweight row covers during egg-laying',
      'Apply neem oil to soil around seedlings',
      'Plant trap crops like radishes',
      'Use diatomaceous earth around plant base'
    ],
  },
  'Carrots_Germination/Seedling_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Carrots_Germination/Seedling_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Avoid grassy fields', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Previous grass crops'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around seedlings',
      'Perform deep tillage to expose wireworms',
      'Introduce predatory ground beetles'
    ],
  },
  'Carrots_Germination/Seedling_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use traps', 'Protect seedlings', 'Clear debris'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Seed availability', 'Unprotected fields'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Use peppermint oil as a repellent around fields',
      'Install owl nesting boxes to encourage predation',
      'Use metal mesh barriers around seedling beds'
    ],
  },
  // Carrots - Vegetative Growth/Weeding
  'Carrots_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic',
      'Spray water to dislodge aphids'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Whiteflies': {
    'imagePath': 'assets/pests/carrots_whiteflies_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Control humidity'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm, humid weather', 'Dense foliage'],
    'pesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    'organicInterventions': [
      'Release Encarsia formosa parasitic wasps',
      'Apply insecticidal soap to undersides of leaves',
      'Use neem oil sprays every 5-7 days',
      'Place yellow sticky traps near plants',
      'Plant repellent herbs like basil'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Avoid dense planting'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Dry conditions', 'Young leaves'],
    'pesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    'organicInterventions': [
      'Spray spinosad on affected leaves',
      'Use blue sticky traps to capture thrips',
      'Apply neem oil sprays every 7 days',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use row covers', 'Monitor plants'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Carrot fields'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to soil around plants',
      'Use lightweight row covers during egg-laying',
      'Apply beneficial nematodes to soil',
      'Plant trap crops like radishes',
      'Use neem oil sprays to deter adults'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_loopers_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Control weeds', 'Monitor populations'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Nearby host plants'],
    'pesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around plants',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization during fallow periods',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Avoid grassy fields', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Previous grass crops'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around plants',
      'Perform deep tillage to expose wireworms',
      'Introduce predatory ground beetles'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Dense vegetation', 'Food sources'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around field edges',
      'Encourage natural predators like owls',
      'Use metal mesh barriers around fields'
    ],
  },
'Carrots_Vegetative Growth/Weeding_Leafminers': {
    'imagePath': 'assets/pests/carrots_leafminers_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use yellow sticky traps', 'Remove affected leaves', 'Introduce beneficial insects'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Nearby host plants'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to affected leaves',
      'Introduce parasitic wasps like Diglyphus isaea',
      'Use yellow sticky traps to monitor populations',
      'Remove and destroy infested leaves',
      'Plant trap crops like marigolds'
    ],
  },
  'Carrots_Vegetative Growth/Weeding_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-pick larvae', 'Use trap crops', 'Introduce beneficial insects'],
    'activeAgent': 'Insecticide (Bacillus thuringiensis)',
    'possibleCauses': ['Warm, humid conditions', 'Weedy fields'],
    'pesticides': ['Dipel (Bacillus thuringiensis)', 'XenTari (Bacillus thuringiensis)'],
    'organicInterventions': [
      'Apply Bacillus thuringiensis (Bt) to foliage',
      'Hand-pick larvae during early morning or evening',
      'Use neem oil sprays on affected areas',
      'Plant trap crops like millet or sorghum',
      'Introduce predatory birds or insects'
    ],
  },

  // Carrots - Maturation/Harvesting
  'Carrots_Maturation/Harvesting_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use row covers', 'Monitor roots'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Mature roots'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to soil around mature plants',
      'Use lightweight row covers during egg-laying',
      'Apply beneficial nematodes to soil',
      'Plant trap crops like radishes',
      'Harvest carrots promptly to reduce exposure'
    ],
  },
  'Carrots_Maturation/Harvesting_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Crop rotation', 'Soil testing'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Mature roots'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting next crop',
      'Plant resistant carrot varieties',
      'Incorporate marigold cover crops',
      'Harvest promptly to minimize damage'
    ],
  },
  'Carrots_Maturation/Harvesting_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Crop rotation', 'Deep tillage'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Cool, moist soil', 'Mature roots'],
    'pesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use trap crops like wheat or barley',
      'Apply diatomaceous earth around plants',
      'Perform deep tillage to expose wireworms',
      'Harvest carrots promptly to reduce damage'
    ],
  },
  'Carrots_Maturation/Harvesting_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Introduce ladybugs', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings on mature plants',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Carrots_Maturation/Harvesting_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Mature roots', 'Unprotected fields'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around field edges',
      'Encourage natural predators like owls',
      'Use metal mesh barriers around harvested carrots'
    ],
  },
  'Carrots_Maturation/Harvesting_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Hand-pick larvae', 'Use trap crops'],
    'activeAgent': 'Insecticide (Bacillus thuringiensis)',
    'possibleCauses': ['Warm, humid conditions', 'Mature plants'],
    'pesticides': ['Dipel (Bacillus thuringiensis)', 'XenTari (Bacillus thuringiensis)'],
    'organicInterventions': [
      'Apply Bacillus thuringiensis (Bt) to foliage',
      'Hand-pick larvae during early morning or evening',
      'Use neem oil sprays on affected areas',
      'Plant trap crops like millet or sorghum',
      'Introduce predatory birds or insects'
    ],
  },
'Carrots_Maturation/Harvesting_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use blue sticky traps', 'Monitor flowers'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Dry conditions', 'Mature plants'],
    'pesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    'organicInterventions': [
      'Spray spinosad on flowers and leaves',
      'Use blue sticky traps to capture thrips',
      'Apply neem oil sprays every 7 days',
      'Introduce predatory mites or lacewings',
      'Ensure adequate irrigation to reduce stress'
    ],
  },
  'Carrots_Maturation/Harvesting_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_looper_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use reflective mulches', 'Monitor plants'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around flowers',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Carrots_Maturation/Harvesting_White Flies': {
    'imagePath': 'assets/pests/carrots_whiteflies_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use yellow traps', 'Introduce Encarsia'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm, humid weather', 'Mature plants'],
    'pesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    'organicInterventions': [
      'Release Encarsia formosa parasitic wasps',
      'Apply insecticidal soap to undersides of leaves',
      'Use neem oil sprays every 5-7 days',
      'Place yellow sticky traps near flowers',
      'Plant repellent herbs like mint'
    ],
  },
  'Carrots_Maturation/Harvesting_Leaf Miners': {
    'imagePath': 'assets/pests/carrots_leafminers_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest early', 'Use yellow sticky traps', 'Remove affected leaves'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Mature plants'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply spinosad to affected leaves',
      'Introduce parasitic wasps like Diglyphus isaea',
      'Use yellow sticky traps to monitor populations',
      'Remove and destroy infested leaves',
      'Plant trap crops like marigolds'
    ],
  },

  // Carrots - Storage
  'Carrots_Storage_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Unprotected storage', 'Food availability'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Use rodent-proof metal containers',
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around storage areas',
      'Encourage natural predators like barn owls',
      'Regularly clean storage to remove food debris'
    ],
  },
  'Carrots_Storage_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect stored produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm storage', 'Infested produce'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Apply neem oil to carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Inspect and remove infested carrots',
      'Use insecticidal soap on affected areas',
      'Sanitize storage with organic disinfectants'
    ],
  },
  'Carrots_Storage_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested produce', 'Warm storage'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Inspect and remove infested carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Use soil solarization before next planting',
      'Plant resistant carrot varieties',
      'Sanitize storage with organic disinfectants'
    ],
  },
  'Carrots_Storage_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_storage.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Inspect produce', 'Use cold storage', 'Sanitize storage'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Infested produce', 'Warm storage'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Inspect and remove infested carrots before storage',
      'Maintain cold storage at 32-40°F',
      'Apply spinosad to carrots before storage',
      'Use beneficial nematodes in soil before next planting',
      'Sanitize storage with organic disinfectants'
    ],
  },

  // Onions - Germination/Seedling
  'Onions_Germination/Seedling_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Plant resistant onion varieties'
    ],
  },
  'Onions_Germination/Seedling_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_germination.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Encourage natural predators', 'Proper spacing'],
    'activeAgent': 'Insecticidal soap or neem oil',
    'possibleCauses': ['High nitrogen levels', 'Weak plants'],
    'pesticides': ['Insecticidal soaps', 'Neem oil', 'Pyrethroids'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
   
  // Onions - Vegetative Growth/Weeding
  'Onions_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Plant resistant onion varieties'
    ],
  },
  'Onions_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_vegetative_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Encourage natural predators', 'Proper spacing'],
    'activeAgent': 'Insecticidal soap or neem oil',
    'possibleCauses': ['High nitrogen levels', 'Weak plants'],
    'pesticides': ['Insecticidal soaps', 'Neem oil', 'Pyrethroids'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
 
 
  // Onions - Bulb Formation/Reproductive
  'Onions_Bulb Formation/Reproductive_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulb_formation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Good field sanitation', 'Use of resistant varieties'],
    'activeAgent': 'Dip bulbs in neem extract, apply insecticidal soil drenches',
    'possibleCauses': ['Exposed bulbs', 'Planting in infested soils'],
    'pesticides': ['Phorate (Thimet)', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Dip bulbs in neem extract before planting',
      'Use lightweight row covers during egg-laying',
      'Plant trap crops like radishes',
      'Apply diatomaceous earth around bulb base'
    ],
  },
  'Onions_Bulb Formation/Reproductive_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulb_formation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use of sticky traps', 'Plant resistant varieties'],
    'activeAgent': 'Apply soil drenches with insecticides like diazinon',
    'possibleCauses': ['Infested soil', 'Overgrown young plants'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around bulbs',
      'Plant trap crops like radishes',
      'Use lightweight row covers during egg-laying'
    ],
  },
  
  // Onions - Bulbing/Maturation
  'Onions_Bulbing/Maturation_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Good field sanitation', 'Use of resistant varieties'],
    'activeAgent': 'Dip bulbs in neem extract, apply insecticidal soil drenches',
    'possibleCauses': ['Exposed bulbs', 'Planting in infested soils'],
    'pesticides': ['Phorate (Thimet)', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Dip bulbs in neem extract before planting',
      'Use lightweight row covers during egg-laying',
      'Plant trap crops like radishes',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Onions_Bulbing/Maturation_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Use of sticky traps', 'Plant resistant varieties'],
    'activeAgent': 'Apply soil drenches with insecticides like diazinon',
    'possibleCauses': ['Infested soil', 'Overgrown young plants'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around bulbs',
      'Plant trap crops like radishes',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Onions_Bulbing/Maturation_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_bulbing.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use resistant varieties', 'Introduce natural predators', 'Maintain proper field hygiene'],
    'activeAgent': 'Neem oil or spinosad sprays',
    'possibleCauses': ['High humidity', 'Overcrowding', 'Late planting'],
    'pesticides': ['Neem-based sprays', 'Spinosad', 'Insecticidal soaps'],
    'organicInterventions': [
      'Apply neem oil sprays every 7 days',
      'Use blue sticky traps to capture thrips',
      'Introduce predatory mites or lacewings',
      'Maintain irrigation to reduce plant stress',
      'Harvest promptly to reduce exposure'
    ],
  },
  
  // Onions - Harvesting/Storage
  'Onions_Harvesting/Storage_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use row covers', 'Monitor mature onions'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Cool, moist conditions', 'Mature onions'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil before harvest',
      'Use lightweight row covers during egg-laying',
      'Apply neem oil to soil around mature plants',
      'Harvest onions promptly to reduce exposure',
      'Inspect and remove infested onions'
    ],
  },
  'Onions_Harvesting/Storage_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Harvest promptly', 'Use row covers', 'Monitor mature onions'],
    'activeAgent': 'Insecticide (Diazinon)',
    'possibleCauses': ['Cool, moist conditions', 'Mature onions'],
    'pesticides': ['Diazinon', 'Chlorpyrifos'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil before harvest',
      'Use yellow sticky traps to capture adults',
      'Apply neem oil to soil around mature plants',
      'Harvest onions promptly to reduce exposure',
      'Inspect and remove infested onions'
    ],
  },
  'Onions_Harvesting/Storage_Rodents': {
    'imagePath': 'assets/pests/onions_rodents_harvesting.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
    'activeAgent': 'Rodenticide (Bromadiolone)',
    'possibleCauses': ['Unprotected storage', 'Food availability'],
    'pesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    'organicInterventions': [
      'Use rodent-proof metal containers',
      'Set mechanical snap traps with organic bait',
      'Apply peppermint oil around storage areas',
      'Encourage natural predators like barn owls',
      'Regularly clean storage to remove food debris'
    ],
  },
  
  //IRISH POTATOES PESTS
  // Irish Potatoes - Early Growth
  'Irish Potatoes_Early Growth_Wireworms': {
    'imagePath': 'assets/pests/irish_potatoes_wireworms_early_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nematicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting',
      'Plant resistant potato varieties',
      'Incorporate marigold cover crops',
      'Apply composted manure to improve soil health'
    ],
  },
  'Irish Potatoes_Early Growth_Cutworms': {
    'imagePath': 'assets/pests/irish_potatoes_cutworms_early_growth.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around seedling stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Use insecticidal soap sprays'
    ],
  },
   
  // Irish Potatoes - Tuber Initiation
  'Irish Potatoes_Tuber Initiation_Colorado Potato Beetle': {
    'imagePath': 'assets/pests/irish_potatoes_colorado_potato_beetle_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-picking', 'Use traps', 'Crop rotation'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Dense planting'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Hand-pick beetles and larvae early in the morning',
      'Apply spinosad sprays to affected plants',
      'Use lightweight row covers to protect plants',
      'Introduce predatory bugs like ladybugs',
      'Plant trap crops like eggplant'
    ],
  },
  'Irish Potatoes_Tuber Initiation_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
  'Irish Potatoes_Tuber Initiation_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_tuber_initiation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Spray water to dislodge mites'
    ],
  },
   
  // Irish Potatoes - Tuber Bulking
  'Irish Potatoes_Tuber Bulking_Flea Beetles': {
    'imagePath': 'assets/pests/irish_potatoes_flea_beetles_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use row covers', 'Crop rotation', 'Monitor plants'],
    'activeAgent': 'Insecticide (Pyrethroids)',
    'possibleCauses': ['Warm weather', 'Young plants'],
    'pesticides': ['Sevin (Carbaryl)', 'Pounce (Permethrin)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use lightweight row covers to protect plants',
      'Place yellow sticky traps around plants',
      'Plant trap crops like mustard',
      'Apply diatomaceous earth to foliage'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Leaf Hoppers': {
    'imagePath': 'assets/pests/irish_potatoes_leafhoppers_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Use reflective mulches', 'Monitor plants', 'Crop rotation'],
    'activeAgent': 'Insecticide (Imidacloprid)',
    'possibleCauses': ['Warm weather', 'Young plants'],
    'pesticides': ['Admire (Imidacloprid)', 'Assail (Acetamiprid)'],
    'organicInterventions': [
      'Apply neem oil sprays weekly',
      'Use insecticidal soap on affected plants',
      'Place yellow sticky traps around plants',
      'Introduce predatory bugs like minute pirate bugs',
      'Plant trap crops like alfalfa'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Spray water to dislodge aphids'
    ],
  },
  'Irish Potatoes_Tuber Bulking_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_tuber_bulking.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Spray water to dislodge mites'
    ],
  },
    
  // Irish Potatoes - Maturation/Harvesting
  'Irish Potatoes_Maturation/Harvesting_Wireworms': {
    'imagePath': 'assets/pests/irish_potatoes_wireworms_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
    'activeAgent': 'Nemicide (Oxamyl)',
    'possibleCauses': ['Infested soil', 'Continuous cropping'],
    'pesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    'organicInterventions': [
      'Apply beneficial nematodes to soil',
      'Use soil solarization before planting next crop',
      'Plant resistant potato varieties',
      'Incorporate marigold cover crops',
      'Harvest promptly to minimize damage'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Cutworms': {
    'imagePath': 'assets/pests/irish_potatoes_cutworms_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
    'activeAgent': 'Insecticide (Lambda-cyhalothrin)',
    'possibleCauses': ['Moist soil', 'Weedy fields'],
    'pesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    'organicInterventions': [
      'Place cardboard collars around plant stems',
      'Apply diatomaceous earth around plant base',
      'Introduce beneficial nematodes to soil',
      'Spray Bacillus thuringiensis (Bt) on affected areas',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Colorado Potato Beetle': {
    'imagePath': 'assets/pests/irish_potatoes_colorado_potato_beetle_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Hand-picking', 'Use traps', 'Crop rotation'],
    'activeAgent': 'Insecticide (Spinosad)',
    'possibleCauses': ['Warm weather', 'Dense planting'],
    'pesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    'organicInterventions': [
      'Hand-pick beetles and larvae early in the morning',
      'Apply spinosad sprays to affected plants',
      'Use lightweight row covers to protect plants',
      'Introduce predatory bugs like ladybugs',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Aphids': {
    'imagePath': 'assets/pests/irish_potatoes_aphids_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
    'activeAgent': 'Insecticide (Neem Oil)',
    'possibleCauses': ['Warm weather', 'Over-fertilization'],
    'pesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    'organicInterventions': [
      'Release ladybugs or lacewings as predators',
      'Apply neem oil sprays every 5-7 days',
      'Use insecticidal soap on affected leaves',
      'Plant companion plants like garlic or chives',
      'Harvest promptly to reduce exposure'
    ],
  },
  'Irish Potatoes_Maturation/Harvesting_Spider Mites': {
    'imagePath': 'assets/pests/irish_potatoes_spider_mites_maturation.jpg',
    'fallbackImagePath': 'assets/pests/default.jpg',
    'preventionStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
    'activeAgent': 'Miticide (Abamectin)',
    'possibleCauses': ['Dry conditions', 'Dusty fields'],
    'pesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    'organicInterventions': [
      'Release predatory mites like Phytoseiulus persimilis',
      'Apply neem oil sprays every 7 days',
      'Use insecticidal soap on affected leaves',
      'Increase humidity around plants',
      'Harvest promptly to reduce exposure'
    ],
  },
 };

   @override
  void initState() {
    super.initState();
    checkAuth();

    // ✅ Debugging
    debugPrint("➡️ Prefill symptoms: ${widget.selectedSymptoms}");
    if (widget.selectedSymptoms != null &&
        widget.selectedSymptoms!.isNotEmpty) {
      final first = widget.selectedSymptoms!.first;
      debugPrint(
          "Prefill Crop=${first.crop}, Stage=${first.stage}, Identity=${first.identity}");

      setState(() {
        _selectedCrop = first.crop;
        _selectedStage = first.stage;
        _selectedPest = first.identity; // assumed pest identity
      });

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _updatePestDetails());
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
      _selectedPest = null;
      _pestData = null;
      _imageKey = UniqueKey();
      _showPestDetails = false;
    });
  }

  Future<void> _updatePestDetails() async {
    try {
      if (_selectedCrop == null ||
          _selectedStage == null ||
          _selectedPest == null) {
        setState(() {
          _pestData = null;
          _imageKey = UniqueKey();
          _showPestDetails = false;
        });
        return;
      }

      final pestKey = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
      final pestDetails = _pestDetails[pestKey];

      setState(() {
        _pestData = pestDetails != null
            ? PestData(
                name: _selectedPest ?? '',
                imagePath:
                    pestDetails['imagePath'] ?? 'assets/pests/default.jpg',
                preventionStrategies: List<String>.from(
                    pestDetails['possibleStrategies'] ?? []),
                activeAgent: pestDetails['intervention'] ?? '',
                possibleCauses:
                    List<String>.from(pestDetails['possibleCauses'] ?? []),
                herbicides: List<String>.from(
                    pestDetails['herbicidesPesticides'] ?? []),
                organicInterventions: List<String>.from(
                    pestDetails['organicInterventions'] ?? []),
              )
            : null;
        _imageKey = UniqueKey();
      });
    } catch (e) {
      debugPrint('Error updating pest details: $e');
      setState(() {
        _pestData = null;
        _imageKey = UniqueKey();
        _showPestDetails = false;
      });
    }
  }

  void _scrollToHints() {
    if (_hintsKey.currentContext != null) {
      Scrollable.ensureVisible(_hintsKey.currentContext!);
    }
  }

  void _showOrganicPestGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Organic Pest Management Tips'),
        content: const SingleChildScrollView(
          child: Text("Use neem, ash, crop rotation, intercropping, traps..."),
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
        title: const Text('Pest Management'),
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
              // ✅ Crop dropdown
              _buildDropdown('Select Crop', _crops, _selectedCrop, (val) {
                setState(() {
                  _selectedCrop = val;
                  _selectedStage = null;
                  _selectedPest = null;
                  _pestData = null;
                  _imageKey = UniqueKey();
                  _showPestDetails = false;
                  updateSelections();
                });
              }),
              const SizedBox(height: 16),

              // ✅ Stage dropdown
              _buildDropdown(
                'Select Stage',
                _selectedCrop != null ? _cropStages[_selectedCrop]! : [],
                _selectedStage,
                (val) {
                  setState(() {
                    _selectedStage = val;
                    _selectedPest = null;
                    _pestData = null;
                    _imageKey = UniqueKey();
                    _showPestDetails = false;
                    _updatePestDetails();
                  });
                },
              ),
              const SizedBox(height: 16),

              // ✅ Pest dropdown
              _buildDropdown(
                'Select Pest',
                _selectedCrop != null && _selectedStage != null
                    ? _cropStagePests[_selectedCrop]![_selectedStage] ?? []
                    : [],
                _selectedPest,
                (val) {
                  setState(() {
                    _selectedPest = val;
                    _pestData = null;
                    _imageKey = UniqueKey();
                    _showPestDetails = false;
                    _updatePestDetails();
                  });
                },
              ),
              const SizedBox(height: 16),

              // ✅ Organic toggle
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

              // ✅ Hints toggle
              GestureDetector(
                onTap: () {
                  if (_pestData != null) {
                    setState(() {
                      _showPestDetails = !_showPestDetails;
                      if (_showPestDetails) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _scrollToHints());
                      }
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text('Please select a pest first')));
                  }
                },
                child: const Text(
                  'View Pest Management Hints',
                  style: TextStyle(
                    color: Color.fromARGB(255, 3, 39, 4),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              if (_pestData != null) ...[
                const SizedBox(height: 16),
                _buildImageCard(_pestData!.imagePath),
              ],

              if (_showPestDetails && _pestData != null) ...[
                const SizedBox(height: 16),
                Column(
                  key: _hintsKey,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_isOrganic) ...[
                      _buildHintCard(
                          'Possible Causes', _pestData!.possibleCauses.join('\n')),
                      const SizedBox(height: 16),
                      _buildHintCard('Prevention Strategies',
                          _pestData!.preventionStrategies.join('\n')),
                      const SizedBox(height: 16),
                      _buildHintCard('Active Agent', _pestData!.activeAgent),
                      const SizedBox(height: 16),
                      _buildHintCard('Herbicides/Pesticides',
                          _pestData!.herbicides.join('\n')),
                    ],
                    if (_pestData!.organicInterventions.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHintCard('Organic Interventions',
                          _pestData!.organicInterventions.join('\n')),
                    ],
                    if (_pestData!.organicInterventions.isEmpty && _isOrganic)
                      _buildHintCard('Organic Interventions',
                          'No organic interventions available'),

                    const SizedBox(height: 16),

                    // ✅ Add Intervention
                    ElevatedButton(
                      onPressed: () {
                        if (_selectedCrop != null &&
                            _selectedStage != null &&
                            _pestData != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InterventionPage(
                                cropType: _selectedCrop!,
                                cropStage: _selectedStage!,
                                pestData: _pestData!,
                                notificationsPlugin: _notificationsPlugin,
                              ),
                            ),
                          );
                        } else {
                          scaffoldMessenger.showSnackBar(const SnackBar(
                              content: Text(
                                  "Please select crop, stage and pest first")));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                        foregroundColor: Colors.white,
                      ),
                      child:
                          const Text('Add Intervention', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // ✅ View Interventions
              ElevatedButton(
                onPressed: () {
                  if (_pestData != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewInterventionsPage(
                          pestData: _pestData!,
                          notificationsPlugin: _notificationsPlugin,
                        ),
                      ),
                    );
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(
                        content: Text("Please select a pest first")));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Interventions'),
              ),

              const SizedBox(height: 16),

              // ✅ View History
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const UserPestHistoryPage()),
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
                  const Text('Organic Pest Guide',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    onPressed: _showOrganicPestGuide,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable widgets
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