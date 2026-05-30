import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../models/auth_user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDatasource _datasource;
  AuthRepositoryImpl(this._datasource);

  @override
  Stream<AuthUser?> watchAuthState() =>
      _datasource.watchAuthState().map((model) => model?.toEntity());

  @override
  Future<AuthUser> signInAnonymously() async {
    final model = await _datasource.signInAnonymously();
    return model.toEntity();
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final model = await _datasource.signInWithGoogle();
    return model.toEntity();
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    final model = await _datasource.signUp(email: email, password: password);
    return model.toEntity();
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final model = await _datasource.signIn(email: email, password: password);
    return model.toEntity();
  }

  @override
  Future<void> signOut() => _datasource.signOut();

  @override
  Future<void> validateToken() => _datasource.validateToken();
}
