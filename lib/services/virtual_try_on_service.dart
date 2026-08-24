import 'dart:io';

import '../models/wardrobe_item.dart';

/// Result returned by the virtual try-on layer.
///
/// The Flutter UI stays independent from the image-generation provider so a
/// production provider can be connected later without rebuilding the screen.
class VirtualTryOnResult {
  const VirtualTryOnResult({
    required this.imageUrl,
    this.provider = 'local-preview',
  });

  final String imageUrl;
  final String provider;
}

class VirtualTryOnService {
  const VirtualTryOnService._();

  /// Backend contract for generating a photorealistic try-on image.
  ///
  /// `modelPhoto` is the user's selected model photo and `items` are pieces
  /// from the user's own wardrobe. A real image-generation endpoint should
  /// receive these inputs and return a hosted generated image URL.
  static Future<VirtualTryOnResult?> generate({
    required File modelPhoto,
    required List<WardrobeItem> items,
    String? occasion,
  }) async {
    if (!modelPhoto.existsSync() || items.isEmpty) return null;

    // Intentionally left provider-neutral. The app currently renders the
    // safe local preview while the production AI endpoint is being connected.
    return null;
  }
}
