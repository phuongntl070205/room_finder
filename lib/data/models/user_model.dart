import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? avatarUrl;
  final String? phoneNumber;
  final String role; // 'user' hoặc 'admin'
  final List<String> habitTags;
  final List<String> savedPostIds;
  final DateTime createdAt;
  
  // New fields for personalization
  final double budgetMin;
  final double budgetMax;
  final List<String> preferredAreas;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.role = 'user',
    this.habitTags = const [],
    this.savedPostIds = const [],
    this.avatarUrl,
    this.phoneNumber,
    this.budgetMin = 0,
    this.budgetMax = 0,
    this.preferredAreas = const [],
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      role: map['role'] ?? 'user',
      avatarUrl: map['avatarUrl'],
      phoneNumber: map['phoneNumber'],
      habitTags: List<String>.from(map['habitTags'] ?? []),
      savedPostIds: List<String>.from(map['savedPostIds'] ?? []),
      budgetMin: (map['budgetMin'] ?? 0).toDouble(),
      budgetMax: (map['budgetMax'] ?? 0).toDouble(),
      preferredAreas: List<String>.from(map['preferredAreas'] ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'displayName': displayName,
    'role': role,
    'avatarUrl': avatarUrl,
    'phoneNumber': phoneNumber,
    'habitTags': habitTags,
    'savedPostIds': savedPostIds,
    'budgetMin': budgetMin,
    'budgetMax': budgetMax,
    'preferredAreas': preferredAreas,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  bool get isAdmin => role == 'admin';
}
