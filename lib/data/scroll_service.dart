import 'package:flutter/foundation.dart';

class ScrollService extends ChangeNotifier {
  static final ScrollService _instance = ScrollService._internal();
  factory ScrollService() => _instance;
  ScrollService._internal();

  bool _isScrolledDown = false;
  bool get isScrolledDown => _isScrolledDown;

  void setScrolledDown(bool value) {
    if (_isScrolledDown != value) {
      _isScrolledDown = value;
      notifyListeners();
    }
  }
}
