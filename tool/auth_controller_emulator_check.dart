import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:linerb/controllers/auth_controller.dart';
import 'package:linerb/models/auth_models.dart';
import 'package:linerb/models/user_profile.dart';
import 'package:linerb/repositories/auth_repository.dart';
import 'package:linerb/repositories/user_profile_repository.dart';
import 'package:linerb/storage/auth_session_storage.dart';

Future<void> main() async {
  final authRepository = const _AuthEmulatorRepository();
  final profileRepository = _MemoryUserProfileRepository();
  final sessionStorage = _MemoryAuthSessionStorage();

  await authRepository.clearAccounts();

  await _loginCorrecto(authRepository, profileRepository, sessionStorage);
  await _passwordIncorrecto(authRepository, profileRepository, sessionStorage);
  await _usuarioInexistente(authRepository, profileRepository, sessionStorage);
  await _perfilInexistente(authRepository, profileRepository, sessionStorage);
  await _perfilInactivo(authRepository, profileRepository, sessionStorage);
  await _resetPassword(authRepository, profileRepository, sessionStorage);
  await _restauracionYLogout(authRepository, profileRepository, sessionStorage);
  await _fallbackOffline(profileRepository, sessionStorage);

  print('AuthController Emulator checks OK');
}

Future<void> _loginCorrecto(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final user = await authRepository.createUser(
    email: 'ok@linerb.test',
    password: 'ValidPass123',
  );
  profileRepository.profile = _profile(uid: user.uid);
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.signIn(email: 'ok@linerb.test', password: 'ValidPass123');

  _expect(
    controller.state.status == AuthStatus.authenticated,
    'login correcto',
  );
  _expect(controller.currentUserId == user.uid, 'uid autenticado');
}

Future<void> _passwordIncorrecto(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final user = await authRepository.createUser(
    email: 'wrong@linerb.test',
    password: 'ValidPass123',
  );
  profileRepository.profile = _profile(uid: user.uid);
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.signIn(email: 'wrong@linerb.test', password: 'bad-password');

  _expect(controller.state.status == AuthStatus.error, 'password incorrecto');
  _expect(
    controller.state.message == AuthController.genericErrorMessage,
    'mensaje genérico',
  );
}

Future<void> _usuarioInexistente(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.signIn(
    email: 'missing@linerb.test',
    password: 'ValidPass123',
  );

  _expect(controller.state.status == AuthStatus.error, 'usuario inexistente');
  _expect(
    controller.state.message == AuthController.genericErrorMessage,
    'usuario inexistente genérico',
  );
}

Future<void> _perfilInexistente(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  await authRepository.createUser(
    email: 'without-profile@linerb.test',
    password: 'ValidPass123',
  );
  profileRepository.profile = null;
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.signIn(
    email: 'without-profile@linerb.test',
    password: 'ValidPass123',
  );

  _expect(controller.state.status == AuthStatus.error, 'perfil inexistente');
}

Future<void> _perfilInactivo(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final user = await authRepository.createUser(
    email: 'inactive@linerb.test',
    password: 'ValidPass123',
  );
  profileRepository.profile = _profile(uid: user.uid, active: false);
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.signIn(
    email: 'inactive@linerb.test',
    password: 'ValidPass123',
  );

  _expect(controller.state.status == AuthStatus.disabled, 'perfil inactivo');
}

Future<void> _resetPassword(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );

  await controller.sendPasswordResetEmail('unknown@linerb.test');

  _expect(controller.state.status == AuthStatus.initial, 'reset password');
}

Future<void> _restauracionYLogout(
  _AuthEmulatorRepository authRepository,
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final user = await authRepository.createUser(
    email: 'restore@linerb.test',
    password: 'ValidPass123',
  );
  profileRepository.profile = _profile(uid: user.uid);
  final controller = _controller(
    authRepository,
    profileRepository,
    sessionStorage,
  );
  await controller.signIn(
    email: 'restore@linerb.test',
    password: 'ValidPass123',
  );

  await controller.restoreSession();
  _expect(controller.state.status == AuthStatus.authenticated, 'restore');

  await controller.signOut();
  _expect(controller.state.status == AuthStatus.unauthenticated, 'logout');
}

