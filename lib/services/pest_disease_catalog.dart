// lib/services/pest_disease_catalog.dart
//
// Which pests and diseases occur on each crop, by growth stage. The Pest
// and Disease Management screens pick from these, and Field Agronomists
// use them to list what farmers should check for in an advisory — so a
// pest named in an advisory opens straight on the right library entry.

const Map<String, Map<String, List<String>>> kCropStagePests = {
  'Beans': {
    'Germination/Seedling': ['Bean Fly', 'Cutworms', 'Rodents', 'Termites'],
    'Vegetative Growth/Weeding': [
      'Aphids',
      'Leafhoppers',
      'Thrips',
      'Whiteflies',
      'Beetles',
      'Rodents',
    ],
    'Flowering/Reproductive': [
      'Aphids',
      'Leafhoppers',
      'Thrips',
      'Pod Borers',
      'Whiteflies',
    ],
    'Maturation/Harvesting': [
      'Pod Borers',
      'Beetles',
      'Bean Weevil',
      'Bruchid Beetles',
      'Rodents',
    ],
    'Storage': ['Bean Weevil', 'Bruchid Beetles', 'Rodents'],
  },
  'Maize': {
    'Germination/Seedling': [
      'Termites',
      'Cutworms',
      'Maize Shoot Fly',
      'Rodents',
    ],
    'Vegetative Growth/Weeding': [
      'Aphids',
      'Stem Borers',
      'Armyworms',
      'Leafhoppers',
      'Grasshoppers',
      'Thrips',
      'Rodents',
    ],
    'Flowering/Reproductive': [
      'Aphids',
      'Stem Borers',
      'Armyworms',
      'Leafhoppers',
      'Grasshoppers',
      'Earworms',
      'Thrips',
      'Birds',
    ],
    'Maturation/Harvesting': ['Earworms', 'Weevils', 'Birds', 'Rodents'],
    'Storage': [
      'Larger Grain Borer',
      'Angoumois Grain Moth',
      'Weevils',
      'Rodents',
    ],
  },
  'Cabbages/Kales': {
    'Germination/Seedling': [
      'Termites',
      'Cutworms',
      'Root Maggots',
      'Flea Beetles',
    ],
    'Vegetative Growth/Weeding': [
      'Aphids',
      'Whiteflies',
      'Diamondback Moth',
      'Cabbage Looper',
      'Cutworms',
      'Flea Beetles',
      'Armyworms',
      'Rodents',
    ],
    'Flowering/Reproductive': [
      'Aphids',
      'Whiteflies',
      'Thrips',
      'Diamondback Moth',
      'Stink Bug',
    ],
    'Maturation/Harvesting': [
      'Diamondback Moth',
      'Cabbage Looper',
      'Leafminers',
      'Stink Bug',
      'Rodents',
    ],
    'Storage': ['Rodents', 'Aphids'],
  },
  'Carrots': {
    'Germination/Seedling': [
      'Termites',
      'Cutworms',
      'Nematodes',
      'Wireworms',
      'Rodents',
    ],
    'Vegetative Growth/Weeding': [
      'Aphids',
      'Whiteflies',
      'Thrips',
      'Leafminers',
      'Carrot Rust Fly',
      'Nematodes',
      'Armyworms',
      'Rodents',
    ],
    'Maturation/Harvesting': [
      'Aphids',
      'Thrips',
      'Carrot Rust Fly',
      'Nematodes',
      'Wireworms',
      'Rodents',
    ],
    'Storage': ['Carrot Rust Fly', 'Nematodes', 'Rodents'],
  },
  'Tomatoes': {
    'Germination/Seedling': ['Cutworms', 'Termites', 'Rodents', 'Nematodes'],
    'Vegetative Growth/Weeding': [
      'Aphids',
      'Whiteflies',
      'Thrips',
      'Leafminers',
      'Spider Mites',
      'Nematodes',
      'Rodents',
    ],
    'Flowering/Reproductive': [
      'Aphids',
      'Whiteflies',
      'Thrips',
      'Spider Mites',
      'Stink Bugs',
      'Fruit Borers',
      'Bollworms',
      'Nematodes',
      'Rodents',
    ],
    'Maturation/Harvesting': [
      'Fruitflies',
      'Stink Bugs',
      'Rodents',
      'Fruit Borers',
      'Bollworms',
      'Leafminers',
      'Spider Mites',
      'Nematodes',
    ],
    'Storage': ['Fruit Flies', 'Stink Bugs', 'Rodents'],
  },
  'Onions': {
    'Germination/Seedling': ['Aphids', 'Thrips'],
    'Vegetative Growth/Weeding': ['Thrips', 'Aphids'],
    'Bulb Formation/Reproductive': ['Bulb Fly', 'Maggots'],
    'Bulbing/Maturation': ['Maggots', 'Thrips', 'Bulb Fly'],
    'Harvesting/Storage': ['Maggots', 'Rodents', 'Bulb Fly'],
  },
  'Irish Potatoes': {
    'Early Growth': ['Wireworms', 'Cutworms'],
    'Tuber Initiation': ['Colorado Potato Beetle', 'Aphids', 'Spider Mites'],
    'Tuber Bulking': ['Aphids', 'Leaf Hoppers', 'Flea Beetles', 'Spider Mites'],
    'Maturation/Harvesting': [
      'Colorado Potato Beetle',
      'Aphids',
      'Wireworms',
      'Cutworms',
      'Spider Mites',
    ],
  },
};

