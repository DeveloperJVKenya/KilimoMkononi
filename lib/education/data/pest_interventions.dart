// lib/education/data/pest_interventions.dart
// Complete intervention database for ALL pests across ALL crops
// Import this file in pest_data_input.dart

/// Teacher-only intervention database
/// Maps pest key (Crop_Stage_Pest) to intervention methods
final Map<String, Map<String, List<String>>> pestInterventions = {
  
  // ═══════════════════════════════════════════════════════════
  // BEANS PESTS - ALL STAGES
  // ═══════════════════════════════════════════════════════════
  
  'Beans_Germination/Seedling_Bean Fly': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Soil application at planting',
      'Thiamethoxam (25g/100L water) - Seed treatment before planting',
      'Cypermethrin (20ml/20L water) - Foliar spray if infestation severe',
      'Dimethoate (30ml/20L water) - Emergency control',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Apply to soil around seedlings weekly',
      'Bacillus thuringiensis (Bt) - Soil drench at emergence',
      'Diatomaceous earth - Create ring around plant base',
      'Row covers - Physical barrier during egg-laying period',
      'Garlic-chili spray - Natural repellent',
    ],
    'culturalControl': [
      'Crop rotation - Do not plant beans in same spot for 2-3 years',
      'Early planting - Plant before peak fly season',
      'Remove crop debris - Destroy all bean residue after harvest',
      'Deep tillage - Plow 20-30cm deep to expose pupae to birds',
      'Plant resistant varieties - Check with extension officer',
      'Avoid water stress - Maintain consistent moisture',
    ],
  },

  'Beans_Germination/Seedling_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha) - Soil application before planting',
      'Permethrin (25ml/20L water) - Spray at dusk on plant stems',
      'Lambda-cyhalothrin (10ml/20L water) - Soil drench around seedlings',
      'Chlorpyrifos (30ml/20L water) - Pre-planting treatment',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) (5ml/L water) - Very effective, spray at dusk',
      'Diatomaceous earth - Ring around seedling stems',
      'Wood ash - Sprinkle around base of plants',
      'Hand-picking at night - Use flashlight to find larvae',
      'Cardboard collars - Place around stems (5cm above, 3cm below soil)',
      'Crushed eggshells - Around stems as barrier',
    ],
    'culturalControl': [
      'Remove all crop debris 2-3 weeks before planting',
      'Till soil deeply - Expose larvae to birds and sun',
      'Delay planting - Wait until soil warms',
      'Plant in morning - Gives seedlings time to harden',
      'Keep field weed-free - Removes cutworm habitat',
      'Use trap crops - Plant sacrificial rows first',
      'Encourage birds - Natural predators',
    ],
  },

  'Beans_Germination/Seedling_Rodents': {
    'chemicalControl': [
      'Bromadiolone (rodenticide) - Use in bait stations ONLY',
      'Zinc phosphide - Grain bait, use with extreme caution',
      'Warfarin-based baits - Follow label instructions carefully',
    ],
    'organicControl': [
      'Mechanical traps - Snap traps or live traps',
      'Cats - Encourage natural predators',
      'Owl boxes - Attract barn owls to area',
      'Peppermint oil - Natural repellent around field edges',
    ],
    'culturalControl': [
      'Clear vegetation around field - Remove rodent hiding places',
      'Remove food sources - Clean up spilled grain',
      'Fencing - Bury wire mesh 30cm deep',
      'Store seeds securely - Metal containers',
      'Community action - Coordinate with neighbors',
    ],
  },

  'Beans_Germination/Seedling_Termites': {
    'chemicalControl': [
      'Chlorpyrifos (200ml/20L water) - Soil drench before planting',
      'Imidacloprid (seed treatment) - Coat seeds before planting',
      'Fipronil (termite bait) - Place around affected areas',
    ],
    'organicControl': [
      'Neem cake powder - Mix 2kg per 100m² into soil',
      'Wood ash - Create barrier around planting holes',
      'Orange oil spray (5ml/L water) - Natural termiticide',
      'Beneficial nematodes - Apply to soil',
      'Cardboard barriers - Termites eat cardboard instead',
    ],
    'culturalControl': [
      'Remove all wood debris - Eliminates food source',
      'Deep plowing before planting - Destroys galleries',
      'Plant during rainy season - Less termite activity',
      'Use certified seeds - Disease-free seeds resist better',
      'Maintain soil moisture - Dry soil attracts termites',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Systemic insecticide, soil drench',
      'Thiamethoxam (25g/100L water) - Foliar spray, very effective',
      'Acetamiprid (20g/100L water) - Contact and systemic',
      'Dimethoate (30ml/20L water) - When infestation severe',
      'Pirimicarb (15g/20L water) - Selective aphicide',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Spray weekly on leaf undersides',
      'Insecticidal soap (2% solution) - Direct spray on aphids',
      'Pyrethrin spray - Natural fast-acting',
      'Garlic spray (5 crushed cloves/L, steep 24hrs)',
      'Strong water spray - Dislodge aphids with hose',
      'Diatomaceous earth - Dust on plants',
    ],
    'culturalControl': [
      'Encourage ladybugs, lacewings, hoverflies - Natural predators',
      'Plant marigolds, nasturtiums - Attract predators',
      'Use reflective aluminum mulch - Confuses aphids',
      'Remove heavily infested leaves - Destroy immediately',
      'Avoid over-fertilizing with nitrogen - Creates tender growth',
      'Maintain plant spacing - Good air circulation',
      'Monitor regularly - Check undersides weekly',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Leafhoppers': {
    'chemicalControl': [
      'Imidacloprid (systemic) - Soil drench or spray',
      'Lambda-cyhalothrin (10ml/20L water) - Contact spray',
      'Thiamethoxam (25g/100L water) - Foliar application',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Weekly sprays',
      'Insecticidal soap - Direct spray',
      'Kaolin clay - Coat leaves to deter feeding',
      'Yellow sticky traps - Monitor and reduce populations',
    ],
    'culturalControl': [
      'Remove weeds - Alternate hosts for leafhoppers',
      'Use row covers - Physical barrier',
      'Plant resistant varieties - Check local recommendations',
      'Maintain plant vigor - Healthy plants resist better',
      'Remove crop residue - Destroys overwintering sites',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water) - Effective on thrips',
      'Thiamethoxam (25g/100L water) - Systemic control',
      'Lambda-cyhalothrin (10ml/20L water) - Contact spray',
    ],
    'organicControl': [
      'Neem oil (3ml/L water) - Weekly applications',
      'Insecticidal soap - Direct spray',
      'Blue sticky traps - Attract and trap thrips',
      'Reflective mulch - Repels thrips',
      'Strong water spray - Dislodge thrips',
    ],
    'culturalControl': [
      'Remove weeds and debris - Reduces breeding sites',
      'Use row covers - Exclude thrips',
      'Avoid excessive nitrogen - Susceptible foliage',
      'Maintain irrigation - Stressed plants vulnerable',
      'Crop rotation - Breaks lifecycle',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Soil drench for systemic control',
      'Spiromesifen (20ml/20L water) - Contact spray',
      'Thiamethoxam (25g/100L water) - Foliar spray',
      'Acetamiprid (20g/100L water) - Contact action',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Spray weekly, undersides too',
      'Insecticidal soap - Direct spray',
      'Yellow sticky traps - Hang 15cm above plants',
      'Garlic-chili spray - Natural repellent',
      'Encarsia formosa (parasitic wasp) - Biological control',
    ],
    'culturalControl': [
      'Reflective aluminum mulch - Confuses whiteflies',
      'Remove infested leaves - Destroy immediately',
      'Good air circulation - Reduces humidity',
      'Remove weeds - Alternate hosts',
      'Row covers on young plants - Physical barrier',
      'Quarantine new plants - Prevent introduction',
      'Disease-free transplants - If using transplants',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Beetles': {
    'chemicalControl': [
      'Carbaryl (2kg/ha) - Broad spectrum',
      'Cypermethrin (20ml/20L water) - Contact spray',
      'Lambda-cyhalothrin (10ml/20L water) - On adults',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Repellent',
      'Spinosad - Organic insecticide',
      'Hand-picking - Early morning when slow',
      'Diatomaceous earth - Dust on plants',
    ],
    'culturalControl': [
      'Crop rotation - Reduces populations',
      'Remove crop debris - Destroys overwintering sites',
      'Encourage birds - Natural predators',
      'Companion planting - Garlic, onions repel beetles',
      'Mulching - Reduces beetle emergence',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Rodents': {
    'chemicalControl': [
      'Bromadiolone (rodenticide) - Bait stations only',
      'Zinc phosphide - Grain bait, extreme caution',
    ],
    'organicControl': [
      'Mechanical traps - Snap or live traps',
      'Cats - Natural predators',
      'Owl boxes - Attract owls',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Clear field borders - Remove hiding places',
      'Remove food sources - Clean spilled grain',
      'Fencing - Wire mesh buried 30cm',
      'Community coordination - Work with neighbors',
    ],
  },

  'Beans_Flowering/Reproductive_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Systemic',
      'Thiamethoxam (25g/100L water) - Foliar',
      'Acetamiprid (20g/100L water) - Contact',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly sprays',
      'Insecticidal soap - Direct application',
      'Pyrethrin - Fast-acting',
      'Strong water spray - Dislodge',
    ],
    'culturalControl': [
      'Encourage predators - Ladybugs, lacewings',
      'Companion plants - Marigolds, nasturtiums',
      'Reflective mulch - Confuses aphids',
      'Remove infested parts - Immediately',
      'Avoid excess nitrogen - Tender growth',
    ],
  },

  'Beans_Flowering/Reproductive_Leafhoppers': {
    'chemicalControl': [
      'Imidacloprid - Systemic control',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Insecticidal soap',
      'Kaolin clay - Leaf coating',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Remove weeds - Alternate hosts',
      'Row covers - Barrier',
      'Resistant varieties',
      'Maintain vigor - Nutrition',
    ],
  },

  'Beans_Flowering/Reproductive_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Insecticidal soap',
      'Blue sticky traps',
      'Reflective mulch',
    ],
    'culturalControl': [
      'Remove weeds and debris',
      'Row covers',
      'Avoid excess nitrogen',
      'Maintain irrigation',
    ],
  },

  'Beans_Flowering/Reproductive_Pod Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - Spray flowers and pods',
      'Emamectin benzoate (5g/20L water) - Very effective',
      'Lambda-cyhalothrin (10ml/20L water) - Contact',
      'Indoxacarb (10ml/20L water) - Targets larvae',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Apply to flowers',
      'Neem oil (5ml/L water) - Weekly sprays',
      'Spinosad - Organic option',
      'Pheromone traps - Monitor adults',
      'Hand-pick affected pods - Destroy',
    ],
    'culturalControl': [
      'Early planting - Avoid peak borer season',
      'Remove infested pods - Prevent spread',
      'Deep plowing after harvest - Destroys pupae',
      'Crop rotation - Breaks lifecycle',
      'Intercrop with marigolds - Repellent',
      'Field hygiene - Remove debris',
    ],
  },

  'Beans_Flowering/Reproductive_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Systemic',
      'Spiromesifen (20ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Insecticidal soap',
      'Yellow sticky traps',
      'Garlic-chili spray',
    ],
    'culturalControl': [
      'Reflective mulch',
      'Remove infested leaves',
      'Good air circulation',
      'Remove weeds',
      'Quarantine new plants',
    ],
  },

  'Beans_Maturation/Harvesting_Pod Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - On pods',
      'Emamectin benzoate (5g/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem oil (5ml/L water)',
      'Hand-pick infested pods',
      'Pheromone traps',
    ],
    'culturalControl': [
      'Early harvest when mature',
      'Remove infested pods',
      'Deep plowing after harvest',
      'Crop rotation',
      'Field hygiene',
    ],
  },

  'Beans_Maturation/Harvesting_Beetles': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Cypermethrin (20ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Hand-picking',
      'Diatomaceous earth',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove debris after harvest',
      'Encourage birds',
    ],
  },

  'Beans_Maturation/Harvesting_Bean Weevil': {
    'chemicalControl': [
      'Pirimiphos-methyl (dust) - Mix with stored beans',
      'Deltamethrin (grain protectant) - Before storage',
    ],
    'organicControl': [
      'Diatomaceous earth (2% by weight) - Mix with beans',
      'Neem leaf powder - Storage protectant',
      'Freezing - Kill eggs (-18°C for 3 days)',
      'Solar heat (60°C for 1 hour) - Kills all stages',
      'Hermetic storage - Airtight containers',
    ],
    'culturalControl': [
      'Early harvest when pods dry',
      'Proper drying - 12-13% moisture',
      'Clean storage facilities',
      'Metal/plastic containers - Tight lids',
      'Regular inspection - Monthly checks',
      'Small batch storage',
    ],
  },

  'Beans_Maturation/Harvesting_Bruchid Beetles': {
    'chemicalControl': [
      'Aluminum phosphide fumigation - Professional only',
      'Pirimiphos-methyl - Grain protectant',
    ],
    'organicControl': [
      'Diatomaceous earth (2% by weight)',
      'Ash (wood ash) - 1:10 ratio',
      'Neem seed powder - Mix with beans',
      'Vegetable oil coating - Light coating',
      'Triple-bagging (PICS bags) - Airtight',
    ],
    'culturalControl': [
      'Proper drying - Below 13% moisture',
      'Clean storage - Remove debris',
      'Metal/plastic containers',
      'Regular monitoring - Every 2 weeks',
      'Cool storage - Lower temperature',
      'Sunning - Periodic exposure',
    ],
  },

  'Beans_Maturation/Harvesting_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide - Grain bait',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats - Natural control',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clean storage areas',
      'Secure containers',
      'Remove food sources',
      'Community action',
    ],
  },

  'Beans_Storage_Bean Weevil': {
    'chemicalControl': [
      'Pirimiphos-methyl - Grain protectant',
      'Deltamethrin dust',
    ],
    'organicControl': [
      'Diatomaceous earth (2%)',
      'PICS bags - Hermetic storage',
      'Neem products',
      'Freezing treatment',
      'Solar heating',
    ],
    'culturalControl': [
      'Proper drying - 12-13% moisture',
      'Clean storage facilities',
      'Airtight containers',
      'Regular inspection - Weekly',
      'Temperature control',
    ],
  },

  'Beans_Storage_Bruchid Beetles': {
    'chemicalControl': [
      'Aluminum phosphide - Professional',
      'Pirimiphos-methyl',
    ],
    'organicControl': [
      'Diatomaceous earth (2%)',
      'PICS bags (triple-layer)',
      'Ash treatment - Traditional',
      'Vegetable oil coating',
    ],
    'culturalControl': [
      'Thorough drying - Below 13%',
      'Complete sanitation',
      'Metal silos - Best option',
      'Weekly inspection',
      'Small batch storage',
    ],
  },

  'Beans_Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations only',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps - Multiple types',
      'Cats - Ongoing control',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Sealed storage - Metal containers',
      'Raised platforms - Off ground',
      'Remove access points',
      'Clean surrounding areas',
      'Community coordination',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // MAIZE PESTS - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Maize_Germination/Seedling_Termites': {
    'chemicalControl': [
      'Chlorpyrifos (200ml/20L water) - Soil drench before planting',
      'Imidacloprid (seed treatment) - Coat seeds',
      'Fipronil (termite bait) - Around affected areas',
    ],
    'organicControl': [
      'Neem cake powder - 2kg per 100m²',
      'Wood ash - Barrier around holes',
      'Orange oil spray (5ml/L water)',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Remove wood debris - Eliminates food',
      'Deep plowing - Destroys galleries',
      'Plant during rains - Less activity',
      'Certified seeds - Disease-free',
      'Maintain soil moisture',
    ],
  },

  'Maize_Germination/Seedling_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha) - Soil application',
      'Permethrin (25ml/20L water) - Dusk spray',
      'Lambda-cyhalothrin (10ml/20L water) - Soil drench',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - At dusk',
      'Diatomaceous earth - Around stems',
      'Wood ash - Plant base',
      'Hand-picking - Night with flashlight',
      'Cardboard collars - 5cm above, 3cm below',
    ],
    'culturalControl': [
      'Remove debris 2-3 weeks before planting',
      'Deep tillage - Expose larvae',
      'Plant in warm soil',
      'Keep weed-free',
      'Encourage birds',
    ],
  },

  'Maize_Germination/Seedling_Maize Shoot Fly': {
    'chemicalControl': [
      'Imidacloprid (seed treatment)',
      'Thiamethoxam (25g/100L water)',
      'Cypermethrin (20ml/20L water) - If severe',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Soil application',
      'Wood ash in whorl - Traditional',
      'Row covers - Physical barrier',
    ],
    'culturalControl': [
      'Early planting - Avoid peak fly season',
      'Remove infested plants - Destroy',
      'Deep plowing - Destroys pupae',
      'Certified seeds',
      'Crop rotation',
    ],
  },

  'Maize_Germination/Seedling_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide - Grain bait',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats - Natural predators',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear vegetation around field',
      'Remove food sources',
      'Secure seed storage',
      'Community action',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Systemic',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly',
      'Insecticidal soap',
      'Strong water spray',
      'Encourage ladybugs',
    ],
    'culturalControl': [
      'Remove infested plants',
      'Companion crops - Marigolds',
      'Avoid excess nitrogen',
      'Monitor regularly',
      'Maintain spacing',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Stem Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - Early whorl',
      'Lambda-cyhalothrin (10ml/20L water) - Before tasseling',
      'Chlorpyrifos granules (10kg/ha) - Pour in whorl',
      'Carbofuran (1kg/ha) - Soil (caution)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - In whorl',
      'Neem seed powder (250g/20L water)',
      'Trichogramma wasps (50,000/ha)',
      'Wood ash + sand - In whorl',
      'Push-pull (Desmodium + Napier grass)',
    ],
    'culturalControl': [
      'Early planting - Avoid peak season',
      'Remove infested plants - Immediately',
      'Resistant varieties',
      'Intercrop with Desmodium',
      'Napier grass borders - Trap crop',
      'Destroy residues after harvest',
      'Scout weekly - Early detection',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Armyworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Emergency',
      'Lambda-cyhalothrin (10ml/20L water) - Very effective',
      'Emamectin benzoate (5g/20L water) - Best for severe',
      'Cypermethrin (20ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Morning/evening',
      'Spinosad - Organic approved',
      'Neem oil (5ml/L water)',
      'NPV (Nuclear polyhedrosis virus)',
      'Hand-picking daily',
    ],
    'culturalControl': [
      'Scout daily - Critical',
      'Plow after harvest - Destroys pupae',
      'Light traps - Catch moths',
      'Encourage birds, wasps, beetles',
      'Plant early - Avoid peak',
      'Report outbreaks - Extension officers',
      'Community coordination',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Leafhoppers': {
    'chemicalControl': [
      'Imidacloprid - Systemic',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Insecticidal soap',
      'Kaolin clay - Coating',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Remove weeds - Alternate hosts',
      'Destroy residue',
      'Resistant varieties',
      'Maintain vigor',
      'Row covers',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Grasshoppers': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Malathion (30ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Repellent',
      'Garlic-chili spray',
      'Hand-picking - Early morning',
      'Guinea fowl/chickens',
    ],
    'culturalControl': [
      'Clear vegetation around field',
      'Encourage birds',
      'Plant trap crops',
      'Community action',
      'Tilling - Destroys egg pods',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Insecticidal soap',
      'Blue sticky traps',
      'Reflective mulch',
    ],
    'culturalControl': [
      'Remove weeds',
      'Avoid excess nitrogen',
      'Maintain irrigation',
      'Crop rotation',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear field borders',
      'Remove food sources',
      'Community coordination',
    ],
  },

  'Maize_Flowering/Reproductive_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Insecticidal soap',
      'Water spray',
      'Encourage predators',
    ],
    'culturalControl': [
      'Remove infested parts',
      'Avoid excess nitrogen',
      'Monitor regularly',
      'Maintain spacing',
    ],
  },

  'Maize_Flowering/Reproductive_Stem Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Chlorpyrifos granules (10kg/ha)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem powder (250g/20L water)',
      'Trichogramma wasps',
      'Push-pull technology',
    ],
    'culturalControl': [
      'Early planting',
      'Remove infested plants',
      'Resistant varieties',
      'Intercrop with legumes',
      'Destroy residues',
    ],
  },

  'Maize_Flowering/Reproductive_Armyworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Spinosad',
      'NPV virus',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Plow after harvest',
      'Light traps',
      'Encourage natural enemies',
      'Community action',
    ],
  },

  'Maize_Flowering/Reproductive_Leafhoppers': {
    'chemicalControl': [
      'Imidacloprid',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Insecticidal soap',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Remove weeds',
      'Resistant varieties',
      'Maintain vigor',
    ],
  },

  'Maize_Flowering/Reproductive_Grasshoppers': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Hand-picking',
      'Guinea fowl',
    ],
    'culturalControl': [
      'Clear vegetation',
      'Encourage birds',
      'Tilling - Egg pods',
    ],
  },

  'Maize_Flowering/Reproductive_Earworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - On silk',
      'Emamectin benzoate (5g/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Fresh silk',
      'Neem oil (5ml/L water)',
      'Vegetable oil drops - In silk',
      'Hand removal',
    ],
    'culturalControl': [
      'Early maturing varieties',
      'Destroy infested ears',
      'Deep plowing',
      'Encourage wasps, birds',
      'Synchronous planting',
    ],
  },

  'Maize_Flowering/Reproductive_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
    ],
    'culturalControl': [
      'Remove weeds',
      'Crop rotation',
    ],
  },

  'Maize_Flowering/Reproductive_Birds': {
    'chemicalControl': [
      'None recommended - Use deterrents',
    ],
    'organicControl': [
      'Scarecrows - Move regularly',
      'Reflective tape - Hang in field',
      'Noise makers - Periodic',
      'Netting - Over small areas',
    ],
    'culturalControl': [
      'Plant larger area - Reduces loss percentage',
      'Community planting - Same timing',
      'Early harvest - When mature',
      'Guard field - During vulnerable period',
      'Alternative food sources - Away from field',
    ],
  },

  'Maize_Maturation/Harvesting_Earworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Hand removal - Check ears',
      'Bacillus thuringiensis (Bt)',
    ],
    'culturalControl': [
      'Early harvest',
      'Destroy infested ears',
      'Deep plowing after harvest',
    ],
  },

  'Maize_Maturation/Harvesting_Weevils': {
    'chemicalControl': [
      'Pirimiphos-methyl - Before storage',
      'Deltamethrin dust',
    ],
    'organicControl': [
      'Diatomaceous earth (2%)',
      'Neem leaf powder',
      'Ash (1:10 ratio)',
      'PICS bags - Hermetic',
      'Freezing (-18°C, 3 days)',
    ],
    'culturalControl': [
      'Proper drying - Below 13.5% moisture',
      'Clean storage - Remove old grain',
      'Metal/plastic containers',
      'Regular inspection - Every 2 weeks',
      'Sunning grain - Periodic',
      'Early harvest',
    ],
  },

  'Maize_Maturation/Harvesting_Birds': {
    'chemicalControl': [
      'None - Use deterrents',
    ],
    'organicControl': [
      'Scarecrows - Vary position',
      'Reflective materials',
      'Noise makers',
      'Netting',
    ],
    'culturalControl': [
      'Harvest promptly when mature',
      'Guard field',
      'Community timing',
    ],
  },

  'Maize_Maturation/Harvesting_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clean harvest area',
      'Secure storage',
      'Remove food sources',
    ],
  },

  'Maize_Storage_Larger Grain Borer': {
    'chemicalControl': [
      'Aluminum phosphide - Professional only',
      'Pirimiphos-methyl',
    ],
    'organicControl': [
      'Diatomaceous earth (2%) - Very effective',
      'PICS bags - Triple-layer airtight',
      'Neem products',
      'Ash treatment',
    ],
    'culturalControl': [
      'Thorough drying - Below 13% moisture',
      'Complete sanitation - Clean structures',
      'Metal silos - Best storage',
      'Weekly inspection',
      'Small batch storage',
      'Shelling before storage',
    ],
  },

  'Maize_Storage_Angoumois Grain Moth': {
    'chemicalControl': [
      'Pirimiphos-methyl - Grain protectant',
      'Deltamethrin',
    ],
    'organicControl': [
      'Diatomaceous earth (2%)',
      'PICS bags - Hermetic',
      'Neem powder',
      'Freezing treatment',
    ],
    'culturalControl': [
      'Proper drying - Critical',
      'Clean storage',
      'Airtight containers',
      'Regular monitoring',
      'Temperature control',
    ],
  },

  'Maize_Storage_Weevils': {
    'chemicalControl': [
      'Pirimiphos-methyl',
      'Deltamethrin dust',
    ],
    'organicControl': [
      'Diatomaceous earth (2%)',
      'Ash (1:10)',
      'PICS bags',
      'Neem products',
    ],
    'culturalControl': [
      'Drying - Below 13.5%',
      'Clean storage',
      'Sealed containers',
      'Regular checks',
    ],
  },

  'Maize_Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats - Ongoing',
      'Peppermint oil',
    ],
    'culturalControl': [
      'Sealed storage - Metal',
      'Raised platforms',
      'Remove access points',
      'Community coordination',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CABBAGE PESTS - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Cabbage_Germination/Seedling_Termites': {
    'chemicalControl': [
      'Chlorpyrifos (200ml/20L water) - Soil drench',
      'Imidacloprid (seed treatment)',
      'Fipronil - Termite bait',
    ],
    'organicControl': [
      'Neem cake powder - 2kg per 100m²',
      'Wood ash barrier',
      'Orange oil spray (5ml/L water)',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Remove wood debris',
      'Deep plowing',
      'Plant during rains',
      'Maintain soil moisture',
    ],
  },

  'Cabbage_Germination/Seedling_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Permethrin (25ml/20L water) - Dusk application',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - At dusk',
      'Diatomaceous earth around stems',
      'Wood ash at base',
      'Hand-picking at night',
      'Cardboard collars (5cm above, 3cm below)',
    ],
    'culturalControl': [
      'Remove debris 2-3 weeks before planting',
      'Deep tillage',
      'Plant in warm soil',
      'Weed-free field',
      'Encourage birds',
    ],
  },

  'Cabbage_Germination/Seedling_Root Maggots': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Soil drench',
      'Diazinon - Around plant base',
    ],
    'organicControl': [
      'Beneficial nematodes - Apply to soil',
      'Row covers - Physical barrier',
      'Wood ash around stem',
    ],
    'culturalControl': [
      'Delay planting - Avoid fly peak',
      'Crop rotation - 3-year minimum',
      'Hill soil around stems',
      'Remove brassica weeds',
    ],
  },

  'Cabbage_Germination/Seedling_Flea Beetles': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Spinosad (5ml/L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Diatomaceous earth - Dust plants',
      'Garlic spray',
      'Row covers - Very effective',
    ],
    'culturalControl': [
      'Plant later - Avoid beetle emergence',
      'Keep well watered - Healthy plants resist',
      'Remove crop debris',
      'Weed control',
      'Trap crops - Radish or mustard',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
      'Pirimicarb (15g/20L water) - Selective',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly',
      'Insecticidal soap (2%)',
      'Pyrethrin spray',
      'Strong water spray',
      'Garlic spray',
    ],
    'culturalControl': [
      'Encourage ladybugs, lacewings',
      'Plant companion flowers - Alyssum, marigolds',
      'Reflective mulch',
      'Remove infested leaves',
      'Avoid excess nitrogen',
      'Good spacing - Air circulation',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Systemic',
      'Spiromesifen (20ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Weekly',
      'Insecticidal soap',
      'Yellow sticky traps',
      'Garlic-chili spray',
    ],
    'culturalControl': [
      'Reflective mulch',
      'Remove infested leaves',
      'Good air circulation',
      'Row covers',
      'Clean transplants',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Cross Stripped Cabbageworm': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Very effective',
      'Neem oil (5ml/L water)',
      'Spinosad',
      'Hand-picking',
    ],
    'culturalControl': [
      'Crop rotation - Non-brassicas',
      'Remove debris after harvest',
      'Row covers',
      'Encourage parasitic wasps',
      'Companion planting - Aromatic herbs',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Diamondback Moth': {
    'chemicalControl': [
      'Emamectin benzoate (5g/20L water) - Most effective',
      'Spinosad (5ml/L water) - Organic option',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Indoxacarb (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Excellent',
      'Neem oil (3-5ml/L water) - Weekly',
      'Garlic-chili spray',
      'Hand-picking larvae',
      'Trichogramma wasps - Parasitoids',
    ],
    'culturalControl': [
      'Crop rotation with non-brassicas',
      'Remove debris immediately after harvest',
      'Row covers during peak season',
      'Intercrop with onions, garlic',
      'Encourage natural predators',
      'Avoid planting near old brassica fields',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Cabbage Looper': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water) - Organic',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Very effective',
      'Neem oil (5ml/L water)',
      'Hand-picking - Check undersides',
      'Parasitic wasps - Biological control',
    ],
    'culturalControl': [
      'Crop rotation',
      'Remove weeds - Alternate hosts',
      'Deep plowing',
      'Encourage birds',
      'Row covers',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Permethrin (25ml/20L water) - Dusk',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Dusk application',
      'Diatomaceous earth',
      'Wood ash',
      'Hand-picking at night',
      'Cardboard collars',
    ],
    'culturalControl': [
      'Remove debris before planting',
      'Deep tillage',
      'Plant in morning',
      'Keep weed-free',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Flea Beetles': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Spinosad (5ml/L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Weekly',
      'Diatomaceous earth',
      'Garlic spray',
      'Row covers - Best prevention',
    ],
    'culturalControl': [
      'Keep well watered',
      'Remove debris',
      'Trap crops - Radish',
      'Weed control',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Cabbage Webworm': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem oil (5ml/L water)',
      'Hand-picking larvae',
    ],
    'culturalControl': [
      'Remove infested plants',
      'Crop rotation',
      'Clean field after harvest',
      'Encourage predators',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Armyworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Morning/evening',
      'Spinosad',
      'NPV virus',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Plow after harvest',
      'Light traps',
      'Encourage natural enemies',
      'Community action',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Cabbage Root Maggot': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Soil drench',
      'Diazinon - Around base',
    ],
    'organicControl': [
      'Beneficial nematodes',
      'Row covers - Physical barrier',
      'Wood ash around stems',
    ],
    'culturalControl': [
      'Delay planting',
      'Crop rotation - 3 years',
      'Hill soil around stems',
      'Remove brassica weeds',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear field borders',
      'Remove food sources',
      'Community coordination',
    ],
  },

  'Cabbage_Flowering/Reproductive_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Insecticidal soap',
      'Strong water spray',
    ],
    'culturalControl': [
      'Encourage predators',
      'Remove infested parts',
      'Reflective mulch',
    ],
  },

  'Cabbage_Flowering/Reproductive_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid',
      'Spiromesifen (20ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Yellow sticky traps',
      'Insecticidal soap',
    ],
    'culturalControl': [
      'Reflective mulch',
      'Remove infested leaves',
      'Good air circulation',
    ],
  },

  'Cabbage_Flowering/Reproductive_Thrip': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
      'Insecticidal soap',
    ],
    'culturalControl': [
      'Remove weeds',
      'Maintain irrigation',
      'Crop rotation',
    ],
  },

  'Cabbage_Flowering/Reproductive_Diamondback Moth': {
    'chemicalControl': [
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem oil (3-5ml/L water)',
      'Trichogramma wasps',
      'Hand-picking',
    ],
    'culturalControl': [
      'Crop rotation',
      'Remove debris',
      'Row covers',
      'Intercrop with aromatics',
    ],
  },

  'Cabbage_Flowering/Reproductive_Cabbage Looper': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem oil (5ml/L water)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Crop rotation',
      'Remove weeds',
      'Encourage birds',
    ],
  },

  'Cabbage_Flowering/Reproductive_Armyworm': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Spinosad',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Light traps',
      'Community action',
    ],
  },

  'Cabbage_Flowering/Reproductive_Stink Bug': {
    'chemicalControl': [
      'Lambda-cyhalothrin (10ml/20L water)',
      'Cypermethrin (20ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Hand-picking - Early morning',
      'Soap water spray',
    ],
    'culturalControl': [
      'Remove weeds - Alternate hosts',
      'Trap crops - Mustard',
      'Encourage natural predators',
    ],
  },

  'Cabbage_Maturation/Harvesting_Diamondback Moth': {
    'chemicalControl': [
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove infested heads',
      'Deep plow after harvest',
    ],
  },

  'Cabbage_Maturation/Harvesting_Cabbage Looper': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Harvest when mature',
      'Clean field after harvest',
    ],
  },

  'Cabbage_Maturation/Harvesting_Leafminers': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Remove infested leaves',
    ],
    'culturalControl': [
      'Remove and destroy infested leaves',
      'Crop rotation',
      'Row covers',
    ],
  },

  'Cabbage_Maturation/Harvesting_Flea Beetle': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Diatomaceous earth',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove debris',
    ],
  },

  'Cabbage_Maturation/Harvesting_Cabbage Webworm': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Remove infested heads',
      'Clean field',
    ],
  },

  'Cabbage_Maturation/Harvesting_Armyworm': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Harvest promptly',
    ],
  },

  'Cabbage_Maturation/Harvesting_Stink Bug': {
    'chemicalControl': [
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Hand-picking',
      'Soap water spray',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove weeds',
    ],
  },

  'Cabbage_Maturation/Harvesting_Rodent': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
    ],
    'culturalControl': [
      'Clean storage area',
      'Secure containers',
    ],
  },

  'Cabbage_Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Peppermint oil',
    ],
    'culturalControl': [
      'Clean storage - Cool, dry',
      'Sealed containers or bags',
      'Raised platforms',
      'Regular inspection',
    ],
  },

  'Cabbage_Storage_Aphids': {
    'chemicalControl': [
      'Fumigation if severe - Professional',
    ],
    'organicControl': [
      'Remove infested outer leaves',
      'Cold storage - Reduces activity',
    ],
    'culturalControl': [
      'Store only healthy heads',
      'Cool temperature (0-2°C)',
      'High humidity (95-100%)',
      'Regular inspection',
    ],
  },

  'Cabbage_Storage_Whiteflies': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'Remove infested leaves before storage',
      'Cold storage',
    ],
    'culturalControl': [
      'Clean cabbage before storage',
      'Cool, dry storage',
      'Regular inspection',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CARROTS PESTS - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Carrots_Germination/Seedling_Termites': {
    'chemicalControl': [
      'Chlorpyrifos (200ml/20L water) - Soil drench',
      'Imidacloprid (seed treatment)',
      'Fipronil - Termite bait',
    ],
    'organicControl': [
      'Neem cake powder - 2kg per 100m²',
      'Wood ash barrier',
      'Orange oil spray (5ml/L water)',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Remove wood debris',
      'Deep plowing',
      'Maintain soil moisture',
      'Plant during rains',
    ],
  },

  'Carrots_Germination/Seedling_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha)',
      'Permethrin (25ml/20L water) - Dusk',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Dusk',
      'Diatomaceous earth around seedlings',
      'Wood ash at base',
      'Hand-picking at night',
      'Cardboard collars',
    ],
    'culturalControl': [
      'Remove debris 2-3 weeks before planting',
      'Deep tillage',
      'Plant in warm soil',
      'Keep weed-free',
    ],
  },

  'Carrots_Germination/Seedling_Carrot Rust Fly': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - Soil drench',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Chlorpyrifos (30ml/20L water) - Preventive',
    ],
    'organicControl': [
      'Beneficial nematodes - Apply to soil',
      'Row covers - Physical barrier',
      'Companion planting - Onions, leeks',
      'Delay thinning until evening',
    ],
    'culturalControl': [
      'Crop rotation - 4-year minimum with non-umbellifers',
      'Late sowing - Avoid first generation',
      'Remove carrot family weeds',
      'Hill soil around plants',
      'Harvest promptly when mature',
    ],
  },

  'Carrots_Germination/Seedling_Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Soil application (use caution)',
      'Fenamiphos - Pre-planting',
    ],
    'organicControl': [
      'Marigolds - Plant as trap crop',
      'Neem cake - Mix into soil',
      'Organic matter - Increases beneficial organisms',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 year cycle',
      'Solarization - Cover soil with clear plastic for 4-6 weeks',
      'Resistant varieties - Check availability',
      'Deep plowing - Exposes nematodes',
      'Add compost - Increases beneficial organisms',
    ],
  },

  'Carrots_Germination/Seedling_Wireworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Soil drench',
      'Imidacloprid (seed treatment)',
    ],
    'organicControl': [
      'Trap with potato pieces - Bury, remove after 3 days',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Avoid planting in recently grassed areas',
      'Fall tillage - Exposes larvae',
      'Crop rotation',
      'Remove grass 1 year before planting',
    ],
  },

  'Carrots_Germination/Seedling_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear vegetation around field',
      'Remove food sources',
      'Secure seed storage',
      'Community action',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly',
      'Insecticidal soap',
      'Strong water spray',
      'Garlic spray',
    ],
    'culturalControl': [
      'Encourage ladybugs, lacewings',
      'Companion plants - Marigolds',
      'Reflective mulch',
      'Remove infested plants',
      'Avoid excess nitrogen',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Systemic',
      'Spiromesifen (20ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Yellow sticky traps',
      'Insecticidal soap',
    ],
    'culturalControl': [
      'Reflective mulch',
      'Remove infested leaves',
      'Good air circulation',
      'Row covers',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
      'Insecticidal soap',
    ],
    'culturalControl': [
      'Remove weeds',
      'Maintain irrigation',
      'Crop rotation',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Leaf Loopers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Neem oil (5ml/L water)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Encourage birds',
      'Crop rotation',
      'Remove weeds',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Leafminers': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water)',
      'Remove and destroy infested leaves',
    ],
    'culturalControl': [
      'Remove infested leaves immediately',
      'Crop rotation',
      'Row covers - Prevent adult flies',
      'Weed control',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Carrot Rust Fly': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - Soil drench',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Chlorpyrifos (30ml/20L water)',
    ],
    'organicControl': [
      'Beneficial nematodes - Apply to soil',
      'Row covers - Very effective',
      'Companion planting - Onions, leeks repel flies',
      'Delay thinning until evening',
    ],
    'culturalControl': [
      'Crop rotation - 4 years minimum',
      'Late sowing to avoid first generation',
      'Remove carrot family weeds',
      'Hill soil around crowns',
      'Harvest promptly',
      'Thin carefully - Smell attracts flies',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use caution',
    ],
    'organicControl': [
      'Marigolds - Trap crop',
      'Neem cake in soil',
      'Compost - Beneficial organisms',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years',
      'Soil solarization',
      'Resistant varieties',
      'Add organic matter',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Wireworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Imidacloprid',
    ],
    'organicControl': [
      'Potato traps - Bury, check after 3 days',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Avoid newly grassed areas',
      'Fall tillage',
      'Crop rotation',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Armyworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Spinosad',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Light traps',
      'Community action',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear field borders',
      'Remove food sources',
      'Community coordination',
    ],
  },

  'Carrots_Maturation/Harvesting_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Water spray',
    ],
    'culturalControl': [
      'Timely harvest',
      'Encourage predators',
    ],
  },

  'Carrots_Maturation/Harvesting_White Flies': {
    'chemicalControl': [
      'Imidacloprid',
      'Spiromesifen (20ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove infested plants',
    ],
  },

  'Carrots_Maturation/Harvesting_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove weeds',
    ],
  },

  'Carrots_Maturation/Harvesting_Leaf Loopers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove foliage after harvest',
    ],
  },

  'Carrots_Maturation/Harvesting_Leaf Miners': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Remove infested leaves',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Destroy foliage after harvest',
    ],
  },

  'Carrots_Maturation/Harvesting_Carrot Rust Fly': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Row covers until harvest',
      'Harvest promptly when mature',
    ],
    'culturalControl': [
      'Timely harvest - Don\t leave overripe',
      'Remove and destroy infested roots',
      'Clean field after harvest',
    ],
  },

  'Carrots_Maturation/Harvesting_Nematodes': {
    'chemicalControl': [
      'None recommended at this stage',
    ],
    'organicControl': [
      'Not applicable at harvest',
    ],
    'culturalControl': [
      'Harvest and remove roots',
      'Rotate next season',
      'Don\t replant carrots in same spot',
    ],
  },

  'Carrots_Maturation/Harvesting_Wireworms': {
    'chemicalControl': [
      'None recommended at harvest',
    ],
    'organicControl': [
      'Potato traps after harvest',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Fall tillage after harvest',
    ],
  },

  'Carrots_Maturation/Harvesting_Armyworms': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove foliage',
    ],
  },

  'Carrots_Maturation/Harvesting_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Don\t leave carrots in ground too long',
    ],
  },

  'Carrots_Storage_Carrot Rust Fly': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'Inspect and remove infested carrots',
    ],
    'culturalControl': [
      'Store only healthy, undamaged carrots',
      'Cool storage (0-2°C)',
      'High humidity (95-100%)',
      'Regular inspection - Remove damaged',
    ],
  },

  'Carrots_Storage_Nematodes': {
    'chemicalControl': [
      'Not applicable in storage',
    ],
    'organicControl': [
      'Not applicable',
    ],
    'culturalControl': [
      'Store only clean, undamaged carrots',
      'Cool, moist conditions',
      'Sand or sawdust storage medium',
    ],
  },

  'Carrots_Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations away from carrots',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Sealed storage - Rodent-proof containers',
      'Cool storage room - Secure doors/windows',
      'Raised storage platforms',
      'Remove access points',
      'Clean surrounding areas',
    ],
  },

  'Carrots_Storage_Aphids': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'Remove infested carrots',
    ],
    'culturalControl': [
      'Store only clean carrots',
      'Cool temperature (0-2°C) - Reduces activity',
      'Regular inspection',
      'Remove and discard infested carrots',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // TOMATOES PESTS  - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Tomatoes_Germination/Seedling_Cutworms': {
    'chemicalControl': [
      'Carbaryl (2kg/ha) - Soil application',
      'Permethrin (25ml/20L water) - Dusk spray',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Dusk',
      'Diatomaceous earth - Around stems',
      'Cardboard collars (5cm above, 3cm below)',
      'Hand-picking at night',
    ],
    'culturalControl': [
      'Remove debris 2-3 weeks before planting',
      'Deep tillage',
      'Plant in warm soil',
      'Keep weed-free',
    ],
  },

  'Tomatoes_Germination/Seedling_Termites': {
    'chemicalControl': [
      'Chlorpyrifos (200ml/20L water) - Soil drench',
      'Imidacloprid (seed treatment)',
    ],
    'organicControl': [
      'Neem cake powder - 2kg per 100m²',
      'Wood ash barrier',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Remove wood debris',
      'Deep plowing',
      'Maintain soil moisture',
    ],
  },

  'Tomatoes_Germination/Seedling_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
      'Zinc phosphide',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Owl boxes',
    ],
    'culturalControl': [
      'Clear vegetation around field',
      'Secure seedlings',
      'Community action',
    ],
  },

  'Tomatoes_Germination/Seedling_Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use caution',
      'Fenamiphos - Pre-planting',
    ],
    'organicControl': [
      'Marigolds - Plant before tomatoes',
      'Neem cake in soil',
      'Compost - Beneficial organisms',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years',
      'Soil solarization - 4-6 weeks',
      'Resistant varieties - Many available',
      'Grafting onto resistant rootstock',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Systemic',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
      'Pirimicarb (15g/20L water) - Selective',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly on undersides',
      'Insecticidal soap (2%)',
      'Pyrethrin spray',
      'Strong water spray - Dislodge',
      'Garlic spray',
    ],
    'culturalControl': [
      'Encourage ladybugs, lacewings, hoverflies',
      'Plant companion flowers - Marigolds, nasturtiums',
      'Reflective mulch - Silver/aluminum',
      'Remove heavily infested leaves',
      'Avoid excess nitrogen fertilizer',
      'Proper plant spacing - Air circulation',
      'Monitor weekly - Check undersides',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Soil drench for systemic control',
      'Spiromesifen (20ml/20L water) - Contact spray',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Spray weekly, especially undersides',
      'Insecticidal soap - Direct spray on whiteflies',
      'Yellow sticky traps - Hang 15-20cm above plants',
      'Garlic-chili spray - Natural repellent',
      'Encarsia formosa (parasitic wasp) - Greenhouse biological control',
    ],
    'culturalControl': [
      'Reflective aluminum mulch - Confuses whiteflies',
      'Remove heavily infested leaves immediately',
      'Maintain good air circulation - Spacing and pruning',
      'Remove weeds - Alternate hosts',
      'Use row covers on young plants',
      'Quarantine new plants - Inspect before introducing',
      'Use disease-free transplants',
      'Avoid planting near cucurbits',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water) - Organic option',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water) - Weekly',
      'Insecticidal soap',
      'Blue sticky traps - Attract thrips',
      'Reflective mulch',
      'Strong water spray',
    ],
    'culturalControl': [
      'Remove weeds and plant debris',
      'Use row covers - Exclude thrips',
      'Avoid excessive nitrogen',
      'Maintain adequate irrigation',
      'Crop rotation',
      'Remove infested flowers',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Leafminers': {
    'chemicalControl': [
      'Abamectin (5ml/20L water) - Systemic',
      'Spinosad (5ml/L water)',
      'Cyromazine - Growth regulator',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Repellent',
      'Remove and destroy infested leaves immediately',
      'Yellow sticky traps - Monitor adults',
    ],
    'culturalControl': [
      'Remove infested leaves as soon as mines appear',
      'Destroy all removed foliage - Don\t compost',
      'Crop rotation',
      'Row covers - Prevent adult flies from laying eggs',
      'Encourage parasitic wasps',
      'Weed control - Removes alternate hosts',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Spider Mites': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spiromesifen (20ml/20L water)',
      'Bifenazate (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Weekly, spray undersides',
      'Insecticidal soap - Direct contact needed',
      'Strong water spray - Daily dislodging',
      'Predatory mites - Phytoseiulus persimilis',
      'Sulfur dust - Traditional control',
    ],
    'culturalControl': [
      'Maintain adequate moisture - Dry conditions favor mites',
      'Overhead irrigation - Disrupts mites',
      'Remove heavily infested leaves',
      'Avoid excessive dust - Keep aisles moist',
      'Plant diversity - Encourages predators',
      'Avoid broad-spectrum insecticides - Kill beneficial mites',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Tomato Hornworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Spinosad (5ml/L water) - Organic option',
      'Carbaryl (2kg/ha)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Very effective on young larvae',
      'Hand-picking - Large larvae easy to spot',
      'Encourage parasitic wasps - Leave larvae with white cocoons',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Hand-pick larvae - Check plants daily',
      'Look for droppings on leaves - Indicates presence above',
      'Encourage beneficial wasps - Don\t kill larvae with white cocoons',
      'Till soil after harvest - Destroys pupae',
      'Companion planting - Dill, basil attract wasps',
      'Crop rotation',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Beet Armyworm': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Emamectin benzoate (5g/20L water) - Very effective',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Apply early, young larvae',
      'Spinosad - Organic approved',
      'NPV (Nuclear polyhedrosis virus)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily - Early detection critical',
      'Remove egg masses - Underside of leaves',
      'Plow after harvest - Destroys pupae',
      'Light traps - Monitor adult moths',
      'Encourage natural enemies - Birds, wasps',
      'Community-wide control',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Nematodes': {
    'chemicalControl': [
      'Carbofuran (1kg/ha) - Use with extreme caution',
      'Fenamiphos - Pre-planting only',
    ],
    'organicControl': [
      'Marigolds - Plant as trap crop before tomatoes',
      'Neem cake (2kg per 100m²) - Mix into soil',
      'Compost addition - Increases beneficial organisms',
      'Chitin amendment - Stimulates beneficial fungi',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years, avoid solanaceous crops',
      'Soil solarization - 4-6 weeks in hot season',
      'Resistant rootstocks - Graft tomatoes onto resistant varieties',
      'Resistant varieties - Many available (check seed catalogs)',
      'Add organic matter - Supports beneficial organisms',
      'Avoid root injury - Creates entry points',
      'Remove and destroy infested plants',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations only',
      'Zinc phosphide - Grain bait',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats - Natural predators',
      'Owl boxes',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Clear field borders',
      'Remove food sources and hiding places',
      'Fencing - Bury 30cm deep',
      'Community coordination',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Insecticidal soap',
      'Strong water spray',
      'Garlic spray',
    ],
    'culturalControl': [
      'Encourage predators',
      'Remove infested parts',
      'Reflective mulch',
      'Avoid excess nitrogen',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid - Systemic',
      'Spiromesifen (20ml/20L water)',
      'Thiamethoxam (25g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water) - Weekly',
      'Yellow sticky traps',
      'Insecticidal soap',
      'Encarsia formosa - Parasitic wasp',
    ],
    'culturalControl': [
      'Reflective mulch',
      'Remove infested leaves',
      'Good air circulation',
      'Quarantine new plants',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
      'Insecticidal soap',
    ],
    'culturalControl': [
      'Remove weeds',
      'Remove infested flowers',
      'Maintain irrigation',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Leafminers': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Remove infested leaves',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Remove and destroy infested leaves',
      'Row covers',
      'Encourage parasitic wasps',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Spider Mites': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
      'Spiromesifen (20ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Weekly',
      'Strong water spray daily',
      'Predatory mites',
      'Sulfur dust',
    ],
    'culturalControl': [
      'Maintain moisture - Dry conditions favor mites',
      'Overhead irrigation',
      'Remove heavily infested leaves',
      'Avoid dust',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Tomato Hornworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking - Very effective',
      'Encourage parasitic wasps',
    ],
    'culturalControl': [
      'Hand-pick daily',
      'Leave parasitized larvae (with white cocoons)',
      'Till after harvest',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Stink Bugs': {
    'chemicalControl': [
      'Lambda-cyhalothrin (10ml/20L water)',
      'Cypermethrin (20ml/20L water)',
      'Bifenthrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (5ml/L water) - Repellent',
      'Hand-picking - Early morning when slow',
      'Soap water spray - Direct contact',
      'Kaolin clay - Barrier coating',
    ],
    'culturalControl': [
      'Remove weeds - Alternate hosts',
      'Trap crops - Plant beans or okra around borders',
      'Encourage natural predators - Tachinid flies, parasitic wasps',
      'Remove crop debris',
      'Border management - Keep clean',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Beet Armyworm': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Spinosad',
      'NPV virus',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout daily',
      'Remove egg masses',
      'Light traps',
      'Community control',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Nematodes': {
    'chemicalControl': [
      'Not recommended during flowering',
    ],
    'organicControl': [
      'Not applicable at this stage',
    ],
    'culturalControl': [
      'Maintain plant health',
      'Adequate watering',
      'Mulching - Reduces stress',
      'Remove severely infected plants',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
    ],
    'culturalControl': [
      'Clear field borders',
      'Remove hiding places',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Fruit Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water) - Spray flowers and young fruits',
      'Emamectin benzoate (5g/20L water) - Very effective',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Indoxacarb (10ml/20L water) - Targets larvae',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - Apply to flowers and small fruits',
      'Neem oil (5ml/L water) - Weekly sprays',
      'Spinosad - Organic option',
      'Pheromone traps - Monitor and trap adults',
      'Remove and destroy infested fruits immediately',
    ],
    'culturalControl': [
      'Scout plants daily - Check for entry holes',
      'Remove and destroy all infested fruits - Don\t compost',
      'Deep plowing after harvest - Destroys pupae in soil',
      'Crop rotation',
      'Intercrop with marigolds - Repellent effect',
      'Maintain field hygiene',
      'Remove fruit drop - Larvae may still be inside',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Bollworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
      'Indoxacarb (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt) - On flowers and fruits',
      'Neem oil (5ml/L water)',
      'Spinosad',
      'Hand-pick infested fruits',
    ],
    'culturalControl': [
      'Remove infested fruits immediately',
      'Deep plowing after harvest',
      'Pheromone traps',
      'Crop rotation',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Fruitflies': {
    'chemicalControl': [
      'Spinosad bait spray - Spot treatment',
      'Malathion (30ml/20L water) - With protein bait',
    ],
    'organicControl': [
      'Spinosad with protein bait - Attract and kill',
      'Traps with vinegar or fermenting fruit',
      'Bag individual fruits - Before they ripen',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Remove and destroy infested fruits - Bury deep or burn',
      'Pick fruits slightly early - Before full ripeness',
      'Collect all fruit drop daily - Destroy',
      'Clean harvest - Remove all fruits at season end',
      'Crop sanitation - No overripe fruits in field',
      'Trap crops - Plant early trap tomatoes',
      'Bury infested fruits 50cm deep',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Stink Bugs': {
    'chemicalControl': [
      'Lambda-cyhalothrin (10ml/20L water)',
      'Cypermethrin (20ml/20L water)',
    ],
    'organicControl': [
      'Hand-picking - Early morning',
      'Soap water spray',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Remove weeds',
      'Harvest promptly',
      'Trap crops',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
    ],
    'culturalControl': [
      'Harvest ripe fruits promptly',
      'Remove damaged fruits',
      'Clear field borders',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Fruit Borers': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Remove infested fruits',
      'Bacillus thuringiensis (Bt)',
    ],
    'culturalControl': [
      'Harvest promptly when ripe',
      'Remove and destroy infested fruits',
      'Deep plow after harvest',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Bollworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
      'Emamectin benzoate (5g/20L water)',
    ],
    'organicControl': [
      'Remove infested fruits',
      'Hand-picking',
    ],
    'culturalControl': [
      'Timely harvest',
      'Remove infested fruits',
      'Field sanitation',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Beet Armyworm': {
    'chemicalControl': [
      'Emamectin benzoate (5g/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Bacillus thuringiensis (Bt)',
      'Hand-picking',
    ],
    'culturalControl': [
      'Scout regularly',
      'Harvest promptly',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Leafminers': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
    ],
    'organicControl': [
      'Remove infested leaves',
    ],
    'culturalControl': [
      'Not critical at harvest',
      'Focus on fruit harvest',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Water spray',
    ],
    'culturalControl': [
      'Harvest ripe fruits',
      'Less critical at this stage',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Whiteflies': {
    'chemicalControl': [
      'Imidacloprid',
    ],
    'organicControl': [
      'Neem oil (3-5ml/L water)',
      'Yellow sticky traps',
    ],
    'culturalControl': [
      'Focus on fruit harvest',
      'Remove plants after final harvest',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove plants after harvest',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Spider Mites': {
    'chemicalControl': [
      'Abamectin (5ml/20L water)',
    ],
    'organicControl': [
      'Strong water spray',
      'Neem oil (5ml/L water)',
    ],
    'culturalControl': [
      'Maintain moisture',
      'Harvest ripe fruits',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Nematodes': {
    'chemicalControl': [
      'Not applicable at harvest',
    ],
    'organicControl': [
      'Not applicable',
    ],
    'culturalControl': [
      'Harvest fruits',
      'Remove and destroy plants after harvest',
      'Do not replant tomatoes in same spot',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Tomato Hornworms': {
    'chemicalControl': [
      'Cypermethrin (20ml/20L water)',
    ],
    'organicControl': [
      'Hand-picking',
    ],
    'culturalControl': [
      'Hand-pick and destroy',
      'Harvest fruits',
    ],
  },

  'Tomatoes_Storage_Fruit Flies': {
    'chemicalControl': [
      'None recommended in storage',
    ],
    'organicControl': [
      'Vinegar traps in storage area',
      'Remove infested fruits immediately',
    ],
    'culturalControl': [
      'Store only undamaged fruits',
      'Cool storage (10-13°C for ripe, 13-21°C for green)',
      'Good ventilation',
      'Regular inspection - Remove damaged fruits',
      'Don\t store overripe fruits',
      'Clean storage area regularly',
    ],
  },

  'Tomatoes_Storage_Fruit Borers': {
    'chemicalControl': [
      'Not applicable in storage',
    ],
    'organicControl': [
      'Inspect fruits before storage',
      'Remove infested fruits',
    ],
    'culturalControl': [
      'Store only clean, undamaged fruits',
      'Inspect regularly',
      'Remove any fruits showing damage',
      'Cool storage slows any remaining larvae',
    ],
  },

  'Tomatoes_Storage_Stink Bugs': {
    'chemicalControl': [
      'Not applicable in storage',
    ],
    'organicControl': [
      'Inspect and remove any bugs found',
    ],
    'culturalControl': [
      'Clean fruits before storage',
      'Seal storage area against entry',
      'Regular inspection',
    ],
  },

  'Tomatoes_Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations away from fruits',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Rodent-proof storage - Sealed containers or room',
      'Raised storage platforms',
      'Remove access points',
      'Clean surrounding areas',
      'Regular inspection',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // ONIONS PESTS - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Onions_Germination/Seedling_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha) - Systemic',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water) - Weekly',
      'Insecticidal soap (2%)',
      'Strong water spray - Dislodge',
      'Garlic spray - Ironically works on onions',
    ],
    'culturalControl': [
      'Encourage ladybugs, lacewings',
      'Reflective mulch',
      'Remove infested plants',
      'Avoid excess nitrogen',
      'Good plant spacing',
    ],
  },

  'Onions_Germination/Seedling_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water) - Organic option',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water) - Weekly applications',
      'Insecticidal soap',
      'Blue sticky traps - Monitor and trap',
      'Reflective mulch - Aluminum foil or silver plastic',
      'Strong water spray',
    ],
    'culturalControl': [
      'Remove weeds and plant debris',
      'Avoid excessive nitrogen fertilization',
      'Maintain adequate irrigation - Stressed plants more susceptible',
      'Crop rotation - Don\t plant onions after onions',
      'Use thrips-resistant varieties if available',
      'Deep tillage after harvest',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water) - Weekly',
      'Insecticidal soap - Direct spray',
      'Blue sticky traps',
      'Reflective mulch',
      'Strong water spray to dislodge',
    ],
    'culturalControl': [
      'Remove weeds - Breeding sites',
      'Avoid excessive nitrogen - Creates succulent foliage',
      'Maintain regular irrigation - Water stress increases susceptibility',
      'Crop rotation - 3-year minimum',
      'Resistant varieties',
      'Remove and destroy crop debris',
      'Monitor regularly - Blue sticky traps',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Aphids': {
    'chemicalControl': [
      'Imidacloprid (200g/ha)',
      'Thiamethoxam (25g/100L water)',
      'Acetamiprid (20g/100L water)',
    ],
    'organicControl': [
      'Neem oil (2-5ml/L water)',
      'Insecticidal soap',
      'Strong water spray',
    ],
    'culturalControl': [
      'Encourage natural predators',
      'Remove heavily infested plants',
      'Avoid excess nitrogen',
      'Reflective mulch',
    ],
  },

  'Onions_Bulb Formation/Reproductive_Bulb Fly': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Soil drench',
      'Diazinon - Around plant base',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Beneficial nematodes - Apply to soil',
      'Row covers - Physical barrier during fly season',
      'Trap crops - Plant early onions as trap',
    ],
    'culturalControl': [
      'Crop rotation - 3-4 years minimum',
      'Avoid planting near previous year\'s onion fields',
      'Remove and destroy infested bulbs immediately',
      'Deep cultivation - Destroys pupae',
      'Early planting - Avoid peak fly emergence',
      'Harvest promptly when mature',
      'Remove volunteer onions and wild alliums',
    ],
  },

  'Onions_Bulb Formation/Reproductive_Maggots': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water) - Soil drench',
      'Diazinon - Around base',
    ],
    'organicControl': [
      'Beneficial nematodes',
      'Row covers - During fly egg-laying period',
      'Wood ash around plants',
    ],
    'culturalControl': [
      'Crop rotation - 3 years minimum',
      'Remove infested plants',
      'Deep tillage after harvest',
      'Avoid fresh manure - Attracts flies',
      'Hill soil around plants',
    ],
  },

  'Onions_Bulbing/Maturation_Maggots': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Diazinon',
    ],
    'organicControl': [
      'Beneficial nematodes',
      'Remove infested bulbs',
    ],
    'culturalControl': [
      'Remove and destroy infested bulbs',
      'Harvest promptly when mature',
      'Don\t leave bulbs in ground after maturity',
      'Clean field after harvest',
    ],
  },

  'Onions_Bulbing/Maturation_Thrips': {
    'chemicalControl': [
      'Spinosad (5ml/L water)',
      'Thiamethoxam (25g/100L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Neem oil (3ml/L water)',
      'Blue sticky traps',
      'Strong water spray',
    ],
    'culturalControl': [
      'Harvest when bulbs mature',
      'Remove debris after harvest',
      'Crop rotation',
    ],
  },

  'Onions_Bulbing/Maturation_Bulb Fly': {
    'chemicalControl': [
      'Chlorpyrifos (30ml/20L water)',
      'Lambda-cyhalothrin (10ml/20L water)',
    ],
    'organicControl': [
      'Remove infested bulbs immediately',
      'Beneficial nematodes',
    ],
    'culturalControl': [
      'Harvest promptly',
      'Remove and destroy infested bulbs',
      'Don\t leave bulbs in field',
      'Deep cultivation after harvest',
    ],
  },

  'Onions_Harvesting/Storage_Maggots': {
    'chemicalControl': [
      'None recommended at harvest/storage',
    ],
    'organicControl': [
      'Inspect bulbs carefully before storage',
      'Remove any infested bulbs',
    ],
    'culturalControl': [
      'Harvest when tops fall over naturally',
      'Cure bulbs properly - 2-3 weeks in warm, dry, ventilated area',
      'Remove tops after curing',
      'Store only clean, dry, undamaged bulbs',
      'Inspect regularly and remove damaged bulbs',
    ],
  },

  'Onions_Harvesting/Storage_Rodents': {
    'chemicalControl': [
      'Bromadiolone - Bait stations away from onions',
      'Warfarin-based baits',
    ],
    'organicControl': [
      'Mechanical traps',
      'Cats',
      'Peppermint oil - Repellent',
    ],
    'culturalControl': [
      'Rodent-proof storage - Sealed containers, mesh bags hung from ceiling',
      'Raised storage platforms',
      'Remove access points',
      'Clean surrounding areas',
      'Store in cool (0-2°C), dry (65-70% humidity) conditions',
      'Good ventilation - Reduces rot that attracts rodents',
      'Regular inspection',
    ],
  },

  'Onions_Harvesting/Storage_Bulb Fly': {
    'chemicalControl': [
      'Not applicable in storage',
    ],
    'organicControl': [
      'Inspect bulbs before storage',
      'Remove infested bulbs',
    ],
    'culturalControl': [
      'Store only healthy, well-cured bulbs',
      'Cool storage (0-2°C) - Prevents fly development',
      'Dry conditions (65-70% humidity)',
      'Regular inspection',
      'Remove and discard any soft or rotting bulbs',
    ],
  },
};