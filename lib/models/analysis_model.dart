import 'package:cloud_firestore/cloud_firestore.dart';

class AnalysisModel {
  final String id;
  final String colourSeason;
  final String skinTone;
  final String imageUrl;
  final DateTime createdAt;

  const AnalysisModel({
    required this.id,
    required this.colourSeason,
    required this.skinTone,
    required this.imageUrl,
    required this.createdAt,
  });

  factory AnalysisModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AnalysisModel(
      id: doc.id,
      colourSeason: data['colourSeason'] ?? '',
      skinTone: data['skinTone'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'colourSeason': colourSeason,
      'skinTone': skinTone,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
