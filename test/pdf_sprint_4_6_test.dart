import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/services/findings_map_service.dart';
import 'package:linerb/services/inspection_pdf_service.dart';
import 'package:linerb/services/pdf_font_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Presentación PDF Sprint 4.6', () {
    test('carga fuentes Unicode y genera PDF mínimo', () async {
      final fonts = await _testFontProvider().load().timeout(
        const Duration(seconds: 5),
      );
      final document = pw.Document();
      document.addPage(
        pw.Page(
          theme: fonts.theme,
          build: (context) {
            return pw.Text(
              'INFORMACIÓN, UBICACIÓN, VÁLVULAS, DESCRIPCIÓN, LÍNEA, '
              'NIÑO, CAÑERÍA, OPERACIÓN, ¿válido? ¡Sí!',
            );
          },
        ),
      );

      final bytes = await document.save().timeout(const Duration(seconds: 5));

      _expectPdf(bytes);
    });

    test('títulos principales no tienen prefijo numérico', () {
      expect(InspectionPdfText.informationTitle, 'INFORMACIÓN GENERAL');
      expect(InspectionPdfText.findingsTitle, 'HALLAZGOS OPERATIVOS');
      expect(InspectionPdfText.informationTitle, isNot(startsWith('1.')));
      expect(InspectionPdfText.findingsTitle, isNot(startsWith('2.')));
    });

    test(
      'subtítulos de información general están definidos como etiquetas',
      () {
        expect(
          InspectionPdfText.generalLabels,
          containsAll([
            'Fecha:',
            'Responsable:',
            'Usuario:',
            'Tipo de línea:',
            'Línea:',
            'Punto de referencia:',
            'Estado operativo:',
            'Total hallazgos:',
          ]),
        );
        expect(
          InspectionPdfText.generalLabels,
          isNot(contains('Esado operativo')),
        );
        expect(
          InspectionPdfText.generalLabels,
          isNot(contains('Tipo de Linea')),
        );
        expect(InspectionPdfText.generalLabels, isNot(contains('Informacion')));
      },
    );

    test('subtítulos de hallazgo están definidos con tildes correctas', () {
      expect(InspectionPdfText.findingLabels, [
        'Latitud:',
        'Longitud:',
        'Descripción:',
      ]);
    });

    test('formatea título de hallazgo con número, categoría y estado', () {
      final title = InspectionPdfFormatter.findingTitle(
        1,
        _finding(tipo: 'Válvulas', detalle: 'No operativa'),
      );

      expect(title.prefix, '1.');
      expect(title.category, 'VÁLVULAS');
      expect(title.state, 'No operativa');
      expect(title.plainText, '1. VÁLVULAS - No operativa');
    });

    test('mantiene numeración continua de hallazgos', () {
      final titles = [
        for (var index = 0; index < 15; index++)
          InspectionPdfFormatter.findingTitle(
            index + 1,
            _finding(tipo: 'Vegetación', detalle: 'Mal estado'),
          ).plainText,
      ];

      expect(titles.first, '1. VEGETACIÓN - Mal estado');
      expect(titles[8], '9. VEGETACIÓN - Mal estado');
      expect(titles[9], '10. VEGETACIÓN - Mal estado');
      expect(titles.last, '15. VEGETACIÓN - Mal estado');
    });

    test('constantes de zona segura y fotos respetan límite inferior', () {
      expect(InspectionPdfService.safeFooterHeight, greaterThanOrEqualTo(90));
      expect(InspectionPdfService.photoWidth, 180);
      expect(InspectionPdfService.photoHeight, 130);
    });

    test('textos fuente conservan Unicode español sin mojibake', () {
      final sourceTexts = [
        InspectionPdfText.informationTitle,
        InspectionPdfText.findingsTitle,
        InspectionPdfText.mapTitle,
        InspectionPdfText.noValidCoordinates,
        InspectionPdfText.mapUnavailable,
        ...InspectionPdfText.generalLabels,
        ...InspectionPdfText.findingLabels,
        InspectionPdfFormatter.findingTitle(
          1,
          _finding(tipo: 'Válvulas', detalle: 'No operativa'),
        ).plainText,
        InspectionPdfFormatter.findingTitle(
          2,
          _finding(tipo: 'Vegetación', detalle: 'Mal estado'),
        ).plainText,
        InspectionPdfFormatter.findingTitle(
          3,
          _finding(tipo: 'Soportería', detalle: 'Operativa'),
        ).plainText,
        'Operación, ubicación, número, línea, ¿inspección válida? ¡Sí!',
      ].join('\n');

      expect(sourceTexts, contains('INFORMACIÓN GENERAL'));
      expect(sourceTexts, contains('MAPA DE UBICACIÓN DE HALLAZGOS'));
      expect(sourceTexts, contains('VÁLVULAS'));
      expect(sourceTexts, contains('VEGETACIÓN'));
      expect(sourceTexts, contains('SOPORTERÍA'));
      expect(sourceTexts, contains('Descripción:'));
      expect(sourceTexts, isNot(contains('\u00c3')));
      expect(sourceTexts, isNot(contains('\u00c2')));
      expect(sourceTexts, isNot(contains('\ufffd')));
    });

    test('proveedor de fuentes Unicode usa Roboto regular y bold', () {
      expect(
        PdfFontProvider.regularAssetPath,
        'assets/fonts/Roboto-Regular.ttf',
      );
      expect(PdfFontProvider.boldAssetPath, 'assets/fonts/Roboto-Bold.ttf');
    });
  });

  group('Generación PDF Sprint 4.6', () {
    test('genera informe de 1 hallazgo sin fotos', () async {
      final bytes = await _service().buildPdf(
        _data([_finding(tipo: 'Fuga', detalle: 'Activa')]),
      );

      _expectPdf(bytes);
    });

    test('genera informe de 1 hallazgo con 1 foto', () async {
      final bytes = await _service(
        photoPaths: ['assets/logo_linerb.png'],
      ).buildPdf(_data([_finding(tipo: 'Fuga', detalle: 'Activa')]));

      _expectPdf(bytes);
    });

    test('genera informe de 1 hallazgo con 2 fotos', () async {
      final bytes = await _service(
        photoPaths: ['assets/logo_linerb.png', 'assets/footer_linerb.png'],
      ).buildPdf(_data([_finding(tipo: 'Soportería', detalle: 'Operativa')]));

      _expectPdf(bytes);
    });

    test('genera informe de 2 hallazgos', () async {
      final bytes = await _service().buildPdf(_data(_manyFindings(2)));

      _expectPdf(bytes);
    });

    test('genera informe de 5 hallazgos con descripciones cortas', () async {
      final bytes = await _service().buildPdf(_data(_manyFindings(5)));

      _expectPdf(bytes);
    });

    test('genera informe de 10 hallazgos con numeración continua', () async {
      final bytes = await _service().buildPdf(_data(_manyFindings(10)));

      _expectPdf(bytes);
    });

    test('genera informe de 15 hallazgos con descripciones largas', () async {
      final bytes = await _service().buildPdf(
        _data(
          _manyFindings(
            15,
            description:
                'Descripción larga del hallazgo operativo con información de contexto '
                'para validar que el bloque conserva título, coordenadas y fotografías '
                'sin invadir el pie de página reservado. ',
          ),
        ),
      );

      _expectPdf(bytes);
    });

    test('genera PDF aunque el mapa no esté disponible', () async {
      final bytes = await _service(
        mapResult: const FindingsMapImageResult.failure(
          FindingsMapFailure.timeout,
        ),
      ).buildPdf(_data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]));

      _expectPdf(bytes);
    });

    test('genera página de mapa con bytes PNG válidos', () async {
      final bytes = await _service(
        mapBytes: _validPngBytes,
      ).buildPdf(_data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]));

      _expectPdf(bytes);
    });

    test(
      'genera página de mapa con bytes JPEG válidos si el decoder lo soporta',
      () async {
        final bytes = await _service(mapBytes: _validJpegBytes).buildPdf(
          _data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]),
        );

        _expectPdf(bytes);
      },
    );

    test('mapa null genera fallback sin romper el PDF', () async {
      final bytes = await _service(
        returnNullMapProvider: true,
      ).buildPdf(_data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]));

      _expectPdf(bytes);
    });

    test('excepción del proveedor genera fallback sin romper el PDF', () async {
      final bytes = await _service(
        throwMapProvider: true,
      ).buildPdf(_data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]));

      _expectPdf(bytes);
    });

    test(
      'bytes corruptos del mapa generan fallback sin lanzar excepción',
      () async {
        final bytes = await _service(mapBytes: Uint8List.fromList([1, 2, 3]))
            .buildPdf(
              _data([_finding(tipo: 'Válvulas', detalle: 'No operativa')]),
            );

        _expectPdf(bytes);
      },
    );

    test(
      'genera PDF con mensaje controlado cuando no hay coordenadas válidas',
      () async {
        final bytes = await _service().buildPdf(
          _data([
            _finding(
              tipo: 'Vegetación',
              detalle: 'Mal estado',
              lat: '',
              lon: '',
            ),
          ]),
        );

        _expectPdf(bytes);
      },
    );

    test('genera PDF con textos largos Unicode del usuario', () async {
      final bytes = await _service().buildPdf(
        _data([
          _finding(
            tipo: 'Válvulas',
            detalle: 'Operación crítica',
            description:
                'Válvula número 3 en condición crítica. Tubería con corrosión '
                'y pérdida de recubrimiento. Inspección realizada en línea de '
                'producción. Señalización y vegetación en área húmeda. Niño, '
                'cañería, operación, ubicación. ¿Requiere acción? ¡Sí!',
          ),
        ]),
      );

      _expectPdf(bytes);
    });

    test('layout de mapa mantiene 3 hallazgos en una sola página', () {
      final layout = InspectionPdfService.planMapLayout(3);

      expect(layout.requiresContinuation, isFalse);
      expect(layout.firstPageLegendCapacity, greaterThanOrEqualTo(3));
      expect(layout.legendColumns, 2);
      expect(layout.estimatedContentHeight, lessThan(_mapPageHeightLimit));
    });

    test('layout de mapa evita página adicional con 5 hallazgos', () {
      final layout = InspectionPdfService.planMapLayout(5);

      expect(layout.requiresContinuation, isFalse);
      expect(layout.firstPageLegendCapacity, greaterThanOrEqualTo(5));
      expect(layout.legendColumns, 2);
      expect(layout.estimatedContentHeight, lessThan(_mapPageHeightLimit));
    });

    test('layout de mapa distribuye 10 y 15 hallazgos en columnas', () {
      final tenFindings = InspectionPdfService.planMapLayout(10);
      final fifteenFindings = InspectionPdfService.planMapLayout(15);

      expect(tenFindings.requiresContinuation, isFalse);
      expect(fifteenFindings.requiresContinuation, isFalse);
      expect(tenFindings.legendColumns, 3);
      expect(fifteenFindings.legendColumns, 3);
      expect(fifteenFindings.firstPageLegendCapacity, greaterThanOrEqualTo(15));
    });

    test('layout de mapa reduce altura cuando crece la leyenda', () {
      final shortLegend = InspectionPdfService.planMapLayout(3);
      final longLegend = InspectionPdfService.planMapLayout(15);

      expect(longLegend.mapHeight, lessThan(shortLegend.mapHeight));
      expect(
        longLegend.mapHeight,
        greaterThanOrEqualTo(InspectionPdfService.mapMinHeight),
      );
      expect(
        shortLegend.mapHeight,
        lessThanOrEqualTo(InspectionPdfService.mapMaxHeight),
      );
    });

    test(
      'layout de mapa reserva espacio para footer y rosa de los vientos',
      () {
        final layout = InspectionPdfService.planMapLayout(15);

        expect(layout.estimatedContentHeight, lessThan(_mapPageHeightLimit));
        expect(layout.compassSize, greaterThan(0));
        expect(layout.verticalGap, greaterThan(0));
      },
    );

    test('layout de mapa conserva numeración completa de leyenda', () {
      final layout = InspectionPdfService.planMapLayout(15);
      final visibleNumbers = _manyFindings(15)
          .asMap()
          .keys
          .map((index) => index + 1)
          .take(layout.firstPageLegendCapacity)
          .toList();

      expect(
        visibleNumbers,
        containsAll(List.generate(15, (index) => index + 1)),
      );
    });

    test('genera artefactos visuales de validación en build', () async {
      final outputDir = Directory('build/sprint_4_6_pdf_validation');
      await outputDir.create(recursive: true);

      final scenarios = {
        'informe_corto.pdf': _data([_finding(tipo: 'Fuga', detalle: 'Activa')]),
        'informe_medio.pdf': _data(_manyFindings(5)),
        'informe_3_hallazgos.pdf': _data(_manyFindings(3)),
        'informe_15_hallazgos.pdf': _data(_manyFindings(15)),
        'informe_dos_fotos_por_hallazgo.pdf': _data(_manyFindings(3)),
        'informe_con_mapa.pdf': _data(_manyFindings(3)),
        'informe_sin_mapa_disponible.pdf': _data(_manyFindings(3)),
      };

      for (final entry in scenarios.entries) {
        final unavailable = entry.key.contains('sin_mapa');
        final service = _service(
          photoPaths: entry.key.contains('dos_fotos')
              ? ['assets/logo_linerb.png', 'assets/footer_linerb.png']
              : const [],
          mapResult: unavailable
              ? const FindingsMapImageResult.failure(FindingsMapFailure.timeout)
              : null,
        );
        final bytes = await service.buildPdf(entry.value);
        _expectPdf(bytes);
        await File('${outputDir.path}/${entry.key}').writeAsBytes(bytes);
      }

      expect(
        await outputDir
            .list()
            .where((entity) => entity.path.endsWith('.pdf'))
            .length,
        7,
      );
    });
  });
}

