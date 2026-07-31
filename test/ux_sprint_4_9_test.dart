import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/auth_controller.dart';
import 'package:linerb/controllers/progress_controller.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/models/inspeccion.dart';
import 'package:linerb/models/user_profile.dart';
import 'package:linerb/pages/auth/login_page.dart';
import 'package:linerb/pages/avance/avance_page.dart';
import 'package:linerb/repositories/auth_repository.dart';
import 'package:linerb/repositories/inspection_repository.dart';
import 'package:linerb/repositories/user_profile_repository.dart';
import 'package:linerb/storage/auth_session_storage.dart';
import 'package:linerb/storage/inspection_storage.dart';
import 'package:linerb/widgets/linerb_empty_state.dart';
import 'package:linerb/widgets/linerb_loading_state.dart';

void main() {
  group('Sprint 4.9 UX y accesibilidad', () {
    testWidgets('estado vacío reutilizable soporta pantalla pequeña y texto 2x', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var actionPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: LinerbEmptyState(
                icon: Icons.history,
                title: 'Sin inspecciones registradas',
                message:
                    'Cuando finalice una inspección aparecerá en este historial.',
                actionLabel: 'Volver',
                onAction: () {
                  actionPressed = true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sin inspecciones registradas'), findsOneWidget);
      expect(find.text('Volver'), findsOneWidget);
      await tester.ensureVisible(find.text('Volver'));
      await tester.tap(find.text('Volver'));
      expect(actionPressed, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('estado de carga reutilizable muestra mensaje claro', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LinerbLoadingState(
              message: 'Cargando historial de inspecciones...',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.text('Cargando historial de inspecciones...'),
        findsOneWidget,
      );
    });

    testWidgets('avance vacío conserva semántica y text scaling', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2),
            ),
            child: AvancePage(lineas: []),
          ),
        ),
      );

      expect(find.text('Sin líneas para mostrar'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Avance general 0.0 por ciento'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avance vacío soporta tamaños definidos del sprint', (
      tester,
    ) async {
      final sizes = <Size>[
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
        const Size(600, 960),
      ];
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final size in sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const AvancePage(lineas: []),
            ),
          ),
        );

        expect(find.text('Sin líneas para mostrar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('avance muestra texto e icono además del color del semáforo', (
      tester,
    ) async {
      final repository = _FakeInspectionRepository({
        'LÍNEA OPERATIVA': DateTime(2026, 7, 30),
      });
      final controller = ProgressController(
        inspectionRepository: repository,
        clock: () => DateTime(2026, 7, 31),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AvancePage(
            lineas: const ['LÍNEA OPERATIVA', 'LÍNEA PENDIENTE'],
            progressController: controller,
          ),
        ),
      );

      expect(find.textContaining('1 días'), findsOneWidget);
      expect(find.textContaining('Nunca inspeccionada'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('login evita doble envío y no expone errores técnicos', (
      tester,
    ) async {
      final authRepository = _FailingAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        userProfileRepository: _FakeUserProfileRepository(),
        sessionStorage: _FakeAuthSessionStorage(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LoginPage(controller: controller, onAuthChanged: () {}),
        ),
      );

      await tester.enterText(
        find.byType(TextField).at(0),
        'operador@linerb.co',
      );
      await tester.enterText(find.byType(TextField).at(1), 'clave');
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.tap(find.text('INICIAR SESIÓN'));
      await tester.pump();

      expect(authRepository.signInAttempts, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text(AuthController.genericErrorMessage), findsOneWidget);
      expect(find.textContaining('firebase'), findsNothing);
      expect(find.textContaining('stack'), findsNothing);
    });
  });
}

class _FailingAuthRepository implements AuthRepository {
  int signInAttempts = 0;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<AuthUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInAttempts++;
    await Future<void>.delayed(const Duration(milliseconds: 40));
    throw const AuthRepositoryException(AuthFailureKind.invalidCredentials);
  }

  @override
  Future<void> signOut() async {}
}

class _FakeUserProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> findByUid(String uid) async => null;
}

class _FakeAuthSessionStorage implements AuthSessionStorage {
  @override
  Future<void> clearLastValidProfile() async {}

  @override
  Future<UserProfile?> loadLastValidProfile() async => null;

  @override
  Future<void> saveLastValidProfile(UserProfile profile) async {}
}

class _FakeInspectionRepository implements InspectionRepository {
  final Map<String, DateTime?> lastInspectionByLine;

  _FakeInspectionRepository(this.lastInspectionByLine);

  @override
  void agregarInspeccion(Inspeccion inspeccion) {}

  @override
  Future<List<Inspeccion>> cargarHistorial() async => [];

  @override
  Future<InspectionHistoryPage> cargarHistorialPage({
    String? cursor,
    int limit = 30,
  }) async {
    return const InspectionHistoryPage(
      items: [],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<void> guardarEnHistorial(Inspeccion inspeccion) async {}

  @override
  Future<void> guardarInspeccionCompleta(
    Inspeccion inspeccion,
    List<HallazgoInspeccion> hallazgos,
  ) async {}

  @override
  List<Inspeccion> obtenerInspecciones() => [];

  @override
  DateTime? ultimaInspeccion(String linea) => lastInspectionByLine[linea];
}
