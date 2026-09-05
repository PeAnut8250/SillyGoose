import 'package:flutter/foundation.dart';

class ScrollService extends ChangeNotifier {
  static final ScrollService _instance = ScrollService._internal();
  factory ScrollService() => _instance;
  ScrollService._internal();

  bool _isScrolledDown = false;
  bool get isScrolledDown => _isScrolledDown;

  double _scrollOffset = 0.0;
  double get scrollOffset => _scrollOffset;

  void setScrolledDown(bool value) {
    if (_isScrolledDown != value) {
      _isScrolledDown = value;
      notifyListeners();
    }
  }

  void setScrollOffset(double value) {
    if (_scrollOffset != value) {
      _scrollOffset = value;
      notifyListeners();
    }
  }
}
