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

  factory WardrobeItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return WardrobeItem(
      id: doc.id,
      userId: _stringOrDefault(data['userId'], ''),
      imageUrl: _stringOrDefault(data['imageUrl'], ''),
      name: _stringOrDefault(data['name'], 'Untitled item'),
      category: _stringOrDefault(data['category'], 'Other'),
      colour: _stringOrDefault(data['colour'], 'Unknown'),
      style: _stringOrDefault(data['style'], 'Everyday'),
      season: _stringOrDefault(data['season'], 'All seasons'),
      isFavourite: data['isFavourite'] == true,
      notes: _stringOrDefault(data['notes'], ''),
      occasion: _stringOrDefault(data['occasion'], ''),
      formality: _stringOrDefault(data['formality'], ''),
      pattern: _stringOrDefault(data['pattern'], ''),
      material: _stringOrDefault(data['material'], ''),
      silhouette: _stringOrDefault(data['silhouette'], ''),
      fit: _stringOrDefault(data['fit'], ''),
      length: _stringOrDefault(data['length'], ''),
      layering: _boolOrNull(data['layering']),
      warmth: _intFromValue(data['warmth']),
      statementLevel: _intFromValue(data['statementLevel']),
      createdAt: _dateTimeFromValue(data['createdAt']),
      updatedAt: _dateTimeFromValue(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
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

  Map<String, dynamic> toUpdateMap() => {
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
  }) =>
      WardrobeItem(
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

  static String _stringOrDefault(dynamic value, String fallback) =>
      value is String ? value : fallback;

  static bool? _boolOrNull(dynamic value) => value is bool ? value : null;

  static int? _intFromValue(dynamic value) => value is num ? value.round() : null;

  static DateTime? _dateTimeFromValue(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
