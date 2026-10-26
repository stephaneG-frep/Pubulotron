import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pubulotron/data/asset_store.dart';
import 'package:pubulotron/engine/image_cache.dart';
import 'package:pubulotron/export/raster_exporter.dart';
import 'package:pubulotron/print/pdf_exporter.dart';

import 'helpers/test_support.dart';

/// Génère le même document en PNG (moteur d'aperçu) et en PDF vectoriel.
/// Si FIDELITY_OUT est défini, les fichiers y sont écrits pour comparaison
/// pixel à pixel (voir tool/check_fidelity.sh).
void main() {
  testWidgets('PNG export matches physical size and PDF is produced', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final store = AssetStore(tempDir('fidelity'));
      final photo = await store.importBytes(
        samplePhotoPng(),
        fileName: 'photo.png',
      );
      final doc = richSampleDocument(photoAssetId: photo);
      final cache = DesignImageCache(store);

      final png = await RasterExporter(cache).export(doc, dpi: 254);
      final decoded = img.decodePng(png)!;
      expect(decoded.width, 850);
      expect(decoded.height, 550);

      final jpeg = await RasterExporter(cache)
          .export(doc, dpi: 254, format: RasterFormat.jpeg);
      expect(img.decodeJpg(jpeg)!.width, 850);

      final pdf = await PdfExporter(store: store).exportDocument(doc);
      expect(pdf.pageCount, 2);
      expect(String.fromCharCodes(pdf.bytes.take(5)), '%PDF-');
      expect(pdf.missingImages, isEmpty);

      final out = Platform.environment['FIDELITY_OUT'];
      if (out != null) {
        Directory(out).createSync(recursive: true);
        File(p.join(out, 'flutter.png')).writeAsBytesSync(png);
        File(p.join(out, 'export.pdf')).writeAsBytesSync(pdf.bytes);
      }
    });
  });
}
