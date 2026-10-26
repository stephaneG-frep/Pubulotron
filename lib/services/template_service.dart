import 'package:flutter/material.dart';

import '../models/pubulotron_models.dart';

class TemplateService {
  static const List<TemplateCard> catalog = [
    TemplateCard(
      id: 'business-card',
      title: 'Carte de visite',
      category: 'Informatique',
      accent: Color(0xFF24C9C2),
      tag: '85 × 55 mm',
      icon: Icons.contact_page_outlined,
      description: 'Carte compacte, contraste sombre et coordonnées lisibles.',
    ),
    TemplateCard(
      id: 'salon-flyer',
      title: 'Flyer salon',
      category: 'Événementiel',
      accent: Color(0xFFFF6384),
      tag: 'A5',
      icon: Icons.spa_outlined,
      description:
          'Mise en page éditoriale avec grande zone photo et appel à réserver.',
    ),
    TemplateCard(
      id: 'restaurant-menu',
      title: 'Menu restaurant',
      category: 'Restauration',
      accent: Color(0xFFFFAA45),
      tag: 'A4',
      icon: Icons.restaurant_menu_outlined,
      description: 'Menu structuré avec catégories, plats et prix alignés.',
    ),
    TemplateCard(
      id: 'sale-poster',
      title: 'Affiche promo',
      category: 'Commerce',
      accent: Color(0xFF7545FF),
      tag: 'A3',
      icon: Icons.campaign_outlined,
      description: 'Affiche à fort impact avec offre, bénéfice et action.',
    ),
  ];

  static List<CreativeElement> createElements(
    String templateId,
    BusinessProfile profile,
  ) {
    switch (templateId) {
      case 'business-card':
        return [
          _shape('Fond nuit', 0, 0, 320, 360, const Color(0xFF17213B)),
          _shape('Accent turquoise', 0, 0, 18, 360, const Color(0xFF24C9C2)),
          _shape('Pastille logo', 245, 34, 54, 54, const Color(0xFF7545FF)),
          _text(
            'Nom de l’activité',
            profile.name,
            34,
            48,
            205,
            56,
            Colors.white,
          ),
          _text(
            'Slogan',
            profile.slogan,
            34,
            118,
            250,
            45,
            const Color(0xFF24C9C2),
          ),
          _shape('Séparateur', 34, 188, 252, 3, const Color(0xFF24C9C2)),
          _text('Téléphone', profile.phone, 34, 214, 240, 40, Colors.white),
          _text('E-mail', profile.email, 34, 266, 250, 38, Colors.white),
          _text(
            'Site web',
            profile.website,
            34,
            312,
            250,
            34,
            const Color(0xFFFFAA45),
          ),
        ];
      case 'salon-flyer':
        return [
          _shape('Fond rose poudré', 0, 0, 320, 360, const Color(0xFF54283D)),
          _text(
            'Sur-titre',
            'PRENEZ DU TEMPS POUR VOUS',
            24,
            18,
            272,
            28,
            const Color(0xFFFFC4D2),
          ),
          _text('Titre du flyer', profile.name, 24, 56, 272, 58, Colors.white),
          _image('Photo du salon', 24, 132, 272, 120, const Color(0xFF9D5570)),
          _text('Slogan', profile.slogan, 24, 264, 272, 40, Colors.white),
          _shape(
            'Bouton réservation',
            24,
            316,
            272,
            32,
            const Color(0xFFFF6384),
          ),
          _text(
            'Coordonnées',
            'Réservez au ${profile.phone}',
            30,
            319,
            260,
            26,
            Colors.white,
          ),
        ];
      case 'restaurant-menu':
        return [
          _shape('Fond ardoise', 0, 0, 320, 360, const Color(0xFF202A2A)),
          _shape('Filet doré', 14, 14, 292, 4, const Color(0xFFFFAA45)),
          _text(
            'Nom du restaurant',
            profile.name,
            28,
            28,
            264,
            46,
            const Color(0xFFFFD28A),
          ),
          _text('Accroche', profile.slogan, 28, 78, 264, 34, Colors.white),
          _text(
            'Catégorie entrée',
            'POUR COMMENCER',
            28,
            132,
            264,
            30,
            const Color(0xFFFFAA45),
          ),
          _text(
            'Plat entrée',
            'Soupe du jour ........ 8 €',
            28,
            166,
            264,
            32,
            Colors.white,
          ),
          _text(
            'Catégorie plat',
            'LES INCONTOURNABLES',
            28,
            214,
            264,
            30,
            const Color(0xFFFFAA45),
          ),
          _text(
            'Plat principal',
            'Plat maison .......... 16 €',
            28,
            248,
            264,
            32,
            Colors.white,
          ),
          _text(
            'Dessert',
            'Dessert gourmand ..... 7 €',
            28,
            282,
            264,
            32,
            Colors.white,
          ),
          _text(
            'Adresse',
            profile.address.isEmpty ? profile.phone : profile.address,
            28,
            324,
            264,
            24,
            const Color(0xFFFFD28A),
          ),
          _shape('Filet bas', 14, 348, 292, 4, const Color(0xFFFFAA45)),
        ];
      case 'sale-poster':
        return [
          _shape('Fond violet', 0, 0, 320, 360, const Color(0xFF24164B)),
          _shape('Bandeau orange', 0, 20, 320, 46, const Color(0xFFFFAA45)),
          _text(
            'Bandeau',
            'OFFRE EXCEPTIONNELLE',
            20,
            26,
            280,
            32,
            const Color(0xFF24164B),
          ),
          _text(
            'Nom de l’activité',
            profile.name,
            24,
            88,
            272,
            48,
            Colors.white,
          ),
          _text(
            'Promesse',
            profile.slogan,
            24,
            144,
            272,
            46,
            const Color(0xFF24C9C2),
          ),
          _text('Remise', '-20 %', 24, 202, 272, 76, const Color(0xFFFFAA45)),
          _shape('Bouton appel', 24, 296, 272, 48, const Color(0xFFFF6384)),
          _text(
            'Appel à action',
            'Appelez-nous : ${profile.phone}',
            30,
            304,
            260,
            34,
            Colors.white,
          ),
        ];
      default:
        throw ArgumentError.value(templateId, 'templateId', 'Modèle inconnu.');
    }
  }

  static CreativeElement _text(
    String name,
    String text,
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
      'text',
      textContent: text,
    );
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

  static CreativeElement _image(
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
      'image',
      textContent: 'Photo à ajouter',
    );
  }
}
