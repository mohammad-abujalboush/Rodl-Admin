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
  final _jobCompletedController = StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get onDriverLocationUpdate =>
      _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onNewJob => _newJobController.stream;
  Stream<String> get onJobCompleted => _jobCompletedController.stream;

  SignalRClient(this._secureStorage);

  Future<void> connect() async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      if (kDebugMode) print('🔴 [SignalR] Cannot connect: No JWT Token found.');
      return;
    }

    // Update to match your local .NET port
    const serverUrl = 'https://localhost:7014/hubs/admin-radar';

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          serverUrl,
          options: HttpConnectionOptions(
            // Ensure the token is passed as a string
            accessTokenFactory: () async =>
                await _secureStorage.getToken() ?? '',
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Register listeners for the exact string names we used in the .NET Hub
    _hubConnection?.on('ReceiveDriverLocation', _handleDriverLocation);
    _hubConnection?.on('ReceiveNewJob', _handleNewJob);
    _hubConnection?.on('JobCompleted', _handleJobCompleted);

    try {
      await _hubConnection?.start();
      if (kDebugMode) print('🟢 [SignalR] Connected to Admin Radar Hub');
    } catch (e) {
      if (kDebugMode) print('🔴 [SignalR] Connection Failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _hubConnection?.stop();
    if (kDebugMode) print('⚪ [SignalR] Disconnected');
  }

  // --- HANDLERS ---
  void _handleDriverLocation(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      // The .NET backend sends an anonymous object which signalr_netcore parses as a Map
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

  void _handleJobCompleted(List<Object?>? args) {
    if (args != null && args.isNotEmpty) {
      final requestId = args.first.toString();
      _jobCompletedController.add(requestId);
    }
  }

  void dispose() {
    _driverLocationController.close();
    _newJobController.close();
    _jobCompletedController.close();
  }
}
