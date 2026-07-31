import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/hallazgo_inspeccion.dart';

enum FindingsMapFailure {
  none,
  noApiKey,
  noValidCoordinates,
  timeout,
  httpError,
  notImage,
  networkError,
  providerException,
}

class MapFindingPoint {
  final int number;
  final String category;
  final String latitudeText;
  final String longitudeText;
  final double? latitude;
  final double? longitude;

  const MapFindingPoint({
    required this.number,
    required this.category,
    required this.latitudeText,
    required this.longitudeText,
    required this.latitude,
    required this.longitude,
  });

  bool get hasValidCoordinates => latitude != null && longitude != null;

  String get categoryLabel => category.trim().toUpperCase();

  static MapFindingPoint fromFinding(int number, HallazgoInspeccion finding) {
    return MapFindingPoint(
      number: number,
      category: finding.tipo,
      latitudeText: finding.latitud,
      longitudeText: finding.longitud,
      latitude: FindingsMapService.parseLatitude(finding.latitud),
      longitude: FindingsMapService.parseLongitude(finding.longitud),
    );
  }
}

class FindingsMapViewport {
  final double centerLatitude;
  final double centerLongitude;
  final int zoom;

  const FindingsMapViewport({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.zoom,
  });
}

class FindingsMapRequest {
  final List<MapFindingPoint> points;
  final int width;
  final int height;
  final String mapType;

  const FindingsMapRequest({
    required this.points,
    this.width = 640,
    this.height = 900,
    this.mapType = 'hybrid',
  });

  List<MapFindingPoint> get validPoints {
    return points.where((point) => point.hasValidCoordinates).toList();
  }
}

class FindingsMapImageResult {
  final Uint8List? bytes;
  final FindingsMapFailure failure;
  final Uri? requestUri;

  const FindingsMapImageResult._({
    required this.bytes,
    required this.failure,
    this.requestUri,
  });

  const FindingsMapImageResult.success(Uint8List bytes, Uri requestUri)
    : this._(
        bytes: bytes,
        failure: FindingsMapFailure.none,
        requestUri: requestUri,
      );

  const FindingsMapImageResult.failure(FindingsMapFailure failure, [Uri? uri])
    : this._(bytes: null, failure: failure, requestUri: uri);

  bool get hasImage => bytes != null && failure == FindingsMapFailure.none;
}

abstract interface class FindingsMapImageProvider {
  /// Returns valid image bytes when a map is available.
  ///
  /// Implementations may also return null, a failure result with null bytes
  /// when the map is unavailable, or throw if an unexpected technical failure
  /// occurs. Consumers must tolerate null, null bytes, categorized failures and
  /// exceptions.
  Future<FindingsMapImageResult?> loadMap(FindingsMapRequest request);
}

class GoogleStaticFindingsMapImageProvider implements FindingsMapImageProvider {
  final http.Client _client;
  final String apiKey;
  final Duration timeout;

  GoogleStaticFindingsMapImageProvider({
    http.Client? client,
    this.apiKey = const String.fromEnvironment('GOOGLE_MAPS_STATIC_API_KEY'),
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  @override
  Future<FindingsMapImageResult> loadMap(FindingsMapRequest request) async {
    if (request.validPoints.isEmpty) {
      return const FindingsMapImageResult.failure(
        FindingsMapFailure.noValidCoordinates,
      );
    }

    if (apiKey.trim().isEmpty) {
      return const FindingsMapImageResult.failure(FindingsMapFailure.noApiKey);
    }

    final uri = FindingsMapService.buildStaticMapUri(
      request: request,
      apiKey: apiKey,
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode != 200) {
        return FindingsMapImageResult.failure(
          FindingsMapFailure.httpError,
          uri,
        );
      }

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().startsWith('image/')) {
        return FindingsMapImageResult.failure(FindingsMapFailure.notImage, uri);
      }

      if (response.bodyBytes.isEmpty) {
        return FindingsMapImageResult.failure(FindingsMapFailure.notImage, uri);
      }

      return FindingsMapImageResult.success(response.bodyBytes, uri);
    } on TimeoutException {
      return FindingsMapImageResult.failure(FindingsMapFailure.timeout, uri);
    } catch (_) {
      return FindingsMapImageResult.failure(
        FindingsMapFailure.networkError,
        uri,
      );
    }
  }
}

