// lib/settings/settings_providers.dart
//
// The signed-in user's profile for Settings (header card, Edit profile,
// Account): farmers live in `Users/{uid}`, education users in
// `EducationUsers/{uid}`.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ProfileSummary {
  final String uid;
  final String fullName;
  final String email;
  final String phone;
  final String county;
  final String constituency;
  final String ward;
  final String? imageBase64;
  final DateTime? createdAt;
  final String role; // farmer, teacher, student, headteacher
  final String schoolName;

  const ProfileSummary({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phone = '',
    this.county = '',
    this.constituency = '',
    this.ward = '',
    this.imageBase64,
    this.createdAt,
    this.role = 'farmer',
    this.schoolName = '',
  });

  factory ProfileSummary.fromMap(String uid, Map<String, dynamic> d, {String fallbackEmail = ''}) {
    String s(String k) => '${d[k] ?? ''}'.trim();
    final ts = d['createdAt'];
    return ProfileSummary(
      uid: uid,
      fullName: s('fullName').isNotEmpty ? s('fullName') : s('name'),
      email: s('email').isNotEmpty ? s('email') : fallbackEmail,
      phone: s('phoneNumber'),
      county: s('county'),
      constituency: s('constituency'),
      ward: s('ward'),
      imageBase64: s('profileImage').isEmpty ? null : s('profileImage'),
      createdAt: ts is Timestamp ? ts.toDate() : null,
      role: s('role').isEmpty ? 'farmer' : s('role'),
      schoolName: s('schoolName'),
    );
  }

  String get firstName => fullName.split(' ').first;

  String get initials {
    final parts = fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }

  String get location => [ward, constituency, county].where((p) => p.isNotEmpty).join(', ');

  String get roleLabel => switch (role) {
        'headteacher' => 'Head teacher',
        'teacher' => 'Teacher',
        'student' => 'Student',
        _ => 'Farmer',
      };

  Uint8List? get imageBytes {
    if (imageBase64 == null) return null;
    try {
      return base64Decode(imageBase64!);
    } catch (_) {
      return null;
    }
  }
}

final settingsAuthProvider = StreamProvider<User?>((ref) => FirebaseAuth.instance.authStateChanges());

/// The profile document for this mode (`true` = education).
final settingsProfileProvider = StreamProvider.autoDispose.family<ProfileSummary?, bool>((ref, isEducation) {
  final user = ref.watch(settingsAuthProvider).value;
  if (user == null) return Stream.value(null);
  return FirebaseFirestore.instance
      .collection(isEducation ? 'EducationUsers' : 'Users')
      .doc(user.uid)
      .snapshots()
      .map((s) => ProfileSummary.fromMap(user.uid, s.data() ?? const {}, fallbackEmail: user.email ?? ''));
});

/// How this user signs in: 'password', 'google.com', …
List<String> signInMethods(User? user) => user?.providerData.map((p) => p.providerId).toList() ?? const [];