InspectionPdfService _service({
  List<String> photoPaths = const [],
  Uint8List? mapBytes,
  FindingsMapImageResult? mapResult,
  bool throwMapProvider = false,
  bool returnNullMapProvider = false,
}) {
  return InspectionPdfService(
    loadAsset: (assetPath) => File(assetPath).readAsBytes(),
    photoPathResolver: (_) async => photoPaths,
    mapImageProvider: returnNullMapProvider
        ? _NullMapProvider()
        : throwMapProvider
        ? _ThrowingMapProvider()
        : _FakeMapProvider(
            mapResult ??
                FindingsMapImageResult.success(
                  mapBytes ?? _satelliteMapPngBytes,
                  Uri.parse('https://maps.googleapis.com/maps/api/staticmap'),
                ),
          ),
    fontProvider: PdfFontProvider(loadFontAsset: _loadTestFontAsset),
  );
}

PdfFontProvider _testFontProvider() {
  return PdfFontProvider(loadFontAsset: _loadTestFontAsset);
}

Future<ByteData> _loadTestFontAsset(String assetPath) async {
  final bytes = await File(assetPath).readAsBytes();
  return ByteData.sublistView(bytes);
}

InspectionPdfData _data(List<HallazgoInspeccion> findings) {
  return InspectionPdfData(
    usuario: 'inspector@linerb.local',
    tipoLinea: 'Troncal',
    seleccionLinea: 'TRONCAL 1 / SUB-TRONCAL 1A',
    responsable: 'Responsable operativo',
    estadoLinea: 'Operativa',
    puntoReferencia: 'PR-001',
    observaciones: 'Observación general de prueba',
    hallazgos: findings,
    generatedAt: DateTime(2026, 7, 26, 10, 30),
  );
}