const Map<String, Map<String, List<String>>> kCropStageDiseases = {
  'Beans': {
    'Germination/Seedling': [
      'Fusarium Root Rot',
      'Rhizoctonia Root Rot',
      'Pythium Root Rot',
      'Damping-Off',
    ],
    'Vegetative Growth/Weeding': [
      'Anthracnose',
      'Angular Leaf Spot',
      'Common Bacterial Blight',
      'Halo Blight',
      'Bean Rust',
      'Powdery Mildew',
      'Bean Common Mosaic Virus',
      'Bean Golden Yellow Mosaic Virus',
      'Root Knot Nematodes',
      'Bacterial Wilt',
    ],
    'Flowering/Reproductive': [
      'Anthracnose',
      'Angular Leaf Spot',
      'Bean Rust',
      'Powdery Mildew',
      'Bean Common Mosaic Virus',
      'Bean Golden Yellow Mosaic Virus',
      'Ascochyta Blight',
      'Sclerotinia White Mold',
      'Bacterial Wilt',
    ],
    'Maturation/Harvesting': [
      'Anthracnose',
      'Ascochyta Blight',
      'Sclerotinia White Mold',
      'Brown Spot',
      'Fusarium Wilt',
      'Web Blight',
    ],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Maize': {
    'Germination/Seedling': ['Pythium Root Rot', 'Damping-Off'],
    'Vegetative Growth/Weeding': [
      'Gray Leaf Spot',
      'Common Rust',
      'Northern Corn Leaf Blight',
      'Maize Dwarf Mosaic Virus',
      'Bacterial Leaf Streak',
      'Anthracnose Leaf Blight',
      "Stewart's Wilt",
      'Maize Streak Virus',
    ],
    'Flowering/Reproductive': [
      'Gray Leaf Spot',
      'Common Rust',
      'Southern Corn Leaf Blight',
      'Northern Corn Leaf Blight',
      'Maize Dwarf Mosaic Virus',
      'Tar Spot',
      'Downy Mildew',
      'Maize Streak Virus',
    ],
    'Maturation/Harvesting': [
      'Maize Lethal Necrosis',
      'Head Smut',
      'Common Smut',
      "Goss's Wilt",
      'Fusarium Ear Rot',
      'Gibberella Ear Rot',
      'Diplodia Ear Rot',
      'Aspergillus Ear Rot',
      'Bacterial Stalk Rot',
      'Charcoal Rot',
    ],
    'Storage': [
      'Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)',
      'Storage Rot',
    ],
  },
  'Cabbages/Kales': {
    'Germination/Seedling': ['Damping-Off', 'Black Rot', 'Downy Mildew'],
    'Vegetative Growth/Weeding': [
      'Black Rot',
      'Downy Mildew',
      'Powdery Mildew',
      'Alternaria Leaf Spot',
      'Ring Spot',
      'Bacterial Soft Rot',
      'Fusarium Yellows',
      'White Rust',
      'Leaf Blight',
      'Black Leg',
    ],
    'Flowering/Reproductive': [
      'Downy Mildew',
      'Powdery Mildew',
      'Alternaria Leaf Spot',
      'Sclerotinia Stem Rot (White Mold)',
      'Anthracnose',
    ],
    'Maturation/Harvesting': [
      'Black Rot',
      'Sclerotinia Stem Rot (White Mold)',
      'Bacterial Soft Rot',
      'Anthracnose',
    ],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Carrots': {
    'Germination/Seedling': [
      'Damping-Off',
      'Fusarium Root Rot',
      'Rhizoctonia Root Rot',
      'Pythium Root Rot',
    ],
    'Vegetative Growth/Weeding': [
      'Alternaria Leaf Blight',
      'Cercospora Leaf Blight',
      'Powdery Mildew',
      'Downy Mildew',
      'Bacterial Leaf Blight',
      'Root Knot Nematodes',
      'Carrot Mosaic Virus',
      'Aster Yellows',
    ],
    'Maturation/Harvesting': [
      'Sclerotinia White Mold',
      'Fusarium Root Rot',
      'Rhizoctonia Root Rot',
      'Soft Rot',
      'Black Rot',
    ],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Tomatoes': {
    'Germination/Seedling': [
      'Damping-Off',
      'Fusarium Wilt',
      'Verticillium Wilt',
      'Bacterial Wilt',
    ],
    'Vegetative Growth/Weeding': [
      'Early Blight',
      'Bacterial Spot',
      'Bacterial Canker',
      'Powdery Mildew',
      'Mosaic Virus',
      'Yellow Leaf Curl Virus',
      'Root Knot Nematodes',
      'Spotted Wilt Virus',
      'Septoria Leaf Spot',
    ],
    'Flowering/Reproductive': [
      'Early Blight',
      'Late Blight',
      'Bacterial Spot',
      'Bacterial Canker',
      'Powdery Mildew',
      'Mosaic Virus',
      'Yellow Leaf Curl Virus',
      'Spotted Wilt Virus',
      'Gray Mold (Botrytis)',
      'Alternaria Stem Canker',
    ],
    'Maturation/Harvesting': [
      'Late Blight',
      'Anthracnose',
      'Early Blight',
      'Southern Blight',
      'Fruit Rot',
      'Gray Mold (Botrytis)',
    ],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
  'Onions': {
    'Germination/Seedling': ['Pythium Root Rot', 'Fusarium Basal Rot'],
    'Vegetative Growth/Weeding': [
      'Downy Mildew',
      'Powdery Mildew',
      'Leaf Blight',
    ],
    'Bulb Formation/Reproductive': ['Purple Blotch', 'Fusarium Basal Rot'],
    'Bulbing/Maturation': ['Gray Mold', 'Neck Rot', 'Purple Blotch'],
    'Harvesting/Storage': ['Gray Mold', 'Post-Harvest Fungal Rot'],
  },
  'Irish Potatoes': {
    'Germination/Seedling': ['Pythium Damping-Off'],
    'Vegetative Growth/Weeding': [
      'Early Blight',
      'Late Blight',
      'Powdery Scab',
      'Black Scurf',
    ],
    'Tuber Formation': [
      'Early Blight',
      'Late Blight',
      'Powdery Scab',
      'Black Scurf',
    ],
    'Maturation': [
      'Early Blight',
      'Late Blight',
      'Powdery Scab',
      'Black Scurf',
    ],
    'Storage': ['Post-Harvest Fungal Rot'],
  },
};

/// Crop names as the pest / disease libraries spell them.
const kCatalogCrops = [
  'Beans',
  'Maize',
  'Cabbages/Kales',
  'Carrots',
  'Tomatoes',
  'Onions',
  'Irish Potatoes',
];

/// The library's spelling of [crop]: Cabbages, Kales and Chinese cabbage
/// share the 'Cabbages/Kales' lists.
String catalogCropFor(String crop) =>
    const {'Cabbages', 'Kales', 'Chinese Cabbage'}.contains(crop) ? 'Cabbages/Kales' : crop;

List<String> _all(
  Map<String, Map<String, List<String>>> m,
  Iterable<String> crops,
) {
  final out = <String>{};
  for (final c in crops) {
    for (final list in (m[catalogCropFor(c)] ?? const {}).values) {
      out.addAll(list);
    }
  }
  return out.toList()..sort();
}

/// Pests seen on any of [crops] (every catalogued crop when empty).
List<String> pestsForCrops(Iterable<String> crops) =>
    _all(kCropStagePests, crops.isEmpty ? kCatalogCrops : crops);

/// Diseases seen on any of [crops] (every catalogued crop when empty).
List<String> diseasesForCrops(Iterable<String> crops) =>
    _all(kCropStageDiseases, crops.isEmpty ? kCatalogCrops : crops);

/// First growth stage of [crop] where [name] appears, so a library page can
/// open pre-selected. Null when the catalogue doesn't list it.
String? catalogStageFor(String crop, String name, {required bool pest}) {
  final m = (pest ? kCropStagePests : kCropStageDiseases)[catalogCropFor(crop)];
  if (m == null) return null;
  for (final e in m.entries) {
    if (e.value.any((v) => v.toLowerCase() == name.toLowerCase())) return e.key;
  }
  return null;
}
