// lib/services/kindwise_name_mapper.dart
//
// Maps names returned by the Kindwise API to the EXACT strings
// used as keys in your _pestDetails and _diseaseDetails maps.
// If a name is not in the map, the AI result is shown directly
// using Kindwise's own treatment text (graceful fallback).

class KindwiseNameMapper {
  // ── PEST NAME MAP ─────────────────────────────────────────────────────────
  // Key   = what Kindwise may return (lowercase for matching)
  // Value = your exact pest key string in _cropStagePests
  static const Map<String, String> _pestNames = {
    // Stem borers / borers
    'busseola fusca': 'Stem Borers',
    'chilo partellus': 'Stem Borers',
    'stem borer': 'Stem Borers',
    'stem borers': 'Stem Borers',
    'maize stem borer': 'Stem Borers',
    'spotted stem borer': 'Stem Borers',
    'african maize stem borer': 'Stem Borers',
    // Armyworms
    'fall armyworm': 'Armyworms',
    'spodoptera frugiperda': 'Armyworms',
    'spodoptera exempta': 'Armyworms',
    'armyworm': 'Armyworms',
    'armyworms': 'Armyworms',
    'african armyworm': 'Armyworms',
    // Aphids
    'aphid': 'Aphids',
    'aphids': 'Aphids',
    'aphis fabae': 'Aphids',
    'myzus persicae': 'Aphids',
    'rhopalosiphum maidis': 'Aphids',
    'maize aphid': 'Aphids',
    'bean aphid': 'Aphids',
    'cabbage aphid': 'Aphids',
    'tomato aphid': 'Aphids',
    // Whiteflies
    'whitefly': 'Whiteflies',
    'whiteflies': 'Whiteflies',
    'bemisia tabaci': 'Whiteflies',
    'trialeurodes vaporariorum': 'Whiteflies',
    // Thrips
    'thrip': 'Thrips',
    'thrips': 'Thrips',
    'frankliniella occidentalis': 'Thrips',
    'thrips tabaci': 'Thrips',
    // Diamondback moth
    'diamondback moth': 'Diamondback Moth',
    'plutella xylostella': 'Diamondback Moth',
    // Cutworms
    'cutworm': 'Cutworms',
    'cutworms': 'Cutworms',
    'agrotis ipsilon': 'Cutworms',
    // Earworms
    'earworm': 'Earworms',
    'helicoverpa zea': 'Earworms',
    'corn earworm': 'Earworms',
    // Pod borers
    'pod borer': 'Pod Borers',
    'pod borers': 'Pod Borers',
    'maruca vitrata': 'Pod Borers',
    // Spider mites
    'spider mite': 'Spider Mites',
    'spider mites': 'Spider Mites',
    'tetranychus urticae': 'Spider Mites',
    // Fruit borers / bollworms
    'tomato fruit borer': 'Fruit Borers',
    'fruit borer': 'Fruit Borers',
    'fruit borers': 'Fruit Borers',
    'bollworm': 'Bollworms',
    'bollworms': 'Bollworms',
    'helicoverpa armigera': 'Bollworms',
    // Leafminers
    'leafminer': 'Leafminers',
    'leafminers': 'Leafminers',
    'liriomyza': 'Leafminers',
    // Termites
    'termite': 'Termites',
    'termites': 'Termites',
    // Bean fly
    'bean fly': 'Bean Fly',
    'ophiomyia phaseoli': 'Bean Fly',
    // Weevils
    'bean weevil': 'Bean Weevil',
    'acanthoscelides obtectus': 'Bean Weevil',
    'maize weevil': 'Weevils',
    'sitophilus zeamais': 'Weevils',
    'weevil': 'Weevils',
    'weevils': 'Weevils',
    // Larger grain borer
    'larger grain borer': 'Larger Grain Borer',
    'prostephanus truncatus': 'Larger Grain Borer',
    // Tomato hornworm
    'tomato hornworm': 'Tomato Hornworms',
    'manduca quinquemaculata': 'Tomato Hornworms',
    // Fruit fly
    'fruit fly': 'Fruitflies',
    'fruit flies': 'Fruitflies',
    'fruitfly': 'Fruitflies',
    'bactrocera': 'Fruitflies',
    // Stink bugs
    'stink bug': 'Stink Bugs',
    'stink bugs': 'Stink Bugs',
    // Cabbage looper
    'cabbage looper': 'Cabbage Looper',
    'trichoplusia ni': 'Cabbage Looper',
    // Root maggots
    'root maggot': 'Root Maggots',
    'cabbage root maggot': 'Cabbage Root Maggot',
    'delia radicum': 'Root Maggots',
    // Carrot rust fly
    'carrot rust fly': 'Carrot Rust Fly',
    'psila rosae': 'Carrot Rust Fly',
    // Wireworms
    'wireworm': 'Wireworms',
    'wireworms': 'Wireworms',
    'agriotes': 'Wireworms',
    // Colorado potato beetle
    'colorado potato beetle': 'Colorado Potato Beetle',
    'leptinotarsa decemlineata': 'Colorado Potato Beetle',
    // Flea beetles
    'flea beetle': 'Flea Beetles',
    'flea beetles': 'Flea Beetles',
    // Nematodes
    'root knot nematode': 'Nematodes',
    'nematode': 'Nematodes',
    'nematodes': 'Nematodes',
    'meloidogyne': 'Nematodes',
    // Rodents
    'rodent': 'Rodents',
    'rodents': 'Rodents',
    'rat': 'Rodents',
    'mouse': 'Rodents',
    // Onion bulb fly
    'bulb fly': 'Bulb Fly',
    'onion fly': 'Bulb Fly',
    'delia antiqua': 'Bulb Fly',
    // Onion maggots
    'maggot': 'Maggots',
    'maggots': 'Maggots',
    // Leafhoppers
    'leafhopper': 'Leafhoppers',
    'leafhoppers': 'Leafhoppers',
    // Grasshoppers
    'grasshopper': 'Grasshoppers',
    'grasshoppers': 'Grasshoppers',
    // Bruchid beetles
    'bruchid': 'Bruchid Beetles',
    'bruchid beetle': 'Bruchid Beetles',
    'bruchid beetles': 'Bruchid Beetles',
    'bruchus rufimanus': 'Bruchid Beetles',
  };

