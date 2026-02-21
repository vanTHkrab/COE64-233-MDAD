import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logging/logging.dart';

/// Provides a reactive and imperative API for checking network connectivity.
///
/// Wraps [Connectivity] so the rest of the app depends on an abstraction
/// rather than a concrete plugin — making it easy to mock in tests.
class NetworkInfo {
  NetworkInfo({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  static final _log = Logger('NetworkInfo');

  /// Returns `true` if the device currently has internet access
  /// (Wi-Fi, mobile data, ethernet, etc.).
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    final connected = !results.contains(ConnectivityResult.none);
    _log.fine('isConnected: $connected ($results)');
    return connected;
  }

  /// Emits whenever connectivity state changes.
  ///
  /// Useful for triggering automatic sync when the device comes back online.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      final connected = !results.contains(ConnectivityResult.none);
      _log.fine('Connectivity changed → connected: $connected');
      return connected;
    });
  }
}
