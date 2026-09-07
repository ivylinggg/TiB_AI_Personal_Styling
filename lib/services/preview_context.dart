import 'package:flutter/foundation.dart';

class PreviewContext extends ChangeNotifier {
  String? _customerUid;

  String? get customerUid => _customerUid;
  bool get isCustomerPreview => _customerUid != null && _customerUid!.isNotEmpty;

  void setCustomerUid(String? uid) {
    final normalized = uid?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (_customerUid == next) return;
    _customerUid = next;
    notifyListeners();
  }

  void clear() => setCustomerUid(null);
}
