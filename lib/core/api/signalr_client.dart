import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/http_connection_options.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'secure_storage_helper.dart';

class SignalRClient {
  final SecureStorageHelper _secureStorage;
  HubConnection? _hubConnection;

  // Streams for the UI to listen to
  final _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _newJobController = StreamController<Map<String, dynamic>>.broadcast();
  final _jobUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _jobCompletedController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onDriverLocationUpdate =>
      _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onNewJob => _newJobController.stream;
  Stream<Map<String, dynamic>> get onJobUpdated => _jobUpdatedController.stream;
  Stream<String> get onJobCompleted => _jobCompletedController.stream;

  SignalRClient(this._secureStorage);

  Future<void> connect() async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('🚫 [SignalR] Cannot connect: No JWT Token found.');
      return;
    }

    const serverUrl =
        'https://rodlapi.mohammad-abujalboush.com/hubs/admin-radar';

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          serverUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async =>
                await _secureStorage.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Mapping to the exact backend broadcast events
    _hubConnection?.on('ReceiveDriverLocation', _handleDriverLocation);
    _hubConnection?.on('ReceiveNewJob', _handleNewJob);
    _hubConnection?.on('ReceiveJobUpdated', _handleJobUpdated);
    _hubConnection?.on(
      'DispatchClaimed',
      _handleJobUpdated,
    ); // Drivers claiming a job updates the status
    _hubConnection?.on('JobCompleted', _handleJobCompleted);

    try {
      await _hubConnection?.start();
      if (kDebugMode) print('✅ [SignalR] Connected to Admin Radar Hub');
    } catch (e) {
      if (kDebugMode) print('🚫 [SignalR] Connection Failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
    if (kDebugMode) print('🔌 [SignalR] Disconnected');
  }

  // --- HANDLERS ---
  void _handleDriverLocation(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      final data = args.first as Map<String, dynamic>;
      _driverLocationController.add(data);
    }
  }

  void _handleNewJob(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      final data = args.first as Map<String, dynamic>;
      _newJobController.add(data);
    }
  }

  void _handleJobUpdated(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      final data = args.first as Map<String, dynamic>;
      _jobUpdatedController.add(data);
    }
  }

  void _handleJobCompleted(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      final requestId = args.first.toString();
      _jobCompletedController.add(requestId);
    }
  }

  void dispose() {
    _driverLocationController.close();
    _newJobController.close();
    _jobUpdatedController.close();
    _jobCompletedController.close();
  }
}
