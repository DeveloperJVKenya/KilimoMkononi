// lib/education/pest/pest_data_input.dart - PHASE 3 (AI-enhanced
// ignore_for_file: dead_code, no_leading_underscores_for_local_identifiers, unused_local_variable, use_build_context_synchronously, body_might_complete_normally_catch_error, unused_element, deprecated_member_use, avoid_print, unnecessary_underscores

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/data/pest_interventions.dart';
import 'package:kilimomkononi/education/pest/edu_photo_diagnosis_button.dart';
import 'package:kilimomkononi/education/tutor/tutor_suppressor.dart';
import 'package:kilimomkononi/services/plot_analysis_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kilimomkononi/widgets/plot_history_card.dart';

const Color primaryGreen = Color(0xFF388E3C);

// ─── AI helper — Gemini via Firebase Function ────────────────────────────────
const String _kGeminiUrl =
    'https://us-central1-kilimomkononi-e1031.cloudfunctions.net/askGemini';

/// Merges system context + user message into a single prompt for Gemini.
Future<String> _callGemini(String systemPrompt, String userMessage) async {
  try {
    final combinedPrompt = '$systemPrompt\n\n$userMessage';
    final response = await http.post(
      Uri.parse(_kGeminiUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'prompt': combinedPrompt}),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return (data['text'] ??
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              'Sorry, I could not generate a response at this time.')
          .toString()
          .trim();
    }
    return 'AI service error (${response.statusCode}). Please try again.';
  } catch (e) {
    return 'Could not reach AI service: $e';
  }
}
// ─────────────────────────────────────────────────────────────────────────────

final List<String> crops = ['Beans', 'Maize', 'Cabbages/Kales', 'Carrots', 'Tomatoes', 'Onions'];

final Map<String, List<String>> cropStages = {
  'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
  'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
};

final Map<String, Map<String, List<String>>> cropStagePests = {
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
    'Germination/Seedling': ['Termites', 'Cutworms', 'Root Maggots', 'Flea Beetles'],
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
    'Storage': ['Fruit Flies', 'Fruit Borers', 'Stink Bugs', 'Rodents'],
  },
  'Onions': {
    'Germination/Seedling': ['Aphids', 'Thrips'],
    'Vegetative Growth/Weeding': ['Thrips', 'Aphids'],
    'Bulb Formation/Reproductive': ['Bulb Fly', 'Maggots'],
    'Bulbing/Maturation': ['Maggots', 'Thrips', 'Bulb Fly'],
    'Harvesting/Storage': ['Maggots', 'Rodents', 'Bulb Fly'],
  },
};

