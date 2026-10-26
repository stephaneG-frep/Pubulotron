import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/models/pubulotron_models.dart';
import 'package:pubulotron/services/ai_design_service.dart';

void main() {
  const styles = ['Futuriste', 'Premium', 'Digital', 'Pop'];

  final profile = BusinessProfile(
    id: 'profile-test',
    name: 'Atelier Lumière',
    slogan: 'Votre projet, notre passion',
    phone: '01 23 45 67 89',
    email: 'contact@example.fr',
    website: 'example.fr',
  );

  test('AI concepts create distinct editable compositions', () {
    final compositions = styles.map((style) {
      return AiDesignService.createComposition(
        concept: DesignConcept(
          title: 'Concept $style',
          style: style,
          palette: 'Bleu électrique / violet',
          slogan: 'Votre idée prend vie',
          summary: 'Concept pour la campagne',
        ),
        profile: profile,
        variant: styles.indexOf(style),
      );
    }).toList();

    final signatures = compositions
        .map(
          (elements) => elements
              .map(
                (element) => [
                  element.name,
                  element.kind,
                  element.textContent,
                  element.x,
                  element.y,
                  element.width,
                  element.height,
                  element.color.toARGB32(),
                  element.fontSize,
                ],
              )
              .toList()
              .toString(),
        )
        .toSet();

    expect(signatures, hasLength(4));
    expect(compositions.every((elements) => elements.length >= 7), isTrue);
  });

  test(
    'composition text includes the selected concept and business details',
    () {
      final elements = AiDesignService.createComposition(
        concept: DesignConcept(
          title: 'Campagne spéciale',
          style: 'Premium',
          palette: 'Vert / blanc / orange',
          slogan: 'Une offre pour vous',
          summary: 'Concept éditorial',
        ),
        profile: profile,
        variant: 1,
      );
      final content = elements.map((element) => element.textContent).toList();

      expect(content, contains('Atelier Lumière'));
      expect(content, contains('Une offre pour vous'));
      expect(content, contains('01 23 45 67 89'));
      expect(elements.first.color, const Color(0xFFF5F0E7));
    },
  );

  test('creative element font size survives project serialization', () {
    final original = CreativeElement(
      'Titre',
      0.1,
      0.2,
      200,
      60,
      const Color(0xFF7545FF),
      'text',
      textContent: 'Un titre',
      fontSize: 28,
    );

    final restored = CreativeElement.fromJson(original.toJson());

    expect(restored.fontSize, 28);
  });
}
