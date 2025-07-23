import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:kilimomkononi/models/pest_disease_model.dart';
import 'package:kilimomkononi/screens/pest%20management/intervention_page.dart';
import 'package:kilimomkononi/screens/pest%20management/user_pest_history_page.dart';

class PestManagementPage extends StatefulWidget {
  const PestManagementPage({super.key});

  @override
  State<PestManagementPage> createState() => _PestManagementPageState();
}

class _PestManagementPageState extends State<PestManagementPage> {
  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedPest;
  PestData? _pestData;
  bool _showPestDetails = false;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _hintsKey = GlobalKey();

  // Updated crop list
  final List<String> _crops = ['Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes'];

  // Crop-specific stages
  final Map<String, List<String>> _cropStages = {
    'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
    'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
    'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  };

  // Nested map for pests by crop and stage
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
      'Storage': ['Maize Weevil', 'Larger Grain Borer', 'Angoumois Grain Moth', 'Weevils', 'Rodents'],
    },
    'Cabbages/Kales': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Cabbage Root Maggot', 'Flea Beetles', 'Rodents'],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Diamondback Moth', 'Cabbage Looper', 'Leafminers', 'Flea Beetles', 'Cabbage Webworm', 'Armyworms', 'Cabbage Root Maggot', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrips', 'Diamondback Moth', 'Cabbage Looper', 'Armyworms', 'Stink Bugs'],
      'Maturation/Harvesting': ['Diamondback Moth', 'Cabbage Looper', 'Leafminers', 'Flea Beetles', 'Cabbage Webworm', 'Armyworms', 'Stink Bugs', 'Rodents'],
      'Storage': ['Rodents', 'Aphids', 'Whiteflies'],
    },
    'Carrots': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Rodents'],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leaf Loopers', 'Leafminers', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
      'Maturation/Harvesting': ['Aphids', 'Whiteflies', 'Thrips', 'Leaf Loopers', 'Leafminers', 'Carrot Rust Fly', 'Nematodes', 'Wireworms', 'Armyworms', 'Rodents'],
      'Storage': ['Carrot Rust Fly', 'Nematodes', 'Rodents', 'Aphids'],
    },
    'Tomatoes': {
      'Germination/Seedling': ['Termites', 'Cutworms', 'Nematodes', 'Rodents'],
      'Vegetative Growth/Weeding': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Nematodes', 'Hornworms', 'Beet Armyworms', 'Spider Mites', 'Rodents'],
      'Flowering/Reproductive': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Nematodes', 'Bollworm', 'Hornworms', 'Beet Armyworms', 'Stink Bugs', 'Fruit Borers', 'Spider Mites'],
      'Maturation/Harvesting': ['Aphids', 'Whiteflies', 'Thrips', 'Leafminers', 'Nematodes', 'Bollworm', 'Hornworms', 'Beet Armyworms', 'Fruitflies', 'Stink Bugs', 'Fruit Borers', 'Spider Mites', 'Rodents'],
      'Storage': ['Fruitflies', 'Stink Bugs', 'Fruit Borers', 'Rodents'],
    },
  };

  final Map<String, Map<String, dynamic>> _pestDetails = {
    // Beans - Germination/Seedling
    'Bean Fly': {
      'imagePath': 'assets/pests/beans_bean_fly_germination.jpg',
      'possibleStrategies': ['Use resistant varieties', 'Crop rotation', 'Early planting'],
      'intervention': 'Insecticide (Dimethoate)',
      'possibleCauses': ['Warm, humid conditions', 'Late sowing'],
      'herbicidesPesticides': ['Rogor (Dimethoate)', 'Perfekthion (Dimethoate)'],
    },
    'Cutworms': {
      'imagePath': 'assets/pests/beans_cutworms_germination.jpg',
      'possibleStrategies': ['Remove crop debris', 'Use collars around seedlings', 'Plow fields before planting'],
      'intervention': 'Insecticide (Lambda-cyhalothrin)',
      'possibleCauses': ['Moist soil', 'Weedy fields'],
      'herbicidesPesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    },
    'Rodents': {
      'imagePath': 'assets/pests/beans_rodents_germination.jpg',
      'possibleStrategies': ['Use traps', 'Remove hiding spots', 'Secure seedling areas'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Abundant food sources', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },
    'Termites': {
      'imagePath': 'assets/pests/beans_termites_germination.jpg',
      'possibleStrategies': ['Soil treatment', 'Remove wood debris', 'Use treated seeds'],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': ['Dry wood presence', 'Soil disturbance'],
      'herbicidesPesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    },

    // Beans - Vegetative Growth/Weeding
    'Aphids': {
      'imagePath': 'assets/pests/beans_aphids_vegetative_growth.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Regular monitoring'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Over-fertilization'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': ['Use reflective mulches', 'Control weeds', 'Monitor populations'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm weather', 'Nearby host plants'],
      'herbicidesPesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Thrips': {
      'imagePath': 'assets/pests/beans_thrips_vegetative_growth.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Crop rotation', 'Maintain plant health'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Dense planting'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': ['Use reflective mulches', 'Introduce Encarsia predators', 'Monitor with yellow traps'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Overcrowded plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Beetles': {
      'imagePath': 'assets/pests/beans_beetles_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Hand-picking', 'Use row covers'],
      'intervention': 'Insecticide (Pyrethrins)',
      'possibleCauses': ['Warm conditions', 'Nearby host plants'],
      'herbicidesPesticides': ['PyGanic (Pyrethrins)', 'EverGreen (Pyrethrins)'],
    },
    'Rodents (Vegetative Growth/Weeding)': {
      'imagePath': 'assets/pests/beans_rodents_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Dense vegetation', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Beans - Flowering/Reproductive
    'Aphids (Flowering/Reproductive)': {
      'imagePath': 'assets/pests/beans_aphids_flowering.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Avoid over-fertilization', 'Use insecticidal soap'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Flowering stage attracting pests'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Leafhoppers (Flowering/Reproductive)': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_flowering.jpg',
      'possibleStrategies': ['Use reflective mulches', 'Control weeds', 'Apply sticky traps'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm weather', 'Flowering plants'],
      'herbicidesPesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Thrips (Flowering/Reproductive)': {
      'imagePath': 'assets/pests/beans_thrips_flowering.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Avoid dense planting', 'Monitor flowers'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Flowering stage'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borer_flowering.jpg',
      'possibleStrategies': ['Remove infested pods', 'Use pheromone traps', 'Early flowering management'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Flowering to podding stage'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Whiteflies (Flowering/Reproductive)': {
      'imagePath': 'assets/pests/beans_whiteflies_flowering.jpg',
      'possibleStrategies': ['Introduce Encarsia predators', 'Use reflective mulches', 'Monitor flowering'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Flowering plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },

    // Beans - Maturation/Harvesting
    'Pod Borers (Maturation/Harvesting)': {
      'imagePath': 'assets/pests/beans_pod_borers_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Remove infested pods', 'Use traps'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Mature pods'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Beetles (Maturation/Harvesting)': {
      'imagePath': 'assets/pests/beans_beetles_harvesting.jpg',
      'possibleStrategies': ['Hand-picking', 'Harvest promptly', 'Clean fields'],
      'intervention': 'Insecticide (Pyrethrins)',
      'possibleCauses': ['Warm conditions', 'Ripening pods'],
      'herbicidesPesticides': ['PyGanic (Pyrethrins)', 'EverGreen (Pyrethrins)'],
    },
    'Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Dry seeds thoroughly', 'Clean bins'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Infested seeds', 'High humidity'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_harvesting.jpg',
      'possibleStrategies': ['Dry seeds', 'Cold storage', 'Sanitize storage'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Infested legumes', 'Poor storage conditions'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Rodents (Maturation/Harvesting)': {
      'imagePath': 'assets/pests/beans_rodents_harvesting.jpg',
      'possibleStrategies': ['Use traps', 'Harvest promptly', 'Secure harvested beans'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Ripening beans', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Beans - Storage
    'Bean Weevil (Storage)': {
      'imagePath': 'assets/pests/beans_bean_weevil_storage.jpg',
      'possibleStrategies': ['Dry storage', 'Use airtight containers', 'Frequent inspection'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['High moisture', 'Infested beans'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Bruchid Beetles (Storage)': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_storage.jpg',
      'possibleStrategies': ['Cold storage', 'Sanitize storage areas', 'Dry beans'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Warm storage', 'Infested seeds'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Rodents (Storage)': {
      'imagePath': 'assets/pests/beans_rodents_storage.jpg',
      'possibleStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage areas'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Unprotected storage', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Maize - Germination/Seedling
    'Termites (Maize Germination)': {
      'imagePath': 'assets/pests/maize_termites_germination.jpg',
      'possibleStrategies': ['Soil treatment', 'Use treated seeds', 'Remove wood debris'],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': ['Dry soil', 'Organic matter'],
      'herbicidesPesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    },
    'Cutworms (Maize Germination)': {
      'imagePath': 'assets/pests/maize_cutworm_germination.jpg',
      'possibleStrategies': ['Plow fields', 'Use collars around seedlings', 'Remove weeds'],
      'intervention': 'Insecticide (Lambda-cyhalothrin)',
      'possibleCauses': ['Moist soil', 'Weedy fields'],
      'herbicidesPesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    },
    'Maize Shoot Fly': {
      'imagePath': 'assets/pests/maize_shoot_fly_germination.jpg',
      'possibleStrategies': ['Early planting', 'Use traps', 'Resistant varieties'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Late planting', 'Warm weather'],
      'herbicidesPesticides': ['Decis (Deltamethrin)', 'Fastac (Cypermethrin)'],
    },
    'Rodents (Maize Germination)': {
      'imagePath': 'assets/pests/maize_rodents_germination.jpg',
      'possibleStrategies': ['Use traps', 'Protect seedlings', 'Remove hiding spots'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Seed availability', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Maize - Vegetative Growth/Weeding
    'Aphids (Maize Vegetative)': {
      'imagePath': 'assets/pests/maize_aphids_weeding.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Over-fertilization'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_vegetative_growth.jpg',
      'possibleStrategies': ['Destroy crop residue', 'Plant resistant hybrids', 'Use traps'],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': ['Crop residue buildup', 'Warm climates'],
      'herbicidesPesticides': ['Lorsban (Chlorpyrifos)', 'Dursban (Chlorpyrifos)'],
    },
    'Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_vegetative_growth.jpg',
      'possibleStrategies': ['Monitor fields', 'Remove weeds', 'Early intervention'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Dense vegetation'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Leafhoppers (Maize Vegetative)': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_vegetative_growth.jpg',
      'possibleStrategies': ['Control weeds', 'Use reflective mulches', 'Monitor populations'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm weather', 'Nearby host plants'],
      'herbicidesPesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_vegetative_growth.jpg',
      'possibleStrategies': ['Tillage', 'Encourage natural predators (birds)', 'Monitor fields'],
      'intervention': 'Insecticide (Malathion)',
      'possibleCauses': ['Dry weather', 'Overgrazed areas'],
      'herbicidesPesticides': ['Malathion 57 (Malathion)', 'Fyfanon (Malathion)'],
    },
    'Thrips (Maize Vegetative)': {
      'imagePath': 'assets/pests/maize_thrips_vegetative_growth.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Crop rotation'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Young plants'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Rodents (Maize Vegetative)': {
      'imagePath': 'assets/pests/maize_rodents_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Remove weeds', 'Secure field boundaries'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Dense vegetation', 'Food sources'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Maize - Flowering/Reproductive
    'Aphids (Maize Flowering)': {
      'imagePath': 'assets/pests/maize_aphids_flowering.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Avoid over-fertilization', 'Monitor tassels'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Flowering stage'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Stem Borers (Flowering)': {
      'imagePath': 'assets/pests/maize_stem_borer_flowering.jpg',
      'possibleStrategies': ['Destroy crop residue', 'Use pheromone traps', 'Resistant hybrids'],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': ['Warm climates', 'Flowering plants'],
      'herbicidesPesticides': ['Lorsban (Chlorpyrifos)', 'Dursban (Chlorpyrifos)'],
    },
    'Armyworms (Flowering)': {
      'imagePath': 'assets/pests/maize_armyworm_flowering.jpg',
      'possibleStrategies': ['Monitor tassels', 'Remove weeds', 'Apply early control'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Flowering maize'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Leafhoppers (Maize Flowering)': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_flowering.jpg',
      'possibleStrategies': ['Use reflective mulches', 'Control weeds', 'Monitor flowering'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm weather', 'Flowering stage'],
      'herbicidesPesticides': ['Confidor (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Grasshoppers (Flowering)': {
      'imagePath': 'assets/pests/maize_grass_hoppers_flowering.jpg',
      'possibleStrategies': ['Tillage', 'Use natural predators', 'Protect flowering plants'],
      'intervention': 'Insecticide (Malathion)',
      'possibleCauses': ['Dry weather', 'Flowering maize'],
      'herbicidesPesticides': ['Malathion 57 (Malathion)', 'Fyfanon (Malathion)'],
    },
    'Earworms': {
      'imagePath': 'assets/pests/maize_earworm_flowering.jpg',
      'possibleStrategies': ['Plant early', 'Use traps', 'Apply silk treatments'],
      'intervention': 'Insecticide (Carbaryl)',
      'possibleCauses': ['Warm temperatures', 'Flowering stage'],
      'herbicidesPesticides': ['Sevin (Carbaryl)', 'Adios (Carbaryl)'],
    },
    'Thrips (Maize Flowering)': {
      'imagePath': 'assets/pests/maize_thrips_flowering.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Monitor silks', 'Avoid dense planting'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Flowering maize'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Birds': {
      'imagePath': 'assets/pests/maize_birds_flowering.jpg',
      'possibleStrategies': ['Use netting', 'Install scare devices', 'Plant early'],
      'intervention': 'Physical control (None)',
      'possibleCauses': ['Ripening tassels', 'Lack of deterrents'],
      'herbicidesPesticides': ['None (Netting/Scarecrows)'],
    },

    // Maize - Maturation/Harvesting
    'Earworms (Maturation)': {
      'imagePath': 'assets/pests/maize_earworm_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use traps', 'Monitor ears'],
      'intervention': 'Insecticide (Carbaryl)',
      'possibleCauses': ['Warm temperatures', 'Mature ears'],
      'herbicidesPesticides': ['Sevin (Carbaryl)', 'Adios (Carbaryl)'],
    },
    'Weevils': {
      'imagePath': 'assets/pests/maize_weevil_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Dry grain', 'Clean fields'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Mature grain', 'Field residue'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Birds (Maturation)': {
      'imagePath': 'assets/pests/maize_birds_harvesting.jpg',
      'possibleStrategies': ['Use netting', 'Install scare devices', 'Harvest early'],
      'intervention': 'Physical control (None)',
      'possibleCauses': ['Ripening grain', 'Lack of deterrents'],
      'herbicidesPesticides': ['None (Netting/Scarecrows)'],
    },
    'Rodents (Maize Maturation)': {
      'imagePath': 'assets/pests/maize_rodents_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Mature grain', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Maize - Storage
    ' W': {
      'imagePath': 'assets/pests/maize_weevil_storage.jpg',
      'possibleStrategies': ['Dry grain storage', 'Clean silos', 'Use airtight containers'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['High moisture', 'Infested grain'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Larger Grain Borer': {
      'imagePath': 'assets/pests/maize_larger_grain_borer_storage.jpg',
      'possibleStrategies': ['Proper drying', 'Frequent inspection', 'Sanitize storage'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Warm storage', 'Infested grain'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Angoumois Grain Moth': {
      'imagePath': 'assets/pests/maize_angoumois_grain_moth_storage.jpg',
      'possibleStrategies': ['Seal storage', 'Reduce moisture', 'Clean bins'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Humid conditions', 'Unsealed grain'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Weevils (Storage)': {
      'imagePath': 'assets/pests/maize_weevil_storage.jpg',
      'possibleStrategies': ['Dry storage', 'Sanitation', 'Frequent checks'],
      'intervention': 'Fumigant (Phosphine)',
      'possibleCauses': ['Moist grain', 'Infested storage'],
      'herbicidesPesticides': ['Fumitoxin (Phosphine)', 'Phostoxin (Phosphine)'],
    },
    'Rodents (Maize Storage)': {
      'imagePath': 'assets/pests/maize_rodents_storage.jpg',
      'possibleStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Unprotected grain', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Cabbages/Kales - Germination/Seedling
    'Termites (Cabbages Germination)': {
      'imagePath': 'assets/pests/cabbage_kale_termites_germination.jpg',
      'possibleStrategies': ['Soil treatment', 'Use treated seeds', 'Remove debris'],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': ['Dry soil', 'Organic matter'],
      'herbicidesPesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    },
    'Cutworms (Cabbages Germination)': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_germination.jpg',
      'possibleStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
      'intervention': 'Insecticide (Lambda-cyhalothrin)',
      'possibleCauses': ['Moist soil', 'Weedy fields'],
      'herbicidesPesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    },
    'Cabbage Root Maggot': {
      'imagePath': 'assets/pests/cabbage_kale_root_maggots_germination.jpg',
      'possibleStrategies': ['Crop rotation', 'Use row covers', 'Avoid overwatering'],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': ['Cool, wet soil', 'Previous brassicas'],
      'herbicidesPesticides': ['Lorsban (Chlorpyrifos)', 'Dursban (Chlorpyrifos)'],
    },
    'Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_germination.jpg',
      'possibleStrategies': ['Use row covers', 'Crop rotation', 'Monitor seedlings'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, dry weather', 'Young plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Rodents (Cabbages Germination)': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Protect seedlings', 'Clear debris'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Seed availability', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Cabbages/Kales - Vegetative Growth/Weeding
    'Aphids (Cabbages Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_vegetative_growth.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Over-fertilization'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Cabbages Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Control humidity'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Dense foliage'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Cabbages Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_thrips_flowering.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Avoid dense planting'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Young leaves'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_vegetative_growth.jpg',
      'possibleStrategies': ['Use pheromone traps', 'Crop rotation', 'Monitor larvae'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm weather', 'Brassica crops'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_vegetative_growth.jpg',
      'possibleStrategies': ['Use row covers', 'Introduce Trichogramma', 'Monitor leaves'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Leafy crops'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Leafminers': {
      'imagePath': 'assets/pests/cabbage_kale_leafminers_harvesting.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Use yellow traps', 'Monitor plants'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Leafy crops'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Flea Beetles (Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_vegetative_growth.jpg',
      'possibleStrategies': ['Use row covers', 'Crop rotation', 'Control weeds'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, dry weather', 'Growing leaves'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_webworm_weeding.jpg',
      'possibleStrategies': ['Remove plant debris', 'Monitor seedlings', 'Early control'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Unclean fields'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Armyworms (Cabbages Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_vegetative_growth.jpg',
      'possibleStrategies': ['Monitor fields', 'Remove weeds', 'Apply early'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Dense foliage'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Cabbage Root Maggot (Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_root_maggots_vegetative_growth.jpg',
      'possibleStrategies': ['Use row covers', 'Crop rotation', 'Monitor roots'],
      'intervention': 'Insecticide (Chlorpyrifos)',
      'possibleCauses': ['Cool, wet soil', 'Growing plants'],
      'herbicidesPesticides': ['Lorsban (Chlorpyrifos)', 'Dursban (Chlorpyrifos)'],
    },
    'Rodents (Cabbages Vegetative)': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Dense vegetation', 'Food sources'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Cabbages/Kales - Flowering/Reproductive
    'Aphids (Cabbages Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_flowering.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Avoid over-fertilization', 'Monitor flowers'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Flowering stage'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Cabbages Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_flowering.jpg',
      'possibleStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Monitor flowering'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Flowering plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Cabbages Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_thrips_flowering.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Avoid dense planting', 'Monitor flowers'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Flowering stage'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Diamondback Moth (Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_flowering.jpg',
      'possibleStrategies': ['Use pheromone traps', 'Monitor larvae', 'Avoid brassica monoculture'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm weather', 'Flowering brassicas'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Cabbage Looper (Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_flowering.jpg',
      'possibleStrategies': ['Use row covers', 'Introduce Trichogramma', 'Monitor flowering'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Flowering stage'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Armyworms (Cabbages Flowering)': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_flowering.jpg',
      'possibleStrategies': ['Monitor flowers', 'Remove weeds', 'Early control'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Flowering plants'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Stink Bugs': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_flowering.jpg',
      'possibleStrategies': ['Remove weeds', 'Use traps', 'Monitor flowering'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Warm weather', 'Flowering crops'],
      'herbicidesPesticides': ['Fastac (Cypermethrin)', 'Decis (Deltamethrin)'],
    },

    // Cabbages/Kales - Maturation/Harvesting
    'Diamondback Moth (Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use pheromone traps', 'Monitor mature plants'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm weather', 'Mature brassicas'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Cabbage Looper (Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use row covers', 'Monitor leaves'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Mature plants'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Leafminers (Cabbages Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_leafminers_harvesting.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Use yellow traps', 'Harvest early'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Mature leaves'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Flea Beetles (Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use row covers', 'Control weeds'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, dry weather', 'Mature plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Gaucho (Imidacloprid)'],
    },
    'Cabbage Webworm (Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Remove debris', 'Monitor mature plants'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Unclean fields'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Armyworms (Cabbages Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Monitor mature plants', 'Remove weeds'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Mature foliage'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Stink Bugs (Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use traps', 'Remove weeds'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Warm weather', 'Mature crops'],
      'herbicidesPesticides': ['Fastac (Cypermethrin)', 'Decis (Deltamethrin)'],
    },
    'Rodents (Cabbages Maturation)': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Mature plants', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Cabbages/Kales - Storage
    'Rodents (Cabbages Storage)': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_storage.jpg',
      'possibleStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Unprotected storage', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },
    'Aphids (Cabbages Storage)': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_storage.jpg',
      'possibleStrategies': ['Inspect stored produce', 'Use cold storage', 'Sanitize storage'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm storage', 'Infested produce'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Cabbages Storage)': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_storage.jpg',
      'possibleStrategies': ['Use cold storage', 'Inspect produce', 'Sanitize storage'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid storage', 'Infested produce'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },

    // Carrots - Germination/Seedling
    'Termites (Carrots Germination)': {
      'imagePath': 'assets/pests/carrots_termites_germination.jpg',
      'possibleStrategies': ['Soil treatment', 'Use treated seeds', 'Remove debris'],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': ['Dry soil', 'Organic matter'],
      'herbicidesPesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    },
    'Cutworms (Carrots Germination)': {
      'imagePath': 'assets/pests/carrots_cutworm_germination.jpg',
      'possibleStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
      'intervention': 'Insecticide (Lambda-cyhalothrin)',
      'possibleCauses': ['Moist soil', 'Weedy fields'],
      'herbicidesPesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    },
    'Carrot Rust Fly': {
      'imagePath': 'assets/pests/carrots_carrot_rust_fly_germination.jpg',
      'possibleStrategies': ['Crop rotation', 'Use row covers', 'Monitor seedlings'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Cool, moist conditions', 'Carrot fields'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Nematodes': {
      'imagePath': 'assets/pests/carrots_nematodes_germination.jpg',
      'possibleStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Continuous cropping'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Wireworms': {
      'imagePath': 'assets/pests/carrots_wireworm_germination.jpg',
      'possibleStrategies': ['Crop rotation', 'Avoid grassy fields', 'Deep tillage'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Cool, moist soil', 'Previous grass crops'],
      'herbicidesPesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    },
    'Rodents (Carrots Germination)': {
      'imagePath': 'assets/pests/carrots_rodent_germination.jpg',
      'possibleStrategies': ['Use traps', 'Protect seedlings', 'Clear debris'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Seed availability', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Carrots - Vegetative Growth/Weeding
    'Aphids (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_aphids_vegetative_growth.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Over-fertilization'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Control humidity'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Dense foliage'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_thrips_vegetative_growth.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Avoid dense planting'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Young leaves'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Leaf Loopers': {
      'imagePath': 'assets/pests/carrots_leaf_loopers_vegetative_growth.jpg',
      'possibleStrategies': ['Use row covers', 'Introduce Trichogramma', 'Monitor leaves'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Leafy crops'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Leafminers (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_leafminers_vegetative_growth.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Use yellow traps', 'Monitor plants'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Leafy crops'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Carrot Rust Fly (Vegetative)': {
      'imagePath': 'assets/pests/carrots_carrot_rust_fly_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Use row covers', 'Monitor growing plants'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Cool, moist conditions', 'Growing carrots'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Nematodes (Vegetative)': {
      'imagePath': 'assets/pests/carrots_nematodes_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Soil solarization', 'Monitor roots'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Growing plants'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Wireworms (Vegetative)': {
      'imagePath': 'assets/pests/carrots_wireworm_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Avoid grassy fields', 'Monitor soil'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Cool, moist soil', 'Growing roots'],
      'herbicidesPesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    },
    'Armyworms (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_armyworm_vegetative_growth.jpg',
      'possibleStrategies': ['Monitor fields', 'Remove weeds', 'Apply early'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Dense foliage'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Rodents (Carrots Vegetative)': {
      'imagePath': 'assets/pests/carrots_rodent_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Dense vegetation', 'Food sources'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Carrots - Maturation/Harvesting
    'Aphids (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_aphids_harvesting.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Harvest early', 'Monitor mature plants'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Mature foliage'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_whiteflies_harvesting.jpg',
      'possibleStrategies': ['Use yellow traps', 'Harvest promptly', 'Control humidity'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Mature plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_thrips_harvesting.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Harvest early', 'Monitor mature plants'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Mature leaves'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Leaf Loopers (Maturation)': {
      'imagePath': 'assets/pests/carrots_leaf_looper_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use row covers', 'Monitor leaves'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Mature plants'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Leafminers (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_leafminers_harvesting.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Harvest early', 'Use yellow traps'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Mature leaves'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Carrot Rust Fly (Maturation)': {
      'imagePath': 'assets/pests/carrots_carrot_rust_fly_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use row covers', 'Monitor mature carrots'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Cool, moist conditions', 'Mature carrots'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Nematodes (Maturation)': {
      'imagePath': 'assets/pests/carrots_nematodes_harvesting.jpg',
      'possibleStrategies': ['Crop rotation', 'Harvest early', 'Monitor roots'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Mature roots'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Wireworms (Maturation)': {
      'imagePath': 'assets/pests/carrots_wireworm_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Crop rotation', 'Monitor soil'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Cool, moist soil', 'Mature roots'],
      'herbicidesPesticides': ['Gaucho (Imidacloprid)', 'Admire (Imidacloprid)'],
    },
    'Armyworms (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_armyworm_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Monitor mature plants', 'Remove weeds'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Rainy seasons', 'Mature foliage'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Rodents (Carrots Maturation)': {
      'imagePath': 'assets/pests/carrots_rodent_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Mature carrots', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Carrots - Storage
    'Carrot Rust Fly (Storage)': {
      'imagePath': 'assets/pests/carrots_carrot_rust_fly_storage.jpg',
      'possibleStrategies': ['Use cold storage', 'Inspect produce', 'Sanitize storage'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm storage', 'Infested carrots'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Nematodes (Storage)': {
      'imagePath': 'assets/pests/carrots_nematodes_storage.jpg',
      'possibleStrategies': ['Inspect stored carrots', 'Use clean storage', 'Avoid infested soil residue'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested carrots', 'Warm storage'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Rodents (Carrots Storage)': {
      'imagePath': 'assets/pests/carrots_rodent_storage.jpg',
      'possibleStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Unprotected storage', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },
    'Aphids (Carrots Storage)': {
      'imagePath': 'assets/pests/carrots_aphids_storage.jpg',
      'possibleStrategies': ['Use cold storage', 'Inspect produce', 'Sanitize storage'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm storage', 'Infested produce'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },

    // Tomatoes - Germination/Seedling
    'Termites (Tomatoes Germination)': {
      'imagePath': 'assets/pests/tomatoes_termites_germination.jpg',
      'possibleStrategies': ['Soil treatment', 'Use treated seeds', 'Remove debris'],
      'intervention': 'Insecticide (Fipronil)',
      'possibleCauses': ['Dry soil', 'Organic matter'],
      'herbicidesPesticides': ['Termidor (Fipronil)', 'Premise (Imidacloprid)'],
    },
    'Cutworms (Tomatoes Germination)': {
      'imagePath': 'assets/pests/tomatoes_cutworm_germination.jpg',
      'possibleStrategies': ['Plow fields', 'Use collars', 'Remove weeds'],
      'intervention': 'Insecticide (Lambda-cyhalothrin)',
      'possibleCauses': ['Moist soil', 'Weedy fields'],
      'herbicidesPesticides': ['Karate (Lambda-cyhalothrin)', 'Sevin (Carbaryl)'],
    },
    'Nematodes (Tomatoes Germination)': {
      'imagePath': 'assets/pests/tomatoes_nematodes_germination.jpg',
      'possibleStrategies': ['Crop rotation', 'Soil solarization', 'Use resistant varieties'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Continuous cropping'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Rodents (Tomatoes Germination)': {
      'imagePath': 'assets/pests/tomatoes_rodents_germination.jpg',
      'possibleStrategies': ['Use traps', 'Protect seedlings', 'Clear debris'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Seed availability', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Tomatoes - Vegetative Growth/Weeding
    'Aphids (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_aphids_vegetative_growth.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Use reflective mulches', 'Monitor leaves'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Over-fertilization'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_vegetative_growth.jpg',
      'possibleStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Control humidity'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Dense foliage'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_thrips_vegetative_growth.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Maintain plant health', 'Avoid dense planting'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Young leaves'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Leafminers (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_leafminers_vegetative_growth.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Use yellow traps', 'Monitor plants'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Leafy crops'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Nematodes (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_nematodes_vegetative_growth.jpg',
      'possibleStrategies': ['Crop rotation', 'Soil solarization', 'Monitor roots'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Growing plants'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_vegetative_growth.jpg',
      'possibleStrategies': ['Hand-picking', 'Introduce parasitic wasps', 'Monitor leaves'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Tomato crops'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Beet Armyworms': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_vegetative_growth.jpg',
      'possibleStrategies': ['Monitor fields', 'Remove crop residues', 'Early control'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Dense vegetation'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg',
      'possibleStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor leaves'],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': ['Dry conditions', 'Dusty fields'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Rodents (Tomatoes Vegetative)': {
      'imagePath': 'assets/pests/tomatoes_rodents_vegetative_growth.jpg',
      'possibleStrategies': ['Use traps', 'Remove weeds', 'Secure field edges'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Dense vegetation', 'Food sources'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Tomatoes - Flowering/Reproductive
    'Aphids (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_aphids_flowering.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Avoid over-fertilization', 'Monitor flowers'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Flowering stage'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_flowering.jpg',
      'possibleStrategies': ['Use yellow traps', 'Introduce Encarsia', 'Monitor flowering'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Flowering plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_thrips_flowering.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Avoid dense planting', 'Monitor flowers'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Flowering stage'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Leafminers (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_leafminers_flowering.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Use yellow traps', 'Monitor flowering'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Flowering plants'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Nematodes (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_nematodes_flowering.jpg',
      'possibleStrategies': ['Crop rotation', 'Monitor roots', 'Avoid infested soil'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Flowering plants'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Bollworm': {
      'imagePath': 'assets/pests/tomatoes_bollworm_flowering.jpg',
      'possibleStrategies': ['Use pheromone traps', 'Remove affected fruits', 'Monitor flowering'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Flowering stage'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Hornworms (Flowering)': {
      'imagePath': 'assets/pests/tomatoes_hornworm_flowering.jpg',
      'possibleStrategies': ['Hand-picking', 'Introduce parasitic wasps', 'Monitor flowers'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Flowering tomatoes'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Beet Armyworms (Flowering)': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_flowering.jpg',
      'possibleStrategies': ['Monitor flowering', 'Remove residues', 'Early control'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Flowering plants'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Stink Bugs (Tomatoes Flowering)': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_flowering.jpg',
      'possibleStrategies': ['Remove weeds', 'Use traps', 'Monitor flowering'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Warm weather', 'Flowering crops'],
      'herbicidesPesticides': ['Fastac (Cypermethrin)', 'Decis (Deltamethrin)'],
    },
    'Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_flowering.jpg',
      'possibleStrategies': ['Remove infested fruits', 'Use traps', 'Monitor flowering'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Flowering to fruiting'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Spider Mites (Flowering)': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_flowering.jpg',
      'possibleStrategies': ['Increase humidity', 'Use predatory mites', 'Monitor flowers'],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': ['Dry conditions', 'Flowering plants'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },

    // Tomatoes - Maturation/Harvesting
    'Aphids (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_aphids_harvesting.jpg',
      'possibleStrategies': ['Introduce ladybugs', 'Harvest early', 'Monitor mature plants'],
      'intervention': 'Insecticide (Neem Oil)',
      'possibleCauses': ['Warm weather', 'Mature foliage'],
      'herbicidesPesticides': ['Azadirachtin (Neem Oil)', 'Admire (Imidacloprid)'],
    },
    'Whiteflies (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_harvesting.jpg',
      'possibleStrategies': ['Use yellow traps', 'Harvest promptly', 'Control humidity'],
      'intervention': 'Insecticide (Imidacloprid)',
      'possibleCauses': ['Warm, humid weather', 'Mature plants'],
      'herbicidesPesticides': ['Admire (Imidacloprid)', 'Confidor (Imidacloprid)'],
    },
    'Thrips (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_thrips_harvesting.jpg',
      'possibleStrategies': ['Use blue sticky traps', 'Harvest early', 'Monitor fruits'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Dry conditions', 'Mature fruits'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Radiant (Spinosad)'],
    },
    'Leafminers (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_leafminers_harvesting.jpg',
      'possibleStrategies': ['Remove affected leaves', 'Harvest early', 'Use yellow traps'],
      'intervention': 'Insecticide (Abamectin)',
      'possibleCauses': ['Warm weather', 'Mature leaves'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Nematodes (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_nematodes_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Crop rotation', 'Monitor roots'],
      'intervention': 'Nematicide (Oxamyl)',
      'possibleCauses': ['Infested soil', 'Mature plants'],
      'herbicidesPesticides': ['Vydate (Oxamyl)', 'Nemacur (Fenamiphos)'],
    },
    'Bollworm (Maturation)': {
      'imagePath': 'assets/pests/tomatoes_bollworm_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Remove affected fruits', 'Use traps'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Mature fruits'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Hornworms (Maturation)': {
      'imagePath': 'assets/pests/tomatoes_hornworm_harvesting.jpg',
      'possibleStrategies': ['Hand-picking', 'Harvest promptly', 'Monitor mature plants'],
      'intervention': 'Insecticide (Bacillus thuringiensis)',
      'possibleCauses': ['Warm nights', 'Mature tomatoes'],
      'herbicidesPesticides': ['Dipel (Bt)', 'Thuricide (Bt)'],
    },
    'Beet Armyworms (Maturation)': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Remove residues', 'Monitor mature plants'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Mature plants'],
      'herbicidesPesticides': ['Tracer (Spinosad)', 'Success (Spinosad)'],
    },
    'Fruitflies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_harvesting.jpg',
      'possibleStrategies': ['Sanitation', 'Use bait traps', 'Harvest early'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Overripe fruit', 'Warm weather'],
      'herbicidesPesticides': ['GF-120 (Spinosad)', 'Entrust (Spinosad)'],
    },
    'Stink Bugs (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Use traps', 'Remove weeds'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Warm weather', 'Mature fruits'],
      'herbicidesPesticides': ['Fastac (Cypermethrin)', 'Decis (Deltamethrin)'],
    },
    'Fruit Borers (Maturation)': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_harvesting.jpg',
      'possibleStrategies': ['Harvest early', 'Remove infested fruits', 'Use traps'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm weather', 'Mature fruits'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Spider Mites (Maturation)': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_harvesting.jpg',
      'possibleStrategies': ['Increase humidity', 'Harvest early', 'Use predatory mites'],
      'intervention': 'Miticide (Abamectin)',
      'possibleCauses': ['Dry conditions', 'Mature plants'],
      'herbicidesPesticides': ['Agri-Mek (Abamectin)', 'Avid (Abamectin)'],
    },
    'Rodents (Tomatoes Maturation)': {
      'imagePath': 'assets/pests/tomatoes_rodents_harvesting.jpg',
      'possibleStrategies': ['Harvest promptly', 'Use traps', 'Secure fields'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Mature fruits', 'Unprotected fields'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },

    // Tomatoes - Storage
    'Fruitflies (Storage)': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_storage.jpg',
      'possibleStrategies': ['Use cold storage', 'Sanitation', 'Inspect produce'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm storage', 'Overripe tomatoes'],
      'herbicidesPesticides': ['GF-120 (Spinosad)', 'Entrust (Spinosad)'],
    },
    'Stink Bugs (Tomatoes Storage)': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_storage.jpg',
      'possibleStrategies': ['Inspect stored tomatoes', 'Use cold storage', 'Sanitize storage'],
      'intervention': 'Insecticide (Cypermethrin)',
      'possibleCauses': ['Warm storage', 'Infested produce'],
      'herbicidesPesticides': ['Fastac (Cypermethrin)', 'Decis (Deltamethrin)'],
    },
    'Fruit Borers (Storage)': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_storage.jpg',
      'possibleStrategies': ['Use cold storage', 'Remove infested fruits', 'Sanitize storage'],
      'intervention': 'Insecticide (Spinosad)',
      'possibleCauses': ['Warm storage', 'Infested tomatoes'],
      'herbicidesPesticides': ['Entrust (Spinosad)', 'Success (Spinosad)'],
    },
    'Rodents (Tomatoes Storage)': {
      'imagePath': 'assets/pests/tomatoes_rodents_storage.jpg',
      'possibleStrategies': ['Use rodent-proof containers', 'Set traps', 'Clean storage'],
      'intervention': 'Rodenticide (Bromadiolone)',
      'possibleCauses': ['Unprotected storage', 'Food availability'],
      'herbicidesPesticides': ['Ratoxin (Bromadiolone)', 'Tomcat (Bromadiolone)'],
    },
  };

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

  void _updatePestDetails() {
    if (_selectedPest != null && _selectedStage != null && _pestDetails.containsKey(_selectedPest!)) {
      String pestKey = _selectedPest!;
      // Handle repeated pests by appending stage if it exists in multiple stages
      if (_pestDetails.containsKey('$_selectedPest ($_selectedStage)')) {
        pestKey = '$_selectedPest ($_selectedStage)';
      }

      setState(() {
        _pestData = PestData(
          name: _selectedPest!,
          imagePath: _pestDetails[pestKey]!['imagePath'], // Fetch imagePath directly from _pestDetails
          preventionStrategies: _pestDetails[pestKey]!['possibleStrategies'],
          activeAgent: _pestDetails[pestKey]!['intervention'].split('(')[1].replaceAll(')', ''),
          possibleCauses: _pestDetails[pestKey]!['possibleCauses'],
          herbicides: _pestDetails[pestKey]!['herbicidesPesticides'],
        );
      });
    }
  }

  void _scrollToHints() {
    if (_showPestDetails && _hintsKey.currentContext != null) {
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
        title: const Text('Pest Management', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              _buildDropdown('Crop Type', _crops, _selectedCrop, (val) {
                setState(() {
                  _selectedCrop = val;
                  _selectedStage = null;
                  _selectedPest = null;
                  _pestData = null;
                  _showPestDetails = false;
                });
              }),
              const SizedBox(height: 16),
              _buildDropdown('Crop Stage', _selectedCrop != null ? _cropStages[_selectedCrop]! : [], _selectedStage, (val) {
                setState(() {
                  _selectedStage = val;
                  _selectedPest = null;
                  _pestData = null;
                  _showPestDetails = false;
                });
              }),
              const SizedBox(height: 16),
              _buildDropdown('Select Pest', _selectedCrop != null && _selectedStage != null ? _cropStagePests[_selectedCrop]![_selectedStage]! : [], _selectedPest, (val) {
                setState(() {
                  _selectedPest = val;
                  _updatePestDetails();
                  _showPestDetails = false;
                });
              }),
              if (_pestData != null) ...[
                const SizedBox(height: 16),
                _buildImageCard(_pestData!.imagePath),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (_pestData != null) {
                    setState(() {
                      _showPestDetails = !_showPestDetails;
                      if (_showPestDetails) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHints());
                      }
                    });
                  } else {
                    scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please select a pest first')));
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
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserPestHistoryPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 3, 39, 4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('View My Pest History'),
              ),
              if (_showPestDetails && _pestData != null) ...[
                const SizedBox(height: 8),
                Column(
                  key: _hintsKey,
                  children: [
                    _buildHintCard('Prevention Strategies', _pestData!.preventionStrategies.join('\n')),
                    _buildHintCard('Possible Intervention(Active Ingredient)', 'Chemical control with ${_pestData!.activeAgent}'),
                    _buildHintCard('Possible Causes', _pestData!.possibleCauses.join('\n')),
                    _buildHintCard('Herbicides/Pesticides', _pestData!.herbicides.join('\n')),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InterventionPage(
                                pestData: _pestData!,
                                cropType: _selectedCrop!,
                                cropStage: _selectedStage ?? '',
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
                        child: const Text('Manage Pest'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, ValueChanged<String?> onChanged) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
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
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 150),
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

  Widget _buildHintCard(String title, String content) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(content, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}