// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String county;
  final String constituency;
  final String ward;
  final String phoneNumber;
  final String? profileImage;
  final bool isDisabled;
  final Timestamp? createdAt;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.county,
    required this.constituency,
    required this.ward,
    required this.phoneNumber,
    this.profileImage,
    this.isDisabled = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': id,                            // REQUIRED for rules
      'fullName': fullName,
      'email': email,
      'county': county,
      'constituency': constituency,
      'ward': ward,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
      'isDisabled': isDisabled,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data() ?? {};
    return AppUser(
      id: snapshot.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      county: data['county'] ?? '',
      constituency: data['constituency'] ?? '',
      ward: data['ward'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      profileImage: data['profileImage'] as String?,
      isDisabled: data['isDisabled'] as bool? ?? false,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}