import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/models/pubulotron_models.dart';
import 'package:pubulotron/services/template_service.dart';

void main() {
  test('template catalogue entries have distinct editable compositions', () {
    final profile = BusinessProfile(
      id: 'test-profile',
      name: 'Atelier Test',
      slogan: 'Créations sur mesure',
      phone: '01 23 45 67 89',
      email: 'bonjour@example.fr',
      website: 'example.fr',
    );
    final signatures = TemplateService.catalog.map((template) {
      final elements = TemplateService.createElements(template.id, profile);
      return elements
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
            ],
          )
          .toList()
          .toString();
    }).toSet();

    expect(TemplateService.catalog, hasLength(4));
    expect(signatures, hasLength(4));
  });

  test(
    'templates personalize their editable text with the business profile',
    () {
      final profile = BusinessProfile(
        id: 'profile-1',
        name: 'Atelier Test',
        slogan: 'Créations sur mesure',
        phone: '01 23 45 67 89',
        email: 'bonjour@example.fr',
        website: 'example.fr',
      );

      final elements = TemplateService.createElements('business-card', profile);
      final text = elements.map((element) => element.textContent).toList();

      expect(text, contains('Atelier Test'));
      expect(text, contains('Créations sur mesure'));
      expect(text, contains('01 23 45 67 89'));
      expect(
        () => TemplateService.createElements('unknown-template', profile),
        throwsArgumentError,
      );
    },
  );
}
