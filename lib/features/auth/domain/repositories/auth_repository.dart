abstract class AuthRepository {
  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<bool> checkAuthStatus();
}
