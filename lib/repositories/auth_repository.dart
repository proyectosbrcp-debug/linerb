enum AuthFailureKind { invalidCredentials, unavailable, unknown }

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;

  const AuthUser({required this.uid, this.email, this.displayName});
}

class AuthRepositoryException implements Exception {
  final AuthFailureKind kind;
  final Object? cause;

  const AuthRepositoryException(this.kind, [this.cause]);

  @override
  String toString() {
    return 'AuthRepositoryException($kind)';
  }
}

abstract class AuthRepository {
  Future<AuthUser?> currentUser();

  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}
