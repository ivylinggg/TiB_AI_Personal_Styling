import 'package:flutter/foundation.dart';

class PreviewContext extends ChangeNotifier {
  String? _customerUid;
  DateTime? _startedAt;

  String? get customerUid => _customerUid;
  bool get isCustomerPreview => _customerUid != null && _customerUid!.isNotEmpty;
  DateTime? get startedAt => _startedAt;
  Duration? get previewDuration =>
      _startedAt == null ? null : DateTime.now().difference(_startedAt!);

  void setCustomerUid(String? uid) {
    final normalized = uid?.trim();
    final next = normalized == null || normalized.isEmpty ? null : normalized;
    if (_customerUid == next) return;
    _customerUid = next;
    _startedAt = next == null ? null : DateTime.now();
    notifyListeners();
  }

  void clear() => setCustomerUid(null);
}
