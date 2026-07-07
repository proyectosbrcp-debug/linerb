import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DatosApp.inspecciones.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('Utilidades y modelos V1', () {
    test('fechaCorta conserva el formato sin ceros iniciales', () {
      expect(fechaCorta(DateTime(2026, 7, 3)), '3/7/2026');
    });

    test('HallazgoInspeccion conserva su representación textual', () {
      final hallazgo = HallazgoInspeccion(
        tipo: 'Fuga',
        detalle: 'Activa',
        latitud: '4.123',
        longitud: '-73.456',
        descripcion: 'Fuga visible',
        foto1Path: '/tmp/foto-1.jpg',
      );

      expect(
        hallazgo.toString(),
        'Fuga - Activa\n'
        'Coordenadas: 4.123, -73.456\n'
        'Fotos: FOTO 1  FOTO 2\n'
        'Descripción: Fuga visible',
      );
    });

    test('los catálogos integrados conservan su estructura V1', () async {
      final troncales =
          jsonDecode(await rootBundle.loadString('assets/data/troncales.json'))
              as Map<String, dynamic>;
      final ramalesDocument =
          jsonDecode(await rootBundle.loadString('assets/data/ramales.json'))
              as Map<String, dynamic>;
      final ramales = ramalesDocument['ramales'] as List<dynamic>;

      expect(troncales, hasLength(12));
      expect(
        troncales.values.expand((value) => value as List<dynamic>),
        hasLength(50),
      );
      expect(ramales, hasLength(20));
      expect(troncales['TRONCAL 1'], contains('SUB-TRONCAL 1A'));
      expect(ramales, contains('CLUSTER 004NE'));
    });
  });

  group('Login V1', () {
    testWidgets('muestra los controles y roles actuales', (tester) async {
      await tester.pumpWidget(const LinerbApp());

      expect(find.text('LINERB'), findsOneWidget);
      expect(find.text('Sistema de Inspección de Líneas'), findsOneWidget);
      expect(find.text('SUPER'), findsOneWidget);
      expect(find.text('INICIAR'), findsOneWidget);

      final passwordField = tester.widget<TextField>(find.byType(TextField));
      expect(passwordField.obscureText, isTrue);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('INSPE'), findsOneWidget);
    });

    testWidgets('rechaza credenciales no reconocidas', (tester) async {
      await tester.pumpWidget(const LinerbApp());

      await tester.enterText(find.byType(TextField), 'incorrecta');
      await tester.tap(find.text('INICIAR'));
      await tester.pump();

      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
      expect(find.byType(InicioPage), findsOneWidget);
    });
  });

  testWidgets('RegistroInspeccionPage conserva su estado inicial', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RegistroInspeccionPage(
          usuario: 'SUPER',
          tipoLinea: 'Troncal',
          seleccionLinea: 'TRONCAL 1 / SUB-TRONCAL 1A',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Registro de Inspección'), findsOneWidget);
    expect(find.text('TRONCAL 1 / SUB-TRONCAL 1A'), findsOneWidget);
    expect(find.text('Operativa'), findsOneWidget);
    expect(find.text('Corrosión'), findsOneWidget);
    expect(find.text('FINALIZAR INSPECCIÓN'), findsOneWidget);
  });

  testWidgets('HistorialPage lee el formato persistido por V1', (tester) async {
    SharedPreferences.setMockInitialValues({
      'historial_inspecciones': <String>[
        jsonEncode({
          'linea': 'TRONCAL 1 / SUB-TRONCAL 1A',
          'tipoLinea': 'Troncal',
          'responsable': 'Operador Uno',
          'fecha': '2026-07-03T10:30:00.000',
          'estadoLinea': 'Operativa',
          'puntoReferencia': 'KM 1+000',
          'observaciones': 'Sin novedades',
        }),
      ],
    });

    await tester.pumpWidget(const MaterialApp(home: HistorialPage()));
    await tester.pumpAndSettle();

    expect(find.text('TRONCAL 1 / SUB-TRONCAL 1A'), findsOneWidget);
    expect(find.textContaining('Fecha: 3/7/2026'), findsOneWidget);
    expect(find.textContaining('Responsable: Operador Uno'), findsOneWidget);
  });

  testWidgets('AvancePage calcula el avance desde DatosApp', (tester) async {
    DatosApp.inspecciones.add(
      Inspeccion(
        linea: 'LÍNEA A',
        tipoLinea: 'Troncal',
        responsable: 'Operador Uno',
        fecha: DateTime.now(),
        estadoLinea: 'Operativa',
        puntoReferencia: 'KM 1',
        observaciones: '',
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: AvancePage(lineas: ['LÍNEA A', 'LÍNEA B'])),
    );

    expect(find.text('Líneas registradas: 2'), findsOneWidget);
    expect(find.text('Inspeccionadas: 1'), findsOneWidget);
    expect(find.text('Pendientes: 1'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);
  });
}
