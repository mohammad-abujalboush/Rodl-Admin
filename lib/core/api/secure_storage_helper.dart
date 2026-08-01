import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageHelper {
  final FlutterSecureStorage _storage;

  // NEW: In-memory cache to beat Flutter Web race conditions
  static String? _memoryToken;

  SecureStorageHelper(this._storage);

  static const String _tokenKey = 'jwt_token';

  Future<void> saveToken(String token) async {
    _memoryToken =
        token; // 1. Save to RAM instantly so Dio can use it immediately
    await _storage.write(
      key: _tokenKey,
      value: token,
    ); // 2. Save to browser disk in the background
  }

  Future<String?> getToken() async {
    if (_memoryToken != null)
      return _memoryToken; // Grab from RAM if available!

    _memoryToken = await _storage.read(key: _tokenKey); // Fallback to disk
    return _memoryToken;
  }

  Future<void> deleteToken() async {
    _memoryToken = null; // Clear RAM
    await _storage.delete(key: _tokenKey); // Clear Disk
  }
}
