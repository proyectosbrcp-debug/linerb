import 'auth_repository.dart';

class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  @override
  Future<AuthUser?> currentUser() {
    throw const AuthRepositoryException(AuthFailureKind.unavailable);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw const AuthRepositoryException(AuthFailureKind.unavailable);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw const AuthRepositoryException(AuthFailureKind.unavailable);
  }

  @override
  Future<void> signOut() async {}
}
