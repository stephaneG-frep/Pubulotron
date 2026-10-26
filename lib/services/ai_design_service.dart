import 'package:flutter/material.dart';

import '../models/pubulotron_models.dart';

class AiDesignService {
  static List<CreativeElement> createComposition({
    required DesignConcept concept,
    required BusinessProfile profile,
    required int variant,
  }) {
    final colors = _palette(concept.palette);
    final style = variant % 4;
    final title = _title(concept.title, profile.name);
    final slogan = concept.slogan.trim().isEmpty
        ? profile.slogan
        : concept.slogan.trim();
    final contact = profile.phone.isNotEmpty ? profile.phone : profile.website;

    return switch (style) {
      0 => [
        _shape('Fond nuit', 0, 0, 320, 360, const Color(0xFF10172B)),
        _shape('Liseré lumineux', 0, 0, 12, 360, colors.$1),
        _shape('Bloc visuel', 190, 126, 104, 112, colors.$2),
        _text(
          'Sur-titre',
          'IDENTITÉ • ${concept.style.toUpperCase()}',
          28,
          28,
          260,
          28,
          colors.$1,
        ),
        _text('Activité', profile.name, 28, 52, 260, 20, colors.$2, size: 12),
        _text('Titre', title, 28, 76, 270, 70, Colors.white, size: 25),
        _text('Slogan', slogan, 28, 170, 150, 64, colors.$2, size: 14),
        _shape('Appel à action', 28, 278, 264, 48, colors.$1),
        _text(
          'Coordonnées',
          contact,
          38,
          287,
          244,
          30,
          const Color(0xFF10172B),
        ),
      ],
      1 => [
        _shape('Fond ivoire', 0, 0, 320, 360, const Color(0xFFF5F0E7)),
        _shape('Filet supérieur', 22, 24, 276, 3, colors.$1),
        _text(
          'Marque',
          profile.name,
          32,
          46,
          256,
          38,
          const Color(0xFF25221E),
          size: 15,
        ),
        _text('Titre éditorial', title, 32, 106, 256, 84, colors.$2, size: 28),
        _shape('Séparateur', 32, 210, 52, 3, colors.$1),
        _text(
          'Slogan',
          slogan,
          32,
          229,
          250,
          52,
          const Color(0xFF25221E),
          size: 13,
        ),
        _text(
          'Coordonnées',
          contact,
          32,
          306,
          250,
          28,
          const Color(0xFF25221E),
          size: 11,
        ),
        _shape('Filet inférieur', 22, 340, 276, 3, colors.$1),
      ],
      2 => [
        _shape('Fond digital', 0, 0, 320, 360, const Color(0xFF251047)),
        _shape('Panneau dégradé simulé', 178, 86, 120, 150, colors.$1),
        _shape('Carte vitrée', 194, 102, 88, 118, const Color(0xFF42206D)),
        _text('Badge', 'NOUVEAU', 26, 26, 122, 28, colors.$2),
        _text('Titre', title, 26, 78, 166, 88, Colors.white, size: 24),
        _text(
          'Slogan',
          slogan,
          26,
          183,
          154,
          68,
          const Color(0xFFD9C8FF),
          size: 13,
        ),
        _text(
          'Nom activité',
          profile.name,
          26,
          272,
          250,
          28,
          colors.$1,
          size: 12,
        ),
        _shape('Bouton action', 26, 308, 268, 38, colors.$2),
        _text(
          'Coordonnées',
          contact,
          36,
          314,
          248,
          26,
          const Color(0xFF251047),
        ),
      ],
      _ => [
        _shape('Fond pop', 0, 0, 320, 360, const Color(0xFFFFF2EB)),
        _shape('Bande diagonale', 0, 0, 320, 50, colors.$1),
        _shape('Pastille décorative', 208, 72, 88, 88, colors.$2),
        _shape('Forme décorative', 18, 190, 30, 112, colors.$1),
        _text(
          'Accroche',
          concept.style.toUpperCase(),
          22,
          12,
          276,
          26,
          Colors.white,
          size: 12,
        ),
        _text(
          'Activité',
          profile.name,
          28,
          48,
          210,
          22,
          const Color(0xFF251047),
          size: 12,
        ),
        _text(
          'Titre impact',
          title,
          28,
          76,
          210,
          88,
          const Color(0xFF251047),
          size: 26,
        ),
        _text(
          'Offre',
          slogan,
          56,
          199,
          230,
          58,
          const Color(0xFF251047),
          size: 14,
        ),
        _shape('Bouton pop', 28, 286, 264, 48, colors.$2),
        _text('Coordonnées', contact, 36, 294, 248, 32, Colors.white),
      ],
    };
  }

  static (Color, Color) _palette(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('vert') || normalized.contains('green')) {
      return (const Color(0xFF3A8F5B), const Color(0xFFE6B655));
    }
    if (normalized.contains('rose') || normalized.contains('pink')) {
      return (const Color(0xFFFF6384), const Color(0xFF7545FF));
    }
    if (normalized.contains('orange') || normalized.contains('jaune')) {
      return (const Color(0xFFFFAA45), const Color(0xFF17213B));
    }
    if (normalized.contains('bleu') || normalized.contains('cyan')) {
      return (const Color(0xFF24C9C2), const Color(0xFF7545FF));
    }
    return (const Color(0xFF7545FF), const Color(0xFF24C9C2));
  }

  static String _title(String conceptTitle, String businessName) {
    final title = conceptTitle.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'concept') return title;
    final name = businessName.trim();
    return name.isNotEmpty && name != 'Mon activité'
        ? name
        : 'Votre nouvelle idée';
  }

  static CreativeElement _shape(
    String name,
    double x,
    double y,
    double width,
    double height,
    Color color,
  ) {
    return CreativeElement(
      name,
      x / 320,
      y / 360,
      width,
      height,
      color,
      'shape',
    );
  }

  static CreativeElement _text(
    String name,
    String text,
    double x,
    double y,
    double width,
    double height,
    Color color, {
    double size = 16,
  }) {
    return CreativeElement(
      name,
      x / 320,
      y / 360,
      width,
      height,
      color,
      'text',
      textContent: text,
    )..fontSize = size;
  }
}
