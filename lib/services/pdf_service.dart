import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/pubulotron_models.dart';

double mm(double value) => value * PdfPageFormat.mm;

class PrintPlacement {
  const PrintPlacement({
    required this.copy,
    required this.page,
    required this.leftMm,
    required this.topMm,
  });

  final int copy;
  final int page;
  final double leftMm;
  final double topMm;
}

class PrintLayout {
  const PrintLayout({
    required this.paperWidthMm,
    required this.paperHeightMm,
    required this.columns,
    required this.rows,
    required this.placements,
  });

  final double paperWidthMm;
  final double paperHeightMm;
  final int columns;
  final int rows;
  final List<PrintPlacement> placements;

  int get copiesPerPage => columns * rows;
  int get pageCount => placements.isEmpty ? 0 : placements.last.page + 1;
}

class PrintLayoutService {
  static PrintLayout calculateLayout(
    PrintLayoutSpec spec, {
    bool cutMarks = false,
  }) {
    final dimensions = [
      spec.paperWidthMm,
      spec.paperHeightMm,
      spec.cardWidthMm,
      spec.cardHeightMm,
      spec.marginMm,
      spec.gapMm,
      spec.bleedMm,
    ];
    if (dimensions.any((value) => !value.isFinite) ||
        spec.paperWidthMm <= 0 ||
        spec.paperHeightMm <= 0 ||
        spec.cardWidthMm <= 0 ||
        spec.cardHeightMm <= 0 ||
        spec.marginMm < 0 ||
        spec.gapMm < 0 ||
        spec.bleedMm < 0 ||
        spec.copies < 1) {
      throw ArgumentError(
        'Les dimensions et le nombre d’exemplaires doivent être valides.',
      );
    }

    final orientation = spec.orientation.toLowerCase();
    if (orientation != 'portrait' && orientation != 'landscape') {
      throw ArgumentError('L’orientation doit être portrait ou paysage.');
    }
    if (cutMarks && spec.marginMm + spec.bleedMm < 2) {
      throw ArgumentError(
        'Les marges ou le fond perdu sont insuffisants pour les traits de découpe.',
      );
    }

    final landscape = orientation == 'landscape';
    final paperWidth = landscape
        ? math.max(spec.paperWidthMm, spec.paperHeightMm)
        : math.min(spec.paperWidthMm, spec.paperHeightMm);
    final paperHeight = landscape
        ? math.min(spec.paperWidthMm, spec.paperHeightMm)
        : math.max(spec.paperWidthMm, spec.paperHeightMm);
    final usableWidth = paperWidth - 2 * spec.marginMm;
    final usableHeight = paperHeight - 2 * spec.marginMm;
    final stepWidth = spec.cardWidthMm + 2 * spec.bleedMm + spec.gapMm;
    final stepHeight = spec.cardHeightMm + 2 * spec.bleedMm + spec.gapMm;
    final columns = ((usableWidth + spec.gapMm) / stepWidth).floor();
    final rows = ((usableHeight + spec.gapMm) / stepHeight).floor();

    if (columns < 1 || rows < 1) {
      throw ArgumentError(
        'La création ne tient pas sur la feuille avec ces marges et ce fond perdu.',
      );
    }

    final placements = <PrintPlacement>[];
    final copiesPerPage = columns * rows;
    for (var copy = 0; copy < spec.copies; copy++) {
      final slot = copy % copiesPerPage;
      final page = copy ~/ copiesPerPage;
      placements.add(
        PrintPlacement(
          copy: copy,
          page: page,
          leftMm: spec.marginMm + spec.bleedMm + (slot % columns) * stepWidth,
          topMm: spec.marginMm + spec.bleedMm + (slot ~/ columns) * stepHeight,
        ),
      );
    }

    return PrintLayout(
      paperWidthMm: paperWidth,
      paperHeightMm: paperHeight,
      columns: columns,
      rows: rows,
      placements: placements,
    );
  }