final Map<String, Map<String, dynamic>> pestDetails = {
  'Beans_Germination/Seedling_Bean Fly': {'imagePath': 'assets/pests/beans_bean_fly_germination.jpg'},
  'Beans_Germination/Seedling_Cutworms': {'imagePath': 'assets/pests/beans_cutworms_germination.jpg'},
  'Beans_Germination/Seedling_Rodents': {'imagePath': 'assets/pests/beans_rodents_germination.jpg'},
  'Beans_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/beans_termites_germination.jpg'},
   'Beans_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_vegetative_growth.jpg'},
     'Beans_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_vegetative_growth.jpg'},
   'Beans_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/beans_aphids_flowering.jpg'},
    'Beans_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/beans_leaf_hoppers_flowering.jpg'},
      'Beans_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/beans_thrips_flowering.jpg'},
    'Beans_Flowering/Reproductive_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borer_flowering.jpg'},
    'Beans_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/beans_whiteflies_flowering.jpg'},
     'Beans_Maturation/Harvesting_Pod Borers': {
      'imagePath': 'assets/pests/beans_pod_borers_harvesting.jpg'},
      'Beans_Maturation/Harvesting_Beetles': {
      'imagePath': 'assets/pests/beans_beetles_harvesting.jpg'},
     'Beans_Maturation/Harvesting_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_harvesting.jpg'},
     'Beans_Maturation/Harvesting_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_harvesting.jpg'},
      'Beans_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_harvesting.jpg'},
      'Beans_Storage_Bean Weevil': {
      'imagePath': 'assets/pests/beans_bean_weevil_storage.jpg'},
      'Beans_Storage_Bruchid Beetles': {
      'imagePath': 'assets/pests/beans_bruchid_beetle_storage.jpg'},
       'Beans_Storage_Rodents': {
      'imagePath': 'assets/pests/beans_rodents_storage.jpg'},
      'Maize_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/maize_termites_germination.jpg'},
       'Maize_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/maize_cutworm_germination.jpg'},
      'Maize_Germination/Seedling_Maize Shoot Fly': {
      'imagePath': 'assets/pests/maize_shoot_fly_germination.jpg'},
       'Maize_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_germination.jpg'},
      'Maize_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/maize_leaf_aphids_vegetative_growth.jpg'},
      'Maize_Vegetative Growth/Weeding_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_vegetative_growth.jpg'},
      'Maize_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_vegetative_growth.jpg'},
      'Maize_Vegetative Growth/Weeding_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_vegetative_growth.jpg'},
       'Maize_Vegetative Growth/Weeding_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_vegetative_growth.jpg'},
      'Maize_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_vegetative_growth.jpg'},
      'Maize_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_vegetative_growth.jpg'},
      'Maize_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/maize_aphids_flowering.jpg'},
      'Maize_Flowering/Reproductive_Stem Borers': {
      'imagePath': 'assets/pests/maize_stem_borer_flowering.jpg'},
      'Maize_Flowering/Reproductive_Armyworms': {
      'imagePath': 'assets/pests/maize_armyworm_flowering.jpg'},
       'Maize_Flowering/Reproductive_Leafhoppers': {
      'imagePath': 'assets/pests/maize_leaf_hoppers_flowering.jpg'},
       'Maize_Flowering/Reproductive_Grasshoppers': {
      'imagePath': 'assets/pests/maize_grass_hoppers_flowering.jpg'},
       'Maize_Flowering/Reproductive_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_flowering.jpg'},
      'Maize_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/maize_thrips_flowering.jpg'},
      'Maize_Flowering/Reproductive_Birds': {
      'imagePath': 'assets/pests/maize_birds_flowering.jpg'},
      'Maize_Maturation/Harvesting_Earworms': {
      'imagePath': 'assets/pests/maize_earworm_harvesting.jpg'},
      'Maize_Maturation/Harvesting_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_harvesting.jpg'},
      'Maize_Maturation/Harvesting_Birds': {
      'imagePath': 'assets/pests/maize_birds_harvesting.jpg'},
     'Maize_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_harvesting.jpg'},
      'Maize_Storage_Larger Grain Borer': {
      'imagePath': 'assets/pests/maize_larger_grain_borer_storage.jpg'},
      'Maize_Storage_Angoumois Grain Moth': {
      'imagePath': 'assets/pests/maize_angoumois_grain_moth_storage.jpg'},
      'Maize_Storage_Weevils': {
      'imagePath': 'assets/pests/maize_weevil_storage.jpg'},
      'Maize_Storage_Rodents': {
      'imagePath': 'assets/pests/maize_rodents_storage.jpg'},
      'Cabbages/Kales_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_germination.jpg'},
       'Cabbages/Kales_Germination/Seedling_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_germination.jpg'},
       'Cabbages/Kales_Germination/Seedling_Root Maggots': {
      'imagePath': 'assets/pests/cabbage_kale_root_maggots_germination.jpg'},
      'Cabbages/Kales_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/cabbage_kale_termites_germination.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_vegetative_growth.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_vegetative_growth.jpg'},
       'Cabbages/Kales_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_vegetative_growth.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Flea Beetles': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_vegetative_growth.jpg'},
       'Cabbages/Kales_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_vegetative_growth.jpg'},
       'Cabbages/Kales_Vegetative Growth/Weeding_Armyworms': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_vegetative_growth.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Cross Stripped Cabbageworm': {
      'imagePath': 'assets/pests/cabbage_kale_cross_stripped_cabbageworm_vegetative_growth.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_vegetative_growth.jpg'},
       'Cabbages/Kales_Vegetative Growth/Weeding_Cutworms': {
      'imagePath': 'assets/pests/cabbage_kale_cutworms_vegetative_growth.jpg'},
      'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_vegetative_growth.jpg'},
       'Cabbages/Kales_Vegetative Growth/Weeding_Cabbage Root Maggot': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_root_maggots_vegetative_growth.jpg'},
      'Cabbages/Kales_Flowering/Reproductive_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_flowering.jpg'},
       'Cabbages/Kales_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_flowering.jpg'},
       'Cabbages/Kales_Flowering/Reproductive_Thrip': {
      'imagePath': 'assets/pests/cabbage_kale_thrips_flowering.jpg'},
       'Cabbages/Kales_Flowering/Reproductive_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_flowering.jpg'},
      'Cabbages/Kales_Flowering/Reproductive_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_flowering.jpg'},
       'Cabbages/Kales_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_flowering.jpg'},
      'Cabbages/Kales_Flowering/Reproductive_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_flowering.jpg'},
      'Cabbages/Kales_Maturation/Harvesting_Cabbage Webworm': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_webworm_harvesting.jpg'},
      'Cabbages/Kales_Maturation/Harvesting_Diamondback Moth': {
      'imagePath': 'assets/pests/cabbage_kale_diamondback_moth_harvesting.jpg'},
       'Cabbages/Kales_Maturation/Harvesting_Rodent': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_harvesting.jpg'},
       'Cabbages/Kales_Maturation/Harvesting_Flea Beetle': {
      'imagePath': 'assets/pests/cabbage_kale_flea_beetle_harvesting.jpg'},
       'Cabbages/Kales_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/cabbage_kale_leafminers_harvesting.jpg'},
      'Cabbages/Kales_Maturation/Harvesting_Cabbage Looper': {
      'imagePath': 'assets/pests/cabbage_kale_cabbage_looper_harvesting.jpg'},
       'Cabbages/Kales_Maturation/Harvesting_Armyworm': {
      'imagePath': 'assets/pests/cabbage_kale_armyworm_harvesting.jpg'},
       'Cabbages/Kales_Maturation/Harvesting_Stink Bug': {
      'imagePath': 'assets/pests/cabbage_kale_stink_bug_harvesting.jpg'},
      'Cabbages/Kales_Storage_Rodents': {
      'imagePath': 'assets/pests/cabbage_kale_rodents_storage.jpg'},
      'Cabbages/Kales_Storage_Whiteflies': {
      'imagePath': 'assets/pests/cabbage_kale_whiteflies_storage.jpg'},
      'Cabbages/Kales_Storage_Aphids': {
      'imagePath': 'assets/pests/cabbage_kale_aphids_storage.jpg'},
      'Tomatoes_Germination/Seedling_Cutworms': {
      'imagePath': 'assets/pests/tomatoes_cutworm_germination.jpg'},
      'Tomatoes_Germination/Seedling_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_germination.jpg'},
      'Tomatoes_Germination/Seedling_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_germination.jpg'},
      'Tomatoes_Germination/Seedling_Termites': {
      'imagePath': 'assets/pests/tomatoes_termites_germination.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_vegetative_growth.jpg'},
        'Tomatoes_Vegetative Growth/Weeding_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg'},
       'Tomatoes_Vegetative Growth/Weeding_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Spidermites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_vegetative_growth.jpg'},
       'Tomatoes_Flowering/Reproductive_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_flowering.jpg'},
       'Tomatoes_Flowering/Reproductive_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_flowering.jpg'},
       'Tomatoes_Flowering/Reproductive_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_flowering.jpg'},
      'Tomatoes_Maturation/Harvesting_Aphids': {
      'imagePath': 'assets/pests/tomatoes_aphids_harvesting.jpg'},
       'Tomatoes_Maturation/Harvesting_Whiteflies': {
      'imagePath': 'assets/pests/tomatoes_whiteflies_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Spider Mites': {
      'imagePath': 'assets/pests/tomatoes_spider_mites_harvesting.jpg'},
       'Tomatoes_Maturation/Harvesting_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Thrips': {
      'imagePath': 'assets/pests/tomatoes_thrips_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Leafminers': {
      'imagePath': 'assets/pests/tomatoes_leafminers_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Beet Armyworm': {
      'imagePath': 'assets/pests/tomatoes_beet_armyworm_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Nematodes': {
      'imagePath': 'assets/pests/tomatoes_nematodes_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Bollworms': {
      'imagePath': 'assets/pests/tomatoes_bollworm_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Fruitflies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Tomato Hornworms': {
      'imagePath': 'assets/pests/tomatoes_hornworm_harvesting.jpg'},
      'Tomatoes_Storage_Rodents': {
      'imagePath': 'assets/pests/tomatoes_rodents_storage.jpg'},
      'Tomatoes_Storage_Fruit Flies': {
      'imagePath': 'assets/pests/tomatoes_fruitflies_storage.jpg'},
      'Tomatoes_Storage_Fruit Borers': {
      'imagePath': 'assets/pests/tomatoes_fruit_borers_storage.jpg'},
      'Tomatoes_Storage_Stink Bugs': {
      'imagePath': 'assets/pests/tomatoes_stink_bugs_storage.jpg'},
      'Carrots_Germination/Seedling_Termites': {
    'imagePath': 'assets/pests/carrots_termites_germination.jpg'},
    'Carrots_Germination/Seedling_Cutworms': {
    'imagePath': 'assets/pests/carrots_cutworm_germination.jpg',},
    'Carrots_Germination/Seedling_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_germination.jpg'},
    'Carrots_Germination/Seedling_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_germination.jpg'},
    'Carrots_Germination/Seedling_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_germination.jpg'},
    'Carrots_Germination/Seedling_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_germination.jpg'},
    'Carrots_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Whiteflies': {
    'imagePath': 'assets/pests/carrots_whiteflies_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_loopers_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Leafminers': {
    'imagePath': 'assets/pests/carrots_leafminers_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_vegetative_growth.jpg'},
    'Carrots_Maturation/Harvesting_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Wireworms': {
    'imagePath': 'assets/pests/carrots_wireworm_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_harvesting.jpg'},
   'Carrots_Maturation/Harvesting_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Armyworms': {
    'imagePath': 'assets/pests/carrots_armyworm_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Thrips': {
    'imagePath': 'assets/pests/carrots_thrips_harvesting.jpg'},
      'Carrots_Maturation/Harvesting_Leaf Loopers': {
    'imagePath': 'assets/pests/carrots_leaf_looper_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_White Flies': {
    'imagePath': 'assets/pests/carrots_whiteflies_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Leaf Miners': {
    'imagePath': 'assets/pests/carrots_leafminers_harvesting.jpg'},
    'Carrots_Storage_Rodents': {
    'imagePath': 'assets/pests/carrots_rodent_storage.jpg'},
     'Carrots_Storage_Aphids': {
    'imagePath': 'assets/pests/carrots_aphids_storage.jpg'},
    'Carrots_Storage_Nematodes': {
    'imagePath': 'assets/pests/carrots_nematodes_storage.jpg'},
    'Carrots_Storage_Carrot Rust Fly': {
    'imagePath': 'assets/pests/carrots_carrot_rust_fly_storage.jpg'},
    'Onions_Germination/Seedling_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_germination.jpg'},
    'Onions_Germination/Seedling_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_germination.jpg'},
    'Onions_Vegetative Growth/Weeding_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_vegetative_growth.jpg'},
    'Onions_Vegetative Growth/Weeding_Aphids': {
    'imagePath': 'assets/pests/onions_aphids_vegetative_growth.jpg'},
    'Onions_Bulb Formation/Reproductive_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulb_formation.jpg'},
    'Onions_Bulb Formation/Reproductive_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulb_formation.jpg'},
   'Onions_Bulbing/Maturation_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_bulbing.jpg'},
    'Onions_Bulbing/Maturation_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_bulbing.jpg'},
     'Onions_Bulbing/Maturation_Thrips': {
    'imagePath': 'assets/pests/onions_thrips_bulbing.jpg'},
    'Onions_Harvesting/Storage_Maggots': {
    'imagePath': 'assets/pests/onions_maggots_harvesting.jpg'},
    'Onions_Harvesting/Storage_Rodents': {
    'imagePath': 'assets/pests/onions_rodents_harvesting.jpg'},
    'Onions_Harvesting/Storage_Bulb Fly': {
    'imagePath': 'assets/pests/onions_bulbfly_harvesting.jpg'},
  };

class PestDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const PestDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<PestDataInput> createState() => _PestDataInputState();
}

class _PestDataInputState extends State<PestDataInput>
    with TutorSuppressorMixin {
  final _formKey = GlobalKey<FormState>();
  final _submissionFormKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _aiLoading = false;
  final _scrollCtrl = ScrollController();

  PlotAnalysisResult? _previousAnalysis;

  // For observations (teachers)
  final _interventionCtrl = TextEditingController();

  // For student submissions
  final _studentNameCtrl = TextEditingController();
  final _studentAnswerCtrl = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedPest;
  String? _editingId;

  late bool isTeacher;
  late bool isStudent;

  @override
  void initState() {
    super.initState();
    isTeacher = widget.role == EduRole.teacher;
    isStudent  = widget.role == EduRole.student;
    if (widget.prefillData != null) {
      _selectedCrop  = widget.prefillData!['crop'];
      _selectedStage = widget.prefillData!['stage'];
      _selectedPest  = widget.prefillData!['name'];
    }
    // Rebuild when student types their name so submission list appears immediately
    _studentNameCtrl.addListener(() => setState(() {}));
    _loadPreviousAnalysis();
  }

  Future<void> _loadPreviousAnalysis() async {
    final parts = widget.classId.split('_');
    if (parts.length < 2) return;
    final school = parts[0];
    final system = parts[1];
    final grade  = parts.length > 2 ? parts.sublist(2).join('_') : parts.last;
    final year   = DateTime.now().year.toString();
    try {
      final snap = await FirebaseFirestore.instance
          .collection('schools').doc(school)
          .collection('systems').doc(system)
          .collection('grades').doc(grade)
          .collection('plot_analyses').doc(year)
          .get();
      if (snap.exists && mounted) {
        setState(() => _previousAnalysis =
            PlotAnalysisResult.fromMap(snap.data() as Map<String, dynamic>));
      }
    } catch (_) {}
  }


  // ═══════════════════════════════════════════════════════════
  // GRADE HELPER METHODS - For student view badges
  // ═══════════════════════════════════════════════════════════
  
  Color _getGradeColor(String? grade) {
    switch (grade) {
      case 'correct':
        return Colors.green.shade600;
      case 'needsWork':
        return Colors.orange.shade600;
      case 'incorrect':
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
  
  IconData _getGradeIcon(String? grade) {
    switch (grade) {
      case 'correct':
        return Icons.check_circle;
      case 'needsWork':
        return Icons.warning;
      case 'incorrect':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
  
  String _getGradeLabel(String? grade) {
    switch (grade) {
      case 'correct':
        return 'Correct!';
      case 'needsWork':
        return 'Needs Improvement';
      case 'incorrect':
        return 'Incorrect';
      default:
        return 'Reviewed';
    }
  }

  // Normalise crop name to match pestInterventions map keys.
  // The UI uses 'Cabbages/Kales' but the data file uses 'Cabbage'.
  String _cropKey(String? crop) {
    if (crop == null) return '';
    if (crop == 'Cabbages/Kales') return 'Cabbage';
    return crop;
  }

  @override
  void dispose() {
    _interventionCtrl.dispose();
    _studentNameCtrl.dispose();
    _studentAnswerCtrl.dispose();
    super.dispose();
  }

  CollectionReference? get _collection {
    if (widget.classId.isEmpty) return null;
    return FirestoreHelper.getContentFromClassId(widget.classId, 'pest_data');
  }

  CollectionReference? get _submissionsCollection {
    if (widget.classId.isEmpty) return null;
    return FirestoreHelper.getContentFromClassId(widget.classId, 'pest_submissions');
  }

  bool get _isHeadteacher => widget.role == EduRole.headteacher;
  bool get _canEdit => !_isHeadteacher && _collection != null;

  Future<void> _saveEntry() async {
    if (!_canEdit || !_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final data = {
      'cropType': _selectedCrop,
      'cropStage': _selectedStage,
      'pestName': _selectedPest,
      'intervention': _interventionCtrl.text.trim().isEmpty ? null : _interventionCtrl.text.trim(),
      'schoolName': widget.schoolName,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      if (_editingId == null) {
        await _collection!.add(data);
      } else {
        await _collection!.doc(_editingId).update(data);
      }
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editingId == null ? 'Pest observation saved!' : 'Entry updated!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _submitStudentAnswer() async {
    if (!_submissionFormKey.currentState!.validate()) return;
    if (_submissionsCollection == null) return;

    setState(() => _isSaving = true);

    final submissionData = {
      'studentName': _studentNameCtrl.text.trim(),
      'crop': _selectedCrop,
      'stage': _selectedStage,
      'pest': _selectedPest,
      'studentAnswer': _studentAnswerCtrl.text.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'isUnlocked': false,
      'schoolName': widget.schoolName,
    };

    // Show snackbar and clear form IMMEDIATELY — don't wait for Firestore round-trip
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Your answer has been submitted! Teacher will review it.'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
    // Only clear the answer — keep the name so My Submissions stays visible
    _studentAnswerCtrl.clear();
    setState(() => _isSaving = false);

    // Write to Firestore in the background
    _submissionsCollection!.add(submissionData).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _editEntry(String id, Map<String, dynamic> data) {
    if (!_canEdit) return;
    setState(() {
      _editingId = id;
      _selectedCrop = data['cropType'];
      _selectedStage = data['cropStage'];
      _selectedPest = data['pestName'];
      _interventionCtrl.text = data['intervention'] ?? '';
    });
  }

  Future<void> _deleteEntry(String id) async {
    if (!_canEdit) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _collection!.doc(id).delete();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.red));
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _selectedCrop = null;
      _selectedStage = null;
      _selectedPest = null;
      _interventionCtrl.clear();
    });
    _formKey.currentState?.reset();
  }

  void _showSubmissionsDialog() {
    if (_submissionsCollection == null) return;
    
    final String? crop = _selectedCrop;
    final String? stage = _selectedStage;
    final String? pest = _selectedPest;
    
    if (crop == null || stage == null || pest == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select crop, stage, and pest first')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubmissionsViewerPage(
          collection: _submissionsCollection!,
          crop: crop,
          stage: stage,
          pest: pest,
          title: 'Pest Submissions',
        ),
      ),
    );
  }

  Widget _buildTeacherHints() {
    if (!isTeacher) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      return const SizedBox.shrink();
    }

    final pestKey     = '${_cropKey(_selectedCrop)}_${_selectedStage}_$_selectedPest';
    final interventions = pestInterventions[pestKey];

    // If no data for this pest, show a notice rather than silently hiding
    if (interventions == null) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(
            'No intervention data found for this pest. Key: $pestKey',
            style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
          )),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.green.shade50, Colors.green.shade100]),
        border: Border.all(color: Colors.green.shade700, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.school, color: Colors.green.shade700, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Text(
              '📚 TEACHER REFERENCE — Pest Interventions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900),
            )),
          ]),
          const Divider(height: 20, thickness: 2),

          if (interventions['chemicalControl'] != null) ...[
            _buildInterventionCategory('🧪 Chemical Control', interventions['chemicalControl']!, Colors.red.shade700),
            const SizedBox(height: 12),
          ],
          if (interventions['organicControl'] != null) ...[
            _buildInterventionCategory('🌿 Organic Control', interventions['organicControl']!, Colors.green.shade700),
            const SizedBox(height: 12),
          ],
          if (interventions['culturalControl'] != null) ...[
            _buildInterventionCategory('🛠️ Cultural/Prevention', interventions['culturalControl']!, Colors.blue.shade700),
            const SizedBox(height: 12),
          ],

          // Info strip + quick-unlock button
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade700),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Students cannot see hints until you unlock them.',
                    style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontStyle: FontStyle.italic),
                  )),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _submissionsCollection == null ? null : () async {
                try {
                  final snap = await _submissionsCollection!
                      .where('crop',  isEqualTo: _selectedCrop)
                      .where('stage', isEqualTo: _selectedStage)
                      .where('pest',  isEqualTo: _selectedPest)
                      .get();
                  for (final doc in snap.docs) {
                    await doc.reference.update({'isUnlocked': true});
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🔓 Hints unlocked for \${snap.docs.length} student(s)'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: \$e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: const Icon(Icons.lock_open, size: 14),
              label: const Text('Unlock for Students', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ]),

          // ── AI Analysis button (teacher) ────────────────────────────────
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _aiLoading ? null : () => _runAiPestAnalysis(null),
              icon: _aiLoading
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome, size: 16, color: Colors.deepPurple),
              label: Text(
                _aiLoading ? 'Analysing…' : '🤖 AI Analysis for this Pest',
                style: const TextStyle(fontSize: 12, color: Colors.deepPurple),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.deepPurple),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI pest analysis (general or student-specific) ─────────────────────
  Future<void> _runAiPestAnalysis(Map<String, dynamic>? studentData) async {
    final crop  = studentData?['crop']  ?? _selectedCrop  ?? '';
    final stage = studentData?['stage'] ?? _selectedStage ?? '';
    final pest  = studentData?['pest']  ?? _selectedPest  ?? '';

    final String userMsg;
    if (studentData != null) {
      userMsg = '''
Crop: \$crop  |  Growth Stage: \$stage  |  Pest: \$pest
Student Name: \${studentData['studentName'] ?? ''}
Student's Proposed Intervention: \${studentData['studentAnswer'] ?? '(none)'}
Teacher Grade: \${studentData['teacherGrade'] ?? 'not yet graded'}
Teacher Comment: \${studentData['teacherComment'] ?? '(none)'}

Analyse the student's proposed intervention for this pest. Provide:
1. Assessment: Is their intervention correct, partially correct, or incorrect? Explain clearly.
2. Ideal IPM approach: best chemical, organic, and cultural controls for this pest on \$crop at \$stage.
3. A Socratic question to deepen their understanding (don't give the answer away).
4. An encouraging closing sentence.
Language: Kenyan secondary school agriculture student level. Be warm but academically rigorous.
''';
    } else {
      userMsg = '''
Crop: \$crop  |  Growth Stage: \$stage  |  Pest: \$pest

Teacher reference analysis:
1. Biology and damage mechanism of \$pest on \$crop at the \$stage stage.
2. Key scouting signs / diagnostic indicators teachers should teach students to look for.
3. Integrated Pest Management interventions ranked by effectiveness:
   a) Chemical options (with active ingredients common in Kenya)
   b) Organic/biopesticide options
   c) Cultural/preventive measures
4. Economic threshold and when to act.
5. Safety notes relevant to Kenyan school farms.
Language: practical for a Kenyan secondary school teacher. Be concise.
''';
    }

    final _savedPos = _scrollCtrl.hasClients ? _scrollCtrl.offset : 0.0;
    setState(() => _aiLoading = true);
    final result = await _callGemini(
      'You are an expert Kenyan agronomist and secondary school agriculture teacher. '
      'Provide practical, evidence-based pest management advice for Kenya.',
      userMsg,
    );
    setState(() => _aiLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(_savedPos);
    });

    if (!mounted) return;
    _showAiResultDialog(
      title: studentData != null
          ? '🤖 AI Feedback: ${studentData['studentName'] ?? 'Student'}'
          : '🤖 AI Pest Analysis: $pest',
      result: result,
    );
  }

  void _showAiResultDialog({required String title, required String result}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold))),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(Icons.close,
                      color: Colors.white70, size: 20),
                ),
              ]),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _AiMarkdownCard(content: result),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Got it!'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterventionCategory(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }


  
  
  


  // ═══════════════════════════════════════════════════════════════════
  // IMPROVED STUDENT VIEW - Shows submission + review + hints persistently
  // ═══════════════════════════════════════════════════════════════════
  
  // ═══════════════════════════════════════════════════════════════════
  // STUDENT VIEW — All submissions by name, no dropdowns required
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPersistentStudentView() {
    if (!isStudent) return const SizedBox.shrink();

    final studentName = _studentNameCtrl.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(thickness: 2),
        const SizedBox(height: 12),
        const Text(
          '📋 My Submissions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryGreen),
        ),
        const SizedBox(height: 12),

        if (studentName.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(child: Text('Enter your name above to see your submissions')),
            ]),
          )
        else
          StreamBuilder<QuerySnapshot>(
            // Use the existing submittedBy+submittedAt index, then filter by name client-side.
            // Querying directly by studentName has no index and silently returns empty.
            stream: _submissionsCollection
                ?.where('studentName', isEqualTo: studentName)
                .orderBy('submittedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // Fall back to full collection scan filtered client-side if index missing
              if (snapshot.hasError) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _submissionsCollection
                      ?.orderBy('submittedAt', descending: true)
                      .snapshots(),
                  builder: (context, snap2) {
                    if (!snap2.hasData) return const Center(child: CircularProgressIndicator());
                    final mine = snap2.data!.docs.where((d) =>
                        (d.data() as Map<String, dynamic>)['studentName']?.toString().trim() == studentName
                    ).toList();
                    return _buildSubmissionCards(mine, studentName);
                  },
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // Primary path: index exists and worked
              final docs = snapshot.data?.docs ?? [];
              final mine = docs.where((d) =>
                  (d.data() as Map<String, dynamic>)['studentName']?.toString().trim() == studentName
              ).toList();
              return _buildSubmissionCards(mine, studentName);
            },
          ),
      ],
    );
  }

  // Extracted so both the primary and fallback streams can share the same card UI
  Widget _buildSubmissionCards(List<QueryDocumentSnapshot> docs, String studentName) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          const Icon(Icons.inbox_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 8),
          const Text('No submissions yet'),
          Text('Looking for: "$studentName"',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
          child: Text(
            '${docs.length} submission${docs.length == 1 ? '' : 's'} found',
            style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.bold),
          ),
        ),
        ...docs.map((doc) {
          final data           = doc.data() as Map<String, dynamic>;
          final isReviewed     = data['reviewStatus'] == 'reviewed';
          final gradeUnlocked  = data['gradeUnlocked'] == true;
          final hintsUnlocked  = data['isUnlocked'] == true;
          final teacherComment  = data['teacherComment']?.toString() ?? '';
          final studentReply    = data['studentReply']?.toString();
          final teacherFollowUp = data['teacherFollowUp']?.toString();
          final studentReply2   = data['studentReply2']?.toString();
          final teacherFollowUp2= data['teacherFollowUp2']?.toString();
          final pestKey        = '${_cropKey(data['crop']?.toString())}_${data['stage']}_${data['pest']}';
          final interventions  = pestInterventions[pestKey];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Header ──
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: hintsUnlocked ? Colors.green.shade600
                          : isReviewed     ? Colors.blue.shade600
                                           : Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hintsUnlocked ? Icons.check_circle
                          : isReviewed ? Icons.rate_review : Icons.pending,
                      color: Colors.white, size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${data['crop']} – ${data['stage']}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Pest: ${data['pest']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ])),
                  // Grade badge — only shown when teacher unlocked it
                  if (isReviewed && gradeUnlocked)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getGradeColor(data['teacherGrade']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_getGradeLabel(data['teacherGrade']),
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ]),
                const SizedBox(height: 12),

                // ── Student answer ──
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Your answer:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                    const SizedBox(height: 4),
                    Text(data['studentAnswer'] ?? '', style: const TextStyle(fontSize: 13)),
                  ]),
                ),

                // ── Teacher feedback (only if grade unlocked) ──
                if (isReviewed && gradeUnlocked && teacherComment.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.school, size: 14, color: Colors.purple.shade700),
                        const SizedBox(width: 4),
                        Text('Teacher feedback:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                      ]),
                      const SizedBox(height: 4),
                      Text(teacherComment, style: TextStyle(fontSize: 13, color: Colors.purple.shade900)),
                    ]),
                  ),
                ],

                // ── Student reply ──
                if (studentReply != null) ...[
                  const SizedBox(height: 8),
                  _convBox(Colors.indigo, 'Your reply:', Icons.reply, studentReply),
                ],

                // ── Teacher follow-up ──
                if (teacherFollowUp != null) ...[
                  const SizedBox(height: 8),
                  _convBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp),
                ],

                // ── Student reply 2 ──
                if (studentReply2 != null) ...[
                  const SizedBox(height: 8),
                  _convBox(Colors.indigo, 'Your reply:', Icons.reply, studentReply2),
                ],

                // ── Teacher follow-up 2 ──
                if (teacherFollowUp2 != null) ...[
                  const SizedBox(height: 8),
                  _convBox(Colors.amber, 'Teacher follow-up:', Icons.chat_bubble_outline, teacherFollowUp2),
                ],

                // ── Reply buttons ──
                // First reply: teacher commented but student hasn't replied yet
                if (isReviewed && gradeUnlocked && teacherComment.isNotEmpty && studentReply == null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showStudentReplyDialog(doc.id, data, replyNumber: 1),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply to Teacher',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
                // Second reply: teacher posted follow-up but student hasn't replied again
                if (teacherFollowUp != null && studentReply2 == null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showStudentReplyDialog(doc.id, data, replyNumber: 2),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply to Follow-up',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],

                // ── Unlocked hints ──
                if (hintsUnlocked && interventions != null) ...[
                  const SizedBox(height: 14),
                  const Divider(thickness: 1),
                  const SizedBox(height: 8),
                  _buildUnlockedHintsHeader(),
                  const SizedBox(height: 10),
                  if (interventions['chemicalControl'] != null) ...[
                    _buildHintsCategory('🧪 Chemical Control',
                        interventions['chemicalControl']!,
                        const Color(0xFFFFEBEE), const Color(0xFFB71C1C), const Color(0xFFC62828)),
                    const SizedBox(height: 10),
                  ],
                  if (interventions['organicControl'] != null) ...[
                    _buildHintsCategory('🌿 Organic Control',
                        interventions['organicControl']!,
                        const Color(0xFFE8F5E9), const Color(0xFF1B5E20), const Color(0xFF2E7D32)),
                    const SizedBox(height: 10),
                  ],
                  if (interventions['culturalControl'] != null)
                    _buildHintsCategory('🛠️ Cultural / Prevention',
                        interventions['culturalControl']!,
                        const Color(0xFFE3F2FD), const Color(0xFF0D47A1), const Color(0xFF1565C0)),
                ] else if (!hintsUnlocked && isReviewed) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.lock, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Your teacher will unlock the correct interventions soon.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      )),
                    ]),
                  ),
                ],

                // ── Status when pending ──
                if (!isReviewed) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.pending, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        'Your teacher will review your submission soon.',
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                      )),
                    ]),
                  ),
                ],

                // ── AI Tutor button (available to students after submission) ──
                if (isReviewed) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _aiLoading
                          ? null
                          : () => _runAiPestAnalysis({
                                'crop':           data['crop'],
                                'stage':          data['stage'],
                                'pest':           data['pest'],
                                'studentName':    data['studentName'],
                                'studentAnswer':  data['studentAnswer'],
                                'teacherGrade':   data['teacherGrade'],
                                'teacherComment': data['teacherComment'],
                              }),
                      icon: const Icon(Icons.auto_awesome, size: 15),
                      label: const Text('🤖 Get AI Feedback on My Answer',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Reusable conversation bubble
  // ─────────────────────────────────────────

  Widget _convBox(MaterialColor color, String label, IconData icon, String body) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: color.shade700),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color.shade900)),
        ]),
        const SizedBox(height: 4),
        Text(body, style: TextStyle(fontSize: 13, color: color.shade900)),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // Student reply dialog — handles 1st and 2nd reply
  // ─────────────────────────────────────────

  Future<void> _showStudentReplyDialog(String docId, Map<String, dynamic> data,
      {int replyNumber = 1}) async {
    if (_submissionsCollection == null) return;
    final ctrl = TextEditingController();
    final isSecond = replyNumber == 2;
    final contextText = isSecond
        ? (data['teacherFollowUp'] ?? '')
        : (data['teacherComment'] ?? '');
    final contextLabel = isSecond ? 'Teacher follow-up:' : 'Teacher said:';
    final dialogTitle  = isSecond ? 'Reply to Follow-up' : 'Reply to Teacher';
    final buttonColor  = isSecond ? Colors.deepPurple : Colors.indigo;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.reply, color: buttonColor),
          const SizedBox(width: 8),
          Expanded(child: Text(dialogTitle)),
        ]),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(contextLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
              const SizedBox(height: 4),
              Text(contextText, style: const TextStyle(fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: 'Your Reply',
              hintText: isSecond
                  ? "Respond to the teacher's follow-up..."
                  : "Respond to the teacher's feedback...",
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
            ),
            maxLines: 4,
            autofocus: true,
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () async {
              final reply = ctrl.text.trim();
              if (reply.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reply')));
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Reply sent!'), backgroundColor: Colors.green));
              final fields = isSecond
                  ? {'studentReply2': reply, 'studentRepliedAt2': FieldValue.serverTimestamp()}
                  : {'studentReply': reply, 'studentRepliedAt': FieldValue.serverTimestamp()};
              _submissionsCollection!.doc(docId).update(fields).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              });
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: buttonColor, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Student submission form (only shown when crop/stage/pest selected)
  // ─────────────────────────────────────────

  Widget _buildStudentSubmissionSection() {
    if (!isStudent) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      return const SizedBox.shrink();
    }

    return Form(
      key: _submissionFormKey,
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade300, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '💡 Submit Your Solution',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              )),
            ]),
            const Divider(height: 20, thickness: 2),
            TextFormField(
              controller: _studentAnswerCtrl,
              decoration: InputDecoration(
                labelText: 'What would YOU do to control this pest? *',
                hintText: 'Write your intervention idea here...',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 6,
              validator: (v) => v?.trim().isEmpty ?? true ? 'Please write your answer' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submitStudentAnswer,
                icon: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_isSaving ? 'Submitting...' : 'Submit My Answer',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your teacher will review your answer',
              style: TextStyle(fontSize: 11, color: Colors.blue.shade700, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Teacher: inline review dialog (no separate page needed)
  // ─────────────────────────────────────────

  Future<void> _showInlineReviewDialog(BuildContext context, String docId, Map<String, dynamic> data) async {
    final gradeCtrl     = TextEditingController(text: data['teacherGrade'] ?? '');
    final feedbackCtrl  = TextEditingController(text: data['teacherComment'] ?? '');
    final followUpCtrl  = TextEditingController(text: data['teacherFollowUp'] ?? '');
    final followUp2Ctrl = TextEditingController(text: data['teacherFollowUp2'] ?? '');
    final hasReply      = (data['studentReply'] ?? '').toString().isNotEmpty;
    final hasReply2     = (data['studentReply2'] ?? '').toString().isNotEmpty;
    bool gradeUnlocked  = data['gradeUnlocked'] ?? false;
    bool hintsUnlocked  = data['isUnlocked']    ?? false;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: Text('${data['studentName'] ?? 'Student'} — ${data['pest'] ?? ''}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${data['crop']} › ${data['stage']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 12),
              // Student answer
              _convBox(Colors.blue, 'Student answer:', Icons.lightbulb_outline, data['studentAnswer'] ?? ''),
              // Student reply 1
              if (hasReply) ...[
                const SizedBox(height: 8),
                _convBox(Colors.indigo, 'Student replied:', Icons.reply, data['studentReply'] ?? ''),
              ],
              // Student reply 2
              if (hasReply2) ...[
                const SizedBox(height: 8),
                _convBox(Colors.deepPurple, 'Student reply 2:', Icons.reply, data['studentReply2'] ?? ''),
              ],
              const SizedBox(height: 12),
              // ── AI draft comment button ─────────────────────────────────
              StatefulBuilder(
                builder: (ctx2, setBtn) {
                  bool localAi = false;
                  String aiDraft = '';
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (aiDraft.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            const Icon(Icons.auto_awesome, size: 13, color: Colors.deepPurple),
                            const SizedBox(width: 4),
                            const Text('AI draft — tap to insert:',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => feedbackCtrl.text = aiDraft,
                            child: Text(aiDraft, style: const TextStyle(fontSize: 12)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ],
                    OutlinedButton.icon(
                      onPressed: localAi ? null : () async {
                        setBtn(() => localAi = true);
                        final draft = await _callGemini(
                          'You are an experienced Kenyan secondary school agriculture teacher.',
                          "Student: ${data['studentName'] ?? ''}\n"
                          "Crop: ${data['crop']}  Stage: ${data['stage']}  Pest: ${data['pest']}\n"
                          "Student answer: ${data['studentAnswer'] ?? ''}\n"
                          "Write a 2–3 sentence encouraging teaching comment or follow-up question for this student.",
                        );
                        setBtn(() { localAi = false; aiDraft = draft; });
                      },
                      icon: localAi
                          ? const SizedBox(width: 12, height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome, size: 14, color: Colors.deepPurple),
                      label: const Text('🤖 AI Draft Comment',
                          style: TextStyle(fontSize: 12, color: Colors.deepPurple)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.deepPurple),
                      ),
                    ),
                  ]);
                },
              ),

              const SizedBox(height: 14),
              // Grade
              const Text('Grade:', style: TextStyle(fontWeight: FontWeight.bold)),
              DropdownButton<String>(
                isExpanded: true,
                value: gradeCtrl.text.isEmpty ? null : gradeCtrl.text,
                items: [
                  DropdownMenuItem(value: 'correct',   child: Text('✅ Correct',   style: TextStyle(color: Colors.green.shade700,  fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'needsWork', child: Text('⚠️ Needs Work', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold))),
                  DropdownMenuItem(value: 'incorrect', child: Text('❌ Incorrect',  style: TextStyle(color: Colors.red.shade700,    fontWeight: FontWeight.bold))),
                ],
                onChanged: (v) => setDlg(() => gradeCtrl.text = v ?? ''),
              ),
              const SizedBox(height: 10),
              // Feedback / first follow-up
              const Text('Feedback / Question:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: feedbackCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Feedback or follow-up question…',
                ),
              ),
              // Second follow-up (shown when student has replied once)
              if (hasReply) ...[
                const SizedBox(height: 10),
                const Text('Follow-up after student reply:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: followUpCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    hintText: "Respond to student's first reply…",
                  ),
                ),
              ],
              // Third follow-up (shown when student has replied twice)
              if (hasReply2) ...[
                const SizedBox(height: 10),
                const Text('Follow-up after 2nd student reply:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: followUp2Ctrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.chat_bubble_outline),
                    hintText: "Respond to student's second reply…",
                  ),
                ),
              ],
              // ── Unlock options ──
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Unlock for student:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    title: const Text('Grade & feedback', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Student sees your grade and comment', style: TextStyle(fontSize: 11)),
                    value: gradeUnlocked,
                    onChanged: (v) => setDlg(() => gradeUnlocked = v ?? false),
                    dense: true,
                    activeColor: Colors.blue.shade700,
                  ),
                  CheckboxListTile(
                    title: const Text('Expert hints / interventions', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('Student sees the correct answers', style: TextStyle(fontSize: 11)),
                    value: hintsUnlocked,
                    onChanged: (v) => setDlg(() => hintsUnlocked = v ?? false),
                    dense: true,
                    activeColor: Colors.green.shade700,
                  ),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> update = {
                    'reviewStatus':  'reviewed',
                    'teacherGrade':  gradeCtrl.text,
                    'teacherComment': feedbackCtrl.text,
                    'gradeUnlocked': gradeUnlocked,
                    'isUnlocked':    hintsUnlocked,
                  };
                  if (hasReply && followUpCtrl.text.trim().isNotEmpty) {
                    update['teacherFollowUp']   = followUpCtrl.text.trim();
                    update['teacherFollowUpAt'] = FieldValue.serverTimestamp();
                  }
                  if (hasReply2 && followUp2Ctrl.text.trim().isNotEmpty) {
                    update['teacherFollowUp2']   = followUp2Ctrl.text.trim();
                    update['teacherFollowUpAt2'] = FieldValue.serverTimestamp();
                  }
                  await _submissionsCollection!.doc(docId).update(update);
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Review saved!'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? imagePath;
    if (_selectedCrop != null && _selectedStage != null && _selectedPest != null) {
      final key = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
      imagePath = pestDetails[key]?['imagePath'] as String? ?? 'assets/pests/default.jpg';
    }

    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Previous season history ──────────────────────────────
            PlotHistoryCard(
              analysis:    _previousAnalysis,
              seasonLabel: '${DateTime.now().year - 1} Season',
              isEducation: true,
            ),

            Text(
              _isHeadteacher ? 'Pest Observation Form (View Only)' : 'Report Pest Observation',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 16),

            // ── AI Photo Diagnosis — pre-fills crop/stage/pest dropdowns ────
            // Only shown for teachers and students; headteachers see read-only form.
            // The AI identifies the pest; the student still writes their own
            // intervention — pedagogical value is preserved.
            if (!_isHeadteacher)
              EduPhotoDiagnosisButton(
                isPest: true,
                role: widget.role,
                onPrefill: (data) {
                  // DropdownButtonFormField with initialValue does not react to
                  // setState alone — we must reset the form so dropdowns rebuild
                  // with the new initialValues set below.
                  setState(() {
                    if (data['crop']?.isNotEmpty == true) {
                      _selectedCrop  = data['crop'];
                      _selectedStage = null;
                      _selectedPest  = null;
                    }
                    if (data['stage']?.isNotEmpty == true) {
                      _selectedStage = data['stage'];
                    }
                    if (data['name']?.isNotEmpty == true) {
                      // Match AI name to the closest pest in the list
                      final aiName = data['name']!;
                      final crop = _selectedCrop;
                      final stage = _selectedStage;
                      if (crop != null && stage != null &&
                          cropStagePests[crop]?[stage] != null) {
                        final list = cropStagePests[crop]![stage]!;
                        // Exact match first
                        if (list.contains(aiName)) {
                          _selectedPest = aiName;
                        } else {
                          // Fuzzy: find list item that contains any word from AI name
                          final aiWords = aiName.toLowerCase().split(RegExp(r'\s+'));
                          final match = list.firstWhere(
                            (p) => aiWords.any((w) => w.length > 3 &&
                                p.toLowerCase().contains(w)),
                            orElse: () => '',
                          );
                          _selectedPest = match.isNotEmpty ? match : null;
                        }
                      } else {
                        _selectedPest = null;
                      }
                    }
                  });
                  // value: on DropdownButtonFormField is reactive to setState.
                  // No formKey.reset() needed — the dropdowns update automatically.
                },
              ),

            // ── Student name at TOP — so submissions list appears immediately ──
            if (isStudent) ...[
              TextFormField(
                controller: _studentNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Your Name *',
                  hintText: 'Enter your full name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
            ],

            // ── Dropdowns ──
            DropdownButtonFormField<String>(
              value: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop Affected', border: OutlineInputBorder()),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _canEdit ? (v) => setState(() { _selectedCrop = v; _selectedStage = null; _selectedPest = null; }) : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedStage,
              decoration: const InputDecoration(labelText: 'Growth Stage', border: OutlineInputBorder()),
              items: _selectedCrop == null ? [] : cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: _canEdit ? (v) => setState(() { _selectedStage = v; _selectedPest = null; }) : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedPest,
              decoration: const InputDecoration(labelText: 'Pest Observed', border: OutlineInputBorder()),
              items: _selectedCrop == null || _selectedStage == null ? [] :
                  cropStagePests[_selectedCrop]![_selectedStage]!.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: _canEdit ? (v) => setState(() => _selectedPest = v) : null,
              // No validator on pest — teacher can select just to view hints without submitting
            ),

            if (imagePath != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Image.asset(imagePath, height: 220, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 100)),
              ),
            ],

            // ── Teacher reference hints (visible as soon as pest is selected) ──
            _buildTeacherHints(),

            // ── Student answer form (only when pest selected) ──
            _buildStudentSubmissionSection(),

            // ── Teacher: optional observation log ──
            if (isTeacher && _selectedPest != null) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _interventionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Intervention Taken (optional)',
                  hintText: 'Record what intervention was actually applied in the field',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                enabled: _canEdit,
              ),
              const SizedBox(height: 16),
              if (_canEdit)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveEntry,
                    icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                    label: Text(_editingId == null ? 'Log Observation (Optional)' : 'Update Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                    ),
                  ),
                ),
              if (_editingId != null && _canEdit)
                Center(child: TextButton(
                  onPressed: _resetForm,
                  child: const Text('Cancel Edit', style: TextStyle(color: Colors.red)),
                )),
            ],

            // ── Teacher: ALL student submissions inline — no selection required ──
            if (isTeacher) ...[
              const SizedBox(height: 32),
              const Divider(thickness: 2),
              const SizedBox(height: 8),
              const Text('📋 Student Submissions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
              const SizedBox(height: 4),
              const Text('All submissions from your class — tap any card to review',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              if (_submissionsCollection == null)
                const Text('No class selected')
              else
                StreamBuilder<QuerySnapshot>(
                  stream: _submissionsCollection!.orderBy('submittedAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                        child: const Text('No student submissions yet'),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc  = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isReviewed = data['reviewStatus'] == 'reviewed';
                        final hasReply   = (data['studentReply'] ?? '').toString().isNotEmpty;
                        final ts = (data['submittedAt'] as Timestamp?)?.toDate();
                        final dateStr = ts != null ? ts.toString().substring(0, 16) : '—';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => _showInlineReviewDialog(context, doc.id, data),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      (data['studentName'] ?? 'U')[0].toUpperCase(),
                                      style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(data['studentName'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('${data['crop']} › ${data['stage']} › ${data['pest']}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  ])),
                                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isReviewed ? Colors.green : Colors.orange,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(isReviewed ? 'Reviewed' : 'Pending',
                                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                                    ),
                                    if (hasReply) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(10)),
                                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                          Icon(Icons.reply, size: 11, color: Colors.white),
                                          SizedBox(width: 3),
                                          Text('Replied', style: TextStyle(color: Colors.white, fontSize: 11)),
                                        ]),
                                      ),
                                    ],
                                  ]),
                                ]),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    data['studentAnswer'] ?? '',
                                    style: const TextStyle(fontSize: 13),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],

            // ── Student: My Submissions list ──
            _buildPersistentStudentView(),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockedHintsHeader() => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: const [
          Icon(Icons.school, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Correct Interventions',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ]),
      );

  Widget _buildHintsCategory(
      String label, List<String> items, Color bg, Color titleColor, Color borderColor) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: borderColor.withOpacity(0.12),
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: titleColor)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map<Widget>((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle,
                                  size: 14, color: borderColor),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(item,
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.4))),
                            ]),
                      ))
                  .toList()),
        ),
      ]),
    );
  }
}
// ========== SUBMISSIONS VIEWER PAGE ==========
class SubmissionsViewerPage extends StatelessWidget {
  final CollectionReference collection;
  final String crop;
  final String stage;
  final String pest;
  final String title;

