import 'dart:io';

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Wardrobe photo gate.
///
/// The previous pixel heuristics are intentionally removed because they could
/// not understand the semantic content of a photo (for example, a car could
/// pass as a "jacket"). This service now uses ML Kit image labeling as the
/// semantic gate before an image can enter the wardrobe flow.
///
/// Category remains user-editable after the image passes the clothing gate.
/// Fine-grained fashion classification is kept separate from the gate so a
/// wrong model label can never silently allow an unrelated object through.
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
      return 'We could not read that photo. Please choose another image.';
    }

    if (category != null && !allowedCategories.contains(category)) {
      return 'Only clothing and fashion accessories can be added to Wardrobe.';
    }

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final labels = await _labeler.processImage(inputImage);

      if (labels.isEmpty) {
        return 'We could not recognise a clothing item in this photo. Please upload one clear wearable item.';
      }

      final wearable = _classifyWearable(labels);

      if (!wearable.isWearable) {
        return 'This photo does not appear to contain clothing or a fashion accessory. Please upload a wearable item only.';
      }

      if (wearable.confidence < 0.50) {
        return 'We could not confidently recognise this as clothing or a fashion accessory. Please use a clearer photo of one wearable item.';
      }

      return null;
    } catch (_) {
      return 'We could not analyse this photo. Please choose a clear photo of one clothing or fashion accessory.';
    }
  }

  static _WearableDecision _classifyWearable(List<ImageLabel> labels) {
    var bestWearable = 0.0;
    var bestReject = 0.0;

    for (final label in labels) {
      final text = label.label.trim().toLowerCase();
      final confidence = label.confidence;

      if (_wearableTokens.any(text.contains)) {
        if (confidence > bestWearable) bestWearable = confidence;
      }

      if (_rejectTokens.any(text.contains)) {
        if (confidence > bestReject) bestReject = confidence;
      }
    }

    if (bestReject >= 0.45 && bestReject >= bestWearable * 1.05) {
      return _WearableDecision(
        isWearable: false,
        confidence: bestReject,
      );
    }

    return _WearableDecision(
      isWearable: bestWearable > 0,
      confidence: bestWearable,
    );
  }

  static const Set<String> _wearableTokens = {
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
    'bag',
    'handbag',
    'purse',
    'backpack',
    'hat',
    'cap',
    'scarf',
    'belt',
    'tie',
    'accessory',
    'fashion',
    'wear',
  };

  static const Set<String> _rejectTokens = {
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
  };

  static Future<void> dispose() async {
    _labeler.close();
  }
}

class _WearableDecision {
  const _WearableDecision({
    required this.isWearable,
    required this.confidence,
  });

  final bool isWearable;
  final double confidence;
}
