import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/logging/app_logger.dart';
import '../core/utils/date_utils.dart';
import '../models/hallazgo_inspeccion.dart';
import 'findings_map_service.dart';
import 'pdf_font_provider.dart';

typedef PdfAssetLoader = Future<Uint8List> Function(String assetPath);
typedef PdfPhotoPathResolver =
    Future<List<String>> Function(HallazgoInspeccion finding);

class InspectionPdfText {
  static const informationTitle = 'INFORMACIÓN GENERAL';
  static const findingsTitle = 'HALLAZGOS OPERATIVOS';
  static const mapTitle = 'MAPA DE UBICACIÓN DE HALLAZGOS';
  static const noValidCoordinates =
      'No existen coordenadas válidas para generar el mapa de hallazgos.';
  static const mapUnavailable =
      'Mapa no disponible. Las coordenadas de los hallazgos se incluyen en la leyenda.';

  static const generalLabels = [
    'Fecha:',
    'Responsable:',
    'Usuario:',
    'Tipo de línea:',
    'Línea:',
    'Punto de referencia:',
    'Estado operativo:',
    'Total hallazgos:',
  ];

  static const findingLabels = ['Latitud:', 'Longitud:', 'Descripción:'];
}

class InspectionPdfData {
  final String usuario;
  final String tipoLinea;
  final String seleccionLinea;
  final String responsable;
  final String estadoLinea;
  final String puntoReferencia;
  final String observaciones;
  final List<HallazgoInspeccion> hallazgos;
  final DateTime generatedAt;

  const InspectionPdfData({
    required this.usuario,
    required this.tipoLinea,
    required this.seleccionLinea,
    required this.responsable,
    required this.estadoLinea,
    required this.puntoReferencia,
    required this.observaciones,
    required this.hallazgos,
    required this.generatedAt,
  });
}

class InspectionPdfFindingTitle {
  final String prefix;
  final String category;
  final String state;

  const InspectionPdfFindingTitle({
    required this.prefix,
    required this.category,
    required this.state,
  });

  String get plainText {
    if (state.isEmpty) return '$prefix $category';
    return '$prefix $category - $state';
  }
}

class InspectionPdfFormatter {
  static InspectionPdfFindingTitle findingTitle(
    int number,
    HallazgoInspeccion finding,
  ) {
    return InspectionPdfFindingTitle(
      prefix: '$number.',
      category: finding.tipo.trim().toUpperCase(),
      state: finding.detalle.trim(),
    );
  }