class FindingsMapService {
  static List<MapFindingPoint> buildPoints(List<HallazgoInspeccion> findings) {
    return [
      for (var index = 0; index < findings.length; index++)
        MapFindingPoint.fromFinding(index + 1, findings[index]),
    ];
  }

  static double? parseLatitude(String value) {
    return _parseCoordinate(value, min: -90, max: 90);
  }

  static double? parseLongitude(String value) {
    return _parseCoordinate(value, min: -180, max: 180);
  }

  static FindingsMapViewport calculateViewport(
    List<MapFindingPoint> points, {
    int width = 640,
    int height = 900,
  }) {
    final validPoints = points.where((point) => point.hasValidCoordinates);
    final latitudes = validPoints.map((point) => point.latitude!).toList();
    final longitudes = points
        .where((point) => point.hasValidCoordinates)
        .map((point) => point.longitude!)
        .toList();

    if (latitudes.isEmpty || longitudes.isEmpty) {
      return const FindingsMapViewport(
        centerLatitude: 0,
        centerLongitude: 0,
        zoom: 3,
      );
    }

    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLon = longitudes.reduce(math.min);
    final maxLon = longitudes.reduce(math.max);

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    final paddedLatSpan = _spanWithPadding(minLat, maxLat);
    final paddedLonSpan = _spanWithPadding(minLon, maxLon);
    final zoom = _calculateZoom(
      latSpan: paddedLatSpan,
      lonSpan: paddedLonSpan,
      width: width,
      height: height,
    );

    return FindingsMapViewport(
      centerLatitude: centerLat,
      centerLongitude: centerLon,
      zoom: zoom,
    );
  }

  static Uri buildStaticMapUri({
    required FindingsMapRequest request,
    required String apiKey,
  }) {
    final validPoints = request.validPoints;
    final viewport = calculateViewport(
      validPoints,
      width: request.width,
      height: request.height,
    );

    final queryParts = <String>[
      'maptype=${Uri.encodeQueryComponent(request.mapType)}',
      'size=${request.width}x${request.height}',
      'scale=2',
      'center=${viewport.centerLatitude},${viewport.centerLongitude}',
      'zoom=${viewport.zoom}',
    ];

    for (final point in validPoints) {
      final label = point.number <= 9 ? '|label:${point.number}' : '';
      final marker = 'color:red$label|${point.latitude},${point.longitude}';
      queryParts.add('markers=${Uri.encodeQueryComponent(marker)}');
    }

    queryParts.add('key=${Uri.encodeQueryComponent(apiKey)}');

    return Uri.parse(
      'https://maps.googleapis.com/maps/api/staticmap?${queryParts.join('&')}',
    );
  }

  static String legendCoordinateText(MapFindingPoint point) {
    if (!point.hasValidCoordinates) return 'Sin coordenadas';
    return '${point.latitudeText.trim()}, ${point.longitudeText.trim()}';
  }

  static double? _parseCoordinate(
    String value, {
    required double min,
    required double max,
  }) {
    final normalized = value.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;

    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    if (parsed < min || parsed > max) return null;
    return parsed;
  }

  static double _spanWithPadding(double min, double max) {
    final span = (max - min).abs();
    final normalizedSpan = span == 0 ? 0.002 : span;
    return normalizedSpan * 1.25;
  }

  static int _calculateZoom({
    required double latSpan,
    required double lonSpan,
    required int width,
    required int height,
  }) {
    final latZoom = _zoomForSpan(latSpan, height);
    final lonZoom = _zoomForSpan(lonSpan, width);
    final zoom = math.min(latZoom, lonZoom).floor();
    return zoom.clamp(3, 18);
  }

  static double _zoomForSpan(double span, int pixels) {
    final safeSpan = span <= 0 ? 0.002 : span;
    return math.log((360 * pixels) / (safeSpan * 256)) / math.ln2;
  }
}
