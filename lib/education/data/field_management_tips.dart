// lib/education/data/field_management_tips.dart
// Complete field management tips database for ALL crops and stages
// Import this file in plot_input_form.dart

/// Teacher-only field management tips database
/// Maps field issue key (Crop_Stage_Issue) to management recommendations
final Map<String, Map<String, List<String>>> fieldManagementTips = {
  
  // ═══════════════════════════════════════════════════════════
  // BEANS FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════
  
  'Beans_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Seed treatment with fungicide - Captan or Thiram (2-3g/kg seed)',
      'Seed treatment with insecticide - Imidacloprid if soil pests present',
    ],
    'organicControl': [
      'Trichoderma seed treatment - Biological protection',
      'Compost tea seed soak - 24 hours before planting',
    ],
    'culturalControl': [
      'Use certified high-quality seeds - Germination rate above 85%',
      'Plant in warm soil - Minimum 15°C soil temperature',
      'Proper planting depth - 3-5cm deep, not deeper',
      'Adequate soil moisture - Moist but not waterlogged',
      'Good seed-to-soil contact - Firm soil after planting',
      'Improve drainage if soil stays waterlogged',
      'Avoid planting in compacted soil',
      'Test seed germination before planting entire field',
    ],
  },

  'Beans_Germination/Seedling_Damping Off': {
    'chemicalControl': [
      'Fungicide seed treatment - Captan, Thiram, or Metalaxyl',
      'Soil drench if problem persists - Metalaxyl (1ml/L)',
    ],
    'organicControl': [
      'Trichoderma harzianum - Seed and soil treatment',
      'Cinnamon powder - Light dusting on soil surface',
    ],
    'culturalControl': [
      'Avoid overwatering - Major cause of damping off',
      'Plant in well-drained soil only',
      'Don\'t plant too deep - 3-5cm maximum',
      'Use raised beds if drainage poor',
      'Increase air circulation - Proper spacing',
      'Plant in warm conditions - Above 15°C',
      'Remove infected seedlings immediately',
    ],
  },

  'Beans_Germination/Seedling_Slow Growth': {
    'chemicalControl': [
      'Foliar fertilizer spray - NPK 20:20:20 (10g/10L water)',
      'Starter fertilizer at planting - DAP (50kg/ha)',
    ],
    'organicControl': [
      'Compost tea foliar spray - Weekly application',
      'Seaweed extract (5ml/L water) - Growth stimulant',
      'Fish emulsion (diluted 1:100) - Nitrogen boost',
    ],
    'culturalControl': [
      'Check soil temperature - Should be above 15°C',
      'Test soil fertility - May need fertilizer',
      'Improve drainage - Waterlogged soil slows growth',
      'Check for pests - Root pests can slow growth',
      'Adequate moisture - Not too wet, not too dry',
      'Weed control - Competition slows growth',
      'Add compost before planting - Improves soil',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'NPK fertilizer - 50kg/ha (e.g., DAP or CAN)',
      'Foliar spray - Micronutrients if specific deficiency',
      'Nitrogen deficiency: CAN (100kg/ha) or Urea (50kg/ha)',
      'Phosphorus deficiency: TSP or DAP (50kg/ha)',
    ],
    'organicControl': [
      'Compost application - 5-10 tons/ha',
      'Manure top-dressing - Well-rotted, 2-3 tons/ha',
      'Foliar compost tea - Weekly sprays',
      'Wood ash for potassium - 200kg/ha',
    ],
    'culturalControl': [
      'Soil test before fertilizing - Know what\'s needed',
      'Balanced fertilization - NPK ratios appropriate for beans',
      'Top-dress at flowering - Critical growth stage',
      'Mulch to retain nutrients - Prevents leaching',
      'Intercrop with nitrogen-fixing plants',
      'Add organic matter regularly - Improves nutrient availability',
      'Maintain proper soil pH (6.0-7.0)',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-emergence herbicide - Pendimethalin (3L/ha) before weeds emerge',
      'Post-emergence selective herbicide - Imazethapyr (1L/ha)',
      'Glyphosate (3-4L/ha) - Only for spot treatment, away from beans',
    ],
    'organicControl': [
      'Mulching - Thick layer (10-15cm) suppresses weeds',
      'Vinegar spray (20% acetic acid) - On young weeds, avoid beans',
      'Boiling water - For weeds between rows',
    ],
    'culturalControl': [
      'Hand weeding - 2-3 times during season',
      'Hoe weeding - Weekly, shallow cultivation',
      'Mulch heavily - Grass, straw, or leaves (10-15cm)',
      'Close plant spacing - Beans shade out weeds',
      'Plant in weed-free soil - Pre-planting preparation',
      'False seedbed technique - Water, wait for weeds, then plant',
      'Don\'t let weeds go to seed - Remove before flowering',
      'Intercropping - Dense planting reduces weed space',
    ],
  },

  'Beans_Vegetative Growth/Weeding_Lodging': {
    'chemicalControl': [
      'Plant growth regulator - Chlormequat if excessive growth',
      'Reduce nitrogen if over-applied',
    ],
    'organicControl': [
      'None applicable - Management is cultural',
    ],
    'culturalControl': [
      'Staking - Install stakes early, tie plants loosely',
      'Avoid excessive nitrogen - Creates weak, tall plants',
      'Proper plant spacing - Not too close (20-30cm)',
      'Plant windbreaks - Reduce wind damage',
      'Select bushy varieties - Less prone to lodging',
      'Hilling - Mound soil around base for support',
      'Timely harvest - Don\'t leave overripe',
    ],
  },

  'Beans_Flowering/Reproductive_Flower Drop': {
    'chemicalControl': [
      'Foliar boron spray - Borax (1g/L water) if deficiency',
      'Foliar calcium spray - Calcium chloride (2g/L)',
    ],
    'organicControl': [
      'Compost tea with seaweed - Provides trace minerals',
      'Wood ash tea - Source of potassium and calcium',
    ],
    'culturalControl': [
      'Consistent watering - Stress causes flower drop',
      'Avoid water stress - Critical during flowering',
      'Mulch to maintain moisture - Reduces stress',
      'Shade cloth if extreme heat - Above 35°C',
      'Check for pests - Thrips damage flowers',
      'Avoid excessive nitrogen - Promotes leaves over flowers',
      'Proper pollination - Ensure bees present',
      'Maintain moderate temperatures',
    ],
  },

  'Beans_Flowering/Reproductive_Poor Pod Set': {
    'chemicalControl': [
      'Boron foliar spray - Borax (1g/L water)',
      'Phosphorus application - If soil test shows deficiency',
    ],
    'organicControl': [
      'Bone meal - Phosphorus source',
      'Compost - Balanced nutrients',
    ],
    'culturalControl': [
      'Adequate watering during flowering - Critical',
      'Avoid water stress - Most common cause',
      'Temperature management - Extreme heat or cold reduces set',
      'Encourage pollinators - Plant flowers nearby',
      'Check nutrient levels - Boron and phosphorus important',
      'Avoid excessive nitrogen - Promotes vegetative growth',
      'Protect from extreme weather',
    ],
  },

  'Beans_Maturation/Harvesting_Uneven Maturity': {
    'chemicalControl': [
      'None recommended',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Plant all seeds same day - Uniform germination',
      'Use same seed lot - Genetic uniformity',
      'Consistent watering throughout season',
      'Harvest in stages - Pick mature pods first',
      'Select determinate varieties - More uniform',
      'Proper plant spacing - Uniform light and nutrients',
      'Consistent fertilization',
    ],
  },

  'Beans_Maturation/Harvesting_Low Yield': {
    'chemicalControl': [
      'Proper fertilization throughout season',
      'Pest and disease control - Maintain healthy plants',
    ],
    'organicControl': [
      'Compost and manure - Season-long fertility',
      'Foliar feeding during critical stages',
    ],
    'culturalControl': [
      'Adequate plant population - 200,000-400,000 plants/ha',
      'Proper spacing - Not too crowded or sparse',
      'Consistent moisture - Especially flowering and pod fill',
      'Good weed control - Reduces competition',
      'Pest and disease management - Maintain plant health',
      'Soil fertility - Test and amend as needed',
      'Timely planting - Optimal growing season',
      'Harvest at right time - Not too early or late',
    ],
  },

  'Beans_Storage_High Moisture Content': {
    'chemicalControl': [
      'Desiccants mixed with grain - Food-grade only',
    ],
    'organicControl': [
      'Diatomaceous earth - Absorbs moisture',
    ],
    'culturalControl': [
      'Sun drying - Spread thin on clean surface, 2-3 days',
      'Proper drying before storage - Target 12-13% moisture',
      'Test moisture content - Use moisture meter',
      'Re-dry if above 13% - Before storage',
      'Good ventilation during drying',
      'Turn beans regularly during drying',
      'Store only when fully dry',
      'Use moisture-proof containers',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // MAIZE FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Maize_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Fungicide seed treatment - Metalaxyl + Thiram',
      'Insecticide seed treatment - Imidacloprid or Thiamethoxam',
    ],
    'organicControl': [
      'Trichoderma seed treatment',
      'Neem powder seed coating',
    ],
    'culturalControl': [
      'Use certified hybrid seeds - High germination rate',
      'Plant when soil temperature above 15°C',
      'Proper planting depth - 3-5cm',
      'Adequate soil moisture at planting',
      'Good seed-to-soil contact',
      'Test seed germination before planting',
      'Protect from birds and rodents',
      'Improve drainage if waterlogged',
    ],
  },

  'Maize_Germination/Seedling_Uneven Germination': {
    'chemicalControl': [
      'Quality seed treatment - Fungicide + insecticide',
    ],
    'organicControl': [
      'Uniform seed treatment',
    ],
    'culturalControl': [
      'Use high-quality, graded seeds - Uniform size',
      'Consistent planting depth - Use planter/jab planter',
      'Uniform soil moisture - Level field, good drainage',
      'Plant all seeds same day - Weather consistency',
      'Calibrate planter properly',
      'Avoid planting in variable soil types',
      'Level seedbed preparation',
    ],
  },

  'Maize_Germination/Seedling_Slow Growth': {
    'chemicalControl': [
      'Starter fertilizer - DAP (50kg/ha) at planting',
      'Foliar spray - NPK 20:20:20 if needed',
    ],
    'organicControl': [
      'Compost at planting - 5 tons/ha',
      'Compost tea foliar spray',
    ],
    'culturalControl': [
      'Check soil temperature - Should be 15°C+',
      'Ensure adequate moisture - Not waterlogged',
      'Weed control - Reduces competition',
      'Check for pests - Termites, cutworms',
      'Soil fertility - Apply fertilizer if deficient',
      'Good drainage - Prevents root stress',
      'Proper plant spacing',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'Nitrogen deficiency: CAN (200kg/ha) or Urea (100kg/ha) - Split application',
      'First application: 3-4 weeks after planting',
      'Second application: 6-8 weeks (before tasseling)',
      'Phosphorus: DAP (50kg/ha) at planting',
      'Zinc deficiency: Zinc sulfate foliar spray (2g/L)',
    ],
    'organicControl': [
      'Well-rotted manure - 10-20 tons/ha',
      'Compost - 10 tons/ha',
      'Green manure - Legume cover crops',
      'Wood ash - Potassium source, 300kg/ha',
    ],
    'culturalControl': [
      'Soil test before fertilizing - Know exact needs',
      'Split nitrogen application - Two or three times',
      'Top-dress at critical stages - V6 and V10',
      'Incorporate organic matter before planting',
      'Maintain proper soil pH (5.5-7.0)',
      'Avoid over-fertilization - Wasteful and harmful',
      'Apply near plant base - Not on leaves',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-emergence: Atrazine (3L/ha) immediately after planting',
      'Post-emergence: Nicosulfuron (80g/ha) at 3-4 leaf stage',
      'Hand weeding safe zone: 15-20 days after herbicide',
    ],
    'organicControl': [
      'Mulching - 10cm layer between rows',
      'Cover crops - Living mulch between rows',
    ],
    'culturalControl': [
      'Early weed control critical - First 4-6 weeks',
      'Hand weeding - 2-3 times, shallow cultivation',
      'Hoe weeding - Weekly when small',
      'Mulch between rows - Grass, crop residue',
      'Proper plant spacing - Maize canopy shades weeds',
      'Inter-row cultivation - Tractor or oxen',
      'Plant in weed-free soil - Good land preparation',
      'False seedbed technique',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Lodging': {
    'chemicalControl': [
      'Balanced fertilization - Avoid excess nitrogen',
      'Potassium application - Strengthens stalks',
    ],
    'organicControl': [
      'Wood ash - Potassium source',
      'Compost - Balanced nutrients',
    ],
    'culturalControl': [
      'Select lodging-resistant hybrids',
      'Proper plant population - Not too dense (53,000-75,000/ha)',
      'Balanced fertilization - Avoid excess nitrogen',
      'Adequate potassium - Strengthens stalks',
      'Hilling - Mound soil around base at knee-height',
      'Plant windbreaks - Reduce wind damage',
      'Control stalk borers - Weaken stalks',
      'Timely harvest - Don\'t leave overripe',
    ],
  },

  'Maize_Vegetative Growth/Weeding_Stunted Growth': {
    'chemicalControl': [
      'Nitrogen fertilizer - CAN (200kg/ha) split application',
      'Micronutrient spray if deficiency identified',
    ],
    'organicControl': [
      'Manure application - 10-20 tons/ha',
      'Compost tea - Weekly foliar spray',
    ],
    'culturalControl': [
      'Check for pests - Stem borers, nematodes',
      'Ensure adequate water - Especially during dry spells',
      'Soil fertility test - Apply needed nutrients',
      'Weed control - Reduces competition',
      'Check soil pH - Lime if below 5.5',
      'Proper drainage - Waterlogging stunts growth',
      'Root health - Check for root diseases',
    ],
  },

  'Maize_Flowering/Reproductive_Poor Pollination': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Adequate water during tasseling - Critical period',
      'Avoid water stress 2 weeks before and after silking',
      'Multiple planting rows - Improves pollen distribution',
      'Plant blocks not single rows - Better pollination',
      'Avoid extreme heat during pollination',
      'Remove very early or late plants - Asynchronous',
      'Ensure adequate plant population',
      'Protect tassels from armyworm damage',
    ],
  },

  'Maize_Flowering/Reproductive_Barrenness (No Ears)': {
    'chemicalControl': [
      'Proper fertilization - Nitrogen critical',
    ],
    'organicControl': [
      'Compost and manure application',
    ],
    'culturalControl': [
      'Avoid plant stress - Water, nutrients, pests',
      'Adequate nitrogen - Apply before tasseling',
      'Proper plant spacing - Not too dense',
      'Water during critical period - Tasseling to grain fill',
      'Control pests and diseases',
      'Avoid late planting - Short growing season',
      'Check soil fertility',
    ],
  },

  'Maize_Flowering/Reproductive_Ear Rot': {
    'chemicalControl': [
      'Fungicide at silking - Limited effectiveness',
      'Control ear-feeding insects',
    ],
    'organicControl': [
      'Control insects organically',
    ],
    'culturalControl': [
      'Select resistant hybrids',
      'Control insects - Especially earworms',
      'Avoid late planting',
      'Maintain plant vigor - Reduces susceptibility',
      'Proper plant spacing - Good air circulation',
      'Timely harvest - Don\'t delay',
      'Crop rotation',
    ],
  },

  'Maize_Maturation/Harvesting_Delayed Maturity': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Select appropriate maturity hybrids - Match season length',
      'Timely planting - Plant during optimal window',
      'Adequate water and nutrients - Entire season',
      'Control pests and diseases - Maintain health',
      'Monitor weather - Harvest before rains',
      'Plan for variable maturity',
    ],
  },

  'Maize_Maturation/Harvesting_Low Grain Fill': {
    'chemicalControl': [
      'Adequate fertilization during grain fill',
    ],
    'organicControl': [
      'Compost application',
    ],
    'culturalControl': [
      'Adequate water during grain fill - Critical 4-6 weeks',
      'Prevent lodging - Reduces fill',
      'Control leaf diseases - Maintain photosynthesis',
      'Adequate nitrogen - Applied before tasseling',
      'Protect from pests - Especially late season',
      'Avoid premature harvest',
      'Maintain plant health through season',
    ],
  },

  'Maize_Storage_High Moisture Content': {
    'chemicalControl': [
      'Approved grain preservatives if moisture high',
    ],
    'organicControl': [
      'Diatomaceous earth - Moisture absorber',
    ],
    'culturalControl': [
      'Proper drying - Sun or mechanical, target 13.5% moisture',
      'Test moisture before storage - Use moisture meter',
      'Continue drying if above 13.5%',
      'Spread grain thin for sun drying',
      'Turn regularly during drying',
      'Store in dry, ventilated structure',
      'Shelling helps drying - If doing by hand',
      'Monitor stored grain regularly',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CABBAGE FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Cabbage_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Fungicide seed treatment - Captan or Thiram',
    ],
    'organicControl': [
      'Trichoderma seed treatment',
    ],
    'culturalControl': [
      'Use fresh, certified seeds - Germination rate 85%+',
      'Proper temperature - 20-25°C for germination',
      'Adequate moisture - Keep seed trays moist',
      'Sterile seedling mix - Prevents damping off',
      'Proper planting depth - 0.5-1cm deep',
      'Good light after emergence',
      'Test seed germination first',
    ],
  },

  'Cabbage_Germination/Seedling_Leggy Seedlings': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Increase light - Seedlings need bright light',
      'Lower temperature slightly - 18-20°C',
      'Reduce watering frequency - Slight stress',
      'Increase air circulation',
      'Transplant deeper - Bury leggy stem',
      'Avoid overcrowding seedlings',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'NPK fertilizer - CAN (150kg/ha) + TSP (100kg/ha)',
      'Foliar feeding - NPK 20:20:20 (10g/L)',
      'Calcium deficiency: Calcium nitrate foliar spray',
    ],
    'organicControl': [
      'Well-rotted manure - 20-30 tons/ha',
      'Compost - 15-20 tons/ha',
      'Wood ash for potassium - 300kg/ha',
      'Bone meal for phosphorus',
    ],
    'culturalControl': [
      'Soil test before fertilizing',
      'Split application - Base + top-dressing',
      'Top-dress 3-4 weeks after transplanting',
      'Side-dress when heads start forming',
      'Maintain soil pH 6.0-7.5',
      'Adequate calcium prevents internal problems',
      'Consistent moisture for nutrient uptake',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-transplant: Trifluralin (2L/ha) before planting',
      'Post-transplant selective herbicides - Limited options',
    ],
    'organicControl': [
      'Mulching - Black plastic or organic (10-15cm)',
      'Newspaper under mulch - Suppresses weeds',
    ],
    'culturalControl': [
      'Hand weeding - 3-4 times during season',
      'Shallow cultivation - Don\'t damage roots',
      'Black plastic mulch - Very effective',
      'Organic mulch - Straw, grass 10-15cm',
      'Close plant spacing - Cabbage canopy shades weeds',
      'Pre-planting weed control - Clean field',
      'Transplant into weed-free soil',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Bolting (Premature Flowering)': {
    'chemicalControl': [
      'None effective',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Avoid planting too early - Cold triggers bolting',
      'Select bolt-resistant varieties',
      'Transplant at right size - 4-6 true leaves',
      'Avoid root disturbance - Stresses plant',
      'Consistent watering - Stress causes bolting',
      'Protect from extreme cold - Cover if needed',
      'Proper variety for season - Early or late types',
    ],
  },

  'Cabbage_Vegetative Growth/Weeding_Loose Heads': {
    'chemicalControl': [
      'Adequate fertilization - Especially nitrogen',
    ],
    'organicControl': [
      'Compost and manure application',
    ],
    'culturalControl': [
      'Consistent watering - Fluctuation causes looseness',
      'Adequate nitrogen - Needed for tight heads',
      'Harvest at right time - Not overripe',
      'Select appropriate variety',
      'Proper spacing - 45-60cm',
      'Avoid high temperatures - Causes loose heads',
      'Maintain soil moisture',
    ],
  },

  'Cabbage_Maturation/Harvesting_Head Splitting': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest promptly when mature - Don\'t delay',
      'Consistent watering - Sudden rain after dry causes splitting',
      'Reduce water as heads mature',
      'Root prune mature heads - Cut some roots to slow growth',
      'Twist heads slightly - Breaks roots, slows water uptake',
      'Plant split-resistant varieties',
      'Monitor maturity closely',
    ],
  },

  'Cabbage_Maturation/Harvesting_Small Heads': {
    'chemicalControl': [
      'Adequate fertilization throughout season',
    ],
    'organicControl': [
      'Compost and manure application',
    ],
    'culturalControl': [
      'Proper plant spacing - 45-60cm for large heads',
      'Adequate water throughout season',
      'Sufficient nutrients - Nitrogen especially',
      'Weed control - Reduces competition',
      'Select large-head varieties',
      'Timely planting - Full growing season',
      'Pest and disease control - Maintains growth',
    ],
  },

  'Cabbage_Storage_Poor Storage Life': {
    'chemicalControl': [
      'None in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest at proper maturity - Firm heads',
      'Remove outer damaged leaves',
      'Cure before storage - Cool, dry area 1 week',
      'Cool storage - 0-2°C ideal',
      'High humidity - 95-100%',
      'Good ventilation',
      'Store only undamaged heads',
      'Regular inspection - Remove rotting heads',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // CARROTS FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Carrots_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Fungicide seed treatment - If soil disease suspected',
    ],
    'organicControl': [
      'Trichoderma seed treatment',
    ],
    'culturalControl': [
      'Use fresh seeds - Viability decreases with age',
      'Shallow planting - 0.5-1cm deep only',
      'Keep soil consistently moist - Critical for carrot seeds',
      'Cover with vermiculite - Holds moisture',
      'Light mulch - Burlap or row cover until emergence',
      'Warm soil - 10-15°C minimum',
      'Fine seedbed - No clods or stones',
      'Pre-soak seeds 24 hours - Speeds germination',
    ],
  },

  'Carrots_Germination/Seedling_Slow Germination': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Warmer soil - Germination slow below 10°C',
      'Consistent moisture - Never let dry out',
      'Cover seeds lightly - Aids moisture retention',
      'Pre-soak seeds - 24-48 hours speeds process',
      'Use fresh seeds - Old seeds slower',
      'Pelleted seeds - Easier to handle, faster',
      'Wait patiently - Can take 14-21 days',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'Balanced NPK fertilizer - Low nitrogen (e.g., 5-10-10)',
      'Potassium sulfate (100kg/ha) if deficient',
    ],
    'organicControl': [
      'Well-rotted compost - 10-15 tons/ha',
      'Wood ash - Potassium source, 200kg/ha',
      'Bone meal - Phosphorus, 200kg/ha',
    ],
    'culturalControl': [
      'Soil test before fertilizing',
      'Low nitrogen - High nitrogen causes forked roots',
      'Adequate potassium - For root development',
      'Phosphorus important - Root growth',
      'Side-dress when 10cm tall',
      'Avoid fresh manure - Causes forking',
      'Maintain soil pH 6.0-7.0',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-emergence: Linuron (1-2L/ha) carefully',
      'Hand weeding preferred - Carrots sensitive to herbicides',
    ],
    'organicControl': [
      'Mulching after seedlings established',
      'Flame weeding between rows - Careful not to damage carrots',
    ],
    'culturalControl': [
      'Critical early weeding - Carrots slow-growing at first',
      'Hand weeding essential - Weekly when small',
      'Shallow cultivation - Don\'t damage carrot roots',
      'Mulch between rows once established',
      'False seedbed - Water, wait for weeds, cultivate, then plant',
      'Intercrop with fast-growing crops - Radish marks rows',
      'Weed before carrots emerge - Easy to damage tiny seedlings',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Forked Roots': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'Only well-rotted compost - Never fresh manure',
    ],
    'culturalControl': [
      'Deep, loose soil - Minimum 30cm deep',
      'Remove stones and clods - Obstructions cause forking',
      'Avoid fresh manure - Major cause of forking',
      'Proper thinning - Overcrowding causes forking',
      'Low nitrogen fertilizer - High nitrogen causes forking',
      'Adequate moisture - Fluctuations cause problems',
      'Proper soil preparation - Deep digging or double digging',
      'Raised beds if soil compacted',
    ],
  },

  'Carrots_Vegetative Growth/Weeding_Stunted Growth': {
    'chemicalControl': [
      'Fertilizer if soil test shows deficiency',
    ],
    'organicControl': [
      'Compost tea foliar spray',
      'Well-rotted compost incorporation',
    ],
    'culturalControl': [
      'Proper thinning - 5-7cm spacing crucial',
      'Adequate water - Especially during root development',
      'Check for pests - Carrot rust fly, nematodes',
      'Weed control - Competition stunts growth',
      'Soil compaction - Loosen if hard',
      'Check soil fertility',
      'Ensure adequate depth for roots',
    ],
  },

  'Carrots_Maturation/Harvesting_Cracking': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Consistent watering - Fluctuations cause cracking',
      'Harvest promptly when mature - Overripe carrots crack',
      'Reduce watering as maturity approaches',
      'Mulch to maintain even moisture',
      'Don\'t let soil dry completely then water heavily',
      'Monitor rainfall - Reduce irrigation after rain',
    ],
  },

  'Carrots_Maturation/Harvesting_Green Shoulders': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Hill soil around crowns - Cover exposed shoulders',
      'Mulch around plants - Blocks light',
      'Plant slightly deeper',
      'Monitor and cover as needed',
      'Harvest promptly when mature',
    ],
  },

  'Carrots_Storage_Poor Storage Life': {
    'chemicalControl': [
      'None in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest carefully - Avoid bruising',
      'Remove tops - Cut to 1cm, don\'t twist off',
      'Don\'t wash before storage',
      'Cool storage - 0-2°C ideal',
      'Very high humidity - 95-100%',
      'Store in sand or sawdust - Maintains moisture',
      'Good ventilation',
      'Remove damaged carrots immediately',
      'Check moisture regularly',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // TOMATOES FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Tomatoes_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Fungicide seed treatment - Captan or Thiram',
    ],
    'organicControl': [
      'Trichoderma seed treatment',
      'Hydrogen peroxide seed soak (3%, 30 minutes)',
    ],
    'culturalControl': [
      'Use certified seeds - High germination rate',
      'Proper temperature - 21-27°C for germination',
      'Sterile seedling mix - Prevents disease',
      'Adequate moisture - Keep moist not wet',
      'Proper depth - 0.5cm deep',
      'Bottom heat if cold - Heating mat',
      'Cover with plastic until emergence',
    ],
  },

  'Tomatoes_Germination/Seedling_Leggy Seedlings': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Increase light immediately - Use grow lights',
      'Lower temperature - 18-21°C',
      'Increase air circulation - Use fan',
      'Reduce watering slightly',
      'Transplant deeper - Bury stem when transplanting',
      'Brush seedlings gently - Strengthens stems',
      'Don\'t overcrowd seedlings',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'Balanced NPK fertilizer - CAN (150kg/ha) + TSP (100kg/ha)',
      'Foliar spray for micronutrients if deficient',
      'Calcium deficiency: Foliar calcium nitrate spray',
      'Magnesium deficiency: Epsom salts (10g/L)',
    ],
    'organicControl': [
      'Well-rotted manure - 20-30 tons/ha',
      'Compost - 15-20 tons/ha',
      'Compost tea - Weekly foliar spray',
      'Wood ash - Potassium, 200kg/ha',
    ],
    'culturalControl': [
      'Soil test before fertilizing',
      'Split application - Base + multiple top-dressing',
      'Side-dress every 2-3 weeks',
      'Adequate calcium prevents blossom end rot',
      'Maintain consistent moisture for nutrient uptake',
      'Mulch to retain nutrients',
      'Maintain soil pH 6.0-6.8',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-transplant herbicides - Limited options',
      'Avoid post-emergence herbicides - Damage tomatoes',
    ],
    'organicControl': [
      'Black plastic mulch - Very effective',
      'Organic mulch - Straw, grass 10-15cm',
    ],
    'culturalControl': [
      'Hand weeding - Regular, 2-3 times',
      'Shallow cultivation - Don\'t damage roots',
      'Mulch heavily - 10-15cm after planting',
      'Black plastic mulch - Warms soil, suppresses weeds',
      'Weed-free transplanting',
      'Close monitoring when small',
      'Don\'t let weeds go to seed',
    ],
  },

  'Tomatoes_Vegetative Growth/Weeding_Excessive Vegetative Growth': {
    'chemicalControl': [
      'Reduce nitrogen application',
    ],
    'organicControl': [
      'Reduce compost/manure',
    ],
    'culturalControl': [
      'Prune excess suckers - Determinate: minimal, Indeterminate: regular',
      'Reduce nitrogen fertilizer',
      'Balance with phosphorus and potassium',
      'Prune lower leaves - Improves air circulation',
      'Stake or cage properly',
      'Ensure adequate calcium - Promotes fruiting',
      'Water consistently - Not excessively',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Flower Drop': {
    'chemicalControl': [
      'Foliar boron spray - Borax (1g/L) if deficient',
    ],
    'organicControl': [
      'Compost tea with seaweed',
    ],
    'culturalControl': [
      'Temperature management - Ideal 18-29°C',
      'Shade cloth if extreme heat - Above 35°C',
      'Consistent watering - Stress causes drop',
      'Avoid excessive nitrogen - Promotes leaves over flowers',
      'Proper pollination - Gently shake plants',
      'Windbreaks if too windy',
      'Check for pests - Thrips damage flowers',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Poor Fruit Set': {
    'chemicalControl': [
      'Tomato growth hormones - Cautious use',
    ],
    'organicControl': [
      'Hand pollination - Shake flowers',
    ],
    'culturalControl': [
      'Temperature management - Night below 15°C or day above 35°C reduces set',
      'Adequate water during flowering',
      'Proper nutrition - Especially boron',
      'Hand pollination - Shake plants or flowers',
      'Reduce stress - Water, pests, disease',
      'Ensure good air circulation',
      'Avoid excessive nitrogen',
    ],
  },

  'Tomatoes_Flowering/Reproductive_Blossom End Rot': {
    'chemicalControl': [
      'Calcium spray - Calcium nitrate or calcium chloride foliar',
      'Calcium soil application if test shows deficiency',
    ],
    'organicControl': [
      'Crushed eggshells around plants - Slow calcium',
      'Gypsum (calcium sulfate) - 200kg/ha',
      'Bone meal - Contains calcium',
    ],
    'culturalControl': [
      'Consistent watering - Most important factor',
      'Mulch heavily - Maintains even moisture',
      'Avoid over-fertilization - Especially nitrogen',
      'Proper soil pH - 6.0-6.8 for calcium availability',
      'Don\'t let soil dry out then flood',
      'Adequate calcium in soil - Test and amend',
      'Avoid root damage - Affects calcium uptake',
      'Remove affected fruits - Divert calcium to new fruits',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Fruit Cracking': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Consistent watering - Fluctuations cause cracking',
      'Mulch to maintain even moisture',
      'Reduce water as fruits near maturity',
      'Harvest promptly when ripe',
      'Select crack-resistant varieties',
      'Avoid excessive watering after dry period',
      'Provide shade during extreme heat',
    ],
  },

  'Tomatoes_Maturation/Harvesting_Sunscald': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Maintain adequate foliage - Don\'t over-prune',
      'Shade cloth during extreme heat',
      'Proper plant spacing - Not too sparse',
      'Don\'t remove too many leaves',
      'Harvest promptly when ripe',
      'Stake to prevent fruit touching ground',
    ],
  },

  'Tomatoes_Storage_Poor Storage Life': {
    'chemicalControl': [
      'None in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Harvest at proper ripeness - Based on storage needs',
      'Handle gently - Avoid bruising',
      'Sort by ripeness - Store separately',
      'Proper temperature - 10-13°C for ripe, 13-21°C for green',
      'High humidity - 85-95%',
      'Good ventilation',
      'Don\'t wash before storage',
      'Remove damaged fruits',
      'Check regularly',
    ],
  },

  // ═══════════════════════════════════════════════════════════
  // ONIONS FIELD MANAGEMENT - ALL STAGES
  // ═══════════════════════════════════════════════════════════

  'Onions_Germination/Seedling_Poor Germination': {
    'chemicalControl': [
      'Fungicide seed treatment if planting seeds',
    ],
    'organicControl': [
      'Trichoderma seed treatment',
    ],
    'culturalControl': [
      'Use certified seeds or sets',
      'Proper temperature - 20-25°C for seeds',
      'Shallow planting - Seeds 1cm, sets 2-3cm deep',
      'Adequate moisture - Keep soil moist',
      'Well-prepared seedbed - Fine, level',
      'Good drainage essential',
      'Plant sets pointed end up',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Nutrient Deficiency': {
    'chemicalControl': [
      'Nitrogen: CAN (150kg/ha) split application',
      'Phosphorus: DAP or TSP (100kg/ha) at planting',
      'Potassium: Potassium sulfate if deficient',
    ],
    'organicControl': [
      'Well-rotted manure - 15-20 tons/ha',
      'Compost - 10-15 tons/ha',
      'Wood ash - Potassium, 200kg/ha',
    ],
    'culturalControl': [
      'Soil test before fertilizing',
      'Split nitrogen application - 3 times during season',
      'Side-dress when 15-20cm tall',
      'Stop nitrogen 4 weeks before harvest',
      'Adequate sulfur - Improves flavor and storage',
      'Maintain soil pH 6.0-7.0',
      'Regular foliar feeding with compost tea',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Weed Pressure': {
    'chemicalControl': [
      'Pre-emergence: Pendimethalin before onions emerge',
      'Post-emergence: Limited selective options',
    ],
    'organicControl': [
      'Mulching - Careful not to bury onions',
      'Straw mulch between rows',
    ],
    'culturalControl': [
      'Critical weed control - Onions poor competitors',
      'Hand weeding - Weekly, shallow cultivation',
      'Shallow hoeing - Don\'t damage bulbs',
      'Mulch between rows lightly',
      'Weed before onions emerge - Easy to damage',
      'False seedbed technique effective',
      'Keep weed-free entire season',
      'Don\'t let weeds shade onions',
    ],
  },

  'Onions_Vegetative Growth/Weeding_Bolting (Premature Flowering)': {
    'chemicalControl': [
      'None effective',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Select appropriate variety for season',
      'Avoid planting too early in cold climates',
      'Use sets less than 2cm diameter - Large sets bolt',
      'Protect from extreme cold',
      'Plant short-day varieties in appropriate latitude',
      'Consistent growing conditions - Avoid stress',
      'Remove flower stalks if they appear',
    ],
  },

  'Onions_Bulbing/Maturation_Small Bulbs': {
    'chemicalControl': [
      'Adequate fertilization throughout season',
    ],
    'organicControl': [
      'Compost and manure application',
    ],
    'culturalControl': [
      'Proper plant spacing - 10-15cm for large bulbs',
      'Adequate water entire season',
      'Sufficient nutrients - Especially nitrogen early',
      'Weed control - Reduces competition',
      'Appropriate day-length variety',
      'Long enough growing season',
      'Timely planting',
    ],
  },

  'Onions_Bulbing/Maturation_Thick Necks': {
    'chemicalControl': [
      'Reduce nitrogen late in season',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Stop nitrogen 4 weeks before harvest',
      'Reduce watering as bulbs mature',
      'Avoid excessive nitrogen throughout',
      'Select appropriate varieties',
      'Plant at proper spacing',
      'Proper day-length variety for location',
    ],
  },

  'Onions_Harvesting/Storage_Poor Curing': {
    'chemicalControl': [
      'None applicable',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Cure in warm, dry, well-ventilated area - 25-30°C',
      'Spread in single layer or hang',
      'Cure 2-4 weeks until necks dry',
      'Good air circulation critical',
      'Cut tops after curing - Leave 2-3cm',
      'Don\'t cure in direct sun - Can sunburn',
      'Check daily - Remove soft bulbs',
    ],
  },

  'Onions_Harvesting/Storage_Poor Storage Life': {
    'chemicalControl': [
      'None in storage',
    ],
    'organicControl': [
      'None applicable',
    ],
    'culturalControl': [
      'Proper curing essential - 2-4 weeks',
      'Cool storage - 0-2°C ideal',
      'Dry conditions - 65-70% humidity',
      'Excellent ventilation - Air movement critical',
      'Store only well-cured bulbs',
      'Hang in mesh bags or on racks',
      'Regular inspection - Remove sprouting or soft bulbs',
      'Don\'t store damaged bulbs',
    ],
  },
};