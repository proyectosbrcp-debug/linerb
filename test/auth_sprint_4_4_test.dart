import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/auth_controller.dart';
import 'package:linerb/controllers/selection_line_controller.dart';
import 'package:linerb/models/auth_models.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/user_profile.dart';
import 'package:linerb/pages/home/seleccion_linea_page.dart';
import 'package:linerb/repositories/auth_repository.dart';
import 'package:linerb/repositories/catalog_repository.dart';
import 'package:linerb/repositories/remote/finding_remote_mapper.dart';
import 'package:linerb/repositories/remote/inspection_remote_mapper.dart';
import 'package:linerb/repositories/remote/remote_mapping_exception.dart';
import 'package:linerb/repositories/user_profile_repository.dart';
import 'package:linerb/services/permission_service.dart';
import 'package:linerb/storage/auth_session_storage.dart';
import 'package:linerb/storage/local/linerb_database.dart';
import 'package:linerb/storage/local/local_database_storage.dart';
import 'package:linerb/storage/shared_preferences_auth_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AuthController Sprint 4.4', () {
    test('inicio de sesión correcto acepta perfil activo', () async {
      final profile = _profile(role: UserRole.inspector);
      final controller = _controller(profile: profile);

      await controller.signIn(email: 'inspector@linerb.test', password: 'ok');

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.currentProfile, profile);
    });

    test('credenciales inválidas no exponen detalle técnico', () async {
      final controller = _controller(
        authRepository: _FakeAuthRepository(failSignIn: true),
        profile: _profile(),
      );

      await controller.signIn(email: 'nadie@linerb.test', password: 'bad');

      expect(controller.state.status, AuthStatus.error);
      expect(controller.state.message, AuthController.genericErrorMessage);
    });

    test('perfil inexistente bloquea el acceso', () async {
      final auth = _FakeAuthRepository();
      final controller = _controller(authRepository: auth);

      await controller.signIn(email: 'sinperfil@linerb.test', password: 'ok');

      expect(controller.state.status, AuthStatus.error);
      expect(auth.signOutCount, 1);
    });

    test('perfil inactivo queda en estado disabled', () async {
      final controller = _controller(profile: _profile(active: false));

      await controller.signIn(email: 'inactivo@linerb.test', password: 'ok');

      expect(controller.state.status, AuthStatus.disabled);
      expect(controller.state.message, AuthController.disabledMessage);
    });

    test(
      'recuperación de contraseña no revela existencia del correo',
      () async {
        final auth = _FakeAuthRepository(failReset: true);
        final controller = _controller(
          authRepository: auth,
          profile: _profile(),
        );

        await controller.sendPasswordResetEmail('oculto@linerb.test');

        expect(auth.resetRequests, ['oculto@linerb.test']);
        expect(controller.state.status, AuthStatus.initial);
      },
    );

    test('restaura sesión Firebase válida con perfil activo', () async {
      final profile = _profile(uid: 'uid-restored');
      final controller = _controller(
        authRepository: _FakeAuthRepository(currentUid: 'uid-restored'),
        profile: profile,
      );

      await controller.restoreSession();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.currentUserId, 'uid-restored');
    });

    test('cerrar sesión limpia solo la sesión, no datos operativos', () async {
      final auth = _FakeAuthRepository();
      final controller = _controller(authRepository: auth, profile: _profile());

      await controller.signIn(email: 'operador@linerb.test', password: 'ok');
      await controller.signOut();

      expect(controller.state.status, AuthStatus.unauthenticated);
      expect(auth.signOutCount, 1);
    });

    test('funcionamiento local con sesión previamente válida', () async {
      final storage = _MemoryAuthSessionStorage(
        cached: _profile(uid: 'uid-offline'),
      );
      final controller = _controller(
        authRepository: _FakeAuthRepository(currentFails: true),
        sessionStorage: storage,
      );

      await controller.restoreSession();

      expect(controller.state.status, AuthStatus.authenticated);
      expect(controller.currentUserId, 'uid-offline');
    });

    test('acceso denegado sin sesión inicial', () async {
      final controller = _controller(
        authRepository: _FakeAuthRepository(currentUid: null),
      );

      await controller.restoreSession();

      expect(controller.state.status, AuthStatus.unauthenticated);
    });
  });

  group('PermissionService Sprint 4.4', () {
    test('permisos de administrator', () {
      final permissions = const PermissionService();
      final profile = _profile(role: UserRole.administrator);

      expect(permissions.canCreateInspection(profile), isTrue);
      expect(permissions.canUpdateInspection(profile), isTrue);
      expect(permissions.canDeleteInspection(profile), isTrue);
      expect(permissions.canViewDashboard(profile), isTrue);
      expect(permissions.canViewAllInspections(profile), isTrue);
      expect(permissions.canManageUsers(profile), isTrue);
    });

    test('permisos de supervisor', () {
      final permissions = const PermissionService();
      final profile = _profile(role: UserRole.supervisor);

      expect(permissions.canCreateInspection(profile), isTrue);
      expect(permissions.canUpdateInspection(profile), isTrue);
      expect(permissions.canDeleteInspection(profile), isFalse);
      expect(permissions.canViewDashboard(profile), isTrue);
      expect(permissions.canViewAllInspections(profile), isTrue);
      expect(permissions.canManageUsers(profile), isFalse);
    });

    test('permisos de inspector', () {
      final permissions = const PermissionService();
      final profile = _profile(role: UserRole.inspector);

      expect(permissions.canCreateInspection(profile), isTrue);
      expect(permissions.canUpdateInspection(profile), isFalse);
      expect(permissions.canDeleteInspection(profile), isFalse);
      expect(permissions.canViewDashboard(profile), isFalse);
      expect(permissions.canViewAllInspections(profile), isFalse);
      expect(permissions.canManageUsers(profile), isFalse);
    });

    test('permisos de viewer', () {
      final permissions = const PermissionService();
      final profile = _profile(role: UserRole.viewer);

      expect(permissions.canCreateInspection(profile), isFalse);
      expect(permissions.canUpdateInspection(profile), isFalse);
      expect(permissions.canDeleteInspection(profile), isFalse);
      expect(permissions.canViewDashboard(profile), isTrue);
      expect(permissions.canViewAllInspections(profile), isTrue);
      expect(permissions.canManageUsers(profile), isFalse);
    });
  });

  testWidgets('viewer sin posibilidad de finalizar inspecciones', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SeleccionLineaPage(
          usuario: 'Viewer',
          userProfile: _profile(role: UserRole.viewer),
          selectionLineController: SelectionLineController(
            catalogRepository: _FakeCatalogRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'INICIAR INSPECCIÓN'),
    );

    expect(button.onPressed, isNull);
  });

  test('created_by usa uid autenticado', () async {
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final storage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
      userIdProvider: () async => 'uid-authenticated',
    );

    await storage.agregarInspeccionCompleta(
      Inspeccion(
        linea: 'LÍNEA A',
        tipoLinea: 'Troncal',
        responsable: 'Operador',
        fecha: DateTime(2026),
        estadoLinea: 'Operativa',
        puntoReferencia: 'KM 1',
        observaciones: 'Sin novedad',
      ),
      [
        HallazgoInspeccion(
          tipo: 'Fuga',
          detalle: 'Activa',
          latitud: '1',
          longitud: '2',
          descripcion: 'Detalle',
        ),
      ],
    );

    final db = await database.open();
    final inspections = await db.query('inspections');
    final findings = await db.query('hallazgos');
    await database.close();

    expect(inspections.single['created_by'], 'uid-authenticated');
    expect(inspections.single['updated_by'], 'uid-authenticated');
    expect(findings.single['created_by'], 'uid-authenticated');
    expect(findings.single['updated_by'], 'uid-authenticated');
  });

  test('contraseña nunca almacenada localmente', () async {
    const storage = SharedPreferencesAuthSessionStorage();
    await storage.saveLastValidProfile(_profile(email: 'user@linerb.test'));

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      SharedPreferencesAuthSessionStorage.lastValidProfileKey,
    );

    expect(raw, isNotNull);
    expect(raw, isNot(contains('password')));
    expect(raw, isNot(contains('secret')));
  });

  test('fotografías y PDF excluidos de payload remoto estructurado', () {
    final inspectionPayload = const InspectionRemoteMapper().fromLocalPayload({
      'global_id': 'i-1',
      'fecha_iso': DateTime(2026).toIso8601String(),
      'responsable': 'Operador',
      'created_by': 'uid-1',
      'updated_by': 'uid-1',
      'tipo_linea': 'Troncal',
      'linea': 'TRONCAL 1 / SUB 1',
      'punto_referencia': 'KM 1',
      'estado_linea': 'Operativa',
      'observaciones': 'Sin novedad',
      'created_at': DateTime(2026).toIso8601String(),
      'updated_at': DateTime(2026).toIso8601String(),
      'device_id': 'device',
      'local_version': 1,
      'remote_version': 0,
      'sync_status': 'pendingCreate',
      'deleted_at': null,
    });

    expect(inspectionPayload.keys, isNot(contains('foto1_path')));
    expect(inspectionPayload.keys, isNot(contains('pdf_path')));

    expect(
      () => const FindingRemoteMapper().fromLocalPayload({
        'global_id': 'f-1',
        'inspection_id': 'i-1',
        'tipo': 'Fuga',
        'detalle': 'Activa',
        'latitud': '1',
        'longitud': '2',
        'descripcion': 'Detalle',
        'created_at': DateTime(2026).toIso8601String(),
        'updated_at': DateTime(2026).toIso8601String(),
        'created_by': 'uid-1',
        'updated_by': 'uid-1',
        'device_id': 'device',
        'local_version': 1,
        'remote_version': 0,
        'deleted_at': null,
        'foto1_path': '/local/foto.jpg',
      }),
      throwsA(isA<RemoteMappingException>()),
    );
  });

  test('datos SQLite se conservan al cerrar sesión', () async {
    final database = LinerbDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    final storage = LocalDatabaseStorage(
      database: database,
      inspeccionesMemoria: [],
    );
    final controller = _controller(profile: _profile());

    await storage.agregarInspeccionHistorial(
      Inspeccion(
        linea: 'LÍNEA A',
        tipoLinea: 'Troncal',
        responsable: 'Operador',
        fecha: DateTime(2026),
        estadoLinea: 'Operativa',
        puntoReferencia: 'KM 1',
        observaciones: 'Sin novedad',
      ),
    );
    await controller.signIn(email: 'operador@linerb.test', password: 'ok');
    await controller.signOut();

    expect(await storage.inspectionCount(), 1);
    await database.close();
  });
}

