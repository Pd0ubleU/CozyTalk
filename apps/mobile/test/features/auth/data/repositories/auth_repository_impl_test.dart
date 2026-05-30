import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/datasources/auth_datasource.dart';
import 'package:mobile/features/auth/data/models/auth_user_model.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';

class _FakeAuthDatasource implements AuthDatasource {
  AuthUserModel? returnUser;
  Exception? error;

  int signInCount = 0;
  int signUpCount = 0;
  int signOutCount = 0;
  int signInAnonymouslyCount = 0;
  int signInWithGoogleCount = 0;
  String? lastEmail;
  String? lastPassword;

  Stream<AuthUserModel?> Function()? watchStateFactory;

  @override
  Stream<AuthUserModel?> watchAuthState() =>
      watchStateFactory != null ? watchStateFactory!() : const Stream.empty();

  @override
  Future<AuthUserModel> signIn({
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
  Future<AuthUserModel> signUp({
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
  Future<AuthUserModel> signInAnonymously() async {
    signInAnonymouslyCount++;
    if (error != null) throw error!;
    return returnUser!;
  }

  @override
  Future<AuthUserModel> signInWithGoogle() async {
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

const _model = AuthUserModel(
  uid: 'uid-1',
  email: 'a@b.com',
  displayName: 'Alice',
);

void main() {
  late _FakeAuthDatasource datasource;
  late AuthRepositoryImpl repository;

  setUp(() {
    datasource = _FakeAuthDatasource();
    repository = AuthRepositoryImpl(datasource);
  });

  group('AuthRepositoryImpl', () {
    group('signIn', () {
      test('calls datasource with email and password', () async {
        datasource.returnUser = _model;
        await repository.signIn(email: 'a@b.com', password: 'pw');
        expect(datasource.signInCount, 1);
        expect(datasource.lastEmail, 'a@b.com');
        expect(datasource.lastPassword, 'pw');
      });

      test('converts model to entity', () async {
        datasource.returnUser = _model;
        final user = await repository.signIn(email: 'a@b.com', password: 'pw');
        expect(user.uid, 'uid-1');
        expect(user.email, 'a@b.com');
        expect(user.displayName, 'Alice');
      });

      test('propagates datasource exception', () {
        datasource.error = Exception('bad credentials');
        expect(
          () => repository.signIn(email: 'a@b.com', password: 'wrong'),
          throwsA(isA<Exception>()),
        );
      });
    });

    group('signUp', () {
      test('calls datasource with email and password', () async {
        datasource.returnUser = _model;
        await repository.signUp(email: 'a@b.com', password: 'pw');
        expect(datasource.signUpCount, 1);
      });

      test('converts model to entity', () async {
        datasource.returnUser = _model;
        final user = await repository.signUp(email: 'a@b.com', password: 'pw');
        expect(user.uid, 'uid-1');
      });
    });

    group('signInAnonymously', () {
      test('calls datasource', () async {
        datasource.returnUser = const AuthUserModel(uid: 'anon');
        await repository.signInAnonymously();
        expect(datasource.signInAnonymouslyCount, 1);
      });

      test('converts model to entity', () async {
        datasource.returnUser = const AuthUserModel(uid: 'anon');
        final user = await repository.signInAnonymously();
        expect(user.uid, 'anon');
      });
    });

    group('signInWithGoogle', () {
      test('calls datasource', () async {
        datasource.returnUser = _model;
        await repository.signInWithGoogle();
        expect(datasource.signInWithGoogleCount, 1);
      });

      test('converts model to entity', () async {
        datasource.returnUser = _model;
        final user = await repository.signInWithGoogle();
        expect(user.uid, 'uid-1');
        expect(user.email, 'a@b.com');
        expect(user.displayName, 'Alice');
      });
    });

    group('signOut', () {
      test('calls datasource', () async {
        await repository.signOut();
        expect(datasource.signOutCount, 1);
      });
    });

    group('watchAuthState', () {
      test('maps AuthUserModel to AuthUser', () async {
        datasource.watchStateFactory = () => Stream.value(
          const AuthUserModel(uid: 'stream-uid', email: 'x@y.com'),
        );
        final repo = AuthRepositoryImpl(datasource);
        final user = await repo.watchAuthState().first;
        expect(user?.uid, 'stream-uid');
        expect(user?.email, 'x@y.com');
      });

      test('maps null to null', () async {
        datasource.watchStateFactory = () => Stream.value(null);
        final repo = AuthRepositoryImpl(datasource);
        final user = await repo.watchAuthState().first;
        expect(user, isNull);
      });
    });
  });
}
