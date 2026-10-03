import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the phone has a network connection. Having one does not prove
/// the server is reachable; callers still handle failed requests.
abstract interface class NetworkStatus {
  Future<bool> isConnected();

  Stream<bool> get changes;
}

class ConnectivityNetworkStatus implements NetworkStatus {
  ConnectivityNetworkStatus([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isConnected() async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get changes =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
