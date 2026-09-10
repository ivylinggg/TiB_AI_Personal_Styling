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

      _drawCover(document.pages.add(), result, profile, accent, dark, muted, white, photoBytes);
      _drawColourProfile(document.pages.add(), result, profile, accent, dark, muted, soft, border);
      _drawFaceShape(document.pages.add(), result, accent, dark, muted, soft, border, photoBytes);
      _drawFaceStyleGuide(document.pages.add(), result, accent, dark, muted, soft, border);
      _drawColourPalette(document.pages.add(), result, profile, accent, dark, muted, soft, border);
      _drawMakeupAndStyle(document.pages.add(), result, profile, accent, dark, muted, soft, border);
      _drawStyleIdentity(document.pages.add(), result, profile, accent, dark, muted, soft, border);
      _drawReferenceGuide(document.pages.add(), accent, dark, muted, soft, border);
      _addFooters(document, date, accent, muted);
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
      text: shareText ?? 'My personal colour and style analysis from VYEA.',
      files: [XFile(file.path)],
    ));
    return file;
  }

  static void _drawCover(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor white, Uint8List? photoBytes) {
    final size = page.getClientSize();
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(0, 0, size.width, size.height));
    page.graphics.drawRectangle(brush: PdfSolidBrush(white), bounds: ui.Rect.fromLTWH(28, 34, size.width - 56, size.height - 68));
    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 26, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, 58, 100, 28));
    _text(page, 'VYEA · STYLE BUT PERSONAL', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(52, 88, 220, 14));
    _text(page, 'PERSONAL COLOUR', PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(52, 122, 250, 16));
    _text(page, 'STYLE ANALYSIS', PdfStandardFont(PdfFontFamily.helvetica, 27, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, 142, 440, 32));
    _text(page, result.season.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 38, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(52, 184, 440, 46));
    _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, 234, 440, 18));
    final photoRect = ui.Rect.fromLTWH(52, 286, 238, 300);
    if (photoBytes != null) {
      page.graphics.drawImage(PdfBitmap(photoBytes), photoRect);
      page.graphics.drawRectangle(pen: PdfPen(accent, width: 1.2), bounds: photoRect);
    } else {
      page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(248, 245, 247)), pen: PdfPen(accent, width: 1.2), bounds: photoRect);
      _text(page, 'Analysis photo', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(82, 420, 178, 22), alignCenter: true);
    }
    page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(251, 249, 252)), pen: PdfPen(PdfColor(232, 226, 234)), bounds: ui.Rect.fromLTWH(314, 286, 218, 300));
    _text(page, 'YOUR PROFILE', PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(334, 310, 170, 16));
    _text(page, result.faceShape.isEmpty ? 'Face shape · Unknown' : 'Face shape · ${result.faceShape}', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(334, 345, 170, 40));
    _smallProfile(page, 'Undertone', result.undertone, 410, dark, muted);
    _smallProfile(page, 'Depth', result.brightness, 462, dark, muted);
    _smallProfile(page, 'Contrast', result.contrast, 514, dark, muted);
    _text(page, 'A personal reference built from your observed colour characteristics and face-shape analysis.', PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(52, 620, 480, 42));
  }

  static void _drawColourProfile(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '01 · YOUR COLOUR PROFILE', 'Observed colour direction', accent, dark, muted);
    _text(page, profile.description, PdfStandardFont(PdfFontFamily.helvetica, 11), muted, ui.Rect.fromLTWH(28, 108, 510, 48));
    _metricCard(page, 28, 175, 158, 'UNDERTONE', result.undertone, accent, dark, soft, border);
    _metricCard(page, 202, 175, 158, 'DEPTH', result.brightness, accent, dark, soft, border);
    _metricCard(page, 376, 175, 158, 'CONTRAST', result.contrast, accent, dark, soft, border);
    _sectionTitle(page, 'Colour direction', 270, accent, dark);
    _dimensionBar(page, 28, 312, 'Warmth', result.undertone, ['Cool', 'Neutral', 'Warm'], accent, dark, muted, border);
    _dimensionBar(page, 28, 370, 'Depth', result.brightness, ['Light', 'Medium', 'Medium-Deep', 'Deep'], accent, dark, muted, border);
    _dimensionBar(page, 28, 428, 'Chroma', result.chroma, ['Soft', 'Balanced', 'Medium', 'High', 'Clear'], accent, dark, muted, border);
    _dimensionBar(page, 28, 486, 'Clarity', result.clarity, ['Soft', 'Balanced', 'Clear'], accent, dark, muted, border);
    if (result.colourReasons.isNotEmpty) {
      _sectionTitle(page, 'Why TiB selected this direction', 560, accent, dark);
      var y = 602.0;
      for (final reason in result.colourReasons.take(5)) {
        page.graphics.drawEllipse(ui.Rect.fromLTWH(29, y + 3, 7, 7), brush: PdfSolidBrush(accent));
        _text(page, reason, PdfStandardFont(PdfFontFamily.helvetica, 9), muted, ui.Rect.fromLTWH(45, y, 480, 22));
        y += 24;
      }
    }
  }

  static void _drawFaceShape(PdfPage page, ColourAnalysisResult result, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border, Uint8List? photoBytes) {
    _header(page, '02 · FACE SHAPE ANALYSIS', 'Proportion-based facial outline analysis', accent, dark, muted);
    if (photoBytes != null) {
      page.graphics.drawImage(PdfBitmap(photoBytes), ui.Rect.fromLTWH(28, 108, 190, 238));
      page.graphics.drawRectangle(pen: PdfPen(accent, width: 1.1), bounds: ui.Rect.fromLTWH(28, 108, 190, 238));
    }
    final cardX = 238.0;
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(cardX, 108, 296, 238));
    _text(page, 'YOUR FACE SHAPE', PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(cardX + 18, 128, 180, 14));
    _text(page, result.faceShape.isEmpty ? 'Unknown' : result.faceShape, PdfStandardFont(PdfFontFamily.helvetica, 27, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(cardX + 18, 148, 240, 32));
    _text(page, result.faceShapeDescription.isEmpty ? 'Proportion-based result from the available face contour.' : result.faceShapeDescription, PdfStandardFont(PdfFontFamily.helvetica, 10), muted, ui.Rect.fromLTWH(cardX + 18, 196, 250, 80));
    _sectionTitle(page, 'Measured proportions', 372, accent, dark);
    final rows = <MapEntry<String, String>>[
      MapEntry('Face length / cheekbone', _formatMeasurement(result.faceMeasurements['faceLengthToCheekbone'])),
      MapEntry('Forehead / cheekbone', _formatMeasurement(result.faceMeasurements['foreheadToCheekbone'])),
      MapEntry('Jaw / cheekbone', _formatMeasurement(result.faceMeasurements['jawToCheekbone'])),
      MapEntry('Chin / jaw', _formatMeasurement(result.faceMeasurements['chinToJaw'])),
      MapEntry('Measurement confidence', _formatMeasurement(result.faceMeasurements['measurementConfidence'], suffix: '%')),
    ];
    var y = 410.0;
    for (final row in rows) {
      page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(252, 251, 253)), bounds: ui.Rect.fromLTWH(28, y, 506, 31));
      page.graphics.drawRectangle(pen: PdfPen(border), bounds: ui.Rect.fromLTWH(28, y, 506, 31));
      _text(page, row.key, PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(40, y + 9, 300, 14));
      _text(page, row.value, PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(380, y + 8, 130, 15), alignRight: true);
      y += 33;
    }
  }

  static void _drawFaceStyleGuide(PdfPage page, ColourAnalysisResult result, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '03 · STYLE FROM YOUR FACE', 'How your proportions can guide styling choices', accent, dark, muted);
    _text(page, 'Your face shape is a proportion guide, not a limit. Use these recommendations to create balance or emphasis intentionally.', PdfStandardFont(PdfFontFamily.helvetica, 10.5), muted, ui.Rect.fromLTWH(28, 108, 506, 44));
    final guidance = result.faceStylingGuidance.isEmpty ? ['Personal styling guidance will appear here after face-shape analysis.'] : result.faceStylingGuidance;
    var y = 184.0;
    final labels = ['STYLE 01', 'STYLE 02', 'STYLE 03', 'STYLE 04'];
    for (var i = 0; i < guidance.take(4).length; i++) {
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(28, y, 506, 82));
      _text(page, labels[i], PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(44, y + 14, 75, 14));
      _text(page, guidance[i], PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(44, y + 34, 455, 32));
      y += 96;
    }
    _sectionTitle(page, 'Use this with your wardrobe', 590, accent, dark);
    _text(page, 'Combine face-shape recommendations with your personal colours, preferred silhouettes and occasion needs for a more complete styling decision.', PdfStandardFont(PdfFontFamily.helvetica, 10.5), muted, ui.Rect.fromLTWH(28, 630, 506, 42));
  }

  static void _drawColourPalette(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '04 · YOUR COLOUR PALETTE', 'Colours that align with your personal colour direction', accent, dark, muted);
    _paletteGroup(page, 'SIGNATURE COLOURS', profile.bestColours, 116, accent, dark, muted, border);
    _paletteGroup(page, 'BEST NEUTRALS', result.bestNeutrals.isEmpty ? _defaultNeutrals(profile) : result.bestNeutrals, 350, accent, dark, muted, border);
    _paletteGroup(page, 'ACCENT COLOURS', result.accentColours.isEmpty ? profile.bestColours.take(6).toList() : result.accentColours, 584, accent, dark, muted, border);
  }

  static void _drawMakeupAndStyle(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '05 · BEAUTY & COLOUR STYLING', 'Makeup tones and colours to explore', accent, dark, muted);
    _sectionTitle(page, 'Eye shadow', 112, accent, dark);
    _drawNamedList(page, profile.eyeShadowColours, 154, accent, dark, muted, border);
    _sectionTitle(page, 'Blush', 378, accent, dark);
    _drawNamedList(page, profile.blushColours, 420, accent, dark, muted, border);
    _sectionTitle(page, 'Colours to use less often', 584, accent, dark);
    _drawNamedList(page, result.lessIdealColours.isEmpty ? _fallbackLessIdeal(result.season) : result.lessIdealColours, 626, accent, dark, muted, border);
  }

  static void _drawStyleIdentity(PdfPage page, ColourAnalysisResult result, SeasonColourProfile profile, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '06 · YOUR STYLE IDENTITY', 'Turning colour and face shape into a personal style direction', accent, dark, muted);
    _sectionTitle(page, 'Style personality', 112, accent, dark);
    _drawPills(page, profile.keywords.take(12).toList(), 154, accent, dark, soft, border);
    _sectionTitle(page, 'Your signature direction', 326, accent, dark);
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(28, 368, 506, 150));
    _text(page, _styleSummary(result, profile), PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(48, 394, 466, 76));
    _text(page, 'This profile can be used by VYEA to personalise wardrobe recommendations and AI styling decisions.', PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(48, 474, 466, 28));
    _sectionTitle(page, 'Your styling formula', 562, accent, dark);
    final formula = '${result.faceShape.isEmpty ? 'Your face shape' : result.faceShape} + ${profile.name} colour direction + intentional silhouette';
    _text(page, formula, PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(28, 604, 506, 52), alignCenter: true);
  }

  static void _drawReferenceGuide(PdfPage page, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor soft, PdfColor border) {
    _header(page, '07 · SEASON REFERENCE', 'Four-season reference guide', accent, dark, muted);
    final profiles = SeasonColourGuide.profiles.values.toList();
    final positions = [ui.Rect.fromLTWH(28, 106, 248, 300), ui.Rect.fromLTWH(292, 106, 248, 300), ui.Rect.fromLTWH(28, 430, 248, 300), ui.Rect.fromLTWH(292, 430, 248, 300)];
    for (var i = 0; i < profiles.length && i < positions.length; i++) {
      final profile = profiles[i];
      final rect = positions[i];
      final color = _seasonColor(profile.name);
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(color), bounds: rect);
      _text(page, profile.name.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), color, ui.Rect.fromLTWH(rect.left + 14, rect.top + 14, rect.width - 28, 18));
      _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(rect.left + 14, rect.top + 40, rect.width - 28, 16));
      _text(page, profile.description, PdfStandardFont(PdfFontFamily.helvetica, 8.5), muted, ui.Rect.fromLTWH(rect.left + 14, rect.top + 65, rect.width - 28, 42));
      _drawSwatchesInRect(page, profile.bestColours.take(6).toList(), rect.left + 14, rect.top + 118, rect.width - 28, color, dark);
      _text(page, 'Eye: ${profile.eyeShadowColours.take(4).join(', ')}', PdfStandardFont(PdfFontFamily.helvetica, 7), dark, ui.Rect.fromLTWH(rect.left + 14, rect.bottom - 50, rect.width - 28, 20));
      _text(page, 'Blush: ${profile.blushColours.take(4).join(', ')}', PdfStandardFont(PdfFontFamily.helvetica, 7), dark, ui.Rect.fromLTWH(rect.left + 14, rect.bottom - 28, rect.width - 28, 20));
    }
  }

  static void _addFooters(PdfDocument document, String date, PdfColor accent, PdfColor muted) {
    for (var i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      _text(page, 'TiB AI Personal Styling · VYEA', PdfStandardFont(PdfFontFamily.helvetica, 7), muted, ui.Rect.fromLTWH(28, size.height - 24, 220, 12));
      _text(page, '${i + 1} / ${document.pages.count}', PdfStandardFont(PdfFontFamily.helvetica, 7, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(size.width - 70, size.height - 24, 42, 12), alignRight: true);
      if (i == 0) _text(page, date, PdfStandardFont(PdfFontFamily.helvetica, 7), muted, ui.Rect.fromLTWH(size.width - 220, size.height - 24, 145, 12), alignRight: true);
    }
  }

  static void _header(PdfPage page, String title, String subtitle, PdfColor accent, PdfColor dark, PdfColor muted) {
    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(28, 28, 60, 14));
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 19, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, 57, 506, 24));
    _text(page, subtitle, PdfStandardFont(PdfFontFamily.helvetica, 9), muted, ui.Rect.fromLTWH(28, 84, 506, 16));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, 101, 52, 2.5));
  }

  static void _sectionTitle(PdfPage page, String title, double y, PdfColor accent, PdfColor dark) {
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, y, 500, 20));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, y + 24, 38, 2));
  }

  static void _metricCard(PdfPage page, double x, double y, double width, String label, String value, PdfColor accent, PdfColor dark, PdfColor soft, PdfColor border) {
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, y, width, 66));
    page.graphics.drawEllipse(ui.Rect.fromLTWH(x + 12, y + 14, 16, 16), brush: PdfSolidBrush(accent));
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), PdfColor(120, 114, 122), ui.Rect.fromLTWH(x + 36, y + 12, width - 48, 12));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x + 12, y + 34, width - 24, 18));
  }

  static void _dimensionBar(PdfPage page, double x, double y, String label, String selected, List<String> options, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor border) {
    _text(page, label.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(x, y, 100, 14));
    final start = x + 112;
    final totalWidth = 394.0;
    final step = totalWidth / options.length;
    page.graphics.drawLine(PdfPen(border, width: 1), ui.Offset(start, y + 8), ui.Offset(start + totalWidth, y + 8));
    for (var i = 0; i < options.length; i++) {
      final centerX = start + i * step + step / 2;
      final isSelected = options[i].toLowerCase() == selected.toLowerCase();
      page.graphics.drawEllipse(ui.Rect.fromLTWH(centerX - 6, y + 2, 12, 12), brush: PdfSolidBrush(isSelected ? accent : PdfColor(238, 233, 240)), pen: PdfPen(border));
      _text(page, options[i], PdfStandardFont(PdfFontFamily.helvetica, 7.5, style: isSelected ? PdfFontStyle.bold : PdfFontStyle.regular), isSelected ? dark : muted, ui.Rect.fromLTWH(start + i * step, y + 18, step, 13), alignCenter: true);
    }
  }

  static void _smallProfile(PdfPage page, String label, String value, double y, PdfColor dark, PdfColor muted) {
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(334, y, 80, 12));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(414, y - 1, 94, 14), alignRight: true);
  }

  static void _paletteGroup(PdfPage page, String title, List<String> names, double y, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor border) {
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(28, y, 300, 14));
    _drawSwatchesInRect(page, names.take(12).toList(), 28, y + 26, 506, accent, dark);
  }

  static void _drawSwatchesInRect(PdfPage page, List<String> names, double x, double y, double width, PdfColor accent, PdfColor dark) {
    final columns = width > 400 ? 6 : 3;
    final gap = 9.0;
    final swatchWidth = (width - gap * (columns - 1)) / columns;
    const swatchHeight = 28.0;
    const rowHeight = 54.0;
    for (var i = 0; i < names.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final px = x + col * (swatchWidth + gap);
      final py = y + row * rowHeight;
      page.graphics.drawRectangle(brush: PdfSolidBrush(_colourFor(names[i], accent)), pen: PdfPen(PdfColor(230, 224, 232)), bounds: ui.Rect.fromLTWH(px, py, swatchWidth, swatchHeight));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, 6.6), dark, ui.Rect.fromLTWH(px, py + 31, swatchWidth, 16), alignCenter: true);
    }
  }

  static void _drawNamedList(PdfPage page, List<String> names, double y, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor border) {
    for (var i = 0; i < names.length && i < 10; i++) {
      final row = i % 5;
      final col = i ~/ 5;
      final x = 28 + col * 253.0;
      final py = y + row * 46.0;
      page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(252, 251, 253)), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, py, 242, 34));
      page.graphics.drawEllipse(ui.Rect.fromLTWH(x + 10, py + 8, 18, 18), brush: PdfSolidBrush(_colourFor(names[i], accent)));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x + 38, py + 10, 190, 14));
    }
  }

  static void _drawPills(PdfPage page, List<String> values, double y, PdfColor accent, PdfColor dark, PdfColor soft, PdfColor border) {
    var x = 28.0;
    var rowY = y;
    for (final value in values) {
      final width = 24 + value.length * 4.2;
      if (x + width > 534) {
        x = 28;
        rowY += 34;
      }
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(accent, width: .55), bounds: ui.Rect.fromLTWH(x, rowY, width, 23));
      _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 7.5), dark, ui.Rect.fromLTWH(x + 5, rowY + 5, width - 10, 13), alignCenter: true);
      x += width + 7;
    }
  }

  static String _styleSummary(ColourAnalysisResult result, SeasonColourProfile profile) {
    final face = result.faceShape.trim().isEmpty ? 'your natural facial proportions' : '${result.faceShape} face proportions';
    return 'Your strongest direction combines ${profile.dimension.toLowerCase()} colour harmony with $face. Build outfits around refined colour contrast, intentional silhouette and details that support your natural proportions.';
  }

  static List<String> _defaultNeutrals(SeasonColourProfile profile) => profile.bestColours.take(4).toList();

  static List<String> _fallbackLessIdeal(String season) {
    switch (season) {
      case 'Winter': return ['Camel', 'Mustard', 'Rust', 'Warm Orange'];
      case 'Summer': return ['Neon Orange', 'Golden Yellow', 'Rust', 'Warm Olive'];
      case 'Spring': return ['Jet Black', 'Charcoal', 'Deep Burgundy', 'Cool Plum'];
      case 'Autumn': return ['Icy Grey', 'Frosted Blue', 'Cool Lilac', 'Neon Pink'];
      default: return ['Extreme neon', 'Very cool grey', 'Very icy pastels'];
    }
  }

  static String _formatMeasurement(double? value, {String suffix = ''}) => value == null ? '—' : '${value.toStringAsFixed(3)}$suffix';

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
    if (key.contains('red') || key.contains('ruby') || key.contains('cranberry')) return PdfColor(167, 65, 74);
    if (key.contains('peach') || key.contains('apricot') || key.contains('coral')) return PdfColor(230, 141, 116);
    if (key.contains('yellow') || key.contains('gold')) return PdfColor(210, 174, 70);
    if (key.contains('green') || key.contains('olive') || key.contains('mint')) return PdfColor(108, 135, 82);
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('sienna')) return PdfColor(143, 103, 74);
    if (key.contains('beige') || key.contains('cream') || key.contains('taupe')) return PdfColor(205, 186, 157);
    if (key.contains('grey') || key.contains('gray')) return PdfColor(154, 153, 157);
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

  static void _text(PdfPage page, String text, PdfFont font, PdfColor color, ui.Rect bounds, {bool alignCenter = false, bool alignRight = false}) {
    final textSize = font.measureString(text);
    var x = bounds.left;
    if (alignRight) x = bounds.right - textSize.width;
    if (alignCenter) x = bounds.left + (bounds.width - textSize.width) / 2;
    if (x < bounds.left) x = bounds.left;
    page.graphics.drawString(text, font, brush: PdfSolidBrush(color), bounds: ui.Rect.fromLTWH(x, bounds.top, textSize.width + 2, bounds.height));
  }
}
