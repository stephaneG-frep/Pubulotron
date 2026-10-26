import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pubulotron/data/asset_store.dart';
import 'package:pubulotron/print/imposition.dart';
import 'package:pubulotron/print/pdf_exporter.dart';

import 'helpers/test_support.dart';

/// Valeurs « /MediaBox » de chaque page (le dictionnaire des pages n'est pas compressé).
List<String> mediaBoxes(List<int> bytes) =>
    RegExp(r'/MediaBox\s*\[([^\]]+)\]')
        .allMatches(latin1.decode(bytes))
        .map((m) => m.group(1)!.trim())
        .toList();

void main() {
  testWidgets('multipose PDF: 100 cards, recto verso, A4 sheets', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final store = AssetStore(tempDir('pdf'));
      final photo = await store.importBytes(
        samplePhotoPng(),
        fileName: 'p.png',
      );
      final doc = richSampleDocument(photoAssetId: photo);
      const settings = PrintSettings(
        copies: 100,
        marginMm: 10,
        bleedMm: 2,
        duplex: true,
        orientation: SheetOrientation.portrait,
      );
      final imposition = Imposition.compute(
        settings: settings,
        cardWidthMm: doc.widthMm,
        cardHeightMm: doc.heightMm,
      );
      expect(imposition.perSheet, 8);
      expect(imposition.sheetCount, 13);

      final result = await PdfExporter(store: store)
          .exportImposed(doc, imposition, duplex: true);
      expect(result.pageCount, 26, reason: '13 feuilles × recto + verso');
      expect(result.missingImages, isEmpty);
      final boxes = mediaBoxes(result.bytes);
      expect(boxes, hasLength(26));
      final dims = boxes.first.split(RegExp(r'\s+')).map(double.parse).toList();
      expect(dims[2], closeTo(595.28, 0.05));
      expect(dims[3], closeTo(841.89, 0.05));

      final single = await PdfExporter(store: store)
          .exportImposed(doc, imposition);
      expect(
        single.pageCount,
        13,
        reason: 'recto seul quand le recto verso est désactivé',
      );

      final out = Platform.environment['FIDELITY_OUT'];
      if (out != null) {
        File(p.join(out, 'multipose.pdf')).writeAsBytesSync(result.bytes);
      }
    });
  });

  testWidgets(
    'single creation PDF uses the exact physical size, with optional bleed',
    (tester) async {
      await tester.runAsync(() async {
        await loadAppFonts();
        final doc = richSampleDocument();
        final plain = await PdfExporter().exportDocument(doc);
        final dims = mediaBoxes(plain.bytes).first
            .split(RegExp(r'\s+'))
            .map(double.parse)
            .toList();
        expect(dims[2], closeTo(85 * 72 / 25.4, 0.05));
        expect(dims[3], closeTo(55 * 72 / 25.4, 0.05));
        final bleed = await PdfExporter().exportDocument(doc, bleedMm: 3);
        final bleedDims = mediaBoxes(bleed.bytes).first
            .split(RegExp(r'\s+'))
            .map(double.parse)
            .toList();
        expect(bleedDims[2], closeTo(91 * 72 / 25.4, 0.05));
        final pack = await PdfExporter().exportDocuments([doc, doc]);
        expect(pack.pageCount, 4);
      });
    },
  );

  testWidgets('missing images are reported instead of crashing the export', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final store = AssetStore(tempDir('pdf-missing'));
      final result = await PdfExporter(store: store)
          .exportDocument(richSampleDocument(photoAssetId: 'absent.png'));
      expect(result.missingImages, ['absent.png']);
      expect(result.pageCount, 2);
    });
  });
}
