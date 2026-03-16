// lib/education/pest/disease_data_input.dart

// ignore_for_file: use_build_context_synchronously, body_might_complete_normally_catch_error, deprecated_member_use

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:kilimomkononi/models/education_user.dart';
import 'package:kilimomkononi/utils/firestore_helper.dart';
import 'package:kilimomkononi/education/data/disease_treatments.dart';

const Color primaryGreen = Color(0xFF388E3C);

final List<String> crops = [
  'Beans',
  'Maize',
  'Cabbages/Kales',
  'Carrots',
  'Tomatoes',
  'Onions',
];

final Map<String, List<String>> cropStages = {
  'Beans': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Maize': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Cabbages/Kales': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Carrots': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Maturation/Harvesting', 'Storage'],
  'Tomatoes': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Flowering/Reproductive', 'Maturation/Harvesting', 'Storage'],
  'Onions': ['Germination/Seedling', 'Vegetative Growth/Weeding', 'Bulb Formation/Reproductive', 'Bulbing/Maturation', 'Harvesting/Storage'],
};

final Map<String, Map<String, List<String>>> cropStageDiseases = {
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
    'Maturation/Harvesting': ['Sclerotinia White Mold', 'Fusarium Root Rot', 'Rhizoctonia Root Rot', 'Soft Rot', 'Black Rot'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Tomatoes': {
    'Germination/Seedling': ['Damping-Off', 'Fusarium Wilt', 'Verticillium Wilt', 'Bacterial Wilt'],
    'Vegetative Growth/Weeding': ['Early Blight', 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Root Knot Nematodes', 'Spotted Wilt Virus', 'Septoria Leaf Spot'],
    'Flowering/Reproductive': ['Early Blight', 'Late Blight', 'Bacterial Spot', 'Bacterial Canker', 'Powdery Mildew', 'Mosaic Virus', 'Yellow Leaf Curl Virus', 'Spotted Wilt Virus', 'Gray Mold (Botrytis)', 'Alternaria Stem Canker'],
    'Maturation/Harvesting': ['Late Blight', 'Anthracnose', 'Early Blight', 'Southern Blight', 'Fruit Rot', 'Gray Mold (Botrytis)'],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Onions': {
    'Germination/Seedling': ['Pythium Root Rot', 'Fusarium Basal Rot'],
    'Vegetative Growth/Weeding': ['Downy Mildew', 'Powdery Mildew', 'Leaf Blight'],
    'Bulb Formation/Reproductive': ['Purple Blotch', 'Fusarium Basal Rot'],
    'Bulbing/Maturation': ['Gray Mold', 'Neck Rot', 'Purple Blotch'],
    'Harvesting/Storage': ['Gray Mold', 'Post-Harvest Fungal Rot'],
  },
};                                          

final Map<String, Map<String, dynamic>> diseaseDetails = {
  'Beans_Germination/Seedling_Fusarium Root Rot': {'imagePath': 'assets/diseases/beans_fusarium_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Rhizoctonia Root Rot': {'imagePath': 'assets/diseases/beans_rhizoctonia_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Pythium Root Rot': {'imagePath': 'assets/diseases/beans_pythium_root_rot_germination.jpg'},
  'Beans_Germination/Seedling_Damping-Off': {'imagePath': 'assets/diseases/beans_damping_off_germination.jpg'},
  'Beans_Vegetative Growth/Weeding_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_vegetative_growth.jpg'},
   'Beans_Vegetative Growth/Weeding_Angular Leaf Spot': {
    'imagePath': 'assets/diseases/beans_angular_leaf_spot_vegetative_growth.jpg'},
   'Beans_Vegetative Growth/Weeding_Common Bacterial Blight': {
    'imagePath': 'assets/diseases/beans_common_bacterial_blight_vegetative_growth.jpg'},
   'Beans_Vegetative Growth/Weeding_Halo Blight': {
    'imagePath': 'assets/diseases/beans_halo_blight_vegetative_growth.jpg'},
   'Beans_Vegetative Growth/Weeding_Bean Rust': {
    'imagePath': 'assets/diseases/beans_rust_vegetative_growth.jpg'}, 
    'Beans_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/beans_powdery_mildew_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Bean Common Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_common_mosaic_virus_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Bean Golden Yellow Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_vegetative_growth.jpg'},
     'Beans_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'imagePath': 'assets/diseases/beans_root_knot_nematodes_vegetative_growth.jpg'},
    'Beans_Vegetative Growth/Weeding_Bacterial Wilt': {
    'imagePath': 'assets/diseases/beans_bacterial_wilt_vegetative_growth.jpg'},
     'Beans_Flowering/Reproductive_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_flowering.jpg'},
     'Beans_Flowering/Reproductive_Angular Leaf Spot': {
    'imagePath': 'assets/diseases/beans_angular_leaf_spot_flowering.jpg'},
    'Beans_Flowering/Reproductive_Bean Rust': {
    'imagePath': 'assets/diseases/beans_rust_flowering.jpg'},
    'Beans_Flowering/Reproductive_Powdery Mildew': {
    'imagePath': 'assets/diseases/beans_powdery_mildew_flowering.jpg'},
    'Beans_Flowering/Reproductive_Bean Common Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_common_mosaic_virus_flowering.jpg'},
   'Beans_Flowering/Reproductive_Bean Golden Yellow Mosaic Virus': {
    'imagePath': 'assets/diseases/beans_golden_yellow_mosaic_virus_flowering.jpg'},
    'Beans_Flowering/Reproductive_Ascochyta Blight': {
    'imagePath': 'assets/diseases/beans_ascochyta_blight_flowering.jpg'},
     'Beans_Flowering/Reproductive_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_flowering.jpg'},
    'Beans_Flowering/Reproductive_Bacterial Wilt': {
    'imagePath': 'assets/diseases/beans_bacterial_wilt_flowering.jpg'},
   'Beans_Maturation/Harvesting_Anthracnose': {
    'imagePath': 'assets/diseases/beans_anthracnose_harvesting.jpg'},
    'Beans_Maturation/Harvesting_Ascochyta Blight': {
    'imagePath': 'assets/diseases/beans_ascochyta_blight_harvesting.jpg'},
    'Beans_Maturation/Harvesting_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/beans_sclerotinia_white_mold_harvesting.jpg'},
    'Beans_Maturation/Harvesting_Brown Spot': {
    'imagePath': 'assets/diseases/beans_brown_spot_harvesting.jpg'},
    'Beans_Maturation/Harvesting_Fusarium Wilt': {
    'imagePath': 'assets/diseases/beans_fusarium_wilt_harvesting.jpg'},
   'Beans_Maturation/Harvesting_Web Blight': {
    'imagePath': 'assets/diseases/beans_web_blight_harvesting.jpg'},
    'Beans_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/beans_post_harvest_fungal_rot_storage.jpg'},
   'Maize_Germination/Seedling_Pythium Root Rot': {
    'imagePath': 'assets/diseases/maize_pythium_root_rot_germination.jpg'},
    'Maize_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/maize_damping_off_germination.jpg'},
    'Maize_Vegetative Growth/Weeding_Gray Leaf Spot': {
    'imagePath': 'assets/diseases/maize_gray_leaf_spot_vegetative_growth.jpg'},
     'Maize_Vegetative Growth/Weeding_Common Rust': {
    'imagePath': 'assets/diseases/maize_common_rust_vegetative_growth.jpg'},
     'Maize_Vegetative Growth/Weeding_Northern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_vegetative_growth.jpg'},
    'Maize_Vegetative Growth/Weeding_Maize Dwarf Mosaic Virus': {
    'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_vegetative_growth.jpg'},
    'Maize_Vegetative Growth/Weeding_Bacterial Leaf Streak': {
    'imagePath': 'assets/diseases/maize_bacterial_leaf_streak_vegetative_growth.jpg'},
    'Maize_Vegetative Growth/Weeding_Anthracnose Leaf Blight': {
    'imagePath': 'assets/diseases/maize_anthracnose_leaf_blight_vegetative_growth.jpg'},
     'Maize_Vegetative Growth/Weeding_Stewart\'s Wilt': {
    'imagePath': 'assets/diseases/maize_stewarts_wilt_vegetative_growth.jpg'},
   'Maize_Vegetative Growth/Weeding_Maize Streak Virus': {
    'imagePath': 'assets/diseases/maize_streak_virus_vegetative_growth.jpg'},
    'Maize_Flowering/Reproductive_Gray Leaf Spot': {
    'imagePath': 'assets/diseases/maize_gray_leaf_spot_flowering.jpg'},
    'Maize_Flowering/Reproductive_Common Rust': {
    'imagePath': 'assets/diseases/maize_common_rust_flowering.jpg'},
     'Maize_Flowering/Reproductive_Southern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_southern_corn_leaf_blight_flowering.jpg'},
    'Maize_Flowering/Reproductive_Northern Corn Leaf Blight': {
    'imagePath': 'assets/diseases/maize_northern_corn_leaf_blight_flowering.jpg'},
     'Maize_Flowering/Reproductive_Maize Dwarf Mosaic Virus': {
    'imagePath': 'assets/diseases/maize_dwarf_mosaic_virus_flowering.jpg'},
    'Maize_Flowering/Reproductive_Tar Spot': {
    'imagePath': 'assets/diseases/maize_tar_spot_flowering.jpg'},
     'Maize_Flowering/Reproductive_Downy Mildew': {
    'imagePath': 'assets/diseases/maize_downy_mildew_flowering.jpg'},
    'Maize_Flowering/Reproductive_Maize Streak Virus': {
    'imagePath': 'assets/diseases/maize_streak_virus_flowering.jpg'},
     'Maize_Maturation/Harvesting_Maize Lethal Necrosis': {
    'imagePath': 'assets/diseases/maize_lethal_necrosis_harvesting.jpg'},
    'Maize_Maturation/Harvesting_Head Smut': {
    'imagePath': 'assets/diseases/maize_head_smut_harvesting.jpg'},
     'Maize_Maturation/Harvesting_Common Smut': {
    'imagePath': 'assets/diseases/maize_common_smut_harvesting.jpg'},
   'Maize_Maturation/Harvesting_Goss\'s Wilt': {
    'imagePath': 'assets/diseases/maize_goss_wilt_harvesting.jpg'},
    'Maize_Maturation/Harvesting_Fusarium Ear Rot': {
    'imagePath': 'assets/diseases/maize_fusarium_ear_rot_harvesting.jpg'},
      'Maize_Maturation/Harvesting_Gibberella Ear Rot': {
    'imagePath': 'assets/diseases/maize_giberella_ear_rot_harvesting.jpg'},
     'Maize_Maturation/Harvesting_Diplodia Ear Rot': {
    'imagePath': 'assets/diseases/maize_diplodia_ear_rot_harvesting.jpg'},
    'Maize_Maturation/Harvesting_Aspergillus Ear Rot': {
    'imagePath': 'assets/diseases/maize_aspergillus_ear_rot_harvesting.jpg'},
    'Maize_Maturation/Harvesting_Bacterial Stalk Rot': {
    'imagePath': 'assets/diseases/maize_bacterial_stalk_rot_harvesting.jpg'},
    'Maize_Maturation/Harvesting_Charcoal Rot': {
    'imagePath': 'assets/diseases/maize_charcoal_rot_harvesting.jpg'},
    'Maize_Storage_Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)': {
    'imagePath': 'assets/diseases/maize_post_harvest_mycotoxins_storage.jpg'},
    'Maize_Storage_Storage Rot': {
    'imagePath': 'assets/diseases/maize_storage_rot_storage.jpg'},
     'Cabbages/Kales_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/cabbage_damping_off_germination.jpg'},
    'Cabbages/Kales_Germination/Seedling_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_germination.jpg'},
    'Cabbages/Kales_Germination/Seedling_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_germination.jpg'},
     'Cabbages/Kales_Vegetative Growth/Weeding_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_vegetative_growth.jpg'},
     'Cabbages/Kales_Vegetative Growth/Weeding_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_vegetative_growth.jpg'},
     'Cabbages/Kales_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/cabbage_powdery_mildew_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_Alternaria Leaf Spot': {
    'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_vegetative_growth.jpg'},
     'Cabbages/Kales_Vegetative Growth/Weeding_Ring Spot': {
    'imagePath': 'assets/diseases/cabbage_ring_spot_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_Bacterial Soft Rot': {
    'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_Fusarium Yellows': {
    'imagePath': 'assets/diseases/cabbage_fusarium_yellows_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_White Rust': {
    'imagePath': 'assets/diseases/cabbage_white_rust_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_Leaf Blight': {
    'imagePath': 'assets/diseases/cabbage_leaf_blight_vegetative_growth.jpg'},
    'Cabbages/Kales_Vegetative Growth/Weeding_Black Leg': {
    'imagePath': 'assets/diseases/cabbage_black_leg_vegetative_growth.jpg'},
    'Cabbages/Kales_Flowering/Reproductive_Downy Mildew': {
    'imagePath': 'assets/diseases/cabbage_downy_mildew_flowering.jpg'},
    'Cabbages/Kales_Flowering/Reproductive_Powdery Mildew': {
    'imagePath': 'assets/diseases/cabbage_powdery_mildew_flowering.jpg'},
    'Cabbages/Kales_Flowering/Reproductive_Alternaria Leaf Spot': {
    'imagePath': 'assets/diseases/cabbage_alternaria_leaf_spot_flowering.jpg'},
     'Cabbages/Kales_Flowering/Reproductive_Sclerotinia Stem Rot (White Mold)': {
    'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_flowering.jpg'},
    'Cabbages/Kales_Flowering/Reproductive_Anthracnose': {
    'imagePath': 'assets/diseases/cabbage_anthracnose_flowering.jpg'},
    'Cabbages/Kales_Maturation/Harvesting_Black Rot': {
    'imagePath': 'assets/diseases/cabbage_black_rot_harvesting.jpg'},
    'Cabbages/Kales_Maturation/Harvesting_Sclerotinia Stem Rot (White Mold)': {
    'imagePath': 'assets/diseases/cabbage_sclerotinia_stem_rot_(white_mold)_harvesting.jpg'},
   'Cabbages/Kales_Maturation/Harvesting_Bacterial Soft Rot': {
    'imagePath': 'assets/diseases/cabbage_bacterial_soft_rot_harvesting.jpg'},
     'Cabbages/Kales_Maturation/Harvesting_Anthracnose': {
    'imagePath': 'assets/diseases/cabbage_anthracnose_harvesting.jpg'},
   'Cabbages/Kales_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/cabbage_post_harvest_fungal_rot_storage.jpg'},
     'Carrots_Germination/Seedling_Damping-Off': {
    'imagePath': 'assets/diseases/carrots_damping_off_germination.jpg'},
    'Carrots_Germination/Seedling_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/carrots_fusarium_root_rot_germination.jpg'},
    'Carrots_Germination/Seedling_Rhizoctonia Root Rot': {
    'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_germination.jpg'},
    'Carrots_Germination/Seedling_Pythium Root Rot': {
    'imagePath': 'assets/diseases/carrots_pythium_root_rot_germination.jpg'},
    'Carrots_Vegetative Growth/Weeding_Alternaria Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_alternaria_leaf_blight_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Cercospora Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_cercospora_leaf_blight_vegetative_growth.jpg'},
   'Carrots_Vegetative Growth/Weeding_Powdery Mildew': {
    'imagePath': 'assets/diseases/carrots_powdery_mildew_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Downy Mildew': {
    'imagePath': 'assets/diseases/carrots_downy_mildew_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Bacterial Leaf Blight': {
    'imagePath': 'assets/diseases/carrots_bacterial_leaf_blight_vegetative_growth.jpg'},
     'Carrots_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'imagePath': 'assets/diseases/carrots_root_knot_nematodes_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Carrot Mosaic Virus': {
    'imagePath': 'assets/diseases/carrots_mosaic_virus_vegetative_growth.jpg'},
    'Carrots_Vegetative Growth/Weeding_Aster Yellows': {
    'imagePath': 'assets/diseases/carrots_aster_yellows_vegetative_growth.jpg'},
    'Carrots_Maturation/Harvesting_Sclerotinia White Mold': {
    'imagePath': 'assets/diseases/carrots_sclerotinia_white_mold_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Black Rot': {
    'imagePath': 'assets/diseases/carrots_black_rot_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Soft Rot': {
    'imagePath': 'assets/diseases/carrots_soft_rot_harvesting.jpg'},
     'Carrots_Maturation/Harvesting_Fusarium Root Rot': {
    'imagePath': 'assets/diseases/carrots_fusarium_root_rot_harvesting.jpg'},
    'Carrots_Maturation/Harvesting_Rhizoctonia Root Rot': {
    'imagePath': 'assets/diseases/carrots_rhizoctonia_root_rot_harvesting.jpg'},
    'Carrots_Storage_Post-Harvest Fungal Rot': {
    'imagePath': 'assets/diseases/carrots_post_harvest_fungal_rot_storage.jpg'},
    'Tomatoes_Germination/Seedling_Damping-Off': {
      'imagePath': 'assets/diseases/tomato_damping_off_germination.jpg'},
     'Tomatoes_Germination/Seedling_Bacterial Wilt': {
      'imagePath': 'assets/diseases/tomato_bacterial_wilt_germination.jpg'},
    'Tomatoes_Germination/Seedling_Fusarium Wilt': {
      'imagePath': 'assets/diseases/tomato_fusarium_wilt_germination.jpg'},
      'Tomatoes_Germination/Seedling_Verticillium Wilt': {
      'imagePath': 'assets/diseases/tomato_verticillium_wilt_germination.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_vegetative_growth.jpg'},
       'Tomatoes_Vegetative Growth/Weeding_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_vegetative_growth.jpg'},
     'Tomatoes_Vegetative Growth/Weeding_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_vegetative_growth.jpg'},
     'Tomatoes_Vegetative Growth/Weeding_Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_vegetative_growth.jpg'},
       'Tomatoes_Vegetative Growth/Weeding_Septoria Leaf Spot': {
      'imagePath': 'assets/diseases/tomato_septoria_leaf_spot_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_vegetative_growth.jpg'},
      'Tomatoes_Vegetative Growth/Weeding_Root Knot Nematodes': {
      'imagePath': 'assets/diseases/tomato_root_knot_nematodes_vegetative_growth.jpg'},
       'Tomatoes_Vegetative Growth/Weeding_Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_vegetative_growth.jpg'},
       'Tomatoes_Flowering/Reproductive_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_flowering.jpg'},
        'Tomatoes_Flowering/Reproductive_Bacterial Spot': {
      'imagePath': 'assets/diseases/tomato_bacterial_spot_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Bacterial Canker': {
      'imagePath': 'assets/diseases/tomato_bacterial_canker_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Mosaic Virus': {
      'imagePath': 'assets/diseases/tomato_mosaic_virus_flowering.jpg'},
       'Tomatoes_Flowering/Reproductive_Yellow Leaf Curl Virus': {
      'imagePath': 'assets/diseases/tomato_yellow_leaf_curl_virus_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Powdery Mildew': {
      'imagePath': 'assets/diseases/tomato_powdery_mildew_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Spotted Wilt Virus': {
      'imagePath': 'assets/diseases/tomato_spotted_wilt_virus_flowering.jpg'},
      'Tomatoes_Flowering/Reproductive_Alternaria Stem Canker': {
      'imagePath': 'assets/diseases/tomato_alternaria_stem_canker_flowering.jpg'},
      'Tomatoes_Maturation/Harvesting_Early Blight': {
      'imagePath': 'assets/diseases/tomato_early_blight_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Late Blight': {
      'imagePath': 'assets/diseases/tomato_late_blight_harvesting.jpg'},
       'Tomatoes_Maturation/Harvesting_Gray Mold (Botrytis)': {
      'imagePath': 'assets/diseases/tomato_gray_mold_(botrytis)_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Southern Blight': {
      'imagePath': 'assets/diseases/tomato_southern_blight_harvesting.jpg'},
        'Tomatoes_Maturation/Harvesting_Anthracnose': {
      'imagePath': 'assets/diseases/tomato_anthracnose_harvesting.jpg'},
      'Tomatoes_Maturation/Harvesting_Fruit Rot': {
      'imagePath': 'assets/diseases/tomato_fruit_rot_harvesting.jpg'},
       'Tomatoes_Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/tomato_post_harvest_fungal_rot_storage.jpg'},
      'Onions_Germination/Seedling_Pythium Root Rot': {
      'imagePath': 'assets/diseases/onions_pythium_root_rot_germination.jpg'},
      'Onions_Germination/Seedling_Fusarium Basal Rot': {
      'imagePath': 'assets/diseases/onions_fusarium_basal_rot_germination.jpg'},
       'Onions_Vegetative Growth/Weeding_Downy Mildew': {
      'imagePath': 'assets/diseases/onions_downy_mildew_vegetative_growth.jpg'},
      'Onions_Vegetative Growth/Weeding_Leaf Blight': {
      'imagePath': 'assets/diseases/onions_leaf_blight_vegetative_growth.jpg'},
      'Onions_Vegetative Growth/Weeding_Powdery Mildew': {
      'imagePath': 'assets/diseases/onions_powdery_mildew_vegetative_growth.jpg'},
      'Onions_Bulb Formation/Reproductive_Fusarium Basal Rot': {
      'imagePath': 'assets/diseases/onions_fusarium_basal_rot_bulb_formation.jpg'},
      'Onions_Bulb Formation/Reproductive_Purple Blotch': {
      'imagePath': 'assets/diseases/onions_purple_blotch_bulb_formation.jpg'},
      'Onions_Bulbing/Maturation_Neck Rot': {
      'imagePath': 'assets/diseases/onions_neck_rot_bulbing.jpg'},
      'Onions_Bulbing/Maturation_Purple Blotch': {
      'imagePath': 'assets/diseases/onions_purple_blotch_bulbing.jpg'},
      'Onions_Bulbing/Maturation_Gray Mold': {
      'imagePath': 'assets/diseases/onions_gray_mold_bulbing.jpg'},
      'Onions_Harvesting/Storage_Post-Harvest Fungal Rot': {
      'imagePath': 'assets/diseases/onions_post_harvest_fungal_rot_storage.jpg'},
     'Onions_Harvesting/Storage_Gray Mold': {
      'imagePath': 'assets/diseases/onions_gray_mold_storage.jpg'},
       
};

class DiseaseDataInput extends StatefulWidget {
  final EduRole role;
  final String schoolName;
  final String classId;
  final Map<String, String>? prefillData;

  const DiseaseDataInput({
    super.key,
    required this.role,
    required this.schoolName,
    required this.classId,
    this.prefillData,
  });

  @override
  State<DiseaseDataInput> createState() => _DiseaseDataInputState();
}

class _DiseaseDataInputState extends State<DiseaseDataInput> {
  final _formKey = GlobalKey<FormState>();
  final _submissionFormKey = GlobalKey<FormState>();
  bool _isSaving = false;

  final _interventionCtrl = TextEditingController();
  final _studentNameCtrl = TextEditingController();
  final _studentAnswerCtrl = TextEditingController();

  String? _selectedCrop;
  String? _selectedStage;
  String? _selectedDisease;
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
      _selectedDisease = widget.prefillData!['name'];
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

  CollectionReference? get _collection => widget.classId.isEmpty
      ? null
      : FirestoreHelper.getContentFromClassId(widget.classId, 'disease_data');

  CollectionReference? get _submissionsCollection => widget.classId.isEmpty
      ? null
      : FirestoreHelper.getContentFromClassId(widget.classId, 'disease_submissions');

  bool get _isHeadteacher => widget.role == EduRole.headteacher;
  bool get _canEdit => !_isHeadteacher && _collection != null;

  Future<void> _saveEntry() async {
    if (!_canEdit || !_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'cropType': _selectedCrop,
      'cropStage': _selectedStage,
      'diseaseName': _selectedDisease,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingId == null ? 'Disease entry saved!' : 'Entry updated!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _submitStudentAnswer() async {
    if (!_submissionFormKey.currentState!.validate() || _submissionsCollection == null) return;
    setState(() => _isSaving = true);

    final data = {
      'studentName': _studentNameCtrl.text.trim(),
      'crop': _selectedCrop,
      'stage': _selectedStage,
      'disease': _selectedDisease,
      'studentAnswer': _studentAnswerCtrl.text.trim(),
      'submittedAt': FieldValue.serverTimestamp(),
      'isUnlocked': false,
      'schoolName': widget.schoolName,
    };

    // Show snackbar and clear form IMMEDIATELY — don't wait for Firestore round-trip
    if (mounted) {
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
    }

    // Write to Firestore in the background
    _submissionsCollection!.add(data).catchError((e) {
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
      _selectedDisease = data['diseaseName'];
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
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _collection!.doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted'), backgroundColor: Colors.red));
      }
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _selectedCrop = null;
      _selectedStage = null;
      _selectedDisease = null;
      _interventionCtrl.clear();
    });
    _formKey.currentState?.reset();
  }

  void _showSubmissionsDialog() {
    if (_submissionsCollection == null) return;
    
    final String? crop = _selectedCrop;
    final String? stage = _selectedStage;
    final String? disease = _selectedDisease;
    
    if (crop == null || stage == null || disease == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select crop, stage, and disease first')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DiseaseSubmissionsViewerPage(
          collection: _submissionsCollection!,
          crop: crop,
          stage: stage,
          disease: disease,
          title: 'Disease Submissions',
        ),
      ),
    );
  }

  Widget _buildTeacherHints() {
    if (!isTeacher || _selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      return const SizedBox.shrink();
    }

    final key = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
    final treatments = diseaseTreatments[key];

    if (treatments == null) return const SizedBox.shrink();

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
              Row(
            children: [
              Icon(Icons.school, color: Colors.green.shade700, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'TEACHER REFERENCE – Disease Treatments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20)),
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 2),
          if (treatments['chemicalControl'] != null) ...[
            _buildTreatmentCategory('Chemical Control', treatments['chemicalControl']!, Colors.red.shade700),
            const SizedBox(height: 12),
          ],
          if (treatments['organicControl'] != null) ...[
            _buildTreatmentCategory('Organic Control', treatments['organicControl']!, Colors.green.shade700),
            const SizedBox(height: 12),
          ],
          if (treatments['culturalControl'] != null) ...[
            _buildTreatmentCategory('Cultural / Prevention', treatments['culturalControl']!, Colors.blue.shade700),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber.shade700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Students cannot see these hints',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreatmentCategory(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 6),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(height: 1.4))),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildInterventionCategory(String title, List<String> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item, style: const TextStyle(height: 1.5, fontSize: 14))),
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
    if (_selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      return const SizedBox.shrink();
    }
    
    // Get interventions
    final key = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
    final interventions = diseaseTreatments[key];
    
    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('disease', isEqualTo: _selectedDisease)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          // No submission yet - show nothing
          return const SizedBox.shrink();
        }
        
        // Get the MOST RECENT submission for this crop/stage/disease
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
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: Colors.purple.shade900)),
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
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlockedAnswersView() {
    if (!isStudent) return const SizedBox.shrink();
    if (_selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      return const SizedBox.shrink();
    }
    
    final key = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
    final interventions = diseaseTreatments[key];
    if (interventions == null) return const SizedBox.shrink();
    
    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('disease', isEqualTo: _selectedDisease)
          .where('isUnlocked', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
    if (!isStudent || _selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      return const SizedBox.shrink();
    }

    return Form(
      key: _submissionFormKey,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
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
                    'Submit Your Disease Management Idea',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 2),
            TextFormField(
              controller: _studentNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _studentAnswerCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'What would you do to control / manage this disease?',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) => v?.trim().isEmpty ?? true ? 'Please write your suggestion' : null,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewSubmissionsButton() {
    if (!isTeacher || _selectedCrop == null || _selectedStage == null || _selectedDisease == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _submissionsCollection
          ?.where('crop', isEqualTo: _selectedCrop)
          .where('stage', isEqualTo: _selectedStage)
          .where('disease', isEqualTo: _selectedDisease)
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: OutlinedButton.icon(
            onPressed: _showSubmissionsDialog,
            icon: const Icon(Icons.assignment_outlined),
            label: Text('View Student Answers ($count)'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryGreen,
              side: BorderSide(color: primaryGreen, width: 2),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String? imagePath;
    if (_selectedCrop != null && _selectedStage != null && _selectedDisease != null) {
      final key = '${_selectedCrop}_${_selectedStage}_$_selectedDisease';
      imagePath = diseaseDetails[key]?['imagePath'] as String?;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isHeadteacher ? 'Disease Observation (View Only)' : 'Report Disease Observation',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              initialValue: _selectedCrop,
              decoration: const InputDecoration(labelText: 'Crop', border: OutlineInputBorder()),
              items: crops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedCrop = v;
                        _selectedStage = null;
                        _selectedDisease = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedStage,
              decoration: const InputDecoration(labelText: 'Stage', border: OutlineInputBorder()),
              items: _selectedCrop == null
                  ? []
                  : cropStages[_selectedCrop]!.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: _canEdit
                  ? (v) => setState(() {
                        _selectedStage = v;
                        _selectedDisease = null;
                      })
                  : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedDisease,
              decoration: const InputDecoration(labelText: 'Disease', border: OutlineInputBorder()),
              items: _selectedCrop == null || _selectedStage == null
                  ? []
                  : cropStageDiseases[_selectedCrop]![_selectedStage]!
                      .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                      .toList(),
              onChanged: _canEdit ? (v) => setState(() => _selectedDisease = v) : null,
              validator: _canEdit ? (v) => v == null ? 'Required' : null : null,
            ),

            if (imagePath != null) ...[
              const SizedBox(height: 24),
              Center(
                child: Image.asset(
                  imagePath,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported, size: 120, color: Colors.grey),
                ),
              ),
            ],

            _buildTeacherHints(),
            _buildStudentSubmissionSection(),
            _buildPersistentStudentView(),
            _buildUnlockedAnswersView(),
            _buildViewSubmissionsButton(),

            if (isTeacher) ...[
              const SizedBox(height: 24),
              TextFormField(
                controller: _interventionCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Intervention Taken (optional – teacher only)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 32),
            if (_canEdit && isTeacher)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveEntry,
                  icon: _isSaving ? const CircularProgressIndicator() : const Icon(Icons.save),
                  label: Text(_editingId == null ? 'Save Observation' : 'Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
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
            const Text('Recent Disease Reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            if (_collection == null)
              const Center(child: Text('No class selected'))
            else
              StreamBuilder<QuerySnapshot>(
                stream: _collection!.orderBy('createdAt', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No reports yet'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final doc = snapshot.data!.docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;
                      final ts = (data['createdAt'] as Timestamp?)?.toDate();
                      final date = ts != null ? ts.toString().split(' ')[0] : '—';

                      return Card(
                        child: ListTile(
                          title: Text('${data['cropType']} – ${data['cropStage']}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Disease: ${data['diseaseName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (data['intervention']?.toString().isNotEmpty ?? false)
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
                              Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
// ========== DISEASE SUBMISSIONS VIEWER PAGE ==========
class DiseaseSubmissionsViewerPage extends StatelessWidget {
  final CollectionReference collection;
  final String crop;
  final String stage;
  final String disease;
  final String title;

  const DiseaseSubmissionsViewerPage({
    super.key,
    required this.collection,
    required this.crop,
    required this.stage,
    required this.disease,
    required this.title,
  });

  Future<void> _unlockAll(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Unlock All Answers?'),
        content: const Text('All students will be able to see the correct interventions for this disease.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Unlock All', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final docs = await collection
            .where('crop', isEqualTo: crop)
            .where('stage', isEqualTo: stage)
            .where('disease', isEqualTo: disease)
            .get();

        for (var doc in docs.docs) {
          await doc.reference.update({'isUnlocked': true});
        }

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All answers unlocked!'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _toggleUnlock(BuildContext context, String docId, bool currentStatus) async {
    try {
      await collection.doc(docId).update({'isUnlocked': !currentStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'Answer locked' : 'Answer unlocked'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showReviewDialog(BuildContext context, String docId, Map<String, dynamic> data) async {
    String? selectedGrade = data['teacherGrade'];
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student: ${data['studentName'] ?? ''}',
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
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  value: selectedGrade,
                  items: const [
                    DropdownMenuItem(value: 'correct', child: Text('✓ Correct')),
                    DropdownMenuItem(value: 'needsWork', child: Text('◐ Needs Work')),
                    DropdownMenuItem(value: 'incorrect', child: Text('✗ Incorrect')),
                  ],
                  onChanged: (v) => setDlg(() => selectedGrade = v),
                ),
                const SizedBox(height: 16),
                const Text('Feedback / Question:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: feedbackCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Enter feedback or ask a follow-up question…',
                    border: OutlineInputBorder(),
                  ),
                ),

                if (hasStudentReply) ...[
                  const SizedBox(height: 16),
                  const Text('Follow-up Response:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: followUpCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: "Respond to the student's reply…",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.chat_bubble_outline),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final Map<String, dynamic> update = {
                    'reviewStatus': 'reviewed',
                    'teacherGrade': selectedGrade,
                    'teacherComment': feedbackCtrl.text.trim(),
                  };
                  if (hasStudentReply && followUpCtrl.text.trim().isNotEmpty) {
                    update['teacherFollowUp'] = followUpCtrl.text.trim();
                    update['teacherFollowUpAt'] = FieldValue.serverTimestamp();
                  }
                  await collection.doc(docId).update(update);
                  feedbackCtrl.dispose();
                  followUpCtrl.dispose();
                  if (context.mounted) {
                    Navigator.pop(c);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Review saved!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(Map<String, dynamic> data) {
    if (data['isUnlocked'] == true) return 'Unlocked';
    if (data['reviewStatus'] == 'reviewed') {
      switch (data['teacherGrade']) {
        case 'correct': return 'Correct';
        case 'needsWork': return 'Needs Work';
        case 'incorrect': return 'Incorrect';
        default: return 'Reviewed';
      }
    }
    return 'Pending';
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
                  '$crop → $stage → $disease',
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
                  .where('disease', isEqualTo: disease)
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
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: (data['isUnlocked'] ?? false) 
        ? Colors.green.shade100 
        : Colors.orange.shade100,
    borderRadius: BorderRadius.circular(15),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        (data['isUnlocked'] ?? false) ? Icons.check_circle : Icons.pending,
        size: 14,
        color: (data['isUnlocked'] ?? false) 
            ? Colors.green.shade900 
            : Colors.orange.shade900,
      ),
      const SizedBox(width: 4),
      Text(
        (data['isUnlocked'] ?? false) ? 'Unlocked' : 'Pending',
        style: TextStyle(
          fontSize: 11,
          color: (data['isUnlocked'] ?? false) 
              ? Colors.green.shade900 
              : Colors.orange.shade900,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),
const SizedBox(width: 8),
ElevatedButton.icon(
  onPressed: () => _toggleUnlock(context, doc.id, data['isUnlocked'] ?? false),
  icon: Icon(
    (data['isUnlocked'] ?? false) ? Icons.lock : Icons.lock_open,
    size: 14,
  ),
  label: Text(
    (data['isUnlocked'] ?? false) ? 'Lock' : 'Unlock',
    style: const TextStyle(fontSize: 11),
  ),
  style: ElevatedButton.styleFrom(
    backgroundColor: (data['isUnlocked'] ?? false) 
        ? Colors.grey.shade600 
        : Colors.green.shade600,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    minimumSize: Size.zero,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
),
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