  const SubmissionsViewerPage({
    super.key,
    required this.collection,
    required this.crop,
    required this.stage,
    required this.pest,
    required this.title,
  });


  // ═══════════════════════════════════════════════════════════
  // STATUS HELPER METHODS - Colored badges with emojis
  // ═══════════════════════════════════════════════════════════
  
  String _getStatusLabel(Map<String, dynamic> data) {
    if (data['isUnlocked'] == true) return '🔓 Unlocked';
    if (data['reviewStatus'] == 'reviewed') {
      switch (data['teacherGrade']) {
        case 'correct': return '✅ Correct';
        case 'needsWork': return '⚠️ Needs Work';
        case 'incorrect': return '❌ Incorrect';
        default: return '📝 Reviewed';
      }
    }
    return '🟠 Pending';
  }
  
  Color _getStatusColor(Map<String, dynamic> data) {
    if (data['isUnlocked'] == true) return Colors.blue.shade100;
    if (data['reviewStatus'] == 'reviewed') {
      switch (data['teacherGrade']) {
        case 'correct': return Colors.green.shade100;
        case 'needsWork': return Colors.orange.shade100;
        case 'incorrect': return Colors.red.shade100;
        default: return Colors.grey.shade100;
      }
    }
    return Colors.orange.shade100;
  }
  
