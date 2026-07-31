import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

typedef PdfFontAssetLoader = Future<ByteData> Function(String assetPath);

class PdfFontBundle {
  final pw.Font regular;
  final pw.Font bold;
  final pw.ThemeData theme;

  const PdfFontBundle({
    required this.regular,
    required this.bold,
    required this.theme,
  });
}

class PdfFontProvider {
  static const regularAssetPath = 'assets/fonts/Roboto-Regular.ttf';
  static const boldAssetPath = 'assets/fonts/Roboto-Bold.ttf';

  final PdfFontAssetLoader loadFontAsset;
  Future<PdfFontBundle>? _bundleFuture;

  PdfFontProvider({PdfFontAssetLoader? loadFontAsset})
    : loadFontAsset = loadFontAsset ?? rootBundle.load;

  Future<PdfFontBundle> load() async {
    final cached = _bundleFuture;
    if (cached != null) return cached;

    final future = _loadBundle();
    _bundleFuture = future;
    try {
      return await future;
    } catch (_) {
      _bundleFuture = null;
      rethrow;
    }
  }

  Future<PdfFontBundle> _loadBundle() async {
    final regularData = await loadFontAsset(regularAssetPath);
    final boldData = await loadFontAsset(boldAssetPath);
    final regular = pw.Font.ttf(regularData);
    final bold = pw.Font.ttf(boldData);
    return PdfFontBundle(
      regular: regular,
      bold: bold,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
  }
}
