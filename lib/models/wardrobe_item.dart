import 'package:cloud_firestore/cloud_firestore.dart';

class WardrobeItem {
  final String id;
  final String userId;
  final String imageUrl;
  final String name;
  final String category;
  final String colour;
  final String style;
  final String season;
  final bool isFavourite;
  final String notes;
  final String occasion;
  final String formality;
  final String pattern;
  final String material;
  final String silhouette;
  final String fit;
  final String length;
  final bool? layering;
  final int? warmth;
  final int? statementLevel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WardrobeItem({
    required this.id,
    required this.userId,
    required this.imageUrl,
    required this.name,
    required this.category,
    required this.colour,
    required this.style,
    required this.season,
    required this.isFavourite,
    required this.notes,
    this.occasion = '',
    this.formality = '',
    this.pattern = '',
    this.material = '',
    this.silhouette = '',
    this.fit = '',
    this.length = '',
    this.layering,
    this.warmth,
    this.statementLevel,
    required this.createdAt,
    this.updatedAt,
  });

  factory WardrobeItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return WardrobeItem(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      name: data['name'] as String? ?? 'Untitled item',
      category: data['category'] as String? ?? 'Other',
      colour: data['colour'] as String? ?? 'Unknown',
      style: data['style'] as String? ?? 'Everyday',
      season: data['season'] as String? ?? 'All seasons',
      isFavourite: data['isFavourite'] as bool? ?? false,
      notes: data['notes'] as String? ?? '',
      occasion: data['occasion'] as String? ?? '',
      formality: data['formality'] as String? ?? '',
      pattern: data['pattern'] as String? ?? '',
      material: data['material'] as String? ?? '',
      silhouette: data['silhouette'] as String? ?? '',
      fit: data['fit'] as String? ?? '',
      length: data['length'] as String? ?? '',
      layering: data['layering'] as bool?,
      warmth: _intFromValue(data['warmth']),
      statementLevel: _intFromValue(data['statementLevel']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'imageUrl': imageUrl,
      'name': name,
      'category': category,
      'colour': colour,
      'style': style,
      'season': season,
      'isFavourite': isFavourite,
      'notes': notes,
      'occasion': occasion,
      'formality': formality,
      'pattern': pattern,
      'material': material,
      'silhouette': silhouette,
      'fit': fit,
      'length': length,
      'layering': layering,
      'warmth': warmth,
      'statementLevel': statementLevel,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'category': category,
      'colour': colour,
      'style': style,
      'season': season,
      'isFavourite': isFavourite,
      'notes': notes,
      'occasion': occasion,
      'formality': formality,
      'pattern': pattern,
      'material': material,
      'silhouette': silhouette,
      'fit': fit,
      'length': length,
      'layering': layering,
      'warmth': warmth,
      'statementLevel': statementLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  WardrobeItem copyWith({
    String? imageUrl,
    String? name,
    String? category,
    String? colour,
    String? style,
    String? season,
    bool? isFavourite,
    String? notes,
    String? occasion,
    String? formality,
    String? pattern,
    String? material,
    String? silhouette,
    String? fit,
    String? length,
    bool? layering,
    int? warmth,
    int? statementLevel,
    DateTime? updatedAt,
  }) {
    return WardrobeItem(
      id: id,
      userId: userId,
      imageUrl: imageUrl ?? this.imageUrl,
      name: name ?? this.name,
      category: category ?? this.category,
      colour: colour ?? this.colour,
      style: style ?? this.style,
      season: season ?? this.season,
      isFavourite: isFavourite ?? this.isFavourite,
      notes: notes ?? this.notes,
      occasion: occasion ?? this.occasion,
      formality: formality ?? this.formality,
      pattern: pattern ?? this.pattern,
      material: material ?? this.material,
      silhouette: silhouette ?? this.silhouette,
      fit: fit ?? this.fit,
      length: length ?? this.length,
      layering: layering ?? this.layering,
      warmth: warmth ?? this.warmth,
      statementLevel: statementLevel ?? this.statementLevel,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static int? _intFromValue(dynamic value) => value is num ? value.round() : null;

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
