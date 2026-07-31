import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:linerb/controllers/selection_line_controller.dart';
import 'package:linerb/pages/home/seleccion_linea_page.dart';
import 'package:linerb/pages/inspeccion/registro_inspeccion_page.dart';
import 'package:linerb/repositories/catalog_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform originalGeolocator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    originalGeolocator = GeolocatorPlatform.instance;
  });

  tearDown(() {
    GeolocatorPlatform.instance = originalGeolocator;
  });

  testWidgets('dropdowns de selección conservan valor inicial y cambio', (
    tester,
  ) async {
    await _pumpSelectionPage(tester);

    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );

    expect(dropdowns.elementAt(0).initialValue, 'Troncal');
    expect(dropdowns.elementAt(1).initialValue, 'TRONCAL 1');
    expect(dropdowns.elementAt(2).initialValue, 'TRONCAL 1');

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ramal').last);
    await tester.pumpAndSettle();

    final updatedDropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );

    expect(updatedDropdowns.elementAt(0).initialValue, 'Ramal');
    expect(updatedDropdowns.elementAt(1).initialValue, 'RAMAL 1');
  });

  testWidgets('dropdown dependiente actualiza subtroncal al cambiar troncal', (
    tester,
  ) async {
    await _pumpSelectionPage(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TRONCAL 2').last);
    await tester.pumpAndSettle();

    final dropdowns = tester.widgetList<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>),
    );

    expect(dropdowns.elementAt(1).initialValue, 'TRONCAL 2');
    expect(dropdowns.elementAt(2).initialValue, 'SUB 2A');
  });

  testWidgets('RadioGroup conserva selección de hallazgo', (tester) async {
    await _pumpInspectionPage(tester);

    expect(find.text('Estado de la fuga'), findsNothing);

    await tester.ensureVisible(find.text('Fuga'));
    await tester.tap(find.widgetWithText(RadioListTile<String>, 'Fuga'));
    await tester.pumpAndSettle();

    expect(find.text('Estado de la fuga'), findsOneWidget);
  });

  testWidgets('captura de ubicación exitosa conserva formato de coordenadas', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      position: _position(latitude: 4.123456, longitude: -73.987654),
    );
    await _pumpInspectionPage(tester);

    await tester.ensureVisible(find.text('OBTENER COORDENADAS'));
    await tester.tap(find.text('OBTENER COORDENADAS'));
    await tester.pumpAndSettle();

    expect(find.text('4.123456'), findsOneWidget);
    expect(find.text('-73.987654'), findsOneWidget);
    expect(find.text('Coordenadas obtenidas correctamente'), findsOneWidget);
  });

  testWidgets('servicio de ubicación desactivado conserva mensaje', (
    tester,
  ) async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      serviceEnabled: false,
    );
    await _pumpInspectionPage(tester);

    await tester.ensureVisible(find.text('OBTENER COORDENADAS'));
    await tester.tap(find.text('OBTENER COORDENADAS'));
    await tester.pumpAndSettle();

    expect(find.text('Active el GPS del dispositivo'), findsOneWidget);
  });

  testWidgets('permiso de ubicación denegado conserva mensaje', (tester) async {
    GeolocatorPlatform.instance = _FakeGeolocatorPlatform(
      permission: LocationPermission.denied,
      requestedPermission: LocationPermission.denied,
    );
    await _pumpInspectionPage(tester);

    await tester.ensureVisible(find.text('OBTENER COORDENADAS'));
    await tester.tap(find.text('OBTENER COORDENADAS'));
    await tester.pumpAndSettle();

    expect(find.text('Permiso de ubicación denegado'), findsOneWidget);
  });

  test('no quedan print directos en lib ni tool', () {
    final files = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>(),
      ...Directory('tool').listSync(recursive: true).whereType<File>(),
    ].where((file) => file.path.endsWith('.dart'));

    final offenders = <String>[];
    for (final file in files) {
      if (file.readAsStringSync().contains('print(')) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty);
  });
}

Future<void> _pumpSelectionPage(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SeleccionLineaPage(
        usuario: 'Operador',
        selectionLineController: SelectionLineController(
          catalogRepository: _FakeCatalogRepository(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpInspectionPage(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: RegistroInspeccionPage(
        usuario: 'Operador',
        tipoLinea: 'Troncal',
        seleccionLinea: 'TRONCAL 1 / SUB 1A',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    longitude: longitude,
    latitude: latitude,
    timestamp: DateTime(2026, 1, 1),
    accuracy: 1,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<CatalogData?> cargarCatalogos() async {
    return CatalogData(
      troncalesJson: {
        'TRONCAL 1': ['TRONCAL 1', 'SUB 1A', 'SUB 1B'],
        'TRONCAL 2': ['SUB 2A'],
      },
      ramalesJson: const ['RAMAL 1', 'RAMAL 2'],
    );
  }
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  final bool serviceEnabled;
  final LocationPermission permission;
  final LocationPermission requestedPermission;
  final Position position;

  _FakeGeolocatorPlatform({
    this.serviceEnabled = true,
    this.permission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    Position? position,
  }) : position = position ?? _position(latitude: 1, longitude: 2);

  @override
  Future<bool> isLocationServiceEnabled() async {
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    expect(locationSettings?.accuracy, LocationAccuracy.high);
    return position;
  }
}