List<HallazgoInspeccion> _manyFindings(
  int count, {
  String description = 'Descripción de prueba',
}) {
  return [
    for (var index = 1; index <= count; index++)
      _finding(
        tipo: index.isEven ? 'Vegetación' : 'Válvulas',
        detalle: index.isEven ? 'Mal estado' : 'No operativa',
        lat: (3.70 + (index / 1000)).toStringAsFixed(5),
        lon: (-71.38 - (index / 1000)).toStringAsFixed(7),
        description: '$description #$index',
      ),
  ];
}

HallazgoInspeccion _finding({
  required String tipo,
  required String detalle,
  String lat = '3.74751',
  String lon = '-71.3826883',
  String description = 'Descripción de prueba',
}) {
  return HallazgoInspeccion(
    tipo: tipo,
    detalle: detalle,
    latitud: lat,
    longitud: lon,
    descripcion: description,
  );
}

void _expectPdf(Uint8List bytes) {
  expect(bytes.length, greaterThan(1000));
  expect(String.fromCharCodes(bytes.take(4)), '%PDF');
}

double get _mapPageHeightLimit {
  return PdfPageFormat.a4.height -
      InspectionPdfService.topMargin -
      InspectionPdfService.safeFooterHeight;
}

class _FakeMapProvider implements FindingsMapImageProvider {
  final FindingsMapImageResult result;

