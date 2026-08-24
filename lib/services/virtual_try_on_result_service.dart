import '../models/wardrobe_item.dart';

/// Contract for a future photorealistic virtual try-on backend.
///
/// The Flutter app can prepare a model reference and real wardrobe pieces
/// without pretending that a generated image exists. A production provider
/// can later implement this contract and return the generated image URL.
class VirtualTryOnRequest {
  final String modelPhotoPath;
  final List<WardrobeItem> items;
  final String occasion;

  const VirtualTryOnRequest({
    required this.modelPhotoPath,
    required this.items,
    required this.occasion,
  });
}

class VirtualTryOnResult {
  final String? imageUrl;
  final String status;

  const VirtualTryOnResult({
    required this.imageUrl,
    required this.status,
  });

  bool get isGenerated => imageUrl != null && imageUrl!.isNotEmpty;
}

class VirtualTryOnResultService {
  VirtualTryOnResultService._();

  /// Placeholder until a real image-generation provider is configured.
  /// Returns an explicit pending state instead of displaying a fake AI result.
  static Future<VirtualTryOnResult> generate(VirtualTryOnRequest request) async {
    if (request.modelPhotoPath.isEmpty || request.items.isEmpty) {
      return const VirtualTryOnResult(
        imageUrl: null,
        status: 'Add your TiB Model and at least one wardrobe piece first.',
      );
    }

    return const VirtualTryOnResult(
      imageUrl: null,
      status: 'Your look is ready for the real AI try-on engine.',
    );
  }
}
