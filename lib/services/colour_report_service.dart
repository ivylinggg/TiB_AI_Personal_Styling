import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

/// Generates a concise personal colour + face-shape analysis report.
class ColourReportService {
  ColourReportService._();

  static Future<Uint8List> generateBytes({required ColourAnalysisResult result}) async {
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;

    try {
      final profile = SeasonColourGuide.forSeason(result.season);
      final accent = _seasonColor(result.season);
      final dark = PdfColor(40, 36, 42);
      final muted = PdfColor(112, 104, 112);
      final soft = PdfColor(247, 243, 249);
      final border = PdfColor(226, 220, 228);
      final white = PdfColor(255, 255, 255);
      final date = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());
      final photoBytes = await _loadImageBytes(result.imageUrl);

      _drawCover(document.pages.add(), result, profile, accent, dark, muted, soft, border, photoBytes, date);
      _drawColourAndFace(document.pages.add(), result, profile, accent, dark, muted, soft, border, photoBytes);
      _drawPaletteAndStyle(document.pages.add(), result, profile, accent, dark, muted, soft, border);
      _drawReference(document.pages.add(), accent, dark, muted, soft, border);
      _addFooters(document, accent, muted);

      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static Future<File> generateReport({required ColourAnalysisResult result}) async {
    final bytes = await generateBytes(result: result);
    final directory = await getTemporaryDirectory();
    final safeSeason = result.season.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final file = File('${directory.path}/TiB_Personal_Style_Report_$safeSeason.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> saveReport({required ColourAnalysisResult result}) async {
    final bytes = await generateBytes(result: result);
    final safeSeason = result.season.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final reportsDirectory = Directory('${documentsDirectory.path}/Reports');
    if (!await reportsDirectory.exists()) await reportsDirectory.create(recursive: true);
    final file = File('${reportsDirectory.path}/TiB_Personal_Style_Report_$safeSeason.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> generateAndShare({required ColourAnalysisResult result, String? shareText}) async {
    final file = await generateReport(result: result);
    await SharePlus.instance.share(ShareParams(
      title: 'TiB Personal Style Report',
      subject: 'My TiB Personal Style Report',
      text: shareText ?? 'My personal colour and face-shape analysis from VYEA.',
      files: [XFile(file.path)],
    ));
    return file;
  }

  static void _drawCover(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border, Uint8List? photoBytes, String date) {
    final size = page.getClientSize();
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(0, 0, size.width, size.height));
    page.graphics.drawRectangle(brush: PdfSolidBrush(whiteColor()), bounds: ui.Rect.fromLTWH(26, 26, size.width - 52, size.height - 52));

    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 27, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(48, 52, 80, 30));
    _text(page, 'VYEA · STYLE BUT PERSONAL', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(48, 84, 240, 14));
    _text(page, 'PERSONAL STYLE ANALYSIS', PdfStandardFont(PdfFontFamily.helvetica, 25, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(48, 120, 430, 30));
    _text(page, result.season.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 37, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(48, 160, 430, 44));
    _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(48, 210, 430, 18));

    final photoRect = ui.Rect.fromLTWH(48, 262, 222, 292);
    if (photoBytes != null) {
      page.graphics.drawImage(PdfBitmap(photoBytes), photoRect);
      page.graphics.drawRectangle(pen: PdfPen(accent, width: 1.2), bounds: photoRect);
    } else {
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(accent, width: 1.2), bounds: photoRect);
      _text(page, 'ANALYSIS PHOTO', PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(78, 390, 162, 18), alignCenter: true);
    }

    page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(251, 249, 252)), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(292, 262, 218, 292));
    _text(page, 'YOUR RESULT', PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(312, 286, 160, 14));
    _text(page, result.faceShape.trim().isEmpty ? 'Unknown face shape' : '${result.faceShape} face shape', PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(312, 322, 170, 40));
    _smallProfile(page, 'Undertone', result.undertone, 392, dark, muted);
    _smallProfile(page, 'Depth', result.brightness, 442, dark, muted);
    _smallProfile(page, 'Contrast', result.contrast, 492, dark, muted);
    _text(page, 'Generated by TiB AI Personal Styling', PdfStandardFont(PdfFontFamily.helvetica, 8.5), muted, ui.Rect.fromLTWH(48, 590, 300, 15));
    _text(page, date, PdfStandardFont(PdfFontFamily.helvetica, 8.5), muted, ui.Rect.fromLTWH(48, 608, 300, 15));
  }

  static void _drawColourAndFace(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border, Uint8List? photoBytes) {
    _header(page, '01 · COLOUR + FACE ANALYSIS', 'The key findings from your scan', accent, dark, muted);

    _sectionTitle(page, 'Colour profile', 112, accent, dark);
    _metricCard(page, 28, 150, 158, 'UNDERTONE', result.undertone, accent, dark, soft, border, muted);
    _metricCard(page, 202, 150, 158, 'DEPTH', result.brightness, accent, dark, soft, border, muted);
    _metricCard(page, 376, 150, 158, 'CONTRAST', result.contrast, accent, dark, soft, border, muted);
    _text(page, profile.description, PdfStandardFont(PdfFontFamily.helvetica, 10.5), muted, ui.Rect.fromLTWH(28, 230, 506, 42));

    _sectionTitle(page, 'Face shape', 300, accent, dark);
    if (photoBytes != null) {
      page.graphics.drawImage(PdfBitmap(photoBytes), ui.Rect.fromLTWH(28, 338, 156, 210));
      page.graphics.drawRectangle(pen: PdfPen(accent, width: 1.1), bounds: ui.Rect.fromLTWH(28, 338, 156, 210));
    }
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(200, 338, 334, 210));
    _text(page, result.faceShape.trim().isEmpty ? 'Unknown' : result.faceShape, PdfStandardFont(PdfFontFamily.helvetica, 26, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(220, 360, 270, 32));
    _text(page, result.faceShapeDescription.trim().isEmpty ? 'Proportion-based analysis from your face contour.' : result.faceShapeDescription, PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(220, 404, 285, 55));
    final m = result.faceMeasurements;
    _smallMeasure(page, 'Length / cheekbone', m['faceLengthToCheekbone'], 480, accent, dark, muted);
    _smallMeasure(page, 'Forehead / cheekbone', m['foreheadToCheekbone'], 505, accent, dark, muted);
    _smallMeasure(page, 'Jaw / cheekbone', m['jawToCheekbone'], 530, accent, dark, muted);
  }

  static void _drawPaletteAndStyle(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '02 · YOUR STYLE BLUEPRINT', 'Practical colour and styling guidance', accent, dark, muted);

    _sectionTitle(page, 'Your best colours', 112, accent, dark);
    _drawSwatches(page, profile.bestColours.take(12).toList(), 154, accent, dark, border);

    _sectionTitle(page, 'Beauty colours', 300, accent, dark);
    _drawBeauty(page, profile.eyeShadowColours.take(6).toList(), 'Eye shadow', 338, accent, dark, border);
    _drawBeauty(page, profile.blushColours.take(6).toList(), 'Blush', 470, accent, dark, border);

    _sectionTitle(page, 'Style identity', 602, accent, dark);
    _drawPills(page, profile.keywords.take(10).toList(), 640, accent, dark, soft, border);
    _text(page, _styleSummary(result, profile), PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(28, 705, 506, 48));
  }

  static void _drawReference(PdfPage page, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '03 · SEASON REFERENCE', 'Four-season reference for comparison', accent, dark, muted);
    final profiles = SeasonColourGuide.profiles.values.toList();
    final positions = <ui.Rect>[
      ui.Rect.fromLTWH(28, 110, 248, 288),
      ui.Rect.fromLTWH(292, 110, 248, 288),
      ui.Rect.fromLTWH(28, 420, 248, 288),
      ui.Rect.fromLTWH(292, 420, 248, 288),
    ];
    for (var i = 0; i < profiles.length && i < positions.length; i++) {
      final profile = profiles[i];
      final rect = positions[i];
      final color = _seasonColor(profile.name);
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(color), bounds: rect);
      _text(page, profile.name.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), color, ui.Rect.fromLTWH(rect.left + 14, rect.top + 14, 200, 18));
      _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(rect.left + 14, rect.top + 40, 200, 16));
      _text(page, profile.description, PdfStandardFont(PdfFontFamily.helvetica, 8), muted, ui.Rect.fromLTWH(rect.left + 14, rect.top + 64, 220, 42));
      _drawSwatchesCompact(page, profile.bestColours.take(6).toList(), rect.left + 14, rect.top + 118, rect.width - 28, color, dark);
    }
  }

  static void _header(PdfPage page, String title, String subtitle, PdfColor accent, PdfColor dark, PdfColor muted) {
    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(28, 28, 60, 14));
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, 57, 506, 24));
    _text(page, subtitle, PdfStandardFont(PdfFontFamily.helvetica, 9), muted, ui.Rect.fromLTWH(28, 84, 506, 16));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, 101, 45, 2));
  }

  static void _sectionTitle(PdfPage page, String title, double y, PdfColor accent, PdfColor dark) {
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, y, 500, 20));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, y + 24, 36, 2));
  }

  static void _metricCard(PdfPage page, double x, double y, double width, String label, String value, PdfColor accent, PdfColor dark, PdfColor soft, PdfColor border, PdfColor muted) {
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, y, width, 64));
    page.graphics.drawEllipse(ui.Rect.fromLTWH(x + 12, y + 13, 15, 15), brush: PdfSolidBrush(accent));
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(x + 34, y + 11, width - 44, 11));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x + 12, y + 34, width - 24, 16));
  }

  static void _drawSwatches(PdfPage page, List<String> names, double y, PdfColor accent, PdfColor dark, PdfColor border) {
    const columns = 4;
    const gap = 9.0;
    const swatchW = 120.0;
    const rowH = 58.0;
    for (var i = 0; i < names.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final x = 28.0 + col * (swatchW + gap);
      final top = y + row * rowH;
      page.graphics.drawRectangle(brush: PdfSolidBrush(_colourFor(names[i], accent)), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, top, swatchW, 30.0));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, 6.8), dark, ui.Rect.fromLTWH(x, top + 34.0, swatchW, 15.0), alignCenter: true);
    }
  }

  static void _drawSwatchesCompact(PdfPage page, List<String> names, double x, double y, double width, PdfColor accent, PdfColor dark) {
    const columns = 3;
    const gap = 7.0;
    final w = (width - gap * 2) / 3.0;
    for (var i = 0; i < names.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final px = x + col * (w + gap);
      final py = y + row * 48.0;
      page.graphics.drawRectangle(brush: PdfSolidBrush(_colourFor(names[i], accent)), bounds: ui.Rect.fromLTWH(px, py, w, 25.0));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, 6), dark, ui.Rect.fromLTWH(px, py + 28.0, w, 14.0), alignCenter: true);
    }
  }

  static void _drawBeauty(PdfPage page, List<String> names, String title, double y, PdfColor accent, PdfColor dark, PdfColor border) {
    _text(page, title.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), mutedColor(), ui.Rect.fromLTWH(28, y, 130, 14));
    for (var i = 0; i < names.length; i++) {
      final x = 28.0 + i * 84.0;
      page.graphics.drawEllipse(ui.Rect.fromLTWH(x, y + 22.0, 24.0, 24.0), brush: PdfSolidBrush(_colourFor(names[i], accent)), pen: PdfPen(border));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, 5.8), dark, ui.Rect.fromLTWH(x - 10.0, y + 50.0, 44.0, 22.0), alignCenter: true);
    }
  }

  static void _drawPills(PdfPage page, List<String> values, double y, PdfColor accent, PdfColor dark, PdfColor soft, PdfColor border) {
    var x = 28.0;
    var rowY = y;
    for (final value in values) {
      final width = 22.0 + value.length * 4.0;
      if (x + width > 534.0) {
        x = 28.0;
        rowY += 31.0;
      }
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(accent, width: .5), bounds: ui.Rect.fromLTWH(x, rowY, width, 22.0));
      _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 7), dark, ui.Rect.fromLTWH(x + 4.0, rowY + 4.0, width - 8.0, 13.0), alignCenter: true);
      x += width + 6.0;
    }
  }

  static void _smallProfile(PdfPage page, String label, String value, double y, PdfColor dark, PdfColor muted) {
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(312, y, 84, 12));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 10.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(398, y - 1, 92, 14), alignRight: true);
  }

  static void _smallMeasure(PdfPage page, String label, double? value, double y, PdfColor accent, PdfColor dark, PdfColor muted) {
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(220, y, 210, 12));
    _text(page, _formatMeasurement(value), PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(438, y, 70, 12), alignRight: true);
  }

  static String _formatMeasurement(double? value) => value == null ? '—' : value.toStringAsFixed(3);

  static String _styleSummary(ColourAnalysisResult result, SeasonColourProfile profile) {
    final face = result.faceShape.trim().isEmpty ? 'your natural facial proportions' : '${result.faceShape} facial proportions';
    return 'Your strongest direction combines ${profile.dimension.toLowerCase()} colour harmony with $face. Use the palette as your core wardrobe language, then adjust silhouette and details for occasion and personal preference.';
  }

  static PdfColor whiteColor() => PdfColor(255, 255, 255);
  static PdfColor mutedColor() => PdfColor(120, 114, 122);

  static PdfColor _seasonColor(String season) {
    switch (season) {
      case 'Winter': return PdfColor(66, 92, 150);
      case 'Summer': return PdfColor(139, 105, 182);
      case 'Spring': return PdfColor(224, 145, 82);
      case 'Autumn': return PdfColor(157, 91, 55);
      default: return PdfColor(139, 105, 182);
    }
  }

  static PdfColor _colourFor(String name, PdfColor accent) {
    final key = name.toLowerCase();
    if (key.contains('white') || key.contains('ivory')) return PdfColor(245, 243, 238);
    if (key.contains('black')) return PdfColor(38, 36, 38);
    if (key.contains('charcoal')) return PdfColor(70, 73, 80);
    if (key.contains('navy')) return PdfColor(38, 57, 88);
    if (key.contains('blue') || key.contains('sapphire') || key.contains('cobalt')) return PdfColor(65, 115, 176);
    if (key.contains('lavender') || key.contains('lilac') || key.contains('mauve')) return PdfColor(176, 151, 193);
    if (key.contains('pink') || key.contains('rose') || key.contains('raspberry')) return PdfColor(211, 132, 155);
    if (key.contains('red') || key.contains('ruby') || key.contains('cranberry') || key.contains('wine')) return PdfColor(167, 65, 74);
    if (key.contains('peach') || key.contains('apricot') || key.contains('coral')) return PdfColor(230, 141, 116);
    if (key.contains('yellow') || key.contains('gold')) return PdfColor(210, 174, 70);
    if (key.contains('green') || key.contains('olive') || key.contains('mint')) return PdfColor(108, 135, 82);
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('sienna') || key.contains('bronze')) return PdfColor(143, 103, 74);
    if (key.contains('beige') || key.contains('cream') || key.contains('taupe')) return PdfColor(205, 186, 157);
    if (key.contains('grey') || key.contains('gray') || key.contains('silver')) return PdfColor(154, 153, 157);
    return accent;
  }

  static Future<Uint8List?> _loadImageBytes(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return null;
    try {
      final response = await http.get(uri);
      if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
        return Uint8List.fromList(response.bodyBytes);
      }
    } catch (_) {}
    return null;
  }

  static void _addFooters(PdfDocument document, PdfColor accent, PdfColor muted) {
    for (var i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      _text(page, 'TiB AI Personal Styling · VYEA', PdfStandardFont(PdfFontFamily.helvetica, 7), muted, ui.Rect.fromLTWH(28, size.height - 24.0, 240, 12));
      _text(page, '${i + 1} / ${document.pages.count}', PdfStandardFont(PdfFontFamily.helvetica, 7, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(size.width - 72.0, size.height - 24.0, 44, 12), alignRight: true);
    }
  }

  static void _text(PdfPage page, String text, PdfFont font, PdfColor color, ui.Rect bounds, {bool alignCenter = false, bool alignRight = false}) {
    final textSize = font.measureString(text);
    var x = bounds.left;
    if (alignRight) x = bounds.right - textSize.width;
    if (alignCenter) x = bounds.left + (bounds.width - textSize.width) / 2.0;
    if (x < bounds.left) x = bounds.left;
    page.graphics.drawString(text, font, brush: PdfSolidBrush(color), bounds: ui.Rect.fromLTWH(x, bounds.top, textSize.width + 2.0, bounds.height));
  }
}