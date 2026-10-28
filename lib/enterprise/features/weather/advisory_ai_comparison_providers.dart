// lib/enterprise/features/weather/advisory_ai_comparison_providers.dart
//
// Riverpod providers for the Advisory AI Comparison admin feature.
// All Firestore access goes through these; screens just ref.watch().

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kilimomkononi/enterprise/features/weather/advisory_ai_comparison.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;

/// Live-ordered list of all AI comparisons — admin-only collection.
final comparisonsProvider =
    StreamProvider.autoDispose<List<AdvisoryAiComparison>>((ref) => _db
        .collection('advisoryAiComparisons')
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AdvisoryAiComparison.fromDoc).toList()));

/// Single live comparison document — refreshes when another admin acts on it.
final comparisonDocProvider = StreamProvider.autoDispose
    .family<AdvisoryAiComparison?, String>((ref, advisoryId) => _db
        .collection('advisoryAiComparisons')
        .doc(advisoryId)
        .snapshots()
        .map((d) => d.exists ? AdvisoryAiComparison.fromDoc(d) : null));