  static Future<Uint8List> buildPdf({
    required PrintLayoutSpec spec,
    required List<CreativeElement> elements,
    bool cutMarks = true,
  }) async {
    final layout = calculateLayout(spec, cutMarks: cutMarks);
    final images = <String, pw.MemoryImage>{};
    for (final element in elements) {
      final path = element.imagePath;
      if (element.kind == 'image' && path != null) {
        final file = File(path);
        if (!await file.exists()) {
          throw FileSystemException(
            'Image introuvable pour l’export PDF',
            path,
          );
        }
        images[path] = pw.MemoryImage(await file.readAsBytes());
      }
    }

    final pageFormat = PdfPageFormat(
      mm(layout.paperWidthMm),
      mm(layout.paperHeightMm),
    );
    final regularFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
    );
    final boldFont = pw.Font.ttf(
      await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
    );
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );
    for (var pageIndex = 0; pageIndex < layout.pageCount; pageIndex++) {
      final pagePlacements = layout.placements.where(
        (placement) => placement.page == pageIndex,
      );
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              for (final placement in pagePlacements)
                ..._buildDesign(
                  placement,
                  elements,
                  images,
                  spec.cardWidthMm,
                  spec.cardHeightMm,
                ),
              if (cutMarks)
                for (final placement in pagePlacements)
                  ..._buildCutMarks(
                    placement,
                    spec.cardWidthMm,
                    spec.cardHeightMm,
                  ),
            ],
          ),
        ),
      );
    }

    return Uint8List.fromList(await document.save());
  }

  static Future<void> printMultiples({
    required PrintLayoutSpec spec,
    required List<CreativeElement> elements,
    bool cutMarks = true,
  }) async {
    final bytes = await buildPdf(
      spec: spec,
      elements: elements,
      cutMarks: cutMarks,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static List<pw.Widget> _buildDesign(
    PrintPlacement placement,
    List<CreativeElement> elements,
    Map<String, pw.MemoryImage> images,
    double cardWidthMm,
    double cardHeightMm,
  ) {
    return [
      pw.Positioned(
        left: mm(placement.leftMm),
        top: mm(placement.topMm),
        child: pw.SizedBox(
          width: mm(cardWidthMm),
          height: mm(cardHeightMm),
          child: pw.ClipRect(
            child: pw.Stack(
              children: elements.map((element) {
                final left = element.x * cardWidthMm;
                final top = element.y * cardHeightMm;
                final width = element.width / 320 * cardWidthMm;
                final height = element.height / 360 * cardHeightMm;
                final color = PdfColor.fromInt(element.color.toARGB32());
                final image = element.imagePath == null
                    ? null
                    : images[element.imagePath];
                final cornerRadius = mm(
                  (element.kind == 'image' ? 18 : 12) / 320 * cardWidthMm,
                );
                return pw.Positioned(
                  left: mm(left),
                  top: mm(top),
                  child: pw.SizedBox(
                    width: mm(width),
                    height: mm(height),
                    child: pw.Transform.rotate(
                      angle: element.rotation,
                      child: pw.Opacity(
                        opacity:
                            (element.opacity *
                                    (image != null || element.kind == 'shape'
                                        ? 1
                                        : 0.9))
                                .clamp(0.0, 1.0),
                        child: image != null
                            ? pw.ClipRRect(
                                horizontalRadius: cornerRadius,
                                verticalRadius: cornerRadius,
                                child: pw.Image(image, fit: pw.BoxFit.cover),
                              )
                            : pw.Container(
                                alignment: pw.Alignment.center,
                                padding: pw.EdgeInsets.fromLTRB(
                                  mm(10 / 320 * cardWidthMm),
                                  mm(10 / 360 * cardHeightMm),
                                  mm(10 / 320 * cardWidthMm),
                                  mm(10 / 360 * cardHeightMm),
                                ),
                                decoration: pw.BoxDecoration(
                                  color: color,
                                  borderRadius: pw.BorderRadius.circular(
                                    cornerRadius,
                                  ),
                                ),
                                child: element.kind == 'shape'
                                    ? null
                                    : pw.Text(
                                        element.textContent ?? element.name,
                                        textAlign: pw.TextAlign.center,
                                        style: pw.TextStyle(
                                          color: PdfColors.white,
                                          fontSize: mm(
                                            element.fontSize /
                                                320 *
                                                cardWidthMm,
                                          ),
                                          fontWeight: pw.FontWeight.bold,
                                        ),
                                      ),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ];
  }

  static List<pw.Widget> _buildCutMarks(
    PrintPlacement placement,
    double cardWidthMm,
    double cardHeightMm,
  ) {
    const markLengthMm = 2.0;
    const strokeMm = 0.15;
    final left = placement.leftMm;
    final top = placement.topMm;
    final right = left + cardWidthMm;
    final bottom = top + cardHeightMm;
    final markColor = PdfColors.grey700;

    pw.Widget line(double x, double y, double width, double height) {
      return pw.Positioned(
        left: mm(x),
        top: mm(y),
        child: pw.SizedBox(
          width: mm(width),
          height: mm(height),
          child: pw.Container(color: markColor),
        ),
      );
    }

    return [
      line(left - markLengthMm, top, markLengthMm, strokeMm),
      line(left, top - markLengthMm, strokeMm, markLengthMm),
      line(right, top - markLengthMm, strokeMm, markLengthMm),
      line(right, top, markLengthMm, strokeMm),
      line(left - markLengthMm, bottom, markLengthMm, strokeMm),
      line(left, bottom, strokeMm, markLengthMm),
      line(right, bottom, strokeMm, markLengthMm),
      line(right, bottom, markLengthMm, strokeMm),
    ];
  }
}
