import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/units.dart';
import '../data/asset_store.dart';
import '../engine/page_renderer.dart';
import '../engine/pdf_canvas.dart';
import '../models/design_document.dart';
import 'imposition.dart';
import 'sheet_renderer.dart';

class PdfExportResult {
  const PdfExportResult(this.bytes, this.pageCount, this.missingImages);

  final Uint8List bytes;
  final int pageCount;

  /// Images référencées mais introuvables dans la médiathèque.
  final List<String> missingImages;
}

/// Génération de PDF vectoriels à partir des documents.
class PdfExporter {
  PdfExporter({this.store, this.loadAsset});

  final AssetStore? store;
  final AssetLoader? loadAsset;

  pw.Document _newDocument(String title) => pw.Document(
    title: title,
    author: 'Pubulotron',
    creator: 'Pubulotron',
    producer: 'Pubulotron',
    compress: true,
  );

  void _addPage(
    pw.Document doc,
    double widthMm,
    double heightMm,
    void Function(PdfDesignCanvas canvas) paint,
    PdfRenderResources res,
  ) {
    final format = PdfPageFormat(
      mmToPdf(widthMm),
      mmToPdf(heightMm),
      marginAll: 0,
    );
    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.CustomPaint(
          size: PdfPoint(format.width, format.height),
          painter: (graphics, size) {
            final canvas = PdfDesignCanvas(graphics, res)
              ..setupMillimetres(heightMm);
            paint(canvas);
          },
        ),
      ),
    );
  }

  /// Une page par face, au format fini (plus le fond perdu éventuel).
  Future<PdfExportResult> exportDocument(
    DesignDocument design, {
    String title = 'Création Pubulotron',
    double bleedMm = 0,
  }) => exportDocuments([design], title: title, bleedMm: bleedMm);

  /// Plusieurs créations dans un seul PDF (pack publicitaire).
  Future<PdfExportResult> exportDocuments(
    List<DesignDocument> designs, {
    String title = 'Pack Pubulotron',
    double bleedMm = 0,
  }) async {
    final doc = _newDocument(title);
    final res = await PdfRenderResources.prepare(
      doc.document,
      designs,
      store: store,
      loadAsset: loadAsset,
    );
    var pages = 0;
    for (final design in designs) {
      for (final page in design.pages) {
        _addPage(
          doc,
          design.widthMm + 2 * bleedMm,
          design.heightMm + 2 * bleedMm,
          (canvas) {
            PageRenderer.paint(
              canvas,
              page,
              design.sizeMm,
              options: RenderOptions(
                bleedMm: bleedMm,
                resolveImage: res.designImage,
              ),
            );
          },
          res,
        );
        pages++;
      }
    }
    return PdfExportResult(
      Uint8List.fromList(await doc.save()),
      pages,
      res.missingImages,
    );
  }

  /// Planches multiposes : recto puis verso pour chaque feuille.
  Future<PdfExportResult> exportImposed(
    DesignDocument design,
    Imposition imposition, {
    bool duplex = false,
    String title = 'Planche d’impression Pubulotron',
  }) async {
    final doc = _newDocument(title);
    final res = await PdfRenderResources.prepare(
      doc.document,
      [design],
      store: store,
      loadAsset: loadAsset,
    );
    final withBack = duplex && design.isDuplex;
    var pages = 0;
    for (var sheet = 0; sheet < imposition.sheetCount; sheet++) {
      for (final back in [false, if (withBack) true]) {
        _addPage(doc, imposition.sheetWidthMm, imposition.sheetHeightMm, (
          canvas,
        ) {
          SheetRenderer.paint(
            canvas,
            document: design,
            imposition: imposition,
            sheet: sheet,
            back: back,
            resolveImage: res.designImage,
          );
        }, res);
        pages++;
      }
    }
    return PdfExportResult(
      Uint8List.fromList(await doc.save()),
      pages,
      res.missingImages,
    );
  }
}
