// lib/education/pest/pest_data_input.dart - PHASE 2

// ignore_for_file: use_build_context_synchronously, body_might_complete_normally_catch_error, unused_element, deprecated_member_use, avoid_print, unnecessary_underscores

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/data/pest_interventions.dart';

const Color primaryGreen = Color(0xFF388E3C);

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

class _PestDataInputState extends State<PestDataInput> {
  final _formKey = GlobalKey<FormState>();
  final _submissionFormKey = GlobalKey<FormState>();
  bool _isSaving = false;

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
    isStudent = widget.role == EduRole.student;

    if (widget.prefillData != null) {
      _selectedCrop = widget.prefillData!['crop'];
      _selectedStage = widget.prefillData!['stage'];
      _selectedPest = widget.prefillData!['name'];
    }
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
    _studentNameCtrl.clear();
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
    
    final pestKey = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
    final interventions = pestInterventions[pestKey];
    
    if (interventions == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
        ),
        border: Border.all(color: Colors.green.shade700, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '📚 TEACHER REFERENCE - Pest Intervention Methods',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 2),
          
          if (interventions['chemicalControl'] != null) ...[
            _buildInterventionCategory(
              '🧪 Chemical Control',
              interventions['chemicalControl']!,
              Colors.red.shade700,
            ),
            const SizedBox(height: 12),
          ],
          
          if (interventions['organicControl'] != null) ...[
            _buildInterventionCategory(
              '🌿 Organic Control',
              interventions['organicControl']!,
              Colors.green.shade700,
            ),
            const SizedBox(height: 12),
          ],
          
          if (interventions['culturalControl'] != null) ...[
            _buildInterventionCategory(
              '🛠️ Cultural/Prevention',
              interventions['culturalControl']!,
              Colors.blue.shade700,
            ),
          ],
          
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade900, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Students cannot see these hints',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
  
  Widget _buildPersistentStudentView() {
    if (!isStudent) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      return const SizedBox.shrink();
    }
    
