import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Semantic first-pass gate for Wardrobe uploads.
///
/// The base ML Kit image-labeling model is used only to decide whether the
/// photo contains a wearable/fashion entity. It is not used to pretend that
/// fine-grained garment classification (Tops/Bottoms/Skirts/Dresses) is
/// already solved. The category remains editable by the user after the gate.
class WardrobeImageValidationService {
  WardrobeImageValidationService._();

  static const List<String> allowedCategories = [
    'Tops',
    'Bottoms',
    'Dresses',
    'Suits',
    'Jackets',
    'Skirts',
    'Shoes',
    'Accessories',
  ];

  static final ImageLabeler _labeler = ImageLabeler(
    options: ImageLabelerOptions(confidenceThreshold: 0.45),
  );

  static Future<String?> validate(
    File file, {
    String? category,
  }) async {
    if (!file.existsSync()) {
      return 'Invalid';
    }

    if (category != null && !allowedCategories.contains(category)) {
      return 'Invalid';
    }

    try {
      final labels = await _labeler.processImage(
        InputImage.fromFilePath(file.path),
      );

      if (labels.isEmpty) {
        return 'Invalid';
      }

      final decision = _classifyWearable(labels);

      if (decision.isExplicitReject) {
        return 'Invalid';
      }

      if (!decision.hasWearableEvidence ||
          decision.wearableConfidence < 0.52) {
        return 'Invalid';
      }

      return null;
    } catch (_) {
      return 'Invalid';
    }
  }

  static _WearableDecision _classifyWearable(List<ImageLabel> labels) {
    var bestWearable = 0.0;
    var bestReject = 0.0;

    for (final label in labels) {
      final text = label.label.trim().toLowerCase();
      final confidence = label.confidence;

      if (_wearableTerms.any(text.contains)) {
        bestWearable = confidence > bestWearable ? confidence : bestWearable;
      }

      if (_rejectTerms.any(text.contains)) {
        bestReject = confidence > bestReject ? confidence : bestReject;
      }
    }

    final explicitReject =
        bestReject >= 0.45 && bestReject >= bestWearable * 1.05;

    return _WearableDecision(
      hasWearableEvidence: bestWearable > 0,
      wearableConfidence: bestWearable,
      isExplicitReject: explicitReject,
    );
  }

  static const Set<String> _wearableTerms = {
    'clothing',
    'cloth',
    'apparel',
    'garment',
    'shirt',
    't-shirt',
    'tee',
    'top',
    'blouse',
    'dress',
    'skirt',
    'jeans',
    'trouser',
    'pants',
    'shorts',
    'coat',
    'jacket',
    'suit',
    'shoe',
    'sneaker',
    'footwear',
    'boot',
    'sandal',
    'handbag',
    'purse',
    'hat',
    'cap',
    'scarf',
    'belt',
    'tie',
    'accessory',
    'fashion accessory',
  };

  static const Set<String> _rejectTerms = {
    'car',
    'automobile',
    'vehicle',
    'food',
    'dish',
    'meal',
    'noodle',
    'fruit',
    'vegetable',
    'drink',
    'beverage',
    'cup',
    'bottle',
    'phone',
    'mobile phone',
    'laptop',
    'computer',
    'screen',
    'television',
    'tv',
    'document',
    'paper',
    'book',
    'building',
    'house',
    'architecture',
    'landscape',
    'mountain',
    'sky',
    'sea',
    'ocean',
    'tree',
    'flower',
    'plant',
    'animal',
    'dog',
    'cat',
    'person',
    'face',
    'portrait',
  };

  static Future<void> dispose() async {
    _labeler.close();
  }
}

class _WearableDecision {
  const _WearableDecision({
    required this.hasWearableEvidence,
    required this.wearableConfidence,
    required this.isExplicitReject,
  });

  final bool hasWearableEvidence;
  final double wearableConfidence;
  final bool isExplicitReject;
}