  static String safeGeneralValue(String value, {String fallback = ''}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class InspectionPdfService {
  static const double safeFooterHeight = 96;
  static const double horizontalMargin = 35;
  static const double topMargin = 35;
  static const double photoWidth = 180;
  static const double photoHeight = 130;
  static const double mapWidth = 360;
  static const double mapMaxHeight = 395;
  static const double mapMinHeight = 265;
  static const double mapTitleEstimatedHeight = 29;
  static const double mapTitleGap = 12;

  final PdfAssetLoader loadAsset;
  final PdfPhotoPathResolver photoPathResolver;
  final FindingsMapImageProvider mapImageProvider;
  final PdfFontProvider fontProvider;

  InspectionPdfService({
    PdfAssetLoader? loadAsset,
    required this.photoPathResolver,
    required this.mapImageProvider,
    PdfFontProvider? fontProvider,
  }) : loadAsset = loadAsset ?? _loadRootAsset,
       fontProvider = fontProvider ?? PdfFontProvider();

  Future<Uint8List> buildPdf(InspectionPdfData data) async {
    final fonts = await fontProvider.load();
    final logoLinerb = pw.MemoryImage(
      await loadAsset('assets/logo_linerb.png'),
    );
    final footerFranjas = pw.MemoryImage(
      await loadAsset('assets/footer_linerb.png'),
    );
    final footerTuberia = pw.MemoryImage(
      await loadAsset('assets/footer_linerb-1.png'),
    );

    final fotosPdf = await _loadPhotos(data.hallazgos);
    final mapPoints = FindingsMapService.buildPoints(data.hallazgos);
    final mapRequest = FindingsMapRequest(points: mapPoints);
    final mapResult = await _loadMapSafely(mapRequest);
    if (!mapResult.hasImage &&
        mapResult.failure != FindingsMapFailure.noValidCoordinates) {
      AppLogger.warning('Mapa de hallazgos no disponible para el PDF');
    }

    final pdf = pw.Document();
    final pageTheme = _pageTheme(
      footerFranjas,
      footerTuberia,
      theme: fonts.theme,
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: _footer,
        maxPages: 80,
        build: (context) => [
          _header(logoLinerb, data.generatedAt),
          pw.SizedBox(height: 12),
          pw.Container(height: 2, color: PdfColors.green900),
          pw.SizedBox(height: 10),
          _generalInformation(data),
          pw.SizedBox(height: 15),
          _sectionTitle(InspectionPdfText.findingsTitle),
          pw.SizedBox(height: 10),
          ..._findingBlocks(data.hallazgos, fotosPdf),
          pw.SizedBox(height: 15),
          pw.Text(
            'OBSERVACIÓN GENERAL',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(data.observaciones),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        footer: _footer,
        maxPages: 20,
        build: (context) => [
          _sectionTitle(InspectionPdfText.mapTitle),
          pw.SizedBox(height: 12),
          ..._mapPageContent(mapPoints, mapResult),
        ],
      ),
    );

    return pdf.save();
  }

  Future<Map<HallazgoInspeccion, List<pw.MemoryImage>>> _loadPhotos(
    List<HallazgoInspeccion> findings,
  ) async {
    final fotosPdf = <HallazgoInspeccion, List<pw.MemoryImage>>{};

    for (final finding in findings) {
      final fotos = <pw.MemoryImage>[];
      final photoPaths = await photoPathResolver(finding);

      for (final photoPath in photoPaths) {
        fotos.add(pw.MemoryImage(await File(photoPath).readAsBytes()));
      }

      fotosPdf[finding] = fotos;
    }

    return fotosPdf;
  }

  Future<FindingsMapImageResult> _loadMapSafely(
    FindingsMapRequest request,
  ) async {
    try {
      final result = await mapImageProvider.loadMap(request);
      return result ??
          const FindingsMapImageResult.failure(FindingsMapFailure.notImage);
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Proveedor de mapa PDF falló: providerException',
        error,
        stackTrace,
      );
      return const FindingsMapImageResult.failure(
        FindingsMapFailure.providerException,
      );
    }
  }

  pw.PageTheme _pageTheme(
    pw.MemoryImage footerFranjas,
    pw.MemoryImage tuberia, {
    pw.ThemeData? theme,
  }) {
    return pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.fromLTRB(
        horizontalMargin,
        topMargin,
        horizontalMargin,
        safeFooterHeight,
      ),
      buildBackground: (context) {
        return pw.FullPage(
          ignoreMargins: true,
          child: pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                bottom: 0,
                child: pw.Image(footerFranjas, width: 220),
              ),
              pw.Positioned(
                right: 0,
                bottom: 24,
                child: pw.Opacity(
                  opacity: 0.72,
                  child: pw.Image(tuberia, width: 300),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  pw.Widget _header(pw.MemoryImage logoLinerb, DateTime generatedAt) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Image(logoLinerb, width: 140),
        pw.SizedBox(width: 25),
        pw.Container(width: 1.5, height: 70, color: PdfColors.green700),
        pw.SizedBox(width: 25),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INFORME DE LINERB',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                'Inspección de Líneas y Ramales',
                style: const pw.TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('No. Informe: LIN-${generatedAt.millisecondsSinceEpoch}'),
            pw.Text('Fecha: ${fechaCorta(generatedAt)}'),
            pw.Text('Versión: 1.0'),
          ],
        ),
      ],
    );
  }

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      height: 24,
      child: pw.Text(
        'Página ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      color: PdfColors.green900,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _generalInformation(InspectionPdfData data) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.green900),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle(InspectionPdfText.informationTitle),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelValue('Fecha:', fechaCorta(data.generatedAt)),
                    _labelValue('Responsable:', data.responsable),
                    _labelValue('Usuario:', data.usuario),
                    _labelValue('Tipo de línea:', data.tipoLinea),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _labelValue('Línea:', data.seleccionLinea),
                    _labelValue('Punto de referencia:', data.puntoReferencia),
                    _labelValue('Estado operativo:', data.estadoLinea),
                    _labelValue(
                      'Total hallazgos:',
                      data.hallazgos.length.toString(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _findingBlocks(
    List<HallazgoInspeccion> findings,
    Map<HallazgoInspeccion, List<pw.MemoryImage>> fotosPdf,
  ) {
    final blocks = <pw.Widget>[];

    for (var index = 0; index < findings.length; index++) {
      final finding = findings[index];
      final photos = fotosPdf[finding] ?? const <pw.MemoryImage>[];
      final reservedSpace = _estimatedFindingBlockHeight(finding, photos);
      blocks.add(pw.NewPage(freeSpace: reservedSpace));
      blocks.add(_findingBlock(index + 1, finding, photos));
    }

    return blocks;
  }

  pw.Widget _findingBlock(
    int number,
    HallazgoInspeccion finding,
    List<pw.MemoryImage> photos,
  ) {
    final title = InspectionPdfFormatter.findingTitle(number, finding);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.green900, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '${title.prefix} ${title.category}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                if (title.state.isNotEmpty)
                  pw.TextSpan(
                    text: ' - ${title.state}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          _labelValue('Latitud:', finding.latitud),
          _labelValue('Longitud:', finding.longitud),
          _labelValue('Descripción:', finding.descripcion),
          if (photos.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: photos.take(2).map((photo) {
                return pw.Container(
                  width: photoWidth,
                  height: photoHeight,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                  ),
                  child: pw.Image(photo, fit: pw.BoxFit.cover),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  double _estimatedFindingBlockHeight(
    HallazgoInspeccion finding,
    List<pw.MemoryImage> photos,
  ) {
    final descriptionLines = (finding.descripcion.length / 75).ceil().clamp(
      1,
      10,
    );
    final textHeight = 70 + (descriptionLines * 14);
    final photoRows = photos.isEmpty ? 0 : ((photos.take(2).length + 1) ~/ 2);
    final photoSpace = photoRows == 0 ? 0 : photoHeight + 14;
    final estimate = textHeight + photoSpace + 32;
    return estimate.clamp(130, 620).toDouble();
  }

  pw.Widget _labelValue(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  List<pw.Widget> _mapPageContent(
    List<MapFindingPoint> points,
    FindingsMapImageResult mapResult,
  ) {
    final validPoints = points.where((point) => point.hasValidCoordinates);
    final hasMap = validPoints.isNotEmpty && mapResult.hasImage;
    final layout = planMapLayout(points.length, hasMap: hasMap);
    final content = <pw.Widget>[];

    if (validPoints.isEmpty) {
      content.add(pw.Text(InspectionPdfText.noValidCoordinates));
      content.add(pw.SizedBox(height: layout.verticalGap));
      content.add(_mapLegend(points, layout));
      return content;
    }

    final mapWidget = _safeMapImageWidget(mapResult, height: layout.mapHeight);
    if (mapWidget != null) {
      content.add(mapWidget);
    } else {
      content.add(pw.Text(InspectionPdfText.mapUnavailable));
    }

    content.add(pw.SizedBox(height: layout.verticalGap));
    content.add(_compassRose(size: layout.compassSize));
    content.add(pw.SizedBox(height: layout.verticalGap));
    content.add(
      _mapLegend(points.take(layout.firstPageLegendCapacity).toList(), layout),
    );

    final pendingPoints = points.skip(layout.firstPageLegendCapacity).toList();
    if (pendingPoints.isNotEmpty) {
      content.add(pw.NewPage());
      content.add(_sectionTitle('LEYENDA DE HALLAZGOS - CONTINUACION'));
      content.add(pw.SizedBox(height: layout.verticalGap));
      content.add(_mapLegend(pendingPoints, layout.forContinuation()));
    }

    return content;
  }

  static PdfMapLayoutPlan planMapLayout(
    int findingCount, {
    bool hasMap = true,
  }) {
    final count = findingCount < 0 ? 0 : findingCount;
    final columns = _legendColumnCount(count);
    final rows = _ceilDiv(count, columns);
    final legendFontSize = count > 12 ? 8.5 : 9.0;
    final legendRowHeight = count > 12 ? 24.0 : 26.0;
    final legendRunSpacing = count > 12 ? 4.0 : 5.0;
    final verticalGap = count > 10 ? 6.0 : 8.0;
    final compassSize = count > 10
        ? 34.0
        : count > 5
        ? 38.0
        : 44.0;
    final contentWidth = PdfPageFormat.a4.width - (horizontalMargin * 2);
    final legendSpacing = columns == 1 ? 0.0 : 10.0;
    final legendItemWidth =
        (contentWidth - ((columns - 1) * legendSpacing)) / columns;
    final compassHeight = compassSize + 26;
    final rowPressure = rows > 2 ? (rows - 2) * 22.0 : 0.0;
    final preferredMapHeight = _clampDouble(
      mapMaxHeight - rowPressure,
      mapMinHeight,
      mapMaxHeight,
    );
    var mapHeight = hasMap ? preferredMapHeight : 0.0;

    var availableLegendHeight =
        _mapContentAvailableHeight -
        (hasMap ? mapHeight + verticalGap : 0) -
        compassHeight -
        verticalGap;
    var rowsThatFit = _rowsThatFitLegend(
      availableLegendHeight,
      legendRowHeight,
      legendRunSpacing,
    );

    if (hasMap && rowsThatFit < rows) {
      mapHeight = mapMinHeight;
      availableLegendHeight =
          _mapContentAvailableHeight -
          mapHeight -
          verticalGap -
          compassHeight -
          verticalGap;
      rowsThatFit = _rowsThatFitLegend(
        availableLegendHeight,
        legendRowHeight,
        legendRunSpacing,
      );
    }

    final firstPageLegendCapacity = count == 0
        ? 0
        : _maxInt(columns, rowsThatFit * columns);
    final firstPageRows = count == 0
        ? 0
        : _ceilDiv(_minInt(count, firstPageLegendCapacity), columns);
    final estimatedContentHeight =
        mapTitleEstimatedHeight +
        mapTitleGap +
        (hasMap ? mapHeight + verticalGap : 0) +
        compassHeight +
        verticalGap +
        _legendHeight(firstPageRows, legendRowHeight, legendRunSpacing);

    return PdfMapLayoutPlan(
      findingCount: count,
      mapHeight: mapHeight,
      compassSize: compassSize,
      legendColumns: columns,
      legendItemWidth: legendItemWidth,
      legendFontSize: legendFontSize,
      legendRunSpacing: legendRunSpacing,
      verticalGap: verticalGap,
      firstPageLegendCapacity: firstPageLegendCapacity,
      estimatedContentHeight: estimatedContentHeight,
    );
  }

  static double get _mapContentAvailableHeight {
    return PdfPageFormat.a4.height -
        topMargin -
        safeFooterHeight -
        mapTitleEstimatedHeight -
        mapTitleGap;
  }

  static int _legendColumnCount(int count) {
    if (count <= 1) return 1;
    if (count <= 5) return 2;
    return 3;
  }

  static int _ceilDiv(int value, int divisor) {
    if (value <= 0) return 0;
    return (value + divisor - 1) ~/ divisor;
  }

  static int _rowsThatFitLegend(
    double availableHeight,
    double rowHeight,
    double runSpacing,
  ) {
    if (availableHeight <= 0) return 0;
    return ((availableHeight + runSpacing) / (rowHeight + runSpacing)).floor();
  }

  static double _legendHeight(int rows, double rowHeight, double runSpacing) {
    if (rows <= 0) return 0;
    return (rows * rowHeight) + ((rows - 1) * runSpacing);
  }

  static double _clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static int _minInt(int a, int b) => a < b ? a : b;

  static int _maxInt(int a, int b) => a > b ? a : b;

  pw.Widget? _safeMapImageWidget(
    FindingsMapImageResult mapResult, {
    required double height,
  }) {
    if (!mapResult.hasImage) return null;

    try {
      final mapImage = pw.MemoryImage(mapResult.bytes!);
      return pw.Center(
        child: pw.Container(
          width: mapWidth,
          height: height,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey500),
          ),
          child: pw.Image(mapImage, fit: pw.BoxFit.cover),
        ),
      );
    } catch (error, stackTrace) {
      AppLogger.warning(
        'Imagen de mapa PDF no pudo decodificarse: imageDecodeError',
        error,
        stackTrace,
      );
      return null;
    }
  }

  pw.Widget _mapLegend(List<MapFindingPoint> points, PdfMapLayoutPlan layout) {
    if (points.isEmpty) {
      return pw.Text('Sin hallazgos registrados.');
    }

    final columns = _splitLegendColumns(points, layout.legendColumns);
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns.length; index++) ...[
          if (index > 0) pw.SizedBox(width: 10),
          pw.Container(
            width: layout.legendItemWidth,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final point in columns[index])
                  pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: layout.legendRunSpacing,
                    ),
                    child: pw.RichText(
                      text: pw.TextSpan(
                        style: pw.TextStyle(fontSize: layout.legendFontSize),
                        children: [
                          pw.TextSpan(
                            text: '${point.number}. ${point.categoryLabel}\n',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: layout.legendFontSize,
                            ),
                          ),
                          pw.TextSpan(
                            text: FindingsMapService.legendCoordinateText(
                              point,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<List<MapFindingPoint>> _splitLegendColumns(
    List<MapFindingPoint> points,
    int columnCount,
  ) {
    final columns = <List<MapFindingPoint>>[];
    final safeColumnCount = columnCount < 1 ? 1 : columnCount;
    final perColumn = _ceilDiv(points.length, safeColumnCount);

    for (var column = 0; column < safeColumnCount; column++) {
      final start = column * perColumn;
      if (start >= points.length) break;
      final end = _minInt(start + perColumn, points.length);
      columns.add(points.sublist(start, end));
    }

    return columns;
  }

  pw.Widget _compassRose({required double size}) {
    final sideLabelGap = size * 0.65;
    final northSize = size <= 34 ? 9.0 : 11.0;
    final labelSize = size <= 34 ? 7.5 : 8.5;
    final ringRadius = size * 0.27;
    final arrowOffset = size * 0.1;
    final arrowBaseOffset = size * 0.17;

    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
            'N',
            style: pw.TextStyle(
              fontSize: northSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.CustomPaint(
            size: PdfPoint(size, size),
            painter: (canvas, pointSize) {
              final centerX = pointSize.x / 2;
              final centerY = pointSize.y / 2;
              canvas
                ..setStrokeColor(PdfColors.green900)
                ..setFillColor(PdfColors.green900)
                ..setLineWidth(1.2)
                ..moveTo(centerX, pointSize.y)
                ..lineTo(centerX + arrowOffset, centerY + arrowOffset)
                ..lineTo(centerX, centerY + arrowBaseOffset)
                ..lineTo(centerX - arrowOffset, centerY + arrowOffset)
                ..fillPath()
                ..moveTo(centerX, 0)
                ..lineTo(centerX, pointSize.y)
                ..moveTo(0, centerY)
                ..lineTo(pointSize.x, centerY)
                ..strokePath()
                ..drawEllipse(centerX, centerY, ringRadius, ringRadius)
                ..strokePath();
            },
          ),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('O', style: pw.TextStyle(fontSize: labelSize)),
              pw.SizedBox(width: sideLabelGap),
              pw.Text('E', style: pw.TextStyle(fontSize: labelSize)),
            ],
          ),
          pw.Text('S', style: pw.TextStyle(fontSize: labelSize)),
        ],
      ),
    );
  }

  static Future<Uint8List> _loadRootAsset(String assetPath) async {
    return (await rootBundle.load(assetPath)).buffer.asUint8List();
  }
}

class PdfMapLayoutPlan {
  final int findingCount;
  final double mapHeight;
  final double compassSize;
  final int legendColumns;
  final double legendItemWidth;
  final double legendFontSize;
  final double legendRunSpacing;
  final double verticalGap;
  final int firstPageLegendCapacity;
  final double estimatedContentHeight;

  const PdfMapLayoutPlan({
    required this.findingCount,
    required this.mapHeight,
    required this.compassSize,
    required this.legendColumns,
    required this.legendItemWidth,
    required this.legendFontSize,
    required this.legendRunSpacing,
    required this.verticalGap,
    required this.firstPageLegendCapacity,
    required this.estimatedContentHeight,
  });

  bool get requiresContinuation => firstPageLegendCapacity < findingCount;

  PdfMapLayoutPlan forContinuation() {
    return PdfMapLayoutPlan(
      findingCount: findingCount - firstPageLegendCapacity,
      mapHeight: 0,
      compassSize: compassSize,
      legendColumns: legendColumns,
      legendItemWidth: legendItemWidth,
      legendFontSize: legendFontSize,
      legendRunSpacing: legendRunSpacing,
      verticalGap: verticalGap,
      firstPageLegendCapacity: findingCount - firstPageLegendCapacity,
      estimatedContentHeight: estimatedContentHeight,
    );
  }
}
