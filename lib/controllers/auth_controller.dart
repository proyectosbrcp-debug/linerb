import '../models/auth_models.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_profile_repository.dart';
import '../storage/auth_session_storage.dart';

class AuthController {
  static const String genericErrorMessage =
      'No fue posible completar la solicitud.';
  static const String disabledMessage = 'Usuario inactivo.';

  final AuthRepository authRepository;
  final UserProfileRepository userProfileRepository;
  final AuthSessionStorage sessionStorage;

  AuthState state = const AuthState.initial();

  AuthController({
    required this.authRepository,
    required this.userProfileRepository,
    required this.sessionStorage,
  });

  UserProfile? get currentProfile => state.profile;

  String get currentUserId {
    return state.profile?.uid ?? 'local_user';
  }

  Future<void> restoreSession() async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final user = await authRepository.currentUser();
      if (user == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      await _loadAndAcceptProfile(user.uid);
    } catch (_) {
      final cachedProfile = await sessionStorage.loadLastValidProfile();
      if (cachedProfile != null && cachedProfile.active) {
        state = AuthState(
          status: AuthStatus.authenticated,
          profile: cachedProfile,
        );
        return;
      }
      state = const AuthState(
        status: AuthStatus.error,
        message: genericErrorMessage,
      );
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final user = await authRepository.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _loadAndAcceptProfile(user.uid);
    } catch (_) {
      state = const AuthState(
        status: AuthStatus.error,
        message: genericErrorMessage,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await authRepository.sendPasswordResetEmail(email);
    } catch (_) {
      // Intencionalmente genérico para no revelar si el correo existe.
    }
  }

  Future<void> signOut() async {
    await authRepository.signOut();
    await sessionStorage.clearLastValidProfile();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _loadAndAcceptProfile(String uid) async {
    final profile = await userProfileRepository.findByUid(uid);
    if (profile == null) {
      await authRepository.signOut();
      await sessionStorage.clearLastValidProfile();
      state = const AuthState(
        status: AuthStatus.error,
        message: genericErrorMessage,
      );
      return;
    }
    if (!profile.active) {
      await authRepository.signOut();
      await sessionStorage.clearLastValidProfile();
      state = const AuthState(
        status: AuthStatus.disabled,
        message: disabledMessage,
      );
      return;
    }
    await sessionStorage.saveLastValidProfile(profile);
    state = AuthState(status: AuthStatus.authenticated, profile: profile);
  }
}
