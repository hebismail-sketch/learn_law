import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Thin wrapper over connectivity_plus that reports online/offline as a
/// stream the sync manager can listen to.
///
/// connectivity_plus reports *transport* reachability, not whether the internet
/// actually works: a captive portal or a dead uplink still shows as connected.
/// So this class deliberately does not claim the network is usable. The sync
/// manager treats a real request failure as the authoritative signal and
/// simply retries on the next connectivity event or app resume.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  /// Current transport state, without waiting for an update event.
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return _isOnline(results);
  }

  /// Emits true when a transport becomes available and false when it drops.
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  static bool _isOnline(List<ConnectivityResult> results) {
    // `none` means no transport. Any other value means a transport exists;
    // whether it reaches the internet is decided by the next real request.
    return !results.contains(ConnectivityResult.none);
  }
}
