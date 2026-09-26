// lib/models/agronomist_note.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AgronomistNote {
  final String id;
  final String? gatewayId;
  final String platform; // km | cc | both
  final String title;
  final String body;
  final String authorName;
  final String authorOrg;
  final List<String> themes;
  final bool published;
  final DateTime createdAt;

  const AgronomistNote({
    required this.id,
    this.gatewayId,
    required this.platform,
    required this.title,
    required this.body,
    required this.authorName,
    required this.authorOrg,
    this.themes = const [],
    required this.published,
    required this.createdAt,
  });

  factory AgronomistNote.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AgronomistNote(
      id: doc.id,
      gatewayId: d['gatewayId'] as String?,
      platform: (d['platform'] as String?) ?? 'both',
      title: (d['title'] as String?) ?? 'Field note',
      body: (d['body'] as String?) ?? '',
      authorName: (d['authorName'] as String?) ?? 'Agronomist',
      authorOrg: (d['authorOrg'] as String?) ?? 'KALRO',
      themes: (d['themes'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      published: d['published'] == true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  String get timeLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}