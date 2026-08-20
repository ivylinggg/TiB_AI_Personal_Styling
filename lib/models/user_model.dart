import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? colourSeason;
  final String? skinTone;
  final String? gender;
  final String? ageRange;
  final String? ethnicity;
  final List<String> preferredBrands;
  final bool onboardingComplete;
  final UserRole role;
  final bool isActive;
  final bool isPremium;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.colourSeason,
    this.skinTone,
    this.gender,
    this.ageRange,
    this.ethnicity,
    this.preferredBrands = const [],
    this.onboardingComplete = false,
    this.role = UserRole.customer,
    this.isActive = true,
    this.isPremium = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final brands = data['preferredBrands'];

    return UserModel(
      uid: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      colourSeason: data['colourSeason'] as String?,
      skinTone: data['skinTone'] as String?,
      gender: data['gender'] as String?,
      ageRange: data['ageRange'] as String?,
      ethnicity: data['ethnicity'] as String?,
      preferredBrands: brands is List
          ? brands.map((item) => item.toString()).toList()
          : const [],
      onboardingComplete: data['onboardingComplete'] as bool? ?? false,
      role: UserRoleExtension.fromString(data['role'] as String?),
      isActive: data['isActive'] as bool? ?? true,
      isPremium: data['isPremium'] as bool? ?? false,
      createdAt: _dateTimeFromTimestamp(data['createdAt']),
      updatedAt: _dateTimeFromTimestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'colourSeason': colourSeason,
      'skinTone': skinTone,
      'gender': gender,
      'ageRange': ageRange,
      'ethnicity': ethnicity,
      'preferredBrands': preferredBrands,
      'onboardingComplete': onboardingComplete,
      'role': role.value,
      'isActive': isActive,
      'isPremium': isPremium,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? photoUrl,
    String? colourSeason,
    String? skinTone,
    String? gender,
    String? ageRange,
    String? ethnicity,
    List<String>? preferredBrands,
    bool? onboardingComplete,
    UserRole? role,
    bool? isActive,
    bool? isPremium,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      colourSeason: colourSeason ?? this.colourSeason,
      skinTone: skinTone ?? this.skinTone,
      gender: gender ?? this.gender,
      ageRange: ageRange ?? this.ageRange,
      ethnicity: ethnicity ?? this.ethnicity,
      preferredBrands: preferredBrands ?? this.preferredBrands,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _dateTimeFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
