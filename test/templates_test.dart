import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pubulotron/engine/text_layout.dart';
import 'package:pubulotron/export/raster_exporter.dart';
import 'package:pubulotron/layout/brand_kit.dart';
import 'package:pubulotron/layout/layout_engine.dart';
import 'package:pubulotron/layout/pack_builder.dart';
import 'package:pubulotron/layout/template_catalog.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_element.dart';

import 'helpers/test_support.dart';

void main() {
  testWidgets('every category has templates and they fit their page', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      TextLayoutEngine.clearCache();
      for (final category in TemplateCatalog.categories) {
        expect(
          TemplateCatalog.all.where((t) => t.category == category).length,
          greaterThanOrEqualTo(2),
          reason: category,
        );
      }
      final out = Platform.environment['TEMPLATES_OUT'];
      for (final template in TemplateCatalog.all) {
        final doc = TemplateCatalog.instantiate(template);
        expect(doc.widthMm, template.format.widthMm);
        expect(
          doc.pages.length,
          template.format.duplex ? 2 : 1,
          reason: template.id,
        );
        for (final page in doc.pages) {
          expect(page.elements, isNotEmpty, reason: template.id);
          for (final e in page.elements.where(
            (e) => e.type == ElementType.text,
          )) {
            final layout = TextLayoutEngine.layout(e);
            expect(
              layout.height,
              lessThanOrEqualTo(e.height + 0.05),
              reason: '${template.id}: « ${e.text} » déborde',
            );
            expect(
              e.x,
              greaterThanOrEqualTo(-0.01),
              reason: '${template.id}: ${e.text}',
            );
            expect(
              e.x + e.width,
              lessThanOrEqualTo(doc.widthMm + 0.01),
              reason: '${template.id}: ${e.text}',
            );
            expect(
              e.y + e.height,
              lessThanOrEqualTo(doc.heightMm + 0.01),
              reason: '${template.id}: ${e.text}',
            );
          }
        }
        if (out != null) {
          Directory(out).createSync(recursive: true);
          for (var i = 0; i < doc.pages.length; i++) {
            final png = await RasterExporter(null)
                .export(doc, pageIndex: i, dpi: 100);
            File(p.join(out, '${template.id}_$i.png')).writeAsBytesSync(png);
          }
        }
      }
    });
  });

  testWidgets('pack shares palette and fonts across five supports', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await loadAppFonts();
      final profile = BusinessProfile.example();
      final kit = BrandKit.fromProfile(
        profile,
        layout: LayoutStyle.neon,
        brief: 'promo -15 %',
      );
      final projects = PackBuilder.build(kit: kit, profile: profile);
      expect(projects, hasLength(5));
      expect(projects.map((p) => p.packId).toSet(), hasLength(1));
      expect(projects.map((p) => p.packRole), [
        'card',
        'flyer',
        'poster',
        'post',
        'story',
      ]);
      for (final project in projects) {
        final texts = project.document.front.elements.where(
          (e) => e.role == 'headline',
        );
        expect(texts, isNotEmpty, reason: project.name);
        expect(texts.first.fontFamily, kit.headingFont);
      }
      expect(kit.offer, '-15 %');
      final out = Platform.environment['TEMPLATES_OUT'];
      if (out != null) {
        for (final project in projects) {
          final png = await RasterExporter(null)
              .export(project.document, dpi: 60);
          File(p.join(out, 'pack_${project.packRole}.png'))
              .writeAsBytesSync(png);
        }
      }
    });
  });

  test('brief keywords drive offline styles and palette', () {
    expect(
      LayoutEngine.stylesForBrief('carte futuriste informatique').first,
      LayoutStyle.neon,
    );
    expect(
      LayoutEngine.stylesForBrief('flyer jardinage vert').first,
      LayoutStyle.nature,
    );
    final kit = LayoutEngine.kitForBrief(
      BrandKit.fromProfile(BusinessProfile.example()),
      'fond bleu électrique',
    );
    expect(kit.primary.toARGB32(), 0xFF1E6BFF);
  });
}
