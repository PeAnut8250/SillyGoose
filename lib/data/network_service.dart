import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class NetworkService extends ChangeNotifier {
  // Singleton
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal() {
    _init();
  }

  List<ConnectivityResult> _results = [ConnectivityResult.none];
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isWifi => _results.contains(ConnectivityResult.wifi) ||
      _results.contains(ConnectivityResult.ethernet);
  bool get isMobile => _results.contains(ConnectivityResult.mobile);
  bool get isConnected => isWifi || isMobile;

  /// Returns a human-readable label for current connection
  String get connectionLabel {
    if (isWifi) return 'Wi-Fi';
    if (isMobile) return 'Mobile data';
    return 'Offline';
  }

  void _init() {
    // Get current state immediately
    Connectivity().checkConnectivity().then((results) {
      _results = results;
      notifyListeners();
    });

    // Listen for changes
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      _results = results;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
