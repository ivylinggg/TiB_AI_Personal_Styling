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
  final String? occupation;
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
    this.occupation,
    this.preferredBrands = const [],
    this.onboardingComplete = false,
    this.role = UserRole.customer,
    this.isActive = true,
    this.isPremium = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return UserModel(
      uid: doc.id,
      name: _stringOrDefault(data['name'], ''),
      email: _stringOrDefault(data['email'], ''),
      photoUrl: _nullableString(data['photoUrl']),
      colourSeason: _nullableString(data['colourSeason']),
      skinTone: _nullableString(data['skinTone']),
      gender: _nullableString(data['gender']),
      ageRange: _nullableString(data['ageRange']),
      ethnicity: _nullableString(data['ethnicity']),
      occupation: _nullableString(data['occupation']),
      preferredBrands: _stringList(data['preferredBrands']),
      onboardingComplete: data['onboardingComplete'] == true,
      role: UserRoleExtension.fromString(_nullableString(data['role'])),
      isActive: data['isActive'] is bool ? data['isActive'] as bool : true,
      isPremium: data['isPremium'] is bool ? data['isPremium'] as bool : false,
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
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
      'occupation': occupation,
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
    String? occupation,
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
      occupation: occupation ?? this.occupation,
      preferredBrands: preferredBrands ?? this.preferredBrands,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _stringOrDefault(dynamic value, String fallback) =>
      value is String ? value : fallback;

  static String? _nullableString(dynamic value) => value is String ? value : null;

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