AuthController _controller({
  AuthRepository? authRepository,
  UserProfile? profile,
  AuthSessionStorage? sessionStorage,
}) {
  return AuthController(
    authRepository: authRepository ?? _FakeAuthRepository(),
    userProfileRepository: _FakeUserProfileRepository(profile),
    sessionStorage: sessionStorage ?? _MemoryAuthSessionStorage(),
  );
}

UserProfile _profile({
  String uid = 'uid-1',
  String displayName = 'Operador Uno',
  String email = 'operador@linerb.test',
  UserRole role = UserRole.inspector,
  bool active = true,
}) {
  return UserProfile(
    uid: uid,
    displayName: displayName,
    email: email,
    role: role,
    active: active,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026, 1, 2),
  );
}

class _FakeAuthRepository implements AuthRepository {
  final bool failSignIn;
  final bool failReset;
  final bool currentFails;
  final String? currentUid;
  int signOutCount = 0;
  final List<String> resetRequests = [];

  _FakeAuthRepository({
    this.failSignIn = false,
    this.failReset = false,
    this.currentFails = false,
    this.currentUid = 'uid-1',
  });

  @override
  Future<AuthUser?> currentUser() async {
    if (currentFails) {
      throw const AuthRepositoryException(AuthFailureKind.unavailable);
    }
    if (currentUid == null) return null;
    return AuthUser(uid: currentUid!, email: 'operador@linerb.test');
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    resetRequests.add(email);
    if (failReset) {
      throw const AuthRepositoryException(AuthFailureKind.unknown);
    }
  }

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    if (failSignIn) {
      throw const AuthRepositoryException(AuthFailureKind.invalidCredentials);
    }
    return AuthUser(uid: currentUid ?? 'uid-1', email: email);
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
  }
}

class _FakeUserProfileRepository implements UserProfileRepository {
  final UserProfile? profile;

  const _FakeUserProfileRepository(this.profile);

  @override
  Future<UserProfile?> findByUid(String uid) async {
    if (profile == null) return null;
    if (profile!.uid == uid) return profile;
    return profile!.uid == 'uid-1' ? profile : null;
  }
}

class _MemoryAuthSessionStorage implements AuthSessionStorage {
  UserProfile? cached;
  int clearCount = 0;

  _MemoryAuthSessionStorage({this.cached});

  @override
  Future<void> clearLastValidProfile() async {
    clearCount++;
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

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogData?> cargarCatalogos() async {
    return CatalogData(
      troncalesJson: {
        'TRONCAL 1': ['TRONCAL 1'],
      },
      ramalesJson: const ['RAMAL 1'],
    );
  }
}
