// lib/education/data/disease_treatments.dart
// Complete treatment database for ALL diseases across ALL crops
// Import this file in disease_data_input.dart

/// Teacher-only disease treatment database
/// Maps disease key (Crop_Stage_Disease) to treatment methods
final Map<String, Map<String, List<String>>> diseaseTreatments = {
  
  // ═══════════════════════════════════════════════════════════
  // BEANS DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════
  
  'Beans_Germination/Seedling_Fusarium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment) - Coat seeds before planting',
      'Captan (2g/kg seed) - Seed treatment',
      'Thiram (3g/kg seed) - Seed treatment',
    ],
    'organicControl': [
      'Trichoderma (biological fungicide) - Seed treatment or soil drench',
      'Compost tea - Soil drench at planting',
      'Biochar amendment - Mix into soil before planting',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation - 3-4 years, avoid legumes',
      'Improve soil drainage - Raised beds or drainage channels',
      'Avoid overwatering - Especially in early growth',
      'Plant in warm soil - Above 15°C',
      'Remove and destroy infected seedlings',
      'Solarize soil - Cover with clear plastic for 4-6 weeks',
      'Add organic matter - Improves soil health',
    ],
  },

  'Beans_Germination/Seedling_Rhizoctonia Root Rot': {
    'chemicalControl': [
      'Pencycuron (seed treatment)',
      'Tolclofos-methyl - Soil drench',
      'Azoxystrobin (2ml/L water) - Soil drench',
    ],
    'organicControl': [
      'Trichoderma harzianum - Seed treatment and soil application',
      'Bacillus subtilis - Biological fungicide',
      'Compost - Increases beneficial microorganisms',
    ],
    'culturalControl': [
      'Plant in well-drained soil - Avoid waterlogged conditions',
      'Shallow planting - 2-3cm depth only',
      'Avoid planting in cool, wet soil',
      'Crop rotation - 3 years minimum',
      'Remove crop debris before planting',
      'Use clean, certified seeds',
      'Maintain soil pH 6.0-7.0',
    ],
  },

  'Beans_Germination/Seedling_Pythium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Mefenoxam (1ml/L water) - Soil drench',
      'Fosetyl-Al (3g/L water) - Soil drench',
    ],
    'organicControl': [
      'Trichoderma species - Seed treatment',
      'Bacillus species - Soil drench',
      'Hydrogen peroxide (3%) - Soil drench for seedlings',
    ],
    'culturalControl': [
      'Improve drainage - Critical for prevention',
      'Avoid overwatering - Let soil dry between waterings',
      'Plant in warm soil - Above 18°C',
      'Use raised beds - Better drainage',
      'Crop rotation',
      'Remove infected plants immediately',
      'Sterilize tools between plants',
    ],
  },

  'Beans_Germination/Seedling_Damping-Off': {
    'chemicalControl': [
      'Captan (seed treatment) - 2g per kg seed',
      'Thiram (seed treatment) - 3g per kg seed',
      'Metalaxyl + Mancozeb - Seed treatment',
    ],
    'organicControl': [
      'Trichoderma harzianum - Seed treatment',
      'Cinnamon powder - Light dusting on soil surface',
      'Chamomile tea - Soil drench',
      'Biochar - Mix into soil',
    ],
    'culturalControl': [
      'Use sterile potting mix - For seedling trays',
      'Avoid overcrowding - Good air circulation',
      'Don\'t overwater - Keep soil moist but not wet',
      'Plant in warm conditions - Above 15°C',
      'Provide good drainage',
      'Use clean containers and tools',
      'Remove infected seedlings immediately',
      'Bottom watering - Keeps foliage dry',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Weekly sprays',
      'Mancozeb (40g/20L water) - Preventive application',
      'Azoxystrobin (2ml/L water) - Systemic fungicide',
      'Copper hydroxide (30g/20L water) - Organic copper',
    ],
    'organicControl': [
      'Copper-based fungicides (organic approved)',
      'Neem oil (5ml/L water) - Has fungicidal properties',
      'Baking soda spray (5g/L + 5ml liquid soap)',
      'Garlic extract spray',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation - 3 years minimum, avoid legumes',
      'Remove infected plant debris immediately',
      'Avoid working in wet fields - Spreads spores',
      'Stake or trellis plants - Improve air circulation',
      'Water at base of plants - Keep foliage dry',
      'Plant resistant varieties if available',
      'Wide plant spacing - 30-40cm between plants',
      'Mulch to prevent soil splash',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Angular Leaf Spot': {
    'chemicalControl': [
      'Copper oxychloride (30g/20L water) - Weekly application',
      'Streptomycin sulfate (1g/20L water) - Bacterial disease',
      'Copper hydroxide (30g/20L water)',
    ],
    'organicControl': [
      'Copper-based bactericides (organic)',
      'Hydrogen peroxide (3%) diluted 1:10 - Foliar spray',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Use certified pathogen-free seeds',
      'Hot water seed treatment - 50°C for 10 minutes',
      'Crop rotation - 2-3 years',
      'Remove infected leaves and plants',
      'Avoid overhead irrigation',
      'Work in fields only when dry',
      'Plant resistant varieties',
      'Destroy crop debris after harvest',
      'Good weed control',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Common Bacterial Blight': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Preventive only',
      'Streptomycin (1g/20L water) - Limited effectiveness',
    ],
    'organicControl': [
      'Copper-based products (organic certified)',
      'Hydrogen peroxide spray (3% diluted 1:10)',
    ],
    'culturalControl': [
      'Use certified disease-free seeds - Most important',
      'Hot water seed treatment - 56°C for 30 minutes',
      'Plant resistant varieties - Check with extension',
      'Crop rotation - Minimum 2 years',
      'Remove and destroy infected plants',
      'Don\'t work in wet fields',
      'Avoid overhead irrigation',
      'Control weeds and volunteer beans',
      'Destroy crop residue',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Halo Blight': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Preventive',
      'Streptomycin sulfate (1g/20L water) - Early stages',
    ],
    'organicControl': [
      'Copper-based bactericides (organic)',
      'Hydrogen peroxide solution',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Hot water seed treatment - 54°C for 15 minutes',
      'Plant resistant varieties',
      'Crop rotation - 2-3 years',
      'Remove infected plants immediately',
      'Avoid working in wet conditions',
      'No overhead irrigation',
      'Good field sanitation',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Bean Rust': {
    'chemicalControl': [
      'Tebuconazole (10ml/20L water) - Systemic fungicide',
      'Sulfur dust or spray (40g/20L water) - Organic option',
      'Mancozeb (40g/20L water) - Preventive',
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Sulfur spray (40g/20L water) - Very effective',
      'Neem oil (5ml/L water)',
      'Baking soda + oil spray (5g/L + 5ml oil)',
      'Copper-based fungicides (organic)',
    ],
    'culturalControl': [
      'Plant resistant varieties - Best control',
      'Remove infected leaves immediately',
      'Avoid overhead irrigation',
      'Improve air circulation - Proper spacing',
      'Remove crop debris after harvest',
      'Early morning watering - Leaves dry quickly',
      'Crop rotation',
      'Avoid planting near previous bean fields',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water) - Organic approved',
      'Myclobutanil (5ml/20L water) - Systemic',
      'Trifloxystrobin (10ml/20L water)',
    ],
    'organicControl': [
      'Sulfur dust or spray - Very effective',
      'Baking soda spray (5g/L + 5ml liquid soap + 5ml oil)',
      'Milk spray (1:9 milk to water ratio)',
      'Neem oil (5ml/L water)',
      'Potassium bicarbonate (5g/L water)',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Proper plant spacing - 30-40cm',
      'Prune for air circulation',
      'Avoid excessive nitrogen - Promotes susceptible growth',
      'Remove infected leaves',
      'Water at base of plants',
      'Plant in sunny locations',
      'Avoid overhead irrigation',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Bean Common Mosaic Virus': {
    'chemicalControl': [
      'No chemical control for viruses',
      'Control aphid vectors - Use insecticides (see pest interventions)',
    ],
    'organicControl': [
      'No direct treatment',
      'Control aphids with neem oil and insecticidal soap',
    ],
    'culturalControl': [
      'Use virus-free certified seeds - Critical',
      'Plant resistant varieties - Many available',
      'Remove infected plants immediately - Don\'t compost',
      'Control aphid vectors aggressively',
      'Remove weeds - Alternate hosts',
      'Use reflective mulch - Deters aphids',
      'Roguing - Remove symptomatic plants weekly',
      'Don\'t save seeds from infected fields',
      'Clean tools between plants',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Bean Golden Yellow Mosaic Virus': {
    'chemicalControl': [
      'No chemical control for virus',
      'Control whitefly vectors - See pest interventions',
    ],
    'organicControl': [
      'No direct treatment',
      'Control whiteflies with neem oil',
    ],
    'culturalControl': [
      'Plant resistant varieties - Most effective',
      'Control whiteflies aggressively',
      'Use reflective mulch - Silver or aluminum',
      'Row covers - Exclude whiteflies',
      'Remove infected plants immediately',
      'Avoid planting near cucurbits',
      'Weed control',
      'Early planting - Avoid peak whitefly season',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use with extreme caution',
      'Fenamiphos - Pre-planting treatment',
    ],
    'organicControl': [
      'Marigolds (Tagetes species) - Plant as trap crop',
      'Neem cake (2kg per 100m²) - Mix into soil',
      'Mustard green manure - Till in before planting',
      'Paecilomyces lilacinus - Biological nematicide',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years, avoid susceptible crops',
      'Resistant varieties - Many available',
      'Soil solarization - 4-6 weeks before planting',
      'Add organic matter - Increases beneficial organisms',
      'Remove and destroy infected plants',
      'Deep plowing - Exposes nematodes',
      'Fallow period - Leave soil unplanted',
      'Clean tools and boots between fields',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Bacterial Wilt': {
    'chemicalControl': [
      'No effective chemical control',
      'Copper compounds - Minimal effect',
    ],
    'organicControl': [
      'No effective treatment once infected',
    ],
    'culturalControl': [
      'Use disease-free transplants and seeds',
      'Crop rotation - 3-4 years minimum',
      'Remove and destroy infected plants immediately',
      'Control cucumber beetles - They spread bacteria',
      'Don\'t plant after cucurbits',
      'Avoid wounding plants',
      'Disinfect tools between plants (10% bleach solution)',
      'Remove volunteer plants',
      'Avoid excessive nitrogen',
    ],
  },

  'Beans_Flowering/Reproductive_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Weekly',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
      'Baking soda spray',
    ],
    'culturalControl': [
      'Remove infected pods immediately',
      'Avoid working in wet fields',
      'Water at plant base',
      'Good air circulation',
      'Crop rotation',
    ],
  },

  'Beans_Flowering/Reproductive_Angular Leaf Spot': {
    'chemicalControl': [
      'Copper oxychloride (30g/20L water)',
      'Streptomycin sulfate (1g/20L water)',
    ],
    'organicControl': [
      'Copper-based bactericides',
      'Hydrogen peroxide spray',
    ],
    'culturalControl': [
      'Remove infected parts',
      'Avoid overhead irrigation',
      'Work in dry fields only',
      'Resistant varieties',
    ],
  },

  'Beans_Flowering/Reproductive_Bean Rust': {
    'chemicalControl': [
      'Tebuconazole (10ml/20L water)',
      'Sulfur spray (40g/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Sulfur spray - Very effective',
      'Neem oil (5ml/L water)',
      'Baking soda + oil spray',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Remove infected leaves',
      'Good air circulation',
      'Avoid overhead watering',
    ],
  },

  'Beans_Flowering/Reproductive_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
    ],
    'organicControl': [
      'Sulfur spray',
      'Milk spray (1:9 ratio)',
      'Baking soda spray',
      'Neem oil',
    ],
    'culturalControl': [
      'Resistant varieties',
      'Proper spacing',
      'Remove infected leaves',
      'Water at base',
    ],
  },

  'Beans_Flowering/Reproductive_Bean Common Mosaic Virus': {
    'chemicalControl': [
      'No chemical control',
      'Control aphids',
    ],
    'organicControl': [
      'Control aphid vectors',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Control aphids',
      'Resistant varieties',
      'Roguing',
    ],
  },

  'Beans_Flowering/Reproductive_Bean Golden Yellow Mosaic Virus': {
    'chemicalControl': [
      'No chemical control',
      'Control whiteflies',
    ],
    'organicControl': [
      'Control whitefly vectors',
    ],
    'culturalControl': [
      'Resistant varieties',
      'Remove infected plants',
      'Control whiteflies',
      'Reflective mulch',
    ],
  },

  'Beans_Flowering/Reproductive_Ascochyta Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation - 3 years',
      'Remove infected plant parts',
      'Avoid overhead irrigation',
      'Destroy crop debris',
      'Plant in well-drained soil',
    ],
  },

  'Beans_Flowering/Reproductive_Sclerotinia White Mold': {
    'chemicalControl': [
      'Boscalid (10ml/20L water) - At early flowering',
      'Thiophanate-methyl (15g/20L water)',
      'Iprodione (20ml/20L water)',
    ],
    'organicControl': [
      'Coniothyrium minitans - Biological control',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Wide plant spacing - 40-50cm',
      'Avoid excessive nitrogen',
      'Ensure good drainage',
      'Crop rotation - 4 years minimum',
      'Remove infected plants and surrounding soil',
      'Avoid overhead irrigation',
      'Deep plowing - Bury sclerotia',
      'Plant in raised beds',
    ],
  },

  'Beans_Flowering/Reproductive_Bacterial Wilt': {
    'chemicalControl': [
      'No effective control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Remove infected plants immediately',
      'Crop rotation',
      'Control beetle vectors',
      'Disinfect tools',
    ],
  },

  'Beans_Maturation/Harvesting_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Harvest promptly when mature',
      'Remove infected pods',
      'Avoid harvesting in wet conditions',
    ],
  },

  'Beans_Maturation/Harvesting_Ascochyta Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove infected pods',
      'Dry beans promptly',
    ],
  },

  'Beans_Maturation/Harvesting_Sclerotinia White Mold': {
    'chemicalControl': [
      'Boscalid (10ml/20L water)',
      'Thiophanate-methyl (15g/20L water)',
    ],
    'organicControl': [
      'Coniothyrium minitans',
    ],
    'culturalControl': [
      'Harvest when dry',
      'Remove infected pods and plants',
      'Proper drying - Below 13% moisture',
      'Deep plow after harvest',
    ],
  },

  'Beans_Maturation/Harvesting_Brown Spot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation',
      'Remove infected plants',
      'Harvest when mature',
      'Proper drying before storage',
    ],
  },

  'Beans_Maturation/Harvesting_Fusarium Wilt': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'Trichoderma - Soil amendment',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Crop rotation - 4-5 years',
      'Remove infected plants',
      'Soil solarization',
      'Avoid wounding roots',
      'Maintain soil pH 6.5-7.0',
    ],
  },

  'Beans_Maturation/Harvesting_Web Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Good air circulation',
      'Avoid overhead irrigation',
      'Remove infected plants',
      'Harvest promptly',
      'Destroy crop debris',
    ],
  },

  'Beans_Storage_Post-Harvest Fungal Rot': {
    'chemicalControl': [
      'Pirimiphos-methyl with fungicide - Dust',
    ],
    'organicControl': [
      'Diatomaceous earth - Prevents moisture',
      'Neem leaf powder',
    ],
    'culturalControl': [
      'Proper drying - 12-13% moisture critical',
      'Cool, dry storage (below 15°C, 60% humidity)',
      'Clean storage containers',
      'Regular inspection',
      'Remove moldy beans immediately',
      'Good ventilation',
      'Don\'t store damaged beans',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // MAIZE DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Maize_Germination/Seedling_Pythium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Mefenoxam (1ml/L water) - Soil drench',
    ],
    'organicControl': [
      'Trichoderma - Seed treatment',
      'Bacillus species',
    ],
    'culturalControl': [
      'Improve drainage',
      'Plant in warm soil (above 18°C)',
      'Avoid overwatering',
      'Raised beds',
      'Crop rotation',
    ],
  },

  'Maize_Germination/Seedling_Damping-Off': {
    'chemicalControl': [
      'Captan (seed treatment)',
      'Thiram (seed treatment)',
    ],
    'organicControl': [
      'Trichoderma harzianum',
      'Cinnamon powder',
    ],
    'culturalControl': [
      'Plant in warm, well-drained soil',
      'Don\'t overwater',
      'Good air circulation',
      'Remove infected seedlings',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Gray Leaf Spot': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water) - Systemic',
      'Propiconazole (10ml/20L water)',
      'Tebuconazole (10ml/20L water)',
      'Pyraclostrobin (5ml/20L water)',
    ],
    'organicControl': [
      'No highly effective organic options',
      'Copper-based fungicides - Limited effect',
    ],
    'culturalControl': [
      'Plant resistant hybrids - Most effective',
      'Crop rotation - 2 years minimum',
      'Remove and destroy crop debris',
      'Avoid excessive nitrogen',
      'Proper plant spacing',
      'Avoid late planting',
      'Balance soil nutrition',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Common Rust': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Propiconazole (10ml/20L water)',
      'Sulfur spray (40g/20L water) - Organic',
    ],
    'organicControl': [
      'Sulfur spray - Moderately effective',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Early planting - Avoid disease peak',
      'Balanced fertilization',
      'Remove volunteer maize',
      'Crop rotation',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Northern Corn Leaf Blight': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Propiconazole (10ml/20L water)',
      'Mancozeb (40g/20L water) - Preventive',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Plant resistant hybrids - Very effective',
      'Crop rotation - 2 years',
      'Bury crop residue by deep plowing',
      'Balanced fertilization',
      'Avoid excessive nitrogen',
      'Plant early',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Maize Dwarf Mosaic Virus': {
    'chemicalControl': [
      'No chemical control for virus',
      'Control aphid vectors',
    ],
    'organicControl': [
      'Control aphids with neem oil',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Control johnsongrass - Primary reservoir',
      'Remove infected plants',
      'Control aphids',
      'Early planting',
      'Weed control critical',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Bacterial Leaf Streak': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Limited effect',
    ],
    'organicControl': [
      'Copper-based bactericides',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Plant resistant hybrids',
      'Crop rotation',
      'Remove infected plants',
      'Avoid working in wet fields',
      'Control grass weeds',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Anthracnose Leaf Blight': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Crop rotation',
      'Bury crop residue',
      'Balanced fertilization',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Stewart\'s Wilt': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Plant resistant hybrids - Only effective control',
      'Control flea beetles - They spread disease',
      'Remove infected plants',
      'Use certified seeds',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Maize Streak Virus': {
    'chemicalControl': [
      'No chemical control',
      'Control leafhopper vectors',
    ],
    'organicControl': [
      'Control vectors with neem oil',
    ],
    'culturalControl': [
      'Plant resistant varieties - Most effective',
      'Early planting - Escape vector peak',
      'Control leafhoppers',
      'Remove infected plants',
      'Roguing - Weekly removal of symptomatic plants',
    ],
  },

  'Maize_Flowering/Reproductive_Gray Leaf Spot': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Propiconazole (10ml/20L water)',
    ],
    'organicControl': [
      'Copper fungicides - Limited',
    ],
    'culturalControl': [
      'Resistant hybrids',
      'Crop rotation',
      'Destroy crop debris',
    ],
  },

  'Maize_Flowering/Reproductive_Common Rust': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Sulfur spray (40g/20L water)',
    ],
    'organicControl': [
      'Sulfur spray',
      'Neem oil',
    ],
    'culturalControl': [
      'Resistant hybrids',
      'Balanced fertilization',
    ],
  },

  'Maize_Flowering/Reproductive_Southern Corn Leaf Blight': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Propiconazole (10ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Plant resistant hybrids - Critical',
      'Crop rotation - 2 years',
      'Bury crop residue deeply',
      'Balanced nitrogen',
      'Remove volunteer maize',
    ],
  },

  'Maize_Flowering/Reproductive_Northern Corn Leaf Blight': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water)',
      'Propiconazole (10ml/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Resistant hybrids',
      'Crop rotation',
      'Bury debris',
    ],
  },

  'Maize_Flowering/Reproductive_Maize Dwarf Mosaic Virus': {
    'chemicalControl': [
      'No control - virus',
      'Control aphids',
    ],
    'organicControl': [
      'Control vectors',
    ],
    'culturalControl': [
      'Resistant varieties',
      'Control johnsongrass',
      'Remove infected plants',
    ],
  },

  'Maize_Flowering/Reproductive_Tar Spot': {
    'chemicalControl': [
      'Azoxystrobin + Benzovindiflupyr (2ml/L water)',
      'Propiconazole (10ml/20L water)',
    ],
    'organicControl': [
      'No effective organic control',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Crop rotation',
      'Remove crop debris',
      'Early planting',
      'Fungicide application at VT stage critical',
    ],
  },

  'Maize_Flowering/Reproductive_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl (systemic) - Seed treatment',
      'Fosetyl-Al (3g/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Remove infected plants',
      'Crop rotation',
      'Good drainage',
    ],
  },

  'Maize_Flowering/Reproductive_Maize Streak Virus': {
    'chemicalControl': [
      'No control',
      'Control leafhoppers',
    ],
    'organicControl': [
      'Control vectors',
    ],
    'culturalControl': [
      'Resistant varieties',
      'Early planting',
      'Remove infected plants',
    ],
  },

  'Maize_Maturation/Harvesting_Maize Lethal Necrosis': {
    'chemicalControl': [
      'No effective chemical control - viral disease',
    ],
    'organicControl': [
      'Control insect vectors (thrips, aphids, beetles)',
    ],
    'culturalControl': [
      'Plant resistant hybrids - Only effective control',
      'Early planting - Escape disease pressure',
      'Roguing - Remove infected plants immediately',
      'Control insect vectors aggressively',
      'Crop rotation - Break disease cycle',
      'Remove maize residue - Destroys virus reservoir',
      'Weed control - Removes alternate hosts',
      'Use certified disease-free seeds',
    ],
  },

  'Maize_Maturation/Harvesting_Head Smut': {
    'chemicalControl': [
      'Tebuconazole (seed treatment)',
      'Carboxin (seed treatment)',
    ],
    'organicControl': [
      'No effective organic control',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Seed treatment essential',
      'Remove and destroy smut galls before spores release',
      'Crop rotation - 2-3 years',
      'Deep plowing - Bury spores',
      'Balanced fertilization - Avoid excess nitrogen',
    ],
  },

  'Maize_Maturation/Harvesting_Common Smut': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Remove and destroy galls before they burst',
      'Avoid wounding plants during cultivation',
      'Balanced fertilization - Excess nitrogen increases susceptibility',
      'Crop rotation',
      'Plant less susceptible hybrids',
      'Remove volunteer maize',
    ],
  },

  'Maize_Maturation/Harvesting_Goss\'s Wilt': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Crop rotation - 2 years',
      'Manage crop residue - Bury or remove',
      'Avoid wounding plants',
      'Control weeds',
      'Use certified disease-free seeds',
    ],
  },

  'Maize_Maturation/Harvesting_Fusarium Ear Rot': {
    'chemicalControl': [
      'Propiconazole (applied at silking) - Limited effect',
    ],
    'organicControl': [
      'No effective organic control',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Control insects - Especially ear-feeding insects',
      'Harvest promptly when mature',
      'Dry grain quickly - Below 13.5% moisture',
      'Proper storage conditions',
      'Crop rotation',
    ],
  },

  'Maize_Maturation/Harvesting_Gibberella Ear Rot': {
    'chemicalControl': [
      'Prothioconazole (at silking) - Limited effectiveness',
    ],
    'organicControl': [
      'None effective',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Harvest at proper maturity',
      'Dry quickly - Below 15% moisture',
      'Avoid late planting',
      'Control insects',
      'Crop rotation',
    ],
  },

  'Maize_Maturation/Harvesting_Diplodia Ear Rot': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Crop rotation - 2 years minimum',
      'Bury or remove crop residue',
      'Harvest at maturity',
      'Dry grain quickly - Below 15% moisture',
      'Balanced nutrition - Avoid nitrogen stress',
    ],
  },

  'Maize_Maturation/Harvesting_Aspergillus Ear Rot': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'Biological control (Aflasafe) - Competitive exclusion',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Irrigation during drought - Critical',
      'Control insects aggressively',
      'Harvest at maturity - Don\'t delay',
      'Dry grain rapidly - Below 13.5% moisture',
      'Proper storage - Cool, dry',
      'Avoid plant stress',
    ],
  },

  'Maize_Maturation/Harvesting_Bacterial Stalk Rot': {
    'chemicalControl': [
      'No effective control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Balanced fertilization - Avoid excess nitrogen',
      'Proper plant population',
      'Adequate potassium',
      'Timely harvest',
      'Resistant hybrids',
    ],
  },

  'Maize_Maturation/Harvesting_Charcoal Rot': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Plant resistant hybrids',
      'Avoid water stress - Irrigate if possible',
      'Balanced fertilization',
      'Proper plant population',
      'Timely harvest',
      'Deep plowing',
    ],
  },

  'Maize_Storage_Post-Harvest Mycotoxins (Aflatoxins, Fumonisins)': {
    'chemicalControl': [
      'Fumigation if contamination severe - Professional only',
    ],
    'organicControl': [
      'Aflasafe - Biological control applied in field',
    ],
    'culturalControl': [
      'Proper drying - Below 13.5% moisture CRITICAL',
      'Clean storage structures',
      'Good ventilation',
      'Cool storage - Below 15°C if possible',
      'Regular inspection',
      'Remove damaged kernels before storage',
      'Don\'t mix new and old grain',
      'Test grain for mycotoxins before feeding',
    ],
  },

  'Maize_Storage_Storage Rot': {
    'chemicalControl': [
      'Fungicide-treated storage bags',
    ],
    'organicControl': [
      'Diatomaceous earth - Reduces moisture',
      'PICS bags - Hermetic storage',
    ],
    'culturalControl': [
      'Proper drying - Below 13.5% moisture',
      'Clean storage - Remove old grain first',
      'Airtight containers - Metal or plastic',
      'Good ventilation if not hermetic',
      'Regular inspection - Check moisture',
      'Cool storage conditions',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CABBAGE DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Cabbage_Germination/Seedling_Damping-Off': {
    'chemicalControl': [
      'Captan (seed treatment) - 2g per kg seed',
      'Thiram (seed treatment) - 3g per kg seed',
      'Metalaxyl + Mancozeb - Seed treatment',
    ],
    'organicControl': [
      'Trichoderma harzianum - Seed treatment',
      'Cinnamon powder - Light dusting on soil',
      'Chamomile tea - Soil drench',
      'Biochar - Mix into potting medium',
    ],
    'culturalControl': [
      'Use sterile potting mix for seedlings',
      'Avoid overcrowding - Good air circulation',
      'Don\'t overwater - Moist but not wet',
      'Warm growing conditions - Above 15°C',
      'Good drainage essential',
      'Clean containers and tools',
      'Remove infected seedlings immediately',
      'Bottom watering - Keep foliage dry',
    ],
  },

  'Cabbage_Germination/Seedling_Black Rot': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Limited effect',
      'Streptomycin (seed treatment)',
    ],
    'organicControl': [
      'Copper-based bactericides (organic certified)',
      'Hot water seed treatment - 50°C for 20-30 minutes',
    ],
    'culturalControl': [
      'Use certified disease-free seeds - Most important',
      'Hot water seed treatment before planting',
      'Crop rotation - 3 years minimum, avoid brassicas',
      'Remove and destroy infected seedlings',
      'Avoid overhead irrigation',
      'Don\'t work in wet fields',
      'Control cabbage maggots and flea beetles - They spread bacteria',
      'Remove brassica weeds',
    ],
  },

  'Cabbage_Germination/Seedling_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Fosetyl-Al (3g/L water) - Systemic',
      'Mancozeb (40g/20L water) - Preventive',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Bacillus subtilis',
      'Potassium bicarbonate (5g/L water)',
    ],
    'culturalControl': [
      'Use disease-free transplants',
      'Good air circulation',
      'Avoid overhead watering',
      'Water early in day - Leaves dry quickly',
      'Remove infected leaves',
      'Proper plant spacing',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Black Rot': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Preventive only',
      'Streptomycin sulfate (1g/20L water) - Limited use',
    ],
    'organicControl': [
      'Copper-based bactericides',
      'Hydrogen peroxide spray (3% diluted 1:10)',
    ],
    'culturalControl': [
      'Use certified disease-free seeds and transplants',
      'Hot water seed treatment - 50°C for 25-30 minutes',
      'Crop rotation - 3 years, no brassicas',
      'Remove infected plants immediately',
      'Control insect vectors (flea beetles, aphids)',
      'Avoid working in wet fields',
      'No overhead irrigation',
      'Destroy crop debris after harvest',
      'Remove brassica weeds',
      'Disinfect tools between plants',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl (systemic fungicide)',
      'Fosetyl-Al (3g/L water)',
      'Mancozeb (40g/20L water) - Preventive',
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Bacillus subtilis',
      'Neem oil (5ml/L water)',
      'Potassium bicarbonate (5g/L water)',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Proper plant spacing - 45-60cm',
      'Avoid overhead irrigation',
      'Water early in morning',
      'Remove infected leaves immediately',
      'Good air circulation',
      'Crop rotation',
      'Remove crop debris',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water) - Organic approved',
      'Myclobutanil (5ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Sulfur spray or dust - Very effective',
      'Baking soda spray (5g/L + 5ml liquid soap)',
      'Milk spray (1:9 milk to water)',
      'Neem oil (5ml/L water)',
      'Potassium bicarbonate (5g/L water)',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Proper spacing - Good air flow',
      'Remove infected leaves',
      'Avoid overhead watering',
      'Water at base of plants',
      'Avoid excessive nitrogen',
      'Plant in sunny locations',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Alternaria Leaf Spot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water)',
      'Boscalid (10ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation - 3 years',
      'Remove infected leaves',
      'Avoid overhead irrigation',
      'Good air circulation',
      'Destroy crop debris',
      'Balanced fertilization',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Ring Spot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Crop rotation - 3 years',
      'Remove infected leaves',
      'Avoid overhead watering',
      'Good sanitation',
      'Destroy crop residue',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Bacterial Soft Rot': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Limited prevention',
      'No cure once infected',
    ],
    'organicControl': [
      'Copper-based bactericides - Preventive only',
    ],
    'culturalControl': [
      'Avoid wounding plants - Critical',
      'Control insects that wound plants',
      'Good drainage - Wet soil promotes disease',
      'Don\'t overwater',
      'Avoid excessive nitrogen',
      'Remove infected plants immediately',
      'Harvest carefully - Avoid bruising',
      'Cure properly before storage',
      'Crop rotation',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Fusarium Yellows': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'Trichoderma - Soil amendment',
    ],
    'culturalControl': [
      'Plant resistant varieties - Only effective control',
      'Crop rotation - 4 years minimum',
      'Remove infected plants',
      'Soil solarization',
      'Maintain soil pH 6.5-7.5',
      'Avoid wounding roots',
      'Good drainage',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_White Rust': {
    'chemicalControl': [
      'Metalaxyl (systemic)',
      'Fosetyl-Al (3g/L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Good air circulation',
      'Avoid overhead irrigation',
      'Crop rotation',
      'Remove brassica weeds',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Leaf Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Good air circulation',
      'Avoid overhead watering',
      'Crop rotation',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Black Leg': {
    'chemicalControl': [
      'Azoxystrobin (2ml/L water) - Seed treatment',
      'Fludioxonil (seed treatment)',
    ],
    'organicControl': [
      'Hot water seed treatment - 50°C for 30 minutes',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Hot water seed treatment',
      'Crop rotation - 4 years',
      'Remove infected plants',
      'Good drainage',
      'Avoid wounding stems',
    ],
  },

  'Cabbage_Flowering/Reproductive_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl',
      'Fosetyl-Al (3g/L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Potassium bicarbonate',
    ],
    'culturalControl': [
      'Remove infected parts',
      'Good air circulation',
      'Avoid overhead watering',
    ],
  },

  'Cabbage_Flowering/Reproductive_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
    ],
    'organicControl': [
      'Sulfur spray',
      'Milk spray (1:9)',
      'Baking soda spray',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Good spacing',
      'Water at base',
    ],
  },

  'Cabbage_Flowering/Reproductive_Alternaria Leaf Spot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Avoid overhead irrigation',
      'Good air circulation',
    ],
  },

  'Cabbage_Flowering/Reproductive_Sclerotinia Stem Rot (White Mold)': {
    'chemicalControl': [
      'Boscalid (10ml/20L water) - At flowering',
      'Thiophanate-methyl (15g/20L water)',
      'Iprodione (20ml/20L water)',
    ],
    'organicControl': [
      'Coniothyrium minitans - Biological control',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Wide plant spacing - 50-60cm',
      'Avoid excessive nitrogen',
      'Good drainage',
      'Crop rotation - 4 years',
      'Remove infected plants and soil',
      'Deep plowing after harvest',
      'Avoid overhead irrigation',
    ],
  },

  'Cabbage_Flowering/Reproductive_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Remove infected parts',
      'Avoid working in wet fields',
      'Crop rotation',
    ],
  },

  'Cabbage_Maturation/Harvesting_Black Rot': {
    'chemicalControl': [
      'Copper compounds - Preventive',
    ],
    'organicControl': [
      'Copper bactericides',
    ],
    'culturalControl': [
      'Harvest when dry',
      'Remove infected heads',
      'Cure properly before storage',
      'Cool storage',
    ],
  },

  'Cabbage_Maturation/Harvesting_Sclerotinia Stem Rot (White Mold)': {
    'chemicalControl': [
      'No control at harvest',
    ],
    'organicControl': [
      'Remove infected plants',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove infected heads',
      'Don\'t store damaged cabbage',
      'Proper curing',
    ],
  },

  'Cabbage_Maturation/Harvesting_Bacterial Soft Rot': {
    'chemicalControl': [
      'No effective control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Harvest carefully - Avoid wounding',
      'Cure in cool, dry, ventilated area',
      'Remove outer damaged leaves before storage',
      'Cool storage (0-2°C, 95-100% humidity)',
      'Don\'t store damaged heads',
    ],
  },

  'Cabbage_Maturation/Harvesting_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Harvest when dry',
      'Remove infected heads',
      'Proper storage conditions',
    ],
  },

  'Cabbage_Storage_Post-Harvest Fungal Rot': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Store only healthy, undamaged heads',
      'Cool storage (0-2°C) - Critical',
      'High humidity (95-100%)',
      'Good ventilation',
      'Regular inspection',
      'Remove rotting heads immediately',
      'Don\'t store wet cabbage',
      'Proper curing before storage',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CARROTS DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Carrots_Germination/Seedling_Damping-Off': {
    'chemicalControl': [
      'Captan (seed treatment)',
      'Thiram (seed treatment)',
      'Metalaxyl (if Pythium suspected)',
    ],
    'organicControl': [
      'Trichoderma harzianum',
      'Cinnamon powder on soil',
      'Chamomile tea drench',
    ],
    'culturalControl': [
      'Use sterile seed starting mix',
      'Don\'t overwater',
      'Good air circulation',
      'Warm growing conditions',
      'Thin seedlings to reduce crowding',
      'Remove infected seedlings',
    ],
  },

  'Carrots_Germination/Seedling_Fusarium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Captan (seed treatment)',
    ],
    'organicControl': [
      'Trichoderma - Seed/soil treatment',
      'Compost tea',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years',
      'Improve drainage',
      'Avoid overwatering',
      'Use certified seeds',
      'Soil solarization',
    ],
  },

  'Carrots_Germination/Seedling_Rhizoctonia Root Rot': {
    'chemicalControl': [
      'Pencycuron (seed treatment)',
      'Azoxystrobin (soil drench)',
    ],
    'organicControl': [
      'Trichoderma harzianum',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Well-drained soil',
      'Shallow planting',
      'Avoid cool, wet soil',
      'Crop rotation - 3 years',
    ],
  },

  'Carrots_Germination/Seedling_Pythium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Mefenoxam (soil drench)',
    ],
    'organicControl': [
      'Trichoderma species',
      'Hydrogen peroxide (3%) diluted',
    ],
    'culturalControl': [
      'Excellent drainage - Critical',
      'Avoid overwatering',
      'Plant in warm soil',
      'Raised beds',
      'Remove infected seedlings',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Alternaria Leaf Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Weekly',
      'Azoxystrobin (2ml/L water)',
      'Mancozeb (40g/20L water) - Preventive',
      'Boscalid (10ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Crop rotation - 3 years, avoid umbellifers',
      'Remove infected leaves immediately',
      'Avoid overhead irrigation',
      'Space plants properly - 5-7cm',
      'Destroy crop debris',
      'Weed control',
      'Avoid working in wet fields',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Cercospora Leaf Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Crop rotation - 3 years',
      'Remove infected leaves',
      'Avoid overhead watering',
      'Good plant spacing',
      'Destroy crop debris',
      'Avoid excessive nitrogen',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Sulfur spray - Very effective',
      'Baking soda spray (5g/L + soap)',
      'Milk spray (1:9 ratio)',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Proper spacing',
      'Remove infected leaves',
      'Avoid overhead watering',
      'Good air circulation',
      'Water at base',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl (systemic)',
      'Fosetyl-Al (3g/L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Good air circulation',
      'Avoid overhead irrigation',
      'Water early in morning',
      'Remove infected leaves',
      'Crop rotation',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Bacterial Leaf Blight': {
    'chemicalControl': [
      'Copper compounds (30g/20L water)',
      'Streptomycin - Limited effectiveness',
    ],
    'organicControl': [
      'Copper-based bactericides',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Hot water seed treatment',
      'Crop rotation - 3 years',
      'Remove infected plants',
      'Avoid overhead irrigation',
      'Don\'t work in wet fields',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use with caution',
      'Fenamiphos - Pre-planting',
    ],
    'organicControl': [
      'Marigolds (Tagetes) - Trap crop',
      'Neem cake (2kg per 100m²)',
      'Mustard green manure',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years',
      'Soil solarization - 4-6 weeks',
      'Add organic matter',
      'Remove infected plants',
      'Use clean tools',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Carrot Mosaic Virus': {
    'chemicalControl': [
      'No chemical control',
      'Control aphid vectors',
    ],
    'organicControl': [
      'Control aphids with neem oil',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Control aphids aggressively',
      'Remove weeds - Alternate hosts',
      'Use reflective mulch',
      'Plant resistant varieties if available',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Aster Yellows': {
    'chemicalControl': [
      'No control for disease',
      'Control leafhopper vectors',
    ],
    'organicControl': [
      'Control leafhoppers with neem oil',
    ],
    'culturalControl': [
      'Remove infected plants immediately',
      'Control leafhoppers aggressively',
      'Use row covers - Exclude leafhoppers',
      'Remove aster family weeds',
      'Plant away from lettuce and asters',
    ],
  },

  'Carrots_Maturation/Harvesting_Sclerotinia White Mold': {
    'chemicalControl': [
      'Boscalid (10ml/20L water) - Preventive',
      'Thiophanate-methyl (15g/20L water)',
    ],
    'organicControl': [
      'Coniothyrium minitans',
    ],
    'culturalControl': [
      'Good drainage',
      'Avoid excessive nitrogen',
      'Wide plant spacing',
      'Crop rotation - 4 years',
      'Harvest promptly when mature',
      'Don\'t leave in wet soil',
    ],
  },

  'Carrots_Maturation/Harvesting_Fusarium Root Rot': {
    'chemicalControl': [
      'No control at harvest',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest when mature',
      'Don\'t leave overripe in ground',
      'Remove infected roots',
      'Crop rotation next season',
    ],
  },

  'Carrots_Maturation/Harvesting_Rhizoctonia Root Rot': {
    'chemicalControl': [
      'No control at harvest',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove infected carrots',
      'Improve drainage for next crop',
    ],
  },

  'Carrots_Maturation/Harvesting_Soft Rot': {
    'chemicalControl': [
      'No effective control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Harvest carefully - Avoid wounding',
      'Cure in cool, ventilated area',
      'Remove damaged carrots',
      'Cool storage quickly',
      'Don\'t wash before storage',
    ],
  },

  'Carrots_Maturation/Harvesting_Black Rot': {
    'chemicalControl': [
      'No control at harvest',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Harvest when dry',
      'Avoid wounding',
      'Remove damaged carrots',
      'Proper curing',
      'Cool storage',
    ],
  },

  'Carrots_Storage_Post-Harvest Fungal Rot': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Store only undamaged carrots',
      'Cool storage (0-2°C) - Critical',
      'High humidity (95-100%)',
      'Store in sand or sawdust',
      'Remove damaged carrots immediately',
      'Good ventilation',
      'Regular inspection',
      'Don\'t wash before storage',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // TOMATOES DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Tomatoes_Germination/Seedling_Damping-Off': {
    'chemicalControl': [
      'Captan (seed treatment) - 2g/kg seed',
      'Thiram (seed treatment)',
      'Metalaxyl (if Pythium)',
    ],
    'organicControl': [
      'Trichoderma harzianum - Seed/soil treatment',
      'Cinnamon powder on soil',
      'Chamomile tea drench',
    ],
    'culturalControl': [
      'Use sterile potting mix',
      'Don\'t overwater',
      'Good air circulation',
      'Warm conditions (above 15°C)',
      'Bottom watering preferred',
      'Remove infected seedlings',
    ],
  },

  'Tomatoes_Germination/Seedling_Fusarium Wilt': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'Trichoderma - Soil amendment',
    ],
    'culturalControl': [
      'Plant resistant varieties (VF, VFN) - Most effective',
      'Use certified disease-free transplants',
      'Crop rotation - 4-5 years, avoid solanaceous crops',
      'Soil solarization before planting',
      'Remove infected plants immediately',
      'Grafting onto resistant rootstock',
      'Maintain soil pH 6.5-7.0',
    ],
  },

  'Tomatoes_Germination/Seedling_Verticillium Wilt': {
    'chemicalControl': [
      'No effective chemical control',
    ],
    'organicControl': [
      'Trichoderma species',
    ],
    'culturalControl': [
      'Plant resistant varieties (V or VF)',
      'Crop rotation - 4 years minimum',
      'Soil solarization',
      'Remove infected plants',
      'Avoid planting after potatoes, eggplant, peppers',
      'Clean tools between plants',
    ],
  },

  'Tomatoes_Germination/Seedling_Bacterial Wilt': {
    'chemicalControl': [
      'No effective control',
    ],
    'organicControl': [
      'None available',
    ],
    'culturalControl': [
      'Use disease-free transplants',
      'Crop rotation - 3 years',
      'Remove infected plants',
      'Disinfect tools (10% bleach)',
      'Avoid wounding plants',
      'Don\'t plant after solanaceous crops',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Early Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Weekly preventive',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water) - Systemic',
      'Boscalid (10ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
      'Bacillus subtilis',
      'Baking soda spray (5g/L + soap)',
    ],
    'culturalControl': [
      'Use certified disease-free transplants',
      'Crop rotation - 3 years minimum',
      'Remove infected lower leaves',
      'Mulch heavily - Prevents soil splash',
      'Stake or cage plants - Keep off ground',
      'Water at base of plants',
      'Avoid working in wet fields',
      'Destroy crop debris after harvest',
      'Space plants properly - 60-90cm',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Bacterial Spot': {
    'chemicalControl': [
      'Copper compounds (30g/20L water) - Weekly',
      'Copper + Mancozeb combination',
      'Streptomycin (1g/20L water) - Limited use',
    ],
    'organicControl': [
      'Copper-based bactericides (organic certified)',
      'Hydrogen peroxide spray (3% diluted 1:10)',
    ],
    'culturalControl': [
      'Use certified disease-free seeds and transplants',
      'Hot water seed treatment - 50°C for 25 minutes',
      'Plant resistant varieties',
      'Crop rotation - 3 years',
      'Remove infected leaves',
      'Avoid overhead irrigation',
      'Don\'t work in wet fields',
      'Stake plants for air circulation',
      'Disinfect tools',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Bacterial Canker': {
    'chemicalControl': [
      'Copper compounds - Limited effectiveness',
    ],
    'organicControl': [
      'Copper bactericides',
    ],
    'culturalControl': [
      'Use certified disease-free seeds',
      'Hot water seed treatment - 56°C for 30 minutes',
      'Remove infected plants immediately',
      'Crop rotation - 3 years',
      'Disinfect tools, stakes, cages',
      'Avoid overhead irrigation',
      'Don\'t save seeds from infected plants',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Sulfur spray - Very effective',
      'Milk spray (1:9 ratio)',
      'Baking soda spray (5g/L + soap + oil)',
      'Neem oil (5ml/L water)',
      'Potassium bicarbonate (5g/L)',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Proper spacing - 60-90cm',
      'Prune for air circulation',
      'Remove infected leaves',
      'Water at base',
      'Avoid overhead watering',
      'Plant in sunny location',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Mosaic Virus': {
    'chemicalControl': [
      'No chemical control',
      'Control aphid vectors',
    ],
    'organicControl': [
      'Control aphids with neem oil',
    ],
    'culturalControl': [
      'Plant resistant varieties (TMV)',
      'Remove infected plants immediately',
      'Control aphids aggressively',
      'Don\'t smoke near plants - TMV in tobacco',
      'Wash hands before handling plants',
      'Remove weeds - Alternate hosts',
      'Use reflective mulch',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Yellow Leaf Curl Virus': {
    'chemicalControl': [
      'No control for virus',
      'Control whitefly vectors aggressively',
    ],
    'organicControl': [
      'Control whiteflies with neem oil',
    ],
    'culturalControl': [
      'Plant resistant varieties - Most effective',
      'Remove infected plants',
      'Control whiteflies aggressively',
      'Use reflective mulch - Silver/aluminum',
      'Row covers on young plants',
      'Avoid planting near cucurbits',
      'Remove weeds',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Root Knot Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use with extreme caution',
      'Fenamiphos - Pre-planting',
    ],
    'organicControl': [
      'Marigolds (Tagetes) - Plant before tomatoes',
      'Neem cake (2kg per 100m²)',
      'Paecilomyces lilacinus - Biological',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years',
      'Resistant rootstocks - Graft tomatoes',
      'Resistant varieties',
      'Soil solarization - 4-6 weeks',
      'Add organic matter',
      'Remove infected plants',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Spotted Wilt Virus': {
    'chemicalControl': [
      'No control for virus',
      'Control thrips vectors',
    ],
    'organicControl': [
      'Control thrips with neem oil',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Control thrips aggressively',
      'Use reflective mulch',
      'Remove weeds',
      'Avoid planting near ornamentals',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Septoria Leaf Spot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Remove infected lower leaves',
      'Mulch heavily',
      'Stake plants',
      'Water at base',
      'Crop rotation',
      'Destroy crop debris',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Early Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Maintain mulch',
      'Water at base',
      'Good air circulation',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Late Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Preventive, apply before symptoms',
      'Mancozeb (40g/20L water) - Preventive',
      'Copper compounds (30g/20L water) - Organic option',
      'Metalaxyl + Mancozeb - Systemic + protectant',
      'Fluazinam (15ml/20L water) - Very effective',
    ],
    'organicControl': [
      'Copper-based fungicides - Apply preventively',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Wide plant spacing - 90cm minimum',
      'Remove infected plants immediately - Don\'t compost',
      'Avoid overhead irrigation',
      'Water early in morning',
      'Remove volunteer potatoes - Disease reservoir',
      'Monitor weather - Apply fungicides before rain',
      'Destroy crop debris immediately after harvest',
      'Don\'t plant tomatoes near potatoes',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Bacterial Spot': {
    'chemicalControl': [
      'Copper compounds (30g/20L water)',
      'Copper + Mancozeb',
    ],
    'organicControl': [
      'Copper bactericides',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Avoid overhead watering',
      'Don\'t work in wet fields',
      'Good air circulation',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Bacterial Canker': {
    'chemicalControl': [
      'Copper compounds - Limited effect',
    ],
    'organicControl': [
      'Copper bactericides',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Disinfect tools',
      'Avoid overhead irrigation',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
    ],
    'organicControl': [
      'Sulfur spray',
      'Milk spray',
      'Baking soda spray',
    ],
    'culturalControl': [
      'Remove infected leaves',
      'Good spacing',
      'Water at base',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Mosaic Virus': {
    'chemicalControl': [
      'No control',
      'Control aphids',
    ],
    'organicControl': [
      'Control aphid vectors',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Control aphids',
      'Wash hands before handling',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Yellow Leaf Curl Virus': {
    'chemicalControl': [
      'No control',
      'Control whiteflies',
    ],
    'organicControl': [
      'Control whitefly vectors',
    ],
    'culturalControl': [
      'Resistant varieties',
      'Remove infected plants',
      'Control whiteflies',
      'Reflective mulch',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Spotted Wilt Virus': {
    'chemicalControl': [
      'No control',
      'Control thrips',
    ],
    'organicControl': [
      'Control thrips vectors',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Control thrips',
      'Reflective mulch',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Gray Mold (Botrytis)': {
    'chemicalControl': [
      'Boscalid (10ml/20L water)',
      'Iprodione (20ml/20L water)',
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Bacillus subtilis',
      'Copper fungicides - Limited effect',
    ],
    'culturalControl': [
      'Good air circulation - Critical',
      'Remove infected flowers and fruits',
      'Avoid overhead watering',
      'Reduce humidity - Greenhouse ventilation',
      'Don\'t water late in day',
      'Prune for airflow',
      'Remove senescent leaves',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Alternaria Stem Canker': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Use certified disease-free transplants',
      'Remove infected stems',
      'Crop rotation',
      'Avoid wounding stems',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Late Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water) - Continue until harvest',
      'Copper compounds',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Harvest fruits from healthy plants only',
      'Destroy crop debris immediately',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Anthracnose': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
      'Neem oil',
    ],
    'culturalControl': [
      'Harvest promptly when ripe',
      'Remove infected fruits',
      'Avoid fruit contact with soil',
      'Handle carefully to avoid wounding',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Early Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Continue removing infected leaves',
      'Harvest ripe fruits',
      'Maintain mulch',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Southern Blight': {
    'chemicalControl': [
      'Azoxystrobin (soil drench)',
    ],
    'organicControl': [
      'Trichoderma species',
    ],
    'culturalControl': [
      'Remove infected plants and surrounding soil',
      'Deep mulch away from stems',
      'Good drainage',
      'Crop rotation - 4 years',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Fruit Rot': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Harvest ripe fruits promptly',
      'Remove overripe and damaged fruits',
      'Keep fruits off ground',
      'Avoid wounding fruits',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Gray Mold (Botrytis)': {
    'chemicalControl': [
      'Boscalid (10ml/20L water)',
      'Iprodione (20ml/20L water)',
    ],
    'organicControl': [
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Remove infected fruits',
      'Good air circulation',
      'Harvest when dry',
      'Handle carefully',
    ],
  },

  'Tomatoes_Storage_Post-Harvest Fungal Rot': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Store only undamaged, clean fruits',
      'Proper ripeness stage for storage',
      'Cool storage (10-13°C for ripe, 13-21°C for green)',
      'High humidity (85-95%)',
      'Good ventilation',
      'Regular inspection',
      'Remove rotting fruits immediately',
      'Don\'t store overripe tomatoes',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // ONIONS DISEASES - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Onions_Germination/Seedling_Pythium Root Rot': {
    'chemicalControl': [
      'Metalaxyl (seed treatment)',
      'Mefenoxam (soil drench)',
    ],
    'organicControl': [
      'Trichoderma species',
    ],
    'culturalControl': [
      'Excellent drainage - Critical',
      'Avoid overwatering',
      'Plant in warm, well-drained soil',
      'Raised beds',
      'Crop rotation',
    ],
  },

  'Onions_Germination/Seedling_Fusarium Basal Rot': {
    'chemicalControl': [
      'Thiabendazole (seed/bulb treatment)',
      'Prochloraz (seed treatment)',
    ],
    'organicControl': [
      'Trichoderma harzianum',
    ],
    'culturalControl': [
      'Use certified disease-free sets or seeds',
      'Crop rotation - 4 years minimum',
      'Avoid planting in infested soil',
      'Good drainage',
      'Avoid wounding bulbs',
      'Hot water treatment of sets - 43°C for 30 minutes',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Downy Mildew': {
    'chemicalControl': [
      'Metalaxyl (systemic fungicide)',
      'Fosetyl-Al (3g/L water)',
      'Mancozeb (40g/20L water) - Preventive',
      'Chlorothalonil (30ml/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Plant resistant varieties',
      'Good air circulation - Proper spacing',
      'Avoid overhead irrigation',
      'Water early in morning',
      'Remove infected leaves',
      'Crop rotation - 3 years',
      'Remove volunteer onions',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Powdery Mildew': {
    'chemicalControl': [
      'Sulfur spray (40g/20L water)',
      'Myclobutanil (5ml/20L water)',
    ],
    'organicControl': [
      'Sulfur spray',
      'Baking soda spray (5g/L + soap)',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Good air circulation',
      'Remove infected leaves',
      'Water at base',
      'Proper spacing',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Leaf Blight': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
    ],
    'culturalControl': [
      'Crop rotation',
      'Remove infected leaves',
      'Avoid overhead irrigation',
      'Destroy crop debris',
    ],
  },

  'Onions_Bulb Formation/Reproductive_Purple Blotch': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Mancozeb (40g/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper-based fungicides',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Crop rotation - 3 years',
      'Remove infected leaves',
      'Avoid overhead watering',
      'Proper spacing for air circulation',
      'Balanced fertilization - Avoid excess nitrogen',
      'Remove crop debris',
    ],
  },

  'Onions_Bulb Formation/Reproductive_Fusarium Basal Rot': {
    'chemicalControl': [
      'Thiabendazole (bulb dip)',
      'Prochloraz',
    ],
    'organicControl': [
      'Trichoderma',
    ],
    'culturalControl': [
      'Remove infected plants',
      'Crop rotation - 4 years',
      'Good drainage',
      'Avoid wounding bulbs',
      'Harvest at maturity',
    ],
  },

  'Onions_Bulbing/Maturation_Gray Mold': {
    'chemicalControl': [
      'Boscalid (10ml/20L water)',
      'Iprodione (20ml/20L water)',
    ],
    'organicControl': [
      'Bacillus subtilis',
    ],
    'culturalControl': [
      'Good air circulation',
      'Avoid excessive nitrogen',
      'Remove senescent foliage',
      'Harvest when tops fall naturally',
      'Cure properly before storage',
    ],
  },

  'Onions_Bulbing/Maturation_Neck Rot': {
    'chemicalControl': [
      'Boscalid (pre-harvest spray)',
    ],
    'organicControl': [
      'None highly effective',
    ],
    'culturalControl': [
      'Harvest at proper maturity',
      'Cure thoroughly - 2-4 weeks in warm, dry, ventilated area',
      'Remove tops after curing',
      'Store only well-cured bulbs',
      'Avoid excessive nitrogen - Promotes soft necks',
      'Good air circulation during curing',
    ],
  },

  'Onions_Bulbing/Maturation_Purple Blotch': {
    'chemicalControl': [
      'Chlorothalonil (30ml/20L water)',
      'Azoxystrobin (2ml/L water)',
    ],
    'organicControl': [
      'Copper fungicides',
    ],
    'culturalControl': [
      'Continue removing infected leaves',
      'Harvest when mature',
      'Proper curing',
    ],
  },

  'Onions_Harvesting/Storage_Gray Mold': {
    'chemicalControl': [
      'None in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Store only well-cured bulbs',
      'Cool storage (0-2°C)',
      'Dry conditions (65-70% humidity)',
      'Good ventilation',
      'Remove infected bulbs immediately',
      'Regular inspection',
    ],
  },

  'Onions_Harvesting/Storage_Post-Harvest Fungal Rot': {
    'chemicalControl': [
      'None recommended',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Proper curing - 2-4 weeks critical',
      'Store only undamaged, well-cured bulbs',
      'Cool storage (0-2°C)',
      'Dry conditions (65-70% humidity)',
      'Excellent ventilation',
      'Remove soft or rotting bulbs',
      'Regular inspection - Weekly',
      'Hang in mesh bags or on racks',
    ],
  },
};