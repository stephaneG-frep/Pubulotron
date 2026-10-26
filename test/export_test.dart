import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pubulotron/data/asset_store.dart';
import 'package:pubulotron/editor/editor_controller.dart';
import 'package:pubulotron/editor/element_factory.dart';
import 'package:pubulotron/engine/image_cache.dart';
import 'package:pubulotron/export/creations_zip.dart';
import 'package:pubulotron/export/file_service.dart';
import 'package:pubulotron/export/raster_exporter.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/layout/pack_builder.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/print/pdf_exporter.dart';

import 'helpers/test_support.dart';

void main() {
  testWidgets('ZIP of several creations: PDF and PNG per face, unique names', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final store = AssetStore(tempDir('zip'));
      final projects = [
        Project(name: 'Carte', document: richSampleDocument()),
        Project(name: 'Carte', document: richSampleDocument()),
        ...PackBuilder.build(
          kit: BrandKit.fromProfile(BusinessProfile.example()),
          profile: BusinessProfile.example(),
        ).where((p) => p.packRole == 'post'),
      ];
      final zip = await buildCreationsZip(
        projects,
        pdf: PdfExporter(store: store),
        raster: RasterExporter(DesignImageCache(store)),
        dpi: 72,
      );
      final archive = ZipDecoder().decodeBytes(zip);
      final names = archive.files.map((f) => f.name).toSet();
      expect(
        names,
        containsAll([
          'Carte.pdf',
          'Carte_2.pdf',
          'Carte_recto.png',
          'Carte_verso.png',
          'Carte_recto_2.png',
          'Toutes_les_creations.pdf',
        ]),
      );
      expect(names.length, archive.files.length, reason: 'aucun doublon');
      final post = archive.files.firstWhere(
        (f) => f.name.endsWith('Publication_réseaux_sociaux.png'),
      );
      final image = img.decodePng(post.readBytes()!)!;
      expect(
        [image.width, image.height],
        [1080, 1080],
        reason: 'taille exacte des formats réseaux sociaux',
      );
    });
  });

  test('safe file names', () {
    expect(safeFileName('Carte: été/2026 ?', 'pdf'), 'Carte-_été-2026_-.pdf');
    expect(safeFileName('   ', 'png'), 'pubulotron.png');
  });

  test('typing in a text field is a single undo step', () {
    final element = DesignElement(
      id: 't',
      type: ElementType.text,
      text: '',
      x: 0,
      y: 0,
      width: 20,
      height: 5,
    );
    final c = EditorController(
      project: Project(
        name: 'x',
        document: DesignDocument(
          widthMm: 85,
          heightMm: 55,
          pages: [
            DesignPage(elements: [element]),
          ],
        ),
      ),
    );
    c.beginTransaction();
    for (final text in ['B', 'Bo', 'Bon', 'Bonjour']) {
      c.updateElement('t', (e) => e.copyWith(text: text));
    }
    c.endTransaction();
    expect(c.page.elementById('t')!.text, 'Bonjour');
    c.undo();
    expect(c.page.elementById('t')!.text, '');
    expect(c.canUndo, isFalse);
  });

  test('element factory scales defaults to the document size', () {
    final card = ElementFactory(const Size(85, 55));
    final poster = ElementFactory(const Size(297, 420));
    final shapeCard = card.shape(ShapeKind.ellipse);
    final shapePoster = poster.shape(ShapeKind.ellipse);
    expect(shapePoster.width / shapeCard.width, closeTo(297 / 55, 0.01));
    expect(shapeCard.x + shapeCard.width / 2, closeTo(42.5, 1e-9));
    final logo = card.image('logo.png', const Size(400, 100), logo: true);
    expect(logo.width / logo.height, closeTo(4, 1e-9));
    expect(logo.imageFit, ImageFit.contain);
    final qr = card.qr('https://pubulotron.fr');
    expect(qr.width, qr.height);
    expect(qr.width, greaterThanOrEqualTo(14));
    expect(() => card.qr(''), throwsArgumentError);
  });
}