  // ── DISEASE NAME MAP ───────────────────────────────────────────────────────
  static const Map<String, String> _diseaseNames = {
    // Early blight
    'early blight': 'Early Blight',
    'alternaria solani': 'Early Blight',
    // Late blight
    'late blight': 'Late Blight',
    'phytophthora infestans': 'Late Blight',
    // Anthracnose
    'anthracnose': 'Anthracnose',
    'colletotrichum': 'Anthracnose',
    // Gray leaf spot
    'gray leaf spot': 'Gray Leaf Spot',
    'cercospora zeae-maydis': 'Gray Leaf Spot',
    'grey leaf spot': 'Gray Leaf Spot',
    // Common rust
    'common rust': 'Common Rust',
    'puccinia sorghi': 'Common Rust',
    // Northern corn leaf blight
    'northern corn leaf blight': 'Northern Corn Leaf Blight',
    'turcicum leaf blight': 'Northern Corn Leaf Blight',
    'setosphaeria turcica': 'Northern Corn Leaf Blight',
    // Powdery mildew
    'powdery mildew': 'Powdery Mildew',
    'erysiphe': 'Powdery Mildew',
    'podosphaera': 'Powdery Mildew',
    // Downy mildew
    'downy mildew': 'Downy Mildew',
    'peronospora': 'Downy Mildew',
    'pseudoperonospora': 'Downy Mildew',
    // Fusarium wilt
    'fusarium wilt': 'Fusarium Wilt',
    'fusarium oxysporum': 'Fusarium Wilt',
    // Fusarium root rot
    'fusarium root rot': 'Fusarium Root Rot',
    // Damping off
    'damping off': 'Damping-Off',
    'damping-off': 'Damping-Off',
    'pythium damping-off': 'Damping-Off',
    // Bacterial wilt
    'bacterial wilt': 'Bacterial Wilt',
    'ralstonia solanacearum': 'Bacterial Wilt',
    // Bacterial spot
    'bacterial spot': 'Bacterial Spot',
    'xanthomonas': 'Bacterial Spot',
    // Black rot
    'black rot': 'Black Rot',
    'xanthomonas campestris': 'Black Rot',
    // Alternaria leaf blight / spot
    'alternaria leaf blight': 'Alternaria Leaf Blight',
    'alternaria leaf spot': 'Alternaria Leaf Spot',
    'alternaria': 'Alternaria Leaf Spot',
    // Angular leaf spot
    'angular leaf spot': 'Angular Leaf Spot',
    'phaeoisariopsis griseola': 'Angular Leaf Spot',
    // Common bacterial blight
    'common bacterial blight': 'Common Bacterial Blight',
    'xanthomonas axonopodis': 'Common Bacterial Blight',
    // Bean rust
    'bean rust': 'Bean Rust',
    'uromyces appendiculatus': 'Bean Rust',
    // Mosaic virus
    'bean common mosaic virus': 'Bean Common Mosaic Virus',
    'mosaic virus': 'Mosaic Virus',
    'mosaic': 'Mosaic Virus',
    // Yellow leaf curl
    'yellow leaf curl': 'Yellow Leaf Curl Virus',
    'tomato yellow leaf curl': 'Yellow Leaf Curl Virus',
    // Gray mold
    'gray mold': 'Gray Mold (Botrytis)',
    'grey mold': 'Gray Mold (Botrytis)',
    'botrytis': 'Gray Mold (Botrytis)',
    'botrytis cinerea': 'Gray Mold (Botrytis)',
    // Sclerotinia
    'sclerotinia': 'Sclerotinia White Mold',
    'white mold': 'Sclerotinia White Mold',
    'sclerotinia white mold': 'Sclerotinia White Mold',
    // Pythium root rot
    'pythium root rot': 'Pythium Root Rot',
    'pythium': 'Pythium Root Rot',
    // Rhizoctonia root rot
    'rhizoctonia root rot': 'Rhizoctonia Root Rot',
    'rhizoctonia': 'Rhizoctonia Root Rot',
    // Maize streak virus
    'maize streak virus': 'Maize Streak Virus',
    // Maize lethal necrosis
    'maize lethal necrosis': 'Maize Lethal Necrosis',
    // Aspergillus ear rot
    'aspergillus ear rot': 'Aspergillus Ear Rot',
    'aspergillus': 'Aspergillus Ear Rot',
    // Fusarium ear rot
    'fusarium ear rot': 'Fusarium Ear Rot',
    // Septoria leaf spot
    'septoria leaf spot': 'Septoria Leaf Spot',
    'septoria': 'Septoria Leaf Spot',
    // Black leg
    'black leg': 'Black Leg',
    'leptosphaeria maculans': 'Black Leg',
    // Bacterial soft rot
    'bacterial soft rot': 'Bacterial Soft Rot',
    'pectobacterium': 'Bacterial Soft Rot',
    // Purple blotch
    'purple blotch': 'Purple Blotch',
    'alternaria porri': 'Purple Blotch',
    // Neck rot
    'neck rot': 'Neck Rot',
    'botrytis allii': 'Neck Rot',
    // Fusarium basal rot
    'fusarium basal rot': 'Fusarium Basal Rot',
    // Post harvest rot
    'post-harvest': 'Post-Harvest Fungal Rot',
    'storage rot': 'Post-Harvest Fungal Rot',
    // Black scurf
    'black scurf': 'Black Scurf',
    'rhizoctonia solani': 'Black Scurf',
    // Powdery scab
    'powdery scab': 'Powdery Scab',
    // Southern blight
    'southern blight': 'Southern Blight',
    'sclerotium rolfsii': 'Southern Blight',
    // Verticillium wilt
    'verticillium wilt': 'Verticillium Wilt',
    'verticillium': 'Verticillium Wilt',
    // Halo blight
    'halo blight': 'Halo Blight',
    'pseudomonas savastanoi': 'Halo Blight',
    // Ascochyta blight
    'ascochyta blight': 'Ascochyta Blight',
    // Ring spot
    'ring spot': 'Ring Spot',
    // Bacterial canker
    'bacterial canker': 'Bacterial Canker',
    // Fruit rot
    'fruit rot': 'Fruit Rot',
    // Web blight
    'web blight': 'Web Blight',
  };