  _FakeMapProvider(this.result);

  @override
  Future<FindingsMapImageResult> loadMap(FindingsMapRequest request) async {
    if (request.validPoints.isEmpty) {
      return const FindingsMapImageResult.failure(
        FindingsMapFailure.noValidCoordinates,
      );
    }
    return result;
  }
}

class _NullMapProvider implements FindingsMapImageProvider {
  @override
  Future<FindingsMapImageResult?> loadMap(FindingsMapRequest request) async {
    return null;
  }
}

class _ThrowingMapProvider implements FindingsMapImageProvider {
  @override
  Future<FindingsMapImageResult> loadMap(FindingsMapRequest request) async {
    throw StateError('map provider unavailable');
  }
}

Uint8List get _validPngBytes => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);

Uint8List get _satelliteMapPngBytes => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAGQAAACMCAIAAAAFl5vsAAAHdklEQVR42u2dW2wUVRiA/z07SyxQSrlar4ChKDEKtYmhtbVO6QYlMaHhajQ1MdEQH/FBotmQDYnxwfhkmvBkDd6wYlJfmt12UhZpH4SFEINaYkVFsQW6ctGi3e76cLbT6e7s7uzMuc2ZOdmH6ezOXr79/v/8c87saeDx7ZuheHvv1W14Q/sqAQDqjlYAOHCkHyi0uxYFbRw1NV1H9m280LoGb3ySuJR3Fyp9pCkXnSD3RpxU6YYsPg47hf2SuJXQyhIsYeVirFUFZokmF3tSVmEJnrlENEscuShpVTphVQDLl6tis7zTLTqFJYhctFN7sRi0Y5ascukJi1gYejxzIXuH8ZKLS3llH5aUcpUtGhyZ5c1u0Q4sz2Yu5ORgr8llE5ZMcllMWE7N8ppc9mF5MHMh50/harmsx6BTWKZy9byxQ1azFCLPou5ojR3TYse08G712s0p6wcuXblg7nuz8MUthIkbt1aTjKzZF1WUAPUwPHCkf8WSKgBQQooSUuTOXARyFlbJjZlr71MP4o3PvvmFESzG3WJN9biLzfJOzUUGlqtrLosxSNgsZnIRiUQ9YXEIQ0pXi0gYhlDuIhw50jx5WMzSvBNelRYN5GFJf2pNJQxdIRd/WOzlYsmLVoJnWaBWystewqICi0vmqojX2lWL8U2g0oHx2Y91Xj9P3MY3IWDxKlBp5y/E7JOwqSFqqsdLI7OdsKjD4jUOQUkxWrC4F6hlFRMxDPkOcpFFRhGWOGc/pJCxSPBGufDsBkfLQsod4DsVVkIurFJ6Og2zsxvJ3uF5KPe3MeP1/BOPAUBIudN35nxNdW6nlbk1LKZC+/2tWFJ17eaUPkumhiNj4cb/0jP4z0AgoA0mWfJy0nVSD0PjRBkmlfeA0fYGrXvIHymdl+YPdw9cbG/A2wuUoBt5IcavNzOTAfAH/yqsIR4Z/p7xR8XZHQD6zpx3gVnBINLl+qn1Ud8smSfK2JmlxaLrYqeNe/Q0X8+7ehAxDLVYdP1gMi/Nu4UUi6I0r5rXYlF1MGnc/4xLSDGFZfRLXyUiGAS3dIWsw9A0zR/aqfoJXsIruVjDcnUNgUR4E26JRG6wcCTGexNuye58YLk3zfMMQ5ZyuRiWqVyRTtWHVap17JyTq3ZRleCwFHvroTlvb30cf+fFDjDMZaT+nop0qtHjmm+WSVtWXQUAz+5TlZBCL3OR6go5w3qtu89dmUuIotSYufxRh6ItelwrVMmYuQY+GDLetfX1Nu/CMsoV703EexPYMp3U6OzsWW7PYJIjL/5haNr9RTrVQlIAMNrekOcas+wuSs4qzFxPt0cKSdnjJVuCN5UrFBToixTOrBLd4sOnLviwrMr1Q/NGaWEd2tvuUC4xW+DJ3Y32jnxZbSh215pVtZcmUsY9H2pJ00cuXBw0Ld/jvYnD3QP4+qTp+deS1FuuHsh2heXrrBJEnJAtxs5Yo769f+vh2OmxcGMoiHRe9VzrLMUJkWKfuSxxfU9QCQDAp8PnTGtUzAsAsrYq+PuX1xKGVZaURSLWn6HwFfc1bdK3L/45uf7uZfqfJwajJXqA0u236ykqpzvOidhjt3Bx0EhqthNUAOC5Per45auTV1LL6moBXJ7gibS8BK9btvHeVQAwfvkqAKy+byW+68LvEw8sX/ru10NcsruIsPK6xckrKZ0XhvXr9b+sPPM9tTV444/UjWKPKcyVroSl88LVvF58/TudIQjLrUM0FoduLMaglTAszJUuhlV2XNBhqzQGhTuRFnzQmbNZ/9yeKXHvmx/lpstwy2YAAN5/abvpTIex7WreNJPOAsAXp86BrEM0xdrWztb0dLr/cw0AJm9NgT+eZdoOHo3j6cVte1T911JG3XxYUGx6ceB4wh/8sxqM+jYXudwB6+DRuHW5djXnCiiy2d1lZnGXCxX/fWfIyk1MuVjAskGBPTiOciHjBwanPzamS427XIjGZ6NNjZdciPIP2wkjKysXva6QUW9IQzEuciFWaycQU4xj5kJsl5sIuVouxHx5DgKK8ZJL4bSiSejGrWkicmFYbR2RkY6Ivn9LV4tUg38OeR08Ojcu2NaRW7Ulk8lNXQ8PnGmiwAtxXTGHQAozrtqCUO6fdvyobh7uOUn8DQfCr2zhe27sxK+RnpNj4Ub8W368wgaWK53JAMAG7SxZv/iPOjj3K2i4oFKXy+uDf4UtC/OWBHoo8Z2ulbSwiMiFUACvb5O33pSEZtnmpS/yBgDZbNYfVi7amrpaNmhn9RXxYG6VG4V4dhcLlj25mrpa1hrWA8JyrYt9eyIelfa3O04q1aaulpH56ycNUSAlRJ1FpOza1bypYV0dAAx8qRnPsY1nkRLmLIc9I8ZE6eza3Qne2JJjVwp3kh26kQcWA7lEhGU7EmnLJYNZhZMUlOSSLQxNuz9SckmYs+jJJSgsJwUEPbmkNYuGXHLCoiQXkq8rpCeXtGFIQy6ZcxZxuWSGRVwu+c0qlMs2LyRxdjfKRSQY5TeLYDB6IgxJySUoLCLX2BCXy0NmOZfLK7CIyIUk7gqJy4WkT1gE5fofBcZPp2N+biEAAAAASUVORK5CYII=',
);

Uint8List get _validJpegBytes => base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDi6KKK+ZP3E//Z',
);