    // Get interventions
    final key = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
    final interventions = pestInterventions[key];
    
    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('pest', isEqualTo: _selectedPest)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No submission yet - show nothing
          return const SizedBox.shrink();
        }
        
        // Get the MOST RECENT submission for this crop/stage/pest
        // This persists even after form is cleared!
        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        
        final isReviewed = data['reviewStatus'] == 'reviewed';
        final isUnlocked = data['isUnlocked'] == true;
        final studentAnswer = data['studentAnswer'] ?? '';
        final studentName = data['studentName'] ?? 'Unknown';
        
        return Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isUnlocked 
                  ? [Colors.green.shade50, Colors.blue.shade50]
                  : isReviewed
                      ? [Colors.blue.shade50, Colors.purple.shade50]
                      : [Colors.orange.shade50, Colors.yellow.shade50],
            ),
            border: Border.all(
              color: isUnlocked 
                  ? Colors.green.shade600 
                  : isReviewed 
                      ? Colors.blue.shade600 
                      : Colors.orange.shade600,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isUnlocked ? Colors.green : Colors.blue).withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnlocked 
                          ? Colors.green.shade600 
                          : isReviewed 
                              ? Colors.blue.shade600 
                              : Colors.orange.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isUnlocked 
                          ? Icons.check_circle 
                          : isReviewed 
                              ? Icons.rate_review 
                              : Icons.pending,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isUnlocked 
                              ? '🎉 Reviewed & Unlocked!' 
                              : isReviewed 
                                  ? '📝 Teacher Reviewed' 
                                  : '⏳ Waiting for Review',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked 
                                ? Colors.green.shade900 
                                : isReviewed 
                                    ? Colors.blue.shade900 
                                    : Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          'Submitted by $studentName',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              
              // ALWAYS show what student submitted
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'YOUR SUBMISSION:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade900,
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
                  border: Border.all(color: Colors.blue.shade300),
                ),
                child: Text(
                  studentAnswer,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ),
              
              // Show teacher review if reviewed
              if (isReviewed) ...[
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                
                // Grade
                Row(
                  children: [
                    const Text(
                      'Your Grade: ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getGradeColor(data['teacherGrade']),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getGradeIcon(data['teacherGrade']), size: 16, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _getGradeLabel(data['teacherGrade']),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Teacher comment
                if (data['teacherComment'] != null && 
                    (data['teacherComment'] as String).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'TEACHER\'S FEEDBACK:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900,
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
                      border: Border.all(color: Colors.purple.shade300),
                    ),
                    child: Text(
                      data['teacherComment'],
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ],

                // Student reply (if any)
                if (data['studentReply'] != null &&
                    (data['studentReply'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.indigo.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.reply, size: 14, color: Colors.indigo.shade700),
                          const SizedBox(width: 4),
                          Text('Your reply:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                  color: Colors.indigo.shade900)),
                        ]),
                        const SizedBox(height: 4),
                        Text(data['studentReply'],
                            style: TextStyle(fontSize: 13, color: Colors.indigo.shade900)),
                      ],
                    ),
                  ),
                ],

                // Teacher follow-up (if any)
                if (data['teacherFollowUp'] != null &&
                    (data['teacherFollowUp'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.chat_bubble_outline, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text('Teacher follow-up:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900)),
                        ]),
                        const SizedBox(height: 4),
                        Text(data['teacherFollowUp'],
                            style: TextStyle(fontSize: 13, color: Colors.amber.shade900)),
                      ],
                    ),
                  ),
                ],

                // Reply button — shown when teacher has commented and student hasn't replied yet
                if (data['reviewStatus'] == 'reviewed' &&
                    data['teacherComment'] != null &&
                    (data['teacherComment'] as String).isNotEmpty &&
                    (data['studentReply'] == null ||
                        (data['studentReply'] as String).isEmpty)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showStudentReplyDialog(doc.id, data),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Reply to Teacher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
              
              // Show hints if unlocked
              if (isUnlocked && interventions != null) ...[
                const SizedBox(height: 20),
                const Divider(thickness: 2),
                const SizedBox(height: 16),
                
                Text(
                  '📚 CORRECT INTERVENTIONS:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                
                if (interventions['chemicalControl'] != null) ...[
                  _buildInterventionCategory(
                    '🧪 Chemical Control',
                    interventions['chemicalControl']!,
                    Colors.red.shade700,
                  ),
                  const SizedBox(height: 12),
                ],
                if (interventions['organicControl'] != null) ...[
                  _buildInterventionCategory(
                    '🌿 Organic Control',
                    interventions['organicControl']!,
                    Colors.green.shade700,
                  ),
                  const SizedBox(height: 12),
                ],
                if (interventions['culturalControl'] != null) ...[
                  _buildInterventionCategory(
                    '🛠️ Cultural/Prevention',
                    interventions['culturalControl']!,
                    Colors.blue.shade700,
                  ),
                ],
                
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compare your answer with the correct interventions above! 📖',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isReviewed) ...[
                // Reviewed but not unlocked
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your teacher will unlock the correct interventions soon.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Not reviewed yet
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.pending, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your teacher will review this submission soon.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────
  // Student reply to teacher feedback
  // ─────────────────────────────────────────

  Future<void> _showStudentReplyDialog(String docId, Map<String, dynamic> data) async {
    if (_submissionsCollection == null) return;
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.reply, color: Colors.indigo), SizedBox(width: 8),
          Expanded(child: Text('Reply to Teacher')),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.shade200),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Teacher said:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade900)),
                const SizedBox(height: 4),
                Text(data['teacherComment'] ?? '', style: const TextStyle(fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                labelText: 'Your Reply',
                hintText: "Respond to the teacher's feedback...",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit),
              ),
              maxLines: 4,
              autofocus: true,
            ),
          ]),
        ),
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
              _submissionsCollection!.doc(docId).update({
                'studentReply': reply,
                'studentRepliedAt': FieldValue.serverTimestamp(),
              }).catchError((e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              });
            },
            icon: const Icon(Icons.send),
            label: const Text('Send Reply'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedAnswersView() {
    if (!isStudent) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      return const SizedBox.shrink();
    }
    
    final key = '${_selectedCrop}_${_selectedStage}_$_selectedPest';
    final interventions = pestInterventions[key];
    if (interventions == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('pest', isEqualTo: _selectedPest)
          .where('isUnlocked', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // DEBUG LOGGING
        print('🔍 Student Feedback View Debug:');
        print('   isStudent: $isStudent');
        print('   _selectedCrop: $_selectedCrop');
        print('   _selectedStage: $_selectedStage');
        print('   pest: $_selectedPest');
        print('   currentStudentName: ${_studentNameCtrl.text.trim()}');
        print('   snapshot.hasData: ${snapshot.hasData}');
        print('   snapshot.docs.length: ${snapshot.data?.docs.length ?? 0}');
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          print('   ❌ No submissions found');
          return const SizedBox.shrink();
        }
        
        return Container(
          margin: const EdgeInsets.only(top: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.green.shade50, Colors.blue.shade50],
            ),
            border: Border.all(color: Colors.green.shade600, width: 3),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✨ Answers Unlocked!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        Text(
                          'Compare your answer with correct interventions',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
              Text(
                '📚 CORRECT INTERVENTIONS:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (interventions['chemicalControl'] != null) ...[
                _buildInterventionCategory(
                  '🧪 Chemical Control',
                  interventions['chemicalControl']!,
                  Colors.red.shade700,
                ),
                const SizedBox(height: 16),
              ],
              if (interventions['organicControl'] != null) ...[
                _buildInterventionCategory(
                  '🌿 Organic Control',
                  interventions['organicControl']!,
                  Colors.green.shade700,
                ),
                const SizedBox(height: 16),
              ],
              if (interventions['culturalControl'] != null) ...[
                _buildInterventionCategory(
                  '🛠️ Cultural/Prevention',
                  interventions['culturalControl']!,
                  Colors.blue.shade700,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

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
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '💡 Submit Your Solution',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 2),
            
            TextFormField(
              controller: _studentNameCtrl,
              decoration: InputDecoration(
                labelText: 'Your Name *',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Name is required' : null,
            ),
            
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _studentAnswerCtrl,
              decoration: InputDecoration(
                labelText: 'What would YOU do to control this pest? *',
                hintText: 'Write your intervention idea here...\n\nExample: I would spray neem oil mixed with water twice per week...',
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
                label: Text(_isSaving ? 'Submitting...' : 'Submit My Answer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.yellow.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.yellow.shade900, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your teacher will review your answer',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.yellow.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSubmissionsButton() {
    if (!isTeacher) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedPest == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('pest', isEqualTo: _selectedPest)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        return Container(
          margin: const EdgeInsets.only(top: 16),
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showSubmissionsDialog,
            icon: const Icon(Icons.assignment),
            label: Text('View Student Answers ($count)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryGreen,
              side: BorderSide(color: primaryGreen, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
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
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHeadteacher ? 'Pest Observation Form (View Only)' : 'Report Pest Observation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop Affected', border: OutlineInputBorder()),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedCrop = v;
                        _selectedStage = null;
                        _selectedPest = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedStage,
              decoration: const InputDecoration(labelText: 'Growth Stage', border: OutlineInputBorder()),
              items: _selectedCrop == null ? [] : cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedStage = v;
                        _selectedPest = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedPest,
              decoration: const InputDecoration(labelText: 'Pest Observed', border: OutlineInputBorder()),
              items: _selectedCrop == null || _selectedStage == null
                  ? []
                  : cropStagePests[_selectedCrop]![_selectedStage]!
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
              onChanged: _canEdit ? (v) => setState(() => _selectedPest = v) : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),

            if (imagePath != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Image.asset(
                  imagePath,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported, size: 100),
                ),
              ),
            ],

            _buildTeacherHints(),
            _buildStudentSubmissionSection(),
            _buildPersistentStudentView(),  // Shows grade, feedback, and hints
            _buildViewSubmissionsButton(),

            if (isTeacher) ...[
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
            ],

            const SizedBox(height: 32),
            if (_canEdit && isTeacher)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.send),
                  label: Text(_editingId == null ? 'Submit Observation' : 'Update Entry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),

            if (_editingId != null && _canEdit)
              Center(
                child: TextButton(
                  onPressed: _resetForm,
                  child: const Text('Cancel Edit', style: TextStyle(color: Colors.red)),
                ),
              ),

            const SizedBox(height: 40),
            const Text('Recent Pest Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen)),
            const Divider(),

            if (_collection == null)
              const Center(child: Text('Viewing form only — no class selected'))
            else
              StreamBuilder<QuerySnapshot>(
                stream: _collection!.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: primaryGreen));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No pest reports yet'));
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                      final id = snapshot.data!.docs[index].id;
                      final timestamp = data['createdAt'] as Timestamp?;
                      final dateStr = timestamp != null ? timestamp.toDate().toLocal().toString().split(' ')[0] : 'No date';

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: ListTile(
                          title: Text('${data['cropType']} - ${data['cropStage']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Pest: ${data['pestName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (data['intervention']?.toString().isNotEmpty == true)
                                Text('Intervention: ${data['intervention']}'),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_canEdit && isTeacher) ...[
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editEntry(id, data)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEntry(id)),
                              ],
                              Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
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