import 'package:cloud_firestore/cloud_firestore.dart';

class Manual {
  final String id;
  final String userId;
  final String title;
  final String fileName;
  final String downloadUrl;
  final DateTime? uploadedAt;
  final String category;
  final String? uploadedBy;
  final String platform;

  Manual({
    required this.id,
    required this.userId,
    required this.title,
    required this.fileName,
    required this.downloadUrl,
    this.uploadedAt,
    required this.category,
    this.uploadedBy,
    required this.platform,
  });

  factory Manual.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return Manual(
      id: snapshot.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      fileName: data['fileName'] as String? ?? '',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      category: data['category'] as String? ?? '',
      uploadedBy: data['uploadedBy'] as String?,
      platform: data['platform'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : null,
      'category': category,
      'uploadedBy': uploadedBy,
      'platform': platform,
    };
  }
}
