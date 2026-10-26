import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/data/legacy_converter.dart';
import 'package:pubulotron/models/app_settings.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';
import 'package:pubulotron/models/project.dart';
import 'package:pubulotron/print/imposition.dart';

import 'helpers/test_support.dart';

void main() {
  test('document survives a JSON round trip with every property', () {
    final doc = richSampleDocument(photoAssetId: 'img-1.png');
    final restored = DesignDocument.fromJson(
      jsonDecode(jsonEncode(doc.toJson())) as Map<String, dynamic>,
    );
    expect(jsonEncode(restored.toJson()), jsonEncode(doc.toJson()));
    expect(restored.pages, hasLength(2));
    final text = restored.front.elements.firstWhere(
      (e) => e.type == ElementType.text,
    );
    expect(text.fontFamily, 'Ubuntu');
    expect(text.bold, isTrue);
    final star = restored.front.elements.firstWhere(
      (e) => e.shape == ShapeKind.star,
    );
    expect(star.rotation, 15);
    expect(restored.front.background.kind, FillKind.linear);
    expect(restored.front.background.angle, 35);
    expect(restored.assetIds, {'img-1.png'});
  });

  test('element copyWith can clear nullable fields', () {
    final e = DesignElement(
      type: ElementType.shape,
      x: 0,
      y: 0,
      width: 10,
      height: 10,
      fill: Fill.solid(const Color(0xFF000000)),
      strokeColor: const Color(0xFFFF0000),
    );
    final cleared = e.copyWith(fill: null, strokeColor: null);
    expect(cleared.fill, isNull);
    expect(cleared.strokeColor, isNull);
    expect(cleared.id, e.id);
    expect(e.duplicate().id, isNot(e.id));
  });

  test('fill parsing is tolerant', () {
    expect(Fill.fromJson('#ff0000')!.primary, const Color(0xFFFF0000));
    expect(
      Fill.fromJson({
        'kind': 'linear',
        'colors': ['#000', '#fff'],
        'angle': 45,
      })!.angle,
      45,
    );
    expect(
      Fill.fromJson({
        'colors': ['nope'],
      }),
      isNull,
    );
    expect(
      Fill.fromJson({
        'kind': 'radial',
        'colors': ['#123456'],
      })!.kind,
      FillKind.solid,
    );
  });

  test('invalid numbers in element JSON fall back to safe values', () {
    final e = DesignElement.fromJson({
      'type': 'text',
      'x': 'abc',
      'y': double.nan,
      'width': -5,
      'height': 0,
      'opacity': 4,
      'fontSize': 1e9,
    });
    expect(e.x, 0);
    expect(e.width, greaterThan(0));
    expect(e.height, greaterThan(0));
    expect(e.opacity, 1);
    expect(e.fontSize, lessThanOrEqualTo(2000));
  });

  test('document resize scales content proportionally', () {
    final doc = DesignDocument(
      widthMm: 100,
      heightMm: 50,
      pages: [
        DesignPage(
          elements: [
            DesignElement(
              type: ElementType.text,
              x: 10,
              y: 10,
              width: 50,
              height: 20,
              fontSize: 10,
            ),
          ],
        ),
      ],
    );
    final resized = doc.resized(200, 100);
    final e = resized.front.elements.single;
    expect([e.x, e.y, e.width, e.height, e.fontSize], [20, 20, 100, 40, 20]);
  });

  test('project and profile round trip', () {
    final project = Project(
      name: 'Carte',
      document: richSampleDocument(),
      brief: 'brief',
      packId: 'pack-1',
      packRole: 'card',
    );
    final restored = Project.fromJson(
      jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>,
    );
    expect(restored.id, project.id);
    expect(restored.packRole, 'card');
    final profile = BusinessProfile.example().copyWith(
      socials: const [SocialLink(network: 'Instagram', url: 'instagram.com/x')],
      logoAssetId: 'logo.png',
    );
    final p2 = BusinessProfile.fromJson(
      jsonDecode(jsonEncode(profile.toJson())) as Map<String, dynamic>,
    );
    expect(p2.socials.single.network, 'Instagram');
    expect(p2.brandColors, profile.brandColors);
    expect(p2.logoAssetId, 'logo.png');
    expect(p2.copyWith(logoAssetId: null).logoAssetId, isNull);
  });

  test('settings round trip keeps provider, models and print settings', () {
    const settings = AppSettings(
      provider: AiProvider.mistral,
      models: {AiProvider.mistral: 'mistral-small-latest'},
      print: PrintSettings(copies: 100, bleedMm: 2, duplex: true),
    );
    final restored = AppSettings.fromJson(
      jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
    );
    expect(restored.provider, AiProvider.mistral);
    expect(restored.modelFor(AiProvider.mistral), 'mistral-small-latest');
    expect(
      restored.modelFor(AiProvider.anthropic),
      AiProvider.anthropic.defaultModel,
    );
    expect(restored.print.copies, 100);
    expect(restored.print.duplex, isTrue);
  });

  test(
    'legacy projects from the first version are converted to millimetres',
    () {
      final legacy = {
        'id': 'old-1',
        'name': 'Ancien',
        'description': 'brief',
        'elements': [
          {
            'name': 'Titre',
            'x': 0.1,
            'y': 0.2,
            'width': 160,
            'height': 72,
            'color': 0xFF7545FF,
            'kind': 'text',
            'textContent': 'Bonjour',
            'fontSize': 16,
            'rotation': 0.5,
          },
          {
            'name': 'Fond',
            'x': 0,
            'y': 0,
            'width': 320,
            'height': 360,
            'color': 0xFF000000,
            'kind': 'shape',
          },
        ],
      };
      expect(LegacyConverter.isLegacyProject(legacy), isTrue);
      final project = LegacyConverter.readProject(legacy);
      expect(project.id, 'old-1');
      final title = project.document.front.elements.first;
      expect(title.text, 'Bonjour');
      expect(title.x, closeTo(8.5, 0.001));
      expect(title.width, closeTo(42.5, 0.001));
      expect(title.rotation, closeTo(28.65, 0.01));
      final background = project.document.front.elements[1];
      expect(background.width, closeTo(85, 0.001));
      expect(background.height, closeTo(55, 0.001));
    },
  );
}
