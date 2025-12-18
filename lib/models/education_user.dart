import 'package:cloud_firestore/cloud_firestore.dart';

enum EduRole { mainadmin, headteacher, teacher, student }

enum ApprovalStatus { pending, approved, denied }

class EduUser {
  final String uid;
  final String fullName;
  final String email;
  final EduRole? role; // Nullable - not set until approved
  final String schoolName;
  final List<String> classIds;
  final String? currentClassId;
  final String? phone;
  final String? profileImage;
  final ApprovalStatus approvalStatus;
  final String? approvedBy; // UID of who approved this user
  final DateTime? approvedAt;
  final String requestedRole; // teacher or student 
  final bool isDisabled;

  EduUser({
    required this.uid,
    required this.fullName,
    required this.email,
    this.role,
    required this.schoolName,
    this.classIds = const [],
    this.currentClassId,
    this.phone,
    this.profileImage,
    this.approvalStatus = ApprovalStatus.pending,
    this.approvedBy,
    this.approvedAt,
    required this.requestedRole,
    this.isDisabled = false,
  });

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'email': email,
        'role': role?.name,
        'schoolName': schoolName,
        'classIds': classIds,
        'currentClassId': currentClassId,
        'phone': phone,
        'profileImage': profileImage,
        'approvalStatus': approvalStatus.name,
        'approvedBy': approvedBy,
        'approvedAt': approvedAt,
        'requestedRole': requestedRole,
        'isDisabled': isDisabled,
      };

  factory EduUser.fromMap(Map<String, dynamic> map, String id) {
    return EduUser(
      uid: id,
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] != null
          ? EduRole.values.firstWhere(
              (e) => e.name == map['role'],
              orElse: () => EduRole.student,
            )
          : null,
      schoolName: map['schoolName'] ?? '',
      classIds: map['classIds'] is List
          ? List<String>.from(map['classIds'])
          : <String>[],
      currentClassId: map['currentClassId'] as String?,
      phone: map['phone'] as String?,
      profileImage: map['profileImage'] as String?,
      approvalStatus: map['approvalStatus'] != null
          ? ApprovalStatus.values.firstWhere(
              (e) => e.name == map['approvalStatus'],
              orElse: () => ApprovalStatus.pending,
            )
          : ApprovalStatus.pending,
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      requestedRole: map['requestedRole'] ?? 'student',
      isDisabled: map['isDisabled'] ?? false,
    );
  }

  bool get isApproved => approvalStatus == ApprovalStatus.approved && role != null;
  bool get isPending => approvalStatus == ApprovalStatus.pending;
  bool get isDenied => approvalStatus == ApprovalStatus.denied;
}