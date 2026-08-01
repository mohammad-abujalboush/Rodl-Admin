import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_helper.dart';

class DioClient {
  final Dio _dio;
  final SecureStorageHelper _secureStorage;

  DioClient(this._dio, this._secureStorage) {
    _dio
      ..options.baseUrl = _getBaseUrl()
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 15)
      ..options.headers = {'Content-Type': 'application/json'};

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Now safely grabs the token from the RAM cache instantly
          final token = await _secureStorage.getToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
            if (kDebugMode) {
              print(
                '🟢 [DIO] Attached Header: Bearer ${token.substring(0, 15)}...',
              );
            }
          } else {
            if (kDebugMode) {
              print('🔴 [DIO] WARNING: Request sent WITHOUT a token!');
            }
          }

          if (kDebugMode) {
            print('🌐 [DIO] Request: ${options.method} ${options.uri}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            print(
              '🔴 [DIO] Error: ${e.response?.statusCode} - on ${e.requestOptions.uri}',
            );
          }

          if (e.response?.statusCode == 401) {
            print('🔴 [DIO] 401 Unauthorized - Wiping Token and Logging Out.');
            await _secureStorage.deleteToken();
          }

          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;

  String _getBaseUrl() {
    if (kIsWeb) return 'http://localhost:5225';
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:5225';
    return 'http://localhost:5225';
  }
}