  // ── CROP NAME MAP ─────────────────────────────────────────────────────────
  // Maps Kindwise crop suggestions to your exact crop dropdown values
  static const Map<String, String> _cropNames = {
    'common bean': 'Beans',
    'bean': 'Beans',
    'phaseolus vulgaris': 'Beans',
    'maize': 'Maize',
    'corn': 'Maize',
    'zea mays': 'Maize',
    'cabbage': 'Cabbages/Kales',
    'kale': 'Cabbages/Kales',
    'brassica oleracea': 'Cabbages/Kales',
    'carrot': 'Carrots',
    'daucus carota': 'Carrots',
    'tomato': 'Tomatoes',
    'solanum lycopersicum': 'Tomatoes',
    'onion': 'Onions',
    'allium cepa': 'Onions',
    'potato': 'Irish Potatoes',
    'irish potato': 'Irish Potatoes',
    'solanum tuberosum': 'Irish Potatoes',
  };

  /// Returns the app's exact pest name string, or null if not mapped.
  static String? mapPestName(String kindwiseName) {
    return _pestNames[kindwiseName.toLowerCase().trim()];
  }

  /// Returns the app's exact disease name string, or null if not mapped.
  static String? mapDiseaseName(String kindwiseName) {
    return _diseaseNames[kindwiseName.toLowerCase().trim()];
  }

  /// Returns the app's exact crop name string, or null if not mapped.
  static String? mapCropName(String kindwiseName) {
    return _cropNames[kindwiseName.toLowerCase().trim()];
  }
}