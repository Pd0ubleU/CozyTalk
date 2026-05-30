import '../entities/auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> watchAuthState();
  Future<AuthUser> signInAnonymously();
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signUp({required String email, required String password});
  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
  // Refreshes the current user's ID token. Throws if token is invalid/expired.
  Future<void> validateToken();
}
