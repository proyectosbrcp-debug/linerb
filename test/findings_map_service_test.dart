import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:linerb/models/hallazgo_inspeccion.dart';
import 'package:linerb/services/findings_map_service.dart';

void main() {
  group('FindingsMapService Sprint 4.6', () {
    test('construye puntos en el mismo orden de los hallazgos', () {
      final points = FindingsMapService.buildPoints([
        _finding('Válvulas', '3.1', '-71.1'),
        _finding('Vegetación', '3.2', '-71.2'),
      ]);

      expect(points.map((point) => point.number), [1, 2]);
      expect(points.first.categoryLabel, 'VÁLVULAS');
      expect(points.last.categoryLabel, 'VEGETACIÓN');
    });

    test('valida coordenadas numéricas y descarta inválidas', () {
      expect(FindingsMapService.parseLatitude('3.74751'), 3.74751);
      expect(FindingsMapService.parseLongitude('-71.3826883'), -71.3826883);
      expect(FindingsMapService.parseLatitude('91'), isNull);
      expect(FindingsMapService.parseLongitude('-181'), isNull);
      expect(FindingsMapService.parseLatitude(''), isNull);
      expect(FindingsMapService.parseLatitude('NaN'), isNull);
      expect(FindingsMapService.parseLatitude('Infinity'), isNull);
    });

    test('leyenda marca hallazgo sin coordenadas como Sin coordenadas', () {
      final point = FindingsMapService.buildPoints([
        _finding('Fuga', '', ''),
      ]).single;

      expect(point.hasValidCoordinates, isFalse);
      expect(FindingsMapService.legendCoordinateText(point), 'Sin coordenadas');
    });

    test('calcula viewport para un punto', () {
      final viewport = FindingsMapService.calculateViewport([
        MapFindingPoint(
          number: 1,
          category: 'Válvulas',
          latitudeText: '3.74751',
          longitudeText: '-71.3826883',
          latitude: 3.74751,
          longitude: -71.3826883,
        ),
      ]);

      expect(viewport.centerLatitude, closeTo(3.74751, 0.00001));
      expect(viewport.centerLongitude, closeTo(-71.3826883, 0.00001));
      expect(viewport.zoom, inInclusiveRange(3, 18));
    });

    test('calcula viewport para línea vertical', () {
      final viewport = FindingsMapService.calculateViewport([
        _point(1, 3.0, -71.0),
        _point(2, 3.5, -71.0),
      ]);

      expect(viewport.centerLatitude, closeTo(3.25, 0.00001));
      expect(viewport.centerLongitude, closeTo(-71.0, 0.00001));
      expect(viewport.zoom, inInclusiveRange(3, 18));
    });

    test('calcula viewport para línea horizontal', () {
      final viewport = FindingsMapService.calculateViewport([
        _point(1, 3.0, -71.5),
        _point(2, 3.0, -70.5),
      ]);

      expect(viewport.centerLatitude, closeTo(3.0, 0.00001));
      expect(viewport.centerLongitude, closeTo(-71.0, 0.00001));
      expect(viewport.zoom, inInclusiveRange(3, 18));
    });

    test('calcula viewport para línea diagonal', () {
      final viewport = FindingsMapService.calculateViewport([
        _point(1, 3.0, -71.5),
        _point(2, 3.8, -70.7),
      ]);

      expect(viewport.centerLatitude, closeTo(3.4, 0.00001));
      expect(viewport.centerLongitude, closeTo(-71.1, 0.00001));
      expect(viewport.zoom, inInclusiveRange(3, 18));
    });

    test('URL usa HTTPS, mapa híbrido vertical y marcadores numerados', () {
      final request = FindingsMapRequest(
        points: [_point(1, 3.1, -71.1), _point(2, 3.2, -71.2)],
      );
      final uri = FindingsMapService.buildStaticMapUri(
        request: request,
        apiKey: 'test-key',
      );
      final text = Uri.decodeFull(uri.toString());

      expect(uri.scheme, 'https');
      expect(uri.host, 'maps.googleapis.com');
      expect(text, contains('maptype=hybrid'));
      expect(text, contains('size=640x900'));
      expect(text, contains('markers=color:red|label:1|3.1,-71.1'));
      expect(text, contains('markers=color:red|label:2|3.2,-71.2'));
      expect(text.indexOf('|label:1|'), lessThan(text.indexOf('|label:2|')));
    });

    test('más de 9 hallazgos no omite marcadores', () {
      final points = [
        for (var index = 1; index <= 12; index++)
          _point(index, 3 + (index / 100), -71 - (index / 100)),
      ];
      final uri = FindingsMapService.buildStaticMapUri(
        request: FindingsMapRequest(points: points),
        apiKey: 'test-key',
      );
      final text = Uri.decodeFull(uri.toString());

      expect('markers='.allMatches(text), hasLength(12));
      expect(text, contains('|label:9|'));
      expect(text, isNot(contains('|label:10|')));
      expect(text, contains('3.12,-71.12'));
    });

    test('URL no incluye datos privados del informe', () {
      final uri = FindingsMapService.buildStaticMapUri(
        request: FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
        apiKey: 'test-key',
      );
      final text = Uri.decodeFull(uri.toString());

      expect(text, isNot(contains('responsable')));
      expect(text, isNot(contains('usuario')));
      expect(text, isNot(contains('descripcion')));
      expect(text, isNot(contains('foto')));
      expect(text, isNot(contains('pdf')));
    });
  });

  group('GoogleStaticFindingsMapImageProvider Sprint 4.6', () {
    test('no llama red cuando no hay API key', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) {
          throw StateError('No debe llamar HTTP sin API key');
        }),
        apiKey: '',
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.failure, FindingsMapFailure.noApiKey);
      expect(result.bytes, isNull);
    });

    test(
      'no llama red cuando todos los hallazgos no tienen coordenadas',
      () async {
        final provider = GoogleStaticFindingsMapImageProvider(
          client: _FakeHttpClient((request) {
            throw StateError('No debe llamar HTTP sin coordenadas');
          }),
          apiKey: 'test-key',
        );

        final result = await provider.loadMap(
          FindingsMapRequest(
            points: FindingsMapService.buildPoints([_finding('Fuga', '', '')]),
          ),
        );

        expect(result.failure, FindingsMapFailure.noValidCoordinates);
      },
    );

    test('devuelve bytes cuando HTTP responde imagen válida', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) async {
          return _response(_validPngBytes, contentType: 'image/png');
        }),
        apiKey: 'test-key',
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.hasImage, isTrue);
      expect(result.bytes, _validPngBytes);
    });

    test('clasifica error HTTP', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) async {
          return _response([], statusCode: 403, contentType: 'text/plain');
        }),
        apiKey: 'test-key',
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.failure, FindingsMapFailure.httpError);
    });

    test('clasifica respuesta no imagen', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) async {
          return _response([1, 2, 3], contentType: 'application/json');
        }),
        apiKey: 'test-key',
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.failure, FindingsMapFailure.notImage);
    });

    test('clasifica timeout', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) => Completer<http.Response>().future),
        apiKey: 'test-key',
        timeout: const Duration(milliseconds: 1),
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.failure, FindingsMapFailure.timeout);
    });

    test('clasifica fallo de red', () async {
      final provider = GoogleStaticFindingsMapImageProvider(
        client: _FakeHttpClient((request) async {
          throw http.ClientException('offline');
        }),
        apiKey: 'test-key',
      );

      final result = await provider.loadMap(
        FindingsMapRequest(points: [_point(1, 3.1, -71.1)]),
      );

      expect(result.failure, FindingsMapFailure.networkError);
    });
  });
}

HallazgoInspeccion _finding(String tipo, String latitud, String longitud) {
  return HallazgoInspeccion(
    tipo: tipo,
    detalle: 'No operativa',
    latitud: latitud,
    longitud: longitud,
    descripcion: 'Descripción de prueba',
  );
}

MapFindingPoint _point(int number, double latitude, double longitude) {
  return MapFindingPoint(
    number: number,
    category: 'Válvulas',
    latitudeText: latitude.toString(),
    longitudeText: longitude.toString(),
    latitude: latitude,
    longitude: longitude,
  );
}

http.Response _response(
  List<int> bytes, {
  int statusCode = 200,
  required String contentType,
}) {
  return http.Response.bytes(
    bytes,
    statusCode,
    headers: {'content-type': contentType},
  );
}

class _FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;

  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      http.ByteStream.fromBytes(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

Uint8List get _validPngBytes => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
);
