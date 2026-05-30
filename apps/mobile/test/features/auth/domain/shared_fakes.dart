import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';

// Shared across all auth use-case tests. Named without underscore because it
// lives in its own file and is imported by siblings.
class FakeAuthRepository implements AuthRepository {
  AuthUser? returnUser;
  Exception? error;

  int signInCount = 0;
  int signUpCount = 0;
  int signOutCount = 0;
  int signInAnonymouslyCount = 0;
  int signInWithGoogleCount = 0;
  String? lastEmail;
  String? lastPassword;

  Stream<AuthUser?> Function()? watchStateFactory;

  @override
  Stream<AuthUser?> watchAuthState() =>
      watchStateFactory != null ? watchStateFactory!() : const Stream.empty();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCount++;
    lastEmail = email;
    lastPassword = password;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    signUpCount++;
    lastEmail = email;
    lastPassword = password;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    signInAnonymouslyCount++;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    signInWithGoogleCount++;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    if (error != null) throw error!;
  }

  @override
  Future<void> validateToken() async {}
}
