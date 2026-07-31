import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/controllers/dashboard_controller.dart';
import 'package:linerb/controllers/selection_line_controller.dart';
import 'package:linerb/models/dashboard_models.dart';
import 'package:linerb/pages/dashboard/dashboard_page.dart';
import 'package:linerb/pages/dashboard/dashboard_findings_detail_page.dart';
import 'package:linerb/pages/home/seleccion_linea_page.dart';
import 'package:linerb/repositories/catalog_repository.dart';
import 'package:linerb/repositories/dashboard_repository.dart';

void main() {
  final now = DateTime(2026, 3, 1);

  testWidgets('muestra estado cargando', (tester) async {
    final pendingCatalog = Completer<CatalogData?>();
    final controller = _dashboardController(
      now,
      repository: _FakeDashboardRepository(
        catalogFuture: pendingCatalog.future,
      ),
    );

    await _pumpDashboard(tester, controller);

    expect(find.text('Cargando dashboard...'), findsOneWidget);
  });

  testWidgets('muestra estado sin datos', (tester) async {
    final controller = _dashboardController(
      now,
      repository: _FakeDashboardRepository(
        catalog: const CatalogData(troncalesJson: {}, ramalesJson: []),
        inspections: const [],
        findings: const [],
      ),
    );

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(
      find.text('No hay datos disponibles para el dashboard'),
      findsOneWidget,
    );
  });

  testWidgets('muestra indicadores principales', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('Cobertura'), findsOneWidget);
    expect(find.text('66.7%'), findsOneWidget);
    expect(find.text('Líneas inspeccionadas'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
    expect(find.text('Líneas pendientes'), findsOneWidget);
    expect(find.text('Total inspecciones'), findsOneWidget);
  });

  testWidgets('muestra tarjetas de semáforo', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('Verdes'), findsOneWidget);
    expect(find.text('Amarillas'), findsOneWidget);
    expect(find.text('Rojas'), findsOneWidget);
  });

  testWidgets('muestra lista de prioridad', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.text('Prioridad de inspección'), findsOneWidget);
    expect(find.text('TRONCAL 1 / SUB 1'), findsOneWidget);
    expect(find.text('RAMAL 2'), findsOneWidget);
    expect(find.text('RAMAL 1'), findsOneWidget);
  });

  testWidgets('indica línea nunca inspeccionada', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(find.textContaining('Nunca inspeccionada'), findsOneWidget);
  });

  testWidgets('muestra error sin detalles técnicos', (tester) async {
    final controller = _dashboardController(
      now,
      repository: _FakeDashboardRepository(
        error: Exception('detalle técnico de SQLite'),
      ),
    );

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No se pudo cargar el dashboard. Intente nuevamente más tarde.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('SQLite'), findsNothing);
  });

  testWidgets('permite navegar al dashboard desde inicio', (tester) async {
    final controller = SelectionLineController(
      catalogRepository: _FakeCatalogRepository(_homeCatalog()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SeleccionLineaPage(
          usuario: 'SUPER',
          selectionLineController: controller,
          dashboardController: _dashboardController(now),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('DASHBOARD'));
    await tester.tap(find.text('DASHBOARD'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('muestra estado sin resultados con filtros', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byType(DropdownButtonFormField<DashboardLineTypeFilter>).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Troncal').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Sin resultados para los filtros aplicados'),
      findsOneWidget,
    );
    expect(find.text('Limpiar filtros'), findsOneWidget);
  });

  testWidgets('navega desde dashboard al detalle de prioridad', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ver prioridad completa'));
    await tester.tap(find.text('Ver prioridad completa'));
    await tester.pumpAndSettle();

    expect(find.text('Prioridad de inspección'), findsOneWidget);
    expect(find.text('Buscar línea'), findsOneWidget);
  });

  testWidgets('detalle de prioridad permite búsqueda por línea', (
    tester,
  ) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver prioridad completa'));
    await tester.tap(find.text('Ver prioridad completa'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'RAMAL 2');
    await tester.pumpAndSettle();

    expect(find.text('RAMAL 2'), findsWidgets);
    expect(find.text('RAMAL 1'), findsNothing);
  });

  testWidgets('detalle de hallazgos muestra total y categorías', (
    tester,
  ) async {
    final controller = _dashboardController(now);

    await tester.pumpWidget(
      MaterialApp(home: DashboardFindingsDetailPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total filtrado: 3'), findsOneWidget);
    expect(find.text('Fuga: 2'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.textContaining('Descripci'), findsWidgets);
  });

  testWidgets('navega desde dashboard al detalle de hallazgos', (tester) async {
    final controller = _dashboardController(now);

    await _pumpDashboard(tester, controller);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ver detalle de hallazgos'));
    await tester.tap(find.text('Ver detalle de hallazgos'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle de hallazgos'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  DashboardController controller,
) {
  return tester.pumpWidget(
    MaterialApp(home: DashboardPage(controller: controller)),
  );
}

DashboardController _dashboardController(
  DateTime now, {
  _FakeDashboardRepository? repository,
}) {
  return DashboardController(
    repository: repository ?? _FakeDashboardRepository(catalog: _catalog()),
    clock: () => now,
  );
}

CatalogData _catalog() {
  return const CatalogData(
    troncalesJson: {
      'TRONCAL 1': ['SUB 1'],
    },
    ramalesJson: ['RAMAL 1', 'RAMAL 2'],
  );
}

CatalogData _homeCatalog() {
  return const CatalogData(
    troncalesJson: {
      'TRONCAL 1': ['TRONCAL 1'],
    },
    ramalesJson: ['RAMAL 1'],
  );
}

class _FakeCatalogRepository implements CatalogRepository {
  final CatalogData? catalog;

  const _FakeCatalogRepository(this.catalog);

  @override
  Future<CatalogData?> cargarCatalogos() async {
    return catalog;
  }
}

class _FakeDashboardRepository extends DashboardRepository {
  final CatalogData? catalog;
  final Future<CatalogData?>? catalogFuture;
  final List<DashboardInspectionRecord>? inspections;
  final List<DashboardFindingRecord>? findings;
  final Object? error;

  _FakeDashboardRepository({
    this.catalog,
    this.catalogFuture,
    this.inspections,
    this.findings,
    this.error,
  });

  @override
  Future<CatalogData?> loadCatalog() async {
    if (error != null) throw error!;
    if (catalogFuture != null) return catalogFuture!;
    return catalog;
  }

  @override
  Future<List<DashboardFindingRecord>> loadValidFindings() async {
    return findings ??
        const [
          DashboardFindingRecord(
            id: 'finding-1',
            inspectionId: 'inspection-1',
            category: 'Fuga',
            lineName: 'RAMAL 1',
            tipoLinea: 'Ramal',
            responsible: 'Ana',
            description: 'Fuga visible',
          ),
          DashboardFindingRecord(
            id: 'finding-2',
            inspectionId: 'inspection-1',
            category: 'Fuga',
            lineName: 'RAMAL 1',
            tipoLinea: 'Ramal',
            responsible: 'Ana',
            description: 'Fuga menor',
          ),
          DashboardFindingRecord(
            id: 'finding-3',
            inspectionId: 'inspection-2',
            category: 'Vegetación',
            lineName: 'RAMAL 2',
            tipoLinea: 'Ramal',
            responsible: 'Luis',
            description: 'Vegetación cercana',
          ),
        ];
  }

  @override
  Future<List<DashboardInspectionRecord>> loadValidInspections() async {
    return inspections ??
        [
          DashboardInspectionRecord(
            id: 'inspection-1',
            lineName: 'RAMAL 1',
            tipoLinea: 'Ramal',
            responsible: 'Ana',
            date: DateTime(2026, 2, 20),
          ),
          DashboardInspectionRecord(
            id: 'inspection-2',
            lineName: 'RAMAL 2',
            tipoLinea: 'Ramal',
            responsible: 'Luis',
            date: DateTime(2026, 2, 1),
          ),
        ];
  }

  @override
  Future<int> countInvalidRecords() async {
    return 0;
  }
}
