import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static Future<String> uploadAnalysisImage({
    required String uid,
    required File image,
  }) async {
    final fileName = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref().child('analysis').child(uid).child('$fileName.jpg');
    await ref.putFile(image);
    return ref.getDownloadURL();
  }

  static Future<String> uploadWardrobeImage({
    required String uid,
    required File image,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('wardrobe').child(uid).child(fileName);
    await ref.putFile(image);
    return ref.getDownloadURL();
  }
}