Future<void> _fallbackOffline(
  _MemoryUserProfileRepository profileRepository,
  _MemoryAuthSessionStorage sessionStorage,
) async {
  final cached = _profile(uid: 'cached-uid');
  sessionStorage.cached = cached;
  profileRepository.failReads = true;
  final controller = _controller(
    _FailingCurrentUserAuthRepository(),
    profileRepository,
    sessionStorage,
  );

  await controller.restoreSession();

  _expect(controller.state.status == AuthStatus.authenticated, 'offline');
  _expect(controller.currentUserId == 'cached-uid', 'offline uid');
}

AuthController _controller(
  AuthRepository authRepository,
  UserProfileRepository userProfileRepository,
  AuthSessionStorage sessionStorage,
) {
  return AuthController(
    authRepository: authRepository,
    userProfileRepository: userProfileRepository,
    sessionStorage: sessionStorage,
  );
}

UserProfile _profile({required String uid, bool active = true}) {
  return UserProfile(
    uid: uid,
    displayName: 'Operador Emulator',
    email: '$uid@linerb.test',
    role: UserRole.inspector,
    active: active,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 2),
  );
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw StateError('Falló verificación Auth Emulator: $message');
  }
}

class _AuthEmulatorRepository implements AuthRepository {
  static const String projectId = 'linerb';
  static const String host = String.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_HOST',
    defaultValue: '127.0.0.1:9099',
  );
  static const String apiKey = 'emulator-key';

  const _AuthEmulatorRepository();

  static AuthUser? _signedUser;

  Future<void> clearAccounts() async {
    _signedUser = null;
    await http.delete(
      Uri.parse('http://$host/emulator/v1/projects/$projectId/accounts'),
    );
  }

  Future<AuthUser> createUser({
    required String email,
    required String password,
  }) async {
    final response = await _post('accounts:signUp', {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    });
    return AuthUser(uid: response['localId'] as String, email: email);
  }

  @override
  Future<AuthUser?> currentUser() async {
    return _signedUser;
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _post('accounts:sendOobCode', {
        'requestType': 'PASSWORD_RESET',
        'email': email,
      });
    } catch (_) {
      throw const AuthRepositoryException(AuthFailureKind.unknown);
    }
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _post('accounts:signInWithPassword', {
        'email': email,
        'password': password,
        'returnSecureToken': true,
      });
      _signedUser = AuthUser(uid: response['localId'] as String, email: email);
      return _signedUser!;
    } catch (error) {
      throw AuthRepositoryException(AuthFailureKind.invalidCredentials, error);
    }
  }

  @override
  Future<void> signOut() async {
    _signedUser = null;
  }

  Future<Map<String, Object?>> _post(
    String action,
    Map<String, Object?> body,
  ) async {
    final response = await http.post(
      Uri.parse(
        'http://$host/identitytoolkit.googleapis.com/v1/$action?key=$apiKey',
      ),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthRepositoryException(AuthFailureKind.unknown, decoded);
    }
    return Map<String, Object?>.from(decoded as Map);
  }
}

class _FailingCurrentUserAuthRepository implements AuthRepository {
  @override
  Future<AuthUser?> currentUser() {
    throw const AuthRepositoryException(AuthFailureKind.unavailable);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw const AuthRepositoryException(AuthFailureKind.unavailable);
  }

  @override
  Future<void> signOut() async {}
}

class _MemoryUserProfileRepository implements UserProfileRepository {
  UserProfile? profile;
  bool failReads = false;

  @override
  Future<UserProfile?> findByUid(String uid) async {
    if (failReads) throw StateError('Firestore temporalmente no disponible');
    if (profile?.uid == uid) return profile;
    return null;
  }
}

class _MemoryAuthSessionStorage implements AuthSessionStorage {
  UserProfile? cached;

  @override
  Future<void> clearLastValidProfile() async {
    cached = null;
  }

  @override
  Future<UserProfile?> loadLastValidProfile() async {
    return cached;
  }

  @override
  Future<void> saveLastValidProfile(UserProfile profile) async {
    cached = profile;
  }
}
