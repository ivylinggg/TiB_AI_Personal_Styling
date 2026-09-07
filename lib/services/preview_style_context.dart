import 'package:flutter/foundation.dart';

class PreviewStyleContext extends ChangeNotifier {
  String? customerUid;

  bool get active => customerUid != null && customerUid!.trim().isNotEmpty;

  void setCustomer(String uid) {
    final normalized = uid.trim();
    if (normalized.isEmpty || normalized == customerUid) return;
    customerUid = normalized;
    notifyListeners();
  }

  void clear() {
    if (customerUid == null) return;
    customerUid = null;
    notifyListeners();
  }
}
