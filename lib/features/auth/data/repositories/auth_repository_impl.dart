import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/api/secure_storage_helper.dart';
import '../../../../core/api/signalr_client.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final DioClient _dioClient;
  final SecureStorageHelper _secureStorage;
  final SignalRClient _signalRClient;

  AuthRepositoryImpl(this._dioClient, this._secureStorage, this._signalRClient);

  @override
  Future<bool> login(String email, String password) async {
    try {
      final response = await _dioClient.dio.post(
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        // ⚠️ CHECK THIS KEY: Is your C# backend sending 'token' or 'accessToken'?
        final token = response.data['token'] ?? response.data['accessToken'];

        print('🔑 RECEIVED TOKEN: $token'); // ADD THIS TO VERIFY IT IS NOT NULL

        if (token != null && token.toString().isNotEmpty) {
          await _secureStorage.saveToken(token);
          return true;
        }
      }
      return false;
    } catch (e) {
      print('🛑 LOGIN EXCEPTION: $e');
      return false;
    }
  }

  @override
  Future<void> logout() async {
    // 1. Drop the live map connection
    await _signalRClient.disconnect();

    // 2. Burn the token
    await _secureStorage.deleteToken();
  }

  @override
  Future<bool> checkAuthStatus() async {
    final token = await _secureStorage.getToken();
    if (token != null) {
      // If they open the app and are already logged in, connect the radar immediately
      await _signalRClient.connect();
      return true;
    }
    return false;
  }
}
