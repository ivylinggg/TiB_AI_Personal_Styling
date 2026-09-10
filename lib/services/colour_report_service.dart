import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../data/professional_style_data.dart';
import '../data/season_colour_guide.dart';
import '../models/colour_analysis_result.dart';

/// Generates a multi-page editorial-style personal colour + face-shape report.
class ColourReportService {
  ColourReportService._();

  static Future<Uint8List> generateBytes({
    required ColourAnalysisResult result,
  }) async {
    final document = PdfDocument();
    document.pageSettings.size = PdfPageSize.a4;

    try {
      final profile = SeasonColourGuide.forSeason(result.season);
      final accent = _seasonColor(result.season);
      final dark = const PdfColor(40, 36, 42);
      final muted = const PdfColor(112, 104, 112);
      final soft = const PdfColor(247, 243, 249);
      final border = const PdfColor(226, 220, 228);
      final white = const PdfColor(255, 255, 255);
      final date = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());

      final photoBytes = await _loadImageBytes(result.imageUrl);

      _drawCover(
        document.pages.add(),
        result: result,
        profile: profile,
        accent: accent,
        dark: dark,
        muted: muted,
        white: white,
        photoBytes: photoBytes,
      );

      _drawColourProfile(
        document.pages.add(),
        result: result,
        profile: profile,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _drawFaceShape(
        document.pages.add(),
        result: result,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
        photoBytes: photoBytes,
      );

      _drawFaceStyleGuide(
        document.pages.add(),
        result: result,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _drawColourPalette(
        document.pages.add(),
        result: result,
        profile: profile,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _drawMakeupAndStyle(
        document.pages.add(),
        result: result,
        profile: profile,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _drawStyleIdentity(
        document.pages.add(),
        result: result,
        profile: profile,
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _drawReferenceGuide(
        document.pages.add(),
        accent: accent,
        dark: dark,
        muted: muted,
        soft: soft,
        border: border,
      );

      _addFooters(document, date: date, accent: accent, muted: muted);
      return Uint8List.fromList(await document.save());
    } finally {
      document.dispose();
    }
  }

  static Future<File> generateReport({
    required ColourAnalysisResult result,
  }) async {
    final bytes = await generateBytes(result: result);
    final directory = await getTemporaryDirectory();
    final safeSeason = result.season.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final fileName = 'TiB_Personal_Style_Report_$safeSeason.pdf';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> saveReport({
    required ColourAnalysisResult result,
  }) async {
    final bytes = await generateBytes(result: result);
    final safeSeason = result.season.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final fileName = 'TiB_Personal_Style_Report_$safeSeason.pdf';
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final reportsDirectory = Directory('${documentsDirectory.path}/Reports');
    if (!await reportsDirectory.exists()) {
      await reportsDirectory.create(recursive: true);
    }
    final file = File('${reportsDirectory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<File> generateAndShare({
    required ColourAnalysisResult result,
    String? shareText,
  }) async {
    final file = await generateReport(result: result);
    await SharePlus.instance.share(
      ShareParams(
        title: 'TiB Personal Style Report',
        subject: 'My TiB Personal Style Report',
        text: shareText ?? 'My personal colour and style analysis from VYEA.',
        files: [XFile(file.path)],
      ),
    );
    return file;
  }

  static void _drawCover(
    PdfPage page, {
    required ColourAnalysisResult result,
    required SeasonColourProfile profile,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor white,
    required Uint8List? photoBytes,
  }) {
    final size = page.getClientSize();
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(accent),
      bounds: ui.Rect.fromLTWH(0, 0, size.width, size.height),
    );
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(const PdfColor(255, 255, 255)),
      bounds: ui.Rect.fromLTWH(28, 34, size.width - 56, size.height - 68),
    );

    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 26, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, 58, 100, 28));
    _text(page, 'VYEA · STYLE BUT PERSONAL', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(52, 88, 220, 14));

    var y = 122.0;
    _text(page, 'PERSONAL COLOUR', PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(52, y, 250, 16));
    _text(page, 'STYLE ANALYSIS', PdfStandardFont(PdfFontFamily.helvetica, 27, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, y + 20, 440, 32));
    _text(page, result.season.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 38, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(52, y + 62, 440, 46));
    _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(52, y + 112, 440, 18));

    if (photoBytes != null) {
      page.graphics.drawImage(
        PdfBitmap(photoBytes),
        ui.Rect.fromLTWH(52, 286, 238, 300),
      );
      page.graphics.drawRectangle(
        pen: PdfPen(accent, width: 1.2),
        bounds: ui.Rect.fromLTWH(52, 286, 238, 300),
      );
    } else {
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(248, 245, 247)),
        pen: PdfPen(accent, width: 1.2),
        bounds: ui.Rect.fromLTWH(52, 286, 238, 300),
      );
      _text(page, 'Analysis photo', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(82, 420, 178, 22), alignCenter: true);
      _text(page, 'Photo unavailable in this report', PdfStandardFont(PdfFontFamily.helvetica, 8), muted, ui.Rect.fromLTWH(76, 450, 190, 20), alignCenter: true);
    }

    page.graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(251, 249, 252)),
      pen: PdfPen(PdfColor(232, 226, 234)),
      bounds: ui.Rect.fromLTWH(314, 286, 218, 300),
    );
    _text(page, 'YOUR PROFILE', PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(334, 310, 170, 16));
    _text(page, result.faceShape.isEmpty ? 'Face shape · Unknown' : 'Face shape · ${result.faceShape}', PdfStandardFont(PdfFontFamily.helvetica, 14, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(334, 345, 170, 32));
    _text(page, 'Undertone', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(334, 410, 70, 13));
    _text(page, result.undertone, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(334, 426, 170, 16));
    _text(page, 'Depth', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(334, 460, 70, 13));
    _text(page, result.brightness, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(334, 476, 170, 16));
    _text(page, 'Contrast', PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold), muted, ui.Rect.fromLTWH(334, 510, 70, 13));
    _text(page, result.contrast, PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(334, 526, 170, 16));

    _text(page, 'A personal reference built from your colour characteristics and face-shape analysis.', PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(52, 620, 480, 42));
  }

  static void _drawColourProfile(
    PdfPage page, {
    required ColourAnalysisResult result,
    required SeasonColourProfile profile,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
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

  static void _drawFaceShape(
    PdfPage page, {
    required ColourAnalysisResult result,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
    required Uint8List? photoBytes,
  }) {
    _header(page, '02 · FACE SHAPE ANALYSIS', 'Proportion-based facial outline analysis', accent, dark, muted);

    if (photoBytes != null) {
      page.graphics.drawImage(PdfBitmap(photoBytes), ui.Rect.fromLTWH(28, 108, 190, 238));
      page.graphics.drawRectangle(pen: PdfPen(accent, width: 1.1), bounds: ui.Rect.fromLTWH(28, 108, 190, 238));
    }

    final cardX = 238.0;
    page.graphics.drawRectangle(
      brush: PdfSolidBrush(soft),
      pen: PdfPen(border),
      bounds: ui.Rect.fromLTWH(cardX, 108, 296, 238),
    );
    _text(page, 'YOUR FACE SHAPE', PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(cardX + 18, 128, 180, 14));
    _text(page, result.faceShape.isEmpty ? 'Unknown' : result.faceShape, PdfStandardFont(PdfFontFamily.helvetica, 27, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(cardX + 18, 148, 240, 32));
    _text(page, result.faceShapeDescription.isEmpty ? 'Proportion-based result from the available face contour.' : result.faceShapeDescription, PdfStandardFont(PdfFontFamily.helvetica, 10), muted, ui.Rect.fromLTWH(cardX + 18, 196, 250, 68));

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
      page.graphics.drawRectangle(brush: PdfSolidBrush(whiteCell()), bounds: ui.Rect.fromLTWH(28, y, 506, 31));
      page.graphics.drawRectangle(pen: PdfPen(border), bounds: ui.Rect.fromLTWH(28, y, 506, 31));
      _text(page, row.key, PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(40, y + 8, 310, 16));
      _text(page, row.value, PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(378, y + 7, 138, 16), alignRight: true);
      y += 35;
    }
    _text(page, 'Face-shape classification is a styling reference; real faces can sit between categories.', PdfStandardFont(PdfFontFamily.helvetica, 8), muted, ui.Rect.fromLTWH(28, 612, 506, 24));
  }

  static void _drawFaceStyleGuide(
    PdfPage page, {
    required ColourAnalysisResult result,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
    _header(page, '03 · FACE SHAPE STYLE GUIDE', 'Turn your proportions into practical styling choices', accent, dark, muted);
    final tips = result.faceStylingGuidance.isEmpty
        ? const <String>[
            'Choose necklines that balance the visual length and width of your face.',
            'Use earrings to add or soften vertical movement around the face.',
            'Let hairstyle volume support the proportions identified in your analysis.',
          ]
        : result.faceStylingGuidance;

    final headings = ['NECKLINES', 'EARRINGS', 'HAIR & BALANCE'];
    final icons = [IconsSafe.neckline, IconsSafe.earrings, IconsSafe.hair];
    for (var i = 0; i < 3; i++) {
      final x = 28 + i * 171.0;
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, 125, 157, 255));
      page.graphics.drawEllipse(ui.Rect.fromLTWH(x + 15, 143, 34, 34), brush: PdfSolidBrush(accent));
      _text(page, icons[i], PdfStandardFont(PdfFontFamily.helvetica, 7, style: PdfFontStyle.bold), const PdfColor(255,255,255), ui.Rect.fromLTWH(x + 20, 154, 24, 12), alignCenter: true);
      _text(page, headings[i], PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(x + 15, 194, 125, 16));
      final group = tips.skip(i).take(i == 0 ? 3 : 3).toList();
      var y = 225.0;
      for (final tip in group.take(3)) {
        _text(page, '• $tip', PdfStandardFont(PdfFontFamily.helvetica, 8.5), muted, ui.Rect.fromLTWH(x + 15, y, 125, 48));
        y += 53;
      }
    }

    _sectionTitle(page, 'Your face-shape takeaway', 420, accent, dark);
    _text(page, result.faceShapeDescription.isEmpty ? 'Use your proportions as a styling guide rather than a fixed label.' : result.faceShapeDescription, PdfStandardFont(PdfFontFamily.helvetica, 11), muted, ui.Rect.fromLTWH(28, 460, 505, 48));
    _text(page, 'TiB uses this profile to inform future styling recommendations across wardrobe, AI styling and saved looks.', PdfStandardFont(PdfFontFamily.helvetica, 9.5), dark, ui.Rect.fromLTWH(28, 535, 505, 45));
  }

  static void _drawColourPalette(
    PdfPage page, {
    required ColourAnalysisResult result,
    required SeasonColourProfile profile,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
    _header(page, '04 · YOUR PERSONAL COLOUR PALETTE', 'Colours to start with when shopping and building outfits', accent, dark, muted);
    _sectionTitle(page, 'Best colours', 108, accent, dark);
    var y = 148.0;
    y = _largeSwatches(page, profile.bestColours, y, accent, dark, border);

    _sectionTitle(page, 'Best neutrals', y + 10, accent, dark);
    final neutrals = result.bestNeutrals.isEmpty ? _deriveNeutrals(profile.bestColours) : result.bestNeutrals;
    y = _largeSwatches(page, neutrals.take(8).toList(), y + 48, accent, dark, border);

    _sectionTitle(page, 'Accent colours', y + 10, accent, dark);
    final accents = result.accentColours.isEmpty ? profile.bestColours.take(6).toList() : result.accentColours;
    _largeSwatches(page, accents.take(8).toList(), y + 48, accent, dark, border);
  }

  static void _drawMakeupAndStyle(
    PdfPage page, {
    required ColourAnalysisResult result,
    required SeasonColourProfile profile,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
    _header(page, '05 · BEAUTY & COLOUR DETAILS', 'Makeup directions that follow your colour profile', accent, dark, muted);
    _sectionTitle(page, 'Eye shadow colour advice', 110, accent, dark);
    _largeSwatches(page, profile.eyeShadowColours.take(10).toList(), 150, accent, dark, border);

    _sectionTitle(page, 'Blush colour advice', 370, accent, dark);
    _largeSwatches(page, profile.blushColours.take(8).toList(), 410, accent, dark, border);

    final avoid = ProfessionalStyleData.avoidColours[result.season] ?? const <String>[];
    _sectionTitle(page, 'Use with intention', 585, accent, dark);
    _text(page, avoid.isEmpty ? 'Colours outside your core palette can still work when balanced with your best neutrals and signature shades.' : 'These colours are better used selectively or away from the face: ${avoid.join(', ')}.', PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(28, 625, 505, 50));
  }

  static void _drawStyleIdentity(
    PdfPage page, {
    required ColourAnalysisResult result,
    required SeasonColourProfile profile,
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
    _header(page, '06 · YOUR STYLE IDENTITY', 'A personal language built around your strongest signals', accent, dark, muted);

    final keywords = profile.keywords.take(12).toList();
    var x = 28.0;
    var y = 124.0;
    for (final keyword in keywords) {
      final width = 18 + keyword.length * 4.3;
      if (x + width > 530) {
        x = 28;
        y += 31;
      }
      page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(accent, width: .7), bounds: ui.Rect.fromLTWH(x, y, width, 23));
      _text(page, keyword, PdfStandardFont(PdfFontFamily.helvetica, 7.2), dark, ui.Rect.fromLTWH(x + 5, y + 5, width - 10, 13), alignCenter: true);
      x += width + 7;
    }

    _sectionTitle(page, 'Your signature direction', y + 65, accent, dark);
    final signature = _signatureSentence(result, profile);
    _text(page, signature, PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, y + 105, 505, 80));

    _sectionTitle(page, 'How this informs TiB', y + 215, accent, dark);
    _text(page, 'Your colour profile and face-shape profile can be carried into wardrobe matching, Style Me, AI outfit suggestions and future saved-look recommendations.', PdfStandardFont(PdfFontFamily.helvetica, 10), muted, ui.Rect.fromLTWH(28, y + 255, 505, 55));

    _sectionTitle(page, 'Your report at a glance', y + 345, accent, dark);
    _summaryRow(page, 28, y + 385, 'Colour', result.season, accent, dark, border);
    _summaryRow(page, 28, y + 423, 'Direction', profile.dimension, accent, dark, border);
    _summaryRow(page, 28, y + 461, 'Face shape', result.faceShape.isEmpty ? 'Unknown' : result.faceShape, accent, dark, border);
  }

  static void _drawReferenceGuide(
    PdfPage page, {
    required PdfColor accent,
    required PdfColor dark,
    required PdfColor muted,
    required PdfColor soft,
    required PdfColor border,
  }) {
    _header(page, '07 · SEASON REFERENCE', 'Use this guide to understand the four broad colour directions', accent, dark, muted);
    final profiles = SeasonColourGuide.profiles.values.toList();
    final positions = <ui.Rect>[
      ui.Rect.fromLTWH(28, 118, 248, 280),
      ui.Rect.fromLTWH(292, 118, 248, 280),
      ui.Rect.fromLTWH(28, 420, 248, 280),
      ui.Rect.fromLTWH(292, 420, 248, 280),
    ];
    for (var i = 0; i < profiles.length; i++) {
      final profile = profiles[i];
      final rect = positions[i];
      final color = _seasonColor(profile.name);
      page.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(251, 249, 252)), pen: PdfPen(color, width: 1), bounds: rect);
      _text(page, profile.name.toUpperCase(), PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), color, ui.Rect.fromLTWH(rect.left + 14, rect.top + 14, rect.width - 28, 18));
      _text(page, profile.dimension, PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(rect.left + 14, rect.top + 41, rect.width - 28, 16));
      _text(page, profile.description, PdfStandardFont(PdfFontFamily.helvetica, 8.2), muted, ui.Rect.fromLTWH(rect.left + 14, rect.top + 66, rect.width - 28, 48));
      _largeSwatches(page, profile.bestColours.take(5).toList(), rect.top + 125, color, dark, border, swatchWidth: 39, swatchHeight: 18, gapX: 7, gapY: 38);
    }
  }

  static void _header(PdfPage page, String title, String subtitle, PdfColor accent, PdfColor dark, PdfColor muted) {
    _text(page, 'TiB', PdfStandardFont(PdfFontFamily.helvetica, 15, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(28, 24, 60, 18));
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 16, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, 54, 505, 22));
    _text(page, subtitle, PdfStandardFont(PdfFontFamily.helvetica, 9.5), muted, ui.Rect.fromLTWH(28, 79, 505, 17));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, 101, 48, 3));
  }

  static void _sectionTitle(PdfPage page, String title, double y, PdfColor accent, PdfColor dark) {
    _text(page, title, PdfStandardFont(PdfFontFamily.helvetica, 13, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(28, y, 505, 20));
    page.graphics.drawRectangle(brush: PdfSolidBrush(accent), bounds: ui.Rect.fromLTWH(28, y + 24, 38, 2));
  }

  static void _metricCard(PdfPage page, double x, double y, double width, String label, String value, PdfColor accent, PdfColor dark, PdfColor soft, PdfColor border) {
    page.graphics.drawRectangle(brush: PdfSolidBrush(soft), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, y, width, 68));
    page.graphics.drawEllipse(ui.Rect.fromLTWH(x + 13, y + 14, 16, 16), brush: PdfSolidBrush(accent));
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 7.8, style: PdfFontStyle.bold), PdfColor(120, 114, 122), ui.Rect.fromLTWH(x + 36, y + 12, width - 48, 12));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 11.2, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x + 13, y + 37, width - 26, 18));
  }

  static void _dimensionBar(PdfPage page, double x, double y, String label, String value, List<String> options, PdfColor accent, PdfColor dark, PdfColor muted, PdfColor border) {
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x, y, 100, 16));
    final selectedIndex = options.indexWhere((option) => option.toLowerCase() == value.toLowerCase());
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final width = 395.0 / options.length;
    for (var i = 0; i < options.length; i++) {
      final rect = ui.Rect.fromLTWH(x + 105 + i * width, y - 2, width - 4, 25);
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(i == safeIndex ? accent : const PdfColor(249, 247, 250)),
        pen: PdfPen(border),
        bounds: rect,
      );
      _text(page, options[i], PdfStandardFont(PdfFontFamily.helvetica, 7), i == safeIndex ? const PdfColor(255,255,255) : muted, rect, alignCenter: true);
    }
  }

  static double _largeSwatches(
    PdfPage page,
    List<String> names,
    double y,
    PdfColor accent,
    PdfColor dark,
    PdfColor border, {
    double swatchWidth = 75,
    double swatchHeight = 31,
    double gapX = 10,
    double gapY = 58,
  }) {
    const startX = 28.0;
    final columns = swatchWidth <= 45 ? 5 : 6;
    for (var i = 0; i < names.length; i++) {
      final row = i ~/ columns;
      final col = i % columns;
      final x = startX + col * (swatchWidth + gapX);
      final top = y + row * gapY;
      page.graphics.drawRectangle(brush: PdfSolidBrush(_colourFor(names[i], accent)), pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, top, swatchWidth, swatchHeight));
      _text(page, names[i], PdfStandardFont(PdfFontFamily.helvetica, swatchWidth <= 45 ? 5.5 : 6.7), dark, ui.Rect.fromLTWH(x, top + swatchHeight + 3, swatchWidth, 17), alignCenter: true);
    }
    final rows = (names.length / columns).ceil();
    return y + math.max(1, rows) * gapY;
  }

  static List<String> _deriveNeutrals(List<String> colours) {
    final result = <String>[];
    for (final colour in colours) {
      final key = colour.toLowerCase();
      if (key.contains('cream') || key.contains('beige') || key.contains('camel') || key.contains('brown') || key.contains('chocolate')) {
        result.add(colour);
      }
    }
    return result.isEmpty ? colours.take(5).toList() : result;
  }

  static String _signatureSentence(ColourAnalysisResult result, SeasonColourProfile profile) {
    final face = result.faceShape.isEmpty || result.faceShape == 'Unknown' ? 'your natural proportions' : '${result.faceShape.toLowerCase()} facial proportions';
    return 'Your strongest direction is ${profile.dimension.toLowerCase()}, expressed through ${profile.keywords.take(3).join(', ').toLowerCase()} energy and styling that respects $face.';
  }

  static String _formatMeasurement(double? value, {String suffix = ''}) {
    if (value == null) return '—';
    return '${value.toStringAsFixed(value.abs() >= 10 ? 1 : 3)}$suffix';
  }

  static PdfColor whiteCell() => const PdfColor(255, 255, 255);

  static PdfColor _seasonColor(String season) {
    switch (season) {
      case 'Winter':
        return const PdfColor(66, 92, 150);
      case 'Summer':
        return const PdfColor(139, 105, 182);
      case 'Spring':
        return const PdfColor(224, 145, 82);
      case 'Autumn':
        return const PdfColor(157, 91, 55);
      default:
        return const PdfColor(139, 105, 182);
    }
  }

  static PdfColor _colourFor(String name, PdfColor accent) {
    final key = name.toLowerCase();
    if (key.contains('white') || key.contains('ivory')) return const PdfColor(245, 243, 238);
    if (key.contains('black')) return const PdfColor(38, 36, 38);
    if (key.contains('charcoal')) return const PdfColor(70, 73, 80);
    if (key.contains('navy')) return const PdfColor(38, 57, 88);
    if (key.contains('blue') || key.contains('sapphire') || key.contains('cobalt')) return const PdfColor(65, 115, 176);
    if (key.contains('lavender') || key.contains('lilac') || key.contains('mauve')) return const PdfColor(176, 151, 193);
    if (key.contains('pink') || key.contains('rose') || key.contains('raspberry')) return const PdfColor(211, 132, 155);
    if (key.contains('red') || key.contains('ruby') || key.contains('cranberry')) return const PdfColor(167, 65, 74);
    if (key.contains('peach') || key.contains('apricot') || key.contains('coral')) return const PdfColor(230, 141, 116);
    if (key.contains('yellow') || key.contains('gold')) return const PdfColor(210, 174, 70);
    if (key.contains('green') || key.contains('olive') || key.contains('mint')) return const PdfColor(108, 135, 82);
    if (key.contains('brown') || key.contains('camel') || key.contains('chocolate') || key.contains('sienna')) return const PdfColor(143, 103, 74);
    if (key.contains('beige') || key.contains('cream') || key.contains('taupe')) return const PdfColor(205, 186, 157);
    if (key.contains('grey') || key.contains('gray')) return const PdfColor(154, 153, 157);
    return accent;
  }

  static Future<Uint8List?> _loadImageBytes(String url) async {
    if (url.trim().isEmpty) return null;
    try {
      if (url.startsWith('data:image/')) {
        final comma = url.indexOf(',');
        if (comma > 0) {
          final encoded = url.substring(comma + 1);
          return Uint8List.fromList(UriData.parse(url).contentBytes);
        }
      }
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {
      // Report remains usable without the remote photo.
    }
    return null;
  }

  static void _summaryRow(PdfPage page, double x, double y, String label, String value, PdfColor accent, PdfColor dark, PdfColor border) {
    page.graphics.drawRectangle(pen: PdfPen(border), bounds: ui.Rect.fromLTWH(x, y, 506, 30));
    _text(page, label, PdfStandardFont(PdfFontFamily.helvetica, 8.5, style: PdfFontStyle.bold), dark, ui.Rect.fromLTWH(x + 12, y + 7, 120, 15));
    _text(page, value, PdfStandardFont(PdfFontFamily.helvetica, 9.5, style: PdfFontStyle.bold), accent, ui.Rect.fromLTWH(x + 150, y + 7, 344, 15), alignRight: true);
  }

  static void _addFooters(PdfDocument document, {required String date, required PdfColor accent, required PdfColor muted}) {
    for (var i = 0; i < document.pages.count; i++) {
      final page = document.pages[i];
      final size = page.getClientSize();
      page.graphics.drawLine(PdfPen(PdfColor(232, 226, 234)), ui.Offset(28, size.height - 28), ui.Offset(size.width - 28, size.height - 28));
      _text(page, 'TiB AI Personal Styling', PdfStandardFont(PdfFontFamily.helvetica, 7), muted, ui.Rect.fromLTWH(28, size.height - 23, 180, 12));
      _text(page, '${i + 1}  ·  $date', PdfStandardFont(PdfFontFamily.helvetica, 7), muted, ui.Rect.fromLTWH(360, size.height - 23, 175, 12), alignRight: true);
    }
  }

  static void _text(PdfPage page, String text, PdfFont font, PdfColor color, ui.Rect bounds, {bool alignCenter = false, bool alignRight = false}) {
    final textSize = font.measureString(text);
    var x = bounds.left;
    if (alignRight) {
      x = bounds.right - textSize.width;
    } else if (alignCenter) {
      x = bounds.left + (bounds.width - textSize.width) / 2;
    }
    if (x < bounds.left) x = bounds.left;
    page.graphics.drawString(text, font, brush: PdfSolidBrush(color), bounds: ui.Rect.fromLTWH(x, bounds.top, textSize.width + 2, bounds.height));
  }
}

class IconsSafe {
  static const neckline = 'N';
  static const earrings = 'E';
  static const hair = 'H';
}
