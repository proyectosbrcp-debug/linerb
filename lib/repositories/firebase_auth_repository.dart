import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth auth;

  FirebaseAuthRepository({firebase_auth.FirebaseAuth? auth})
    : auth = auth ?? firebase_auth.FirebaseAuth.instance;

  @override
  Future<AuthUser?> currentUser() async {
    final user = auth.currentUser;
    if (user == null) return null;
    return _fromFirebaseUser(user);
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthRepositoryException(AuthFailureKind.unknown);
      }
      return _fromFirebaseUser(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthRepositoryException(_failureKind(e.code), e);
    } catch (e) {
      throw AuthRepositoryException(AuthFailureKind.unknown, e);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw AuthRepositoryException(_failureKind(e.code), e);
    } catch (e) {
      throw AuthRepositoryException(AuthFailureKind.unknown, e);
    }
  }

  @override
  Future<void> signOut() {
    return auth.signOut();
  }

  AuthUser _fromFirebaseUser(firebase_auth.User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  AuthFailureKind _failureKind(String code) {
    const invalidCodes = {
      'invalid-email',
      'invalid-credential',
      'user-disabled',
      'user-not-found',
      'wrong-password',
    };
    if (invalidCodes.contains(code)) return AuthFailureKind.invalidCredentials;
    const unavailableCodes = {
      'network-request-failed',
      'too-many-requests',
      'app-not-authorized',
    };
    if (unavailableCodes.contains(code)) return AuthFailureKind.unavailable;
    return AuthFailureKind.unknown;
  }
}
