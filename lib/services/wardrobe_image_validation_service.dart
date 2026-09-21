import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';

/// Strict semantic gate for Wardrobe uploads.
///
/// Only labels that clearly describe a garment or footwear are accepted.
/// Generic labels such as "cloth", "fashion", "wear", "accessory", "bag",
/// or "handbag" are intentionally not accepted because they can produce
/// false positives for non-clothing objects.
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

      // A person/object label is a strong signal that the image is not a
      // clean standalone wardrobe-item photo.
      if (_containsStrongNonGarmentLabel(labels)) {
        return 'Invalid';
      }

      // Do not accept broad semantic labels. A valid upload needs a
      // specific garment/footwear label from this allow-list.
      final garmentConfidence = _bestSpecificGarmentConfidence(labels);

      if (garmentConfidence < 0.55) {
        return 'Invalid';
      }

      return null;
    } catch (_) {
      return 'Invalid';
    }
  }

  static double _bestSpecificGarmentConfidence(List<ImageLabel> labels) {
    var best = 0.0;

    for (final label in labels) {
      final text = label.label.trim().toLowerCase();
      if (!_specificGarmentLabels.contains(text)) {
        continue;
      }

      if (label.confidence > best) {
        best = label.confidence;
      }
    }

    return best;
  }

  static bool _containsStrongNonGarmentLabel(List<ImageLabel> labels) {
    for (final label in labels) {
      final text = label.label.trim().toLowerCase();

      if (_strongNonGarmentLabels.contains(text)) {
        return true;
      }
    }

    return false;
  }

  /// Specific labels only. Generic labels such as "clothing", "cloth",
  /// "apparel", "fashion", "wear", and "accessory" are deliberately excluded.
  static const Set<String> _specificGarmentLabels = {
    'shirt',
    't-shirt',
    'tee',
    'blouse',
    'dress',
    'skirt',
    'jeans',
    'trouser',
    'trousers',
    'pants',
    'shorts',
    'coat',
    'jacket',
    'suit',
    'shoe',
    'sneaker',
    'footwear',
    'boot',
    'boots',
    'sandal',
    'sandals',
  };

  /// Explicitly reject common non-garment or ambiguous object labels.
  static const Set<String> _strongNonGarmentLabels = {
    'bag',
    'plastic bag',
    'handbag',
    'purse',
    'backpack',
    'wallet',
    'hat',
    'cap',
    'scarf',
    'belt',
    'tie',
    'watch',
    'jewelry',
    'jewellery',
    'accessory',
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
    'car',
    'automobile',
    'vehicle',
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
