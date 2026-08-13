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
  final DateTime? createdAt;

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
    required this.createdAt,
  });

  factory WardrobeItem.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'];

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
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
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
      'createdAt': FieldValue.serverTimestamp(),
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
      createdAt: createdAt,
    );
  }
}