  Color _getStatusTextColor(Map<String, dynamic> data) {
    if (data['isUnlocked'] == true) return Colors.blue.shade900;
    if (data['reviewStatus'] == 'reviewed') {
      switch (data['teacherGrade']) {
        case 'correct': return Colors.green.shade900;
        case 'needsWork': return Colors.orange.shade900;
        case 'incorrect': return Colors.red.shade900;
        default: return Colors.grey.shade900;
      }
    }
    return Colors.orange.shade900;
  }
  
  IconData _getStatusIcon(Map<String, dynamic> data) {
    if (data['isUnlocked'] == true) return Icons.lock_open;
    if (data['reviewStatus'] == 'reviewed') {
      switch (data['teacherGrade']) {
        case 'correct': return Icons.check_circle;
        case 'needsWork': return Icons.warning;
        case 'incorrect': return Icons.cancel;
        default: return Icons.rate_review;
      }
    }
    return Icons.pending;
  }

  Future<void> _unlockAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unlock All Answers?'),
        content: const Text('This will unlock correct interventions for all students in this category.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Unlock All', style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final snapshot = await collection
            .where('crop', isEqualTo: crop)
            .where('stage', isEqualTo: stage)
            .where('pest', isEqualTo: pest)
            .get();

        for (var doc in snapshot.docs) {
          await doc.reference.update({'isUnlocked': true});
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All answers unlocked!'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleUnlock(BuildContext context, String docId, bool isCurrentlyUnlocked) async {
    try {
      await collection.doc(docId).update({'isUnlocked': !isCurrentlyUnlocked});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isCurrentlyUnlocked ? '🔓 Unlocked!' : '🔒 Locked!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showReviewDialog(BuildContext context, String docId, Map<String, dynamic> data) async {
    final gradeCtrl = TextEditingController(text: data['teacherGrade'] ?? '');
    final feedbackCtrl = TextEditingController(text: data['teacherComment'] ?? '');
    final followUpCtrl = TextEditingController(text: data['teacherFollowUp'] ?? '');
    final hasStudentReply = (data['studentReply'] ?? '').toString().isNotEmpty;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          title: const Text('Review Student Answer'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Student: ${data['studentName']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // Student reply badge
                if (hasStudentReply) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.indigo.shade200)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.reply, size: 14, color: Colors.indigo.shade700),
                        const SizedBox(width: 4),
                        Text('Student replied:',
                            style: TextStyle(fontWeight: FontWeight.bold,
                                color: Colors.indigo.shade900, fontSize: 12)),
                      ]),
                      const SizedBox(height: 4),
                      Text(data['studentReply'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Grade:', style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: gradeCtrl.text.isEmpty ? null : gradeCtrl.text,
                  items: ['correct', 'needsWork', 'incorrect']
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (v) => setDlg(() => gradeCtrl.text = v ?? ''),
                ),
                const SizedBox(height: 12),
                const Text('Feedback / Question:', style: TextStyle(fontWeight: FontWeight.bold)),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Ask a follow-up question or give feedback…',
                  ),
                ),
                if (hasStudentReply) ...[
                  const SizedBox(height: 12),
                  const Text('Follow-up Response:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: followUpCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Respond to the student's reply…",
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> update = {
                    'reviewStatus': 'reviewed',
                    'teacherGrade': gradeCtrl.text,
                    'teacherComment': feedbackCtrl.text,
                  };
                  if (hasStudentReply && followUpCtrl.text.trim().isNotEmpty) {
                    update['teacherFollowUp'] = followUpCtrl.text.trim();
                    update['teacherFollowUpAt'] = FieldValue.serverTimestamp();
                  }
                  await collection.doc(docId).update(update);
                  Navigator.pop(c);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Review saved!'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Save Review', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF388E3C),
        foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: const Icon(Icons.lock_open_outlined),
          tooltip: 'Unlock All Answers',
          onPressed: () => _unlockAll(context),
        ),
      ],
    ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Viewing submissions for:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(
                  '$crop → $stage → $pest',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: collection
                  .where('crop', isEqualTo: crop)
                  .where('stage', isEqualTo: stage)
                  .where('pest', isEqualTo: pest)
                  .orderBy('submittedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF388E3C),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                          const SizedBox(height: 16),
                          const Text(
                            'Error Loading Submissions',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No Student Submissions Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Students will submit their answers here',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final timestamp = data['submittedAt'] as Timestamp?;
                    final dateStr = timestamp != null
                        ? timestamp.toDate().toLocal().toString().substring(0, 16)
                        : 'No date';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    (data['studentName'] ?? 'U')[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.blue.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['studentName'] ?? 'Unknown Student',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(data),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(_getStatusIcon(data), size: 14, color: _getStatusTextColor(data)),
                                      const SizedBox(width: 4),
                                      Text(_getStatusLabel(data),
                                        style: TextStyle(fontSize: 11, color: _getStatusTextColor(data), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
if ((data['studentReply'] ?? '').toString().isNotEmpty)
  Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: Colors.indigo, borderRadius: BorderRadius.circular(12)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.reply, size: 11, color: Colors.white),
      SizedBox(width: 3),
      Text('Replied', style: TextStyle(color: Colors.white, fontSize: 11)),
    ]),
  ),
const SizedBox(width: 8),
if (data['reviewStatus'] != 'reviewed')
  ElevatedButton.icon(
    onPressed: () => _showReviewDialog(context, doc.id, data),
    icon: const Icon(Icons.rate_review, size: 14),
    label: const Text('Review', style: TextStyle(fontSize: 11)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: Size.zero,
    ),
  )
else ...[
  ElevatedButton.icon(
    onPressed: () => _showReviewDialog(context, doc.id, data),
    icon: const Icon(Icons.edit, size: 14),
    label: const Text('Edit', style: TextStyle(fontSize: 11)),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.grey.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: Size.zero,
    ),
  ),
  const SizedBox(width: 4),
  ElevatedButton.icon(
    onPressed: () => _toggleUnlock(context, doc.id, data['isUnlocked'] ?? false),
    icon: Icon((data['isUnlocked'] ?? false) ? Icons.lock : Icons.lock_open, size: 14),
    label: Text((data['isUnlocked'] ?? false) ? 'Lock' : 'Unlock', 
      style: const TextStyle(fontSize: 11)),
    style: ElevatedButton.styleFrom(
      backgroundColor: (data['isUnlocked'] ?? false) 
          ? Colors.orange.shade600 
          : Colors.green.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      minimumSize: Size.zero,
    ),
  ),
],
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STUDENT\'S ANSWER:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                data['studentAnswer'] ?? 'No answer provided',
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  _AiMarkdownCard — renders Gemini markdown responses beautifully
// ═══════════════════════════════════════════════════════════════════════════
class _AiMarkdownCard extends StatelessWidget {
  final String content;
  const _AiMarkdownCard({required this.content});

  static const List<Color> _sectionBg = [
    Color(0xFFE8F5E9), Color(0xFFE3F2FD), Color(0xFFFFF8E1),
    Color(0xFFFCE4EC), Color(0xFFEDE7F6), Color(0xFFE0F7FA),
  ];
  static const List<Color> _sectionBorder = [
    Color(0xFF2E7D32), Color(0xFF1565C0), Color(0xFFF9A825),
    Color(0xFFC62828), Color(0xFF6A1B9A), Color(0xFF00695C),
  ];
  static const List<Color> _sectionTitle = [
    Color(0xFF1B5E20), Color(0xFF0D47A1), Color(0xFFE65100),
    Color(0xFFB71C1C), Color(0xFF4A148C), Color(0xFF004D40),
  ];

  Widget _renderBody(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) { widgets.add(const SizedBox(height: 4)); continue; }
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)').firstMatch(line);
      if (numMatch != null) {
        widgets.add(_bulletRow(
            '${numMatch.group(1)}.',  numMatch.group(2)!, numbered: true));
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ') ||
          line.startsWith('• ')) {
        final t = line.replaceFirst(RegExp(r'^[-*•]\s+'), '');
        widgets.add(_bulletRow('•', t, numbered: false));
        continue;
      }
      if (line.startsWith('**') && line.endsWith('**') && line.length > 4) {
        final inner = line.substring(2, line.length - 2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(inner,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.black87)),
        ));
        continue;
      }
      widgets.add(
          Padding(padding: const EdgeInsets.only(bottom: 3), child: _inlineBold(line)));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _parseSections(content);
    if (sections.isEmpty) return _plainText(content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections.asMap().entries.map((entry) {
        final i = entry.key % _sectionBg.length;
        final s = entry.value;
        if (s['type'] == 'intro') {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: _renderBody(s['body'] ?? '')),
                  ]),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            decoration: BoxDecoration(
              color: _sectionBg[i],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: _sectionBorder[i].withOpacity(0.5), width: 1.5),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _sectionBorder[i].withOpacity(0.12),
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11)),
                ),
                child: Row(children: [
                  Icon(_sectionIcon(s['title'] ?? ''),
                      color: _sectionTitle[i], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    _cleanTitle(s['title'] ?? ''),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _sectionTitle[i]),
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: _renderBody(s['body'] ?? ''),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }

  List<Map<String, String>> _parseSections(String raw) {
    final lines = raw.split('\n');
    final sections = <Map<String, String>>[];
    String? currentTitle;
    final bodyBuf = StringBuffer();

    void flush() {
      final body = bodyBuf.toString().trim();
      if (body.isEmpty && currentTitle == null) return;
      sections.add({
        'type': currentTitle == null ? 'intro' : 'section',
        'title': currentTitle ?? '',
        'body': body,
      });
      bodyBuf.clear();
      currentTitle = null;
    }

    for (final line in lines) {
      if (RegExp(r'^#{1,3}\s').hasMatch(line)) {
        flush();
        currentTitle = line.replaceFirst(RegExp(r'^#+\s*'), '');
      } else {
        bodyBuf.writeln(line);
      }
    }
    flush();
    return sections;
  }

  Widget _bulletRow(String marker, String text, {required bool numbered}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5, left: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: numbered ? 22 : 16,
            child: Text(marker,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        numbered ? FontWeight.bold : FontWeight.normal,
                    color: numbered
                        ? const Color(0xFF1B5E20)
                        : Colors.black54)),
          ),
          Expanded(child: _inlineBold(text)),
        ]),
      );

  Widget _inlineBold(String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
          text: m.group(1),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return RichText(
        text: TextSpan(
            style: const TextStyle(
                fontSize: 13, color: Colors.black87, height: 1.45),
            children: spans));
  }

  Widget _plainText(String t) =>
      Text(t, style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45));

  String _cleanTitle(String t) => t.replaceAll(RegExp(r'^[#*]+\s*'), '').trim();

  IconData _sectionIcon(String title) {
    final t = title.toLowerCase();
    if (t.contains('chemical') || t.contains('pesticide') || t.contains('fungicid')) return Icons.science;
    if (t.contains('organic') || t.contains('bio') || t.contains('natural')) return Icons.eco;
    if (t.contains('cultural') || t.contains('prevent') || t.contains('practice')) return Icons.agriculture;
    if (t.contains('diagnos') || t.contains('symptom') || t.contains('sign')) return Icons.search;
    if (t.contains('soil') || t.contains('nutrient') || t.contains('fertiliz')) return Icons.grass;
    if (t.contains('economic') || t.contains('threshold')) return Icons.trending_up;
    if (t.contains('safety') || t.contains('warning') || t.contains('caution')) return Icons.warning_amber;
    if (t.contains('recommend') || t.contains('action')) return Icons.recommend;
    if (t.contains('question') || t.contains('reflect')) return Icons.psychology;
    if (t.contains('assessment') || t.contains('evaluat') || t.contains('feedback')) return Icons.grading;
    if (t.contains('rotation') || t.contains('next crop')) return Icons.loop;
    if (t.contains('biology') || t.contains('life cycle')) return Icons.biotech;
    if (t.contains('assessment') || t.contains('evaluat')) return Icons.grading;
    return Icons.info_outline;
  }
}