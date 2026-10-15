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
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};
    final timestamp = data['createdAt'];

    return AnalysisModel(
      id: doc.id,
      colourSeason: _stringOrDefault(data['colourSeason']),
      skinTone: _stringOrDefault(data['skinTone']),
      imageUrl: _stringOrDefault(data['imageUrl']),
      createdAt: _dateTimeOrDefault(timestamp),
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

  static String _stringOrDefault(dynamic value) =>
      value is String ? value : '';

  static DateTime _dateTimeOrDefault(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
