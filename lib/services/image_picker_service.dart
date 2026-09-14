import 'dart:io';

import 'package:image_picker/image_picker.dart';

class ImagePickerService {
  ImagePickerService._();

  static final ImagePicker _picker = ImagePicker();

  static const _maxImageBytes = 10 * 1024 * 1024;

  static Future<File?> pickGallery() async {
    return _pickAndValidate(ImageSource.gallery);
  }

  static Future<File?> pickCamera() async {
    return _pickAndValidate(ImageSource.camera);
  }

  static Future<File?> _pickAndValidate(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (image == null) return null;

      final file = File(image.path);
      if (!await file.exists()) return null;

      final length = await file.length();
      if (length <= 0 || length > _maxImageBytes) return null;

      return file;
    } on FileSystemException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
