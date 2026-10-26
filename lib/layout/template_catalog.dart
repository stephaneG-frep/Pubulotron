import 'dart:ui';

import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/formats.dart';
import 'brand_kit.dart';
import 'layout_engine.dart';

/// Modèle de la bibliothèque : style + format + identité d'exemple.
class TemplateDef {
  const TemplateDef({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.formatId,
    required this.style,
    this.offer = '',
    this.headline,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String formatId;
  final LayoutStyle style;
  final String offer;
  final String? headline;

  DesignFormat get format =>
      DesignFormats.byId(formatId) ?? DesignFormats.businessCard;
}

class TemplateCatalog {
  static const categories = [
    'Artisanat',
    'Informatique',
    'Jardinage',
    'Coiffure',
    'Restauration',
    'Commerce',
    'Services à domicile',
    'Événementiel',
    'Associations',
    'Activités artistiques',
  ];

  static const List<TemplateDef> all = [
    TemplateDef(
      id: 'artisan-card',
      title: 'Carte artisan',
      category: 'Artisanat',
      description: 'Bloc de couleur franc et coordonnées claires.',
      formatId: 'business-card',
      style: LayoutStyle.split,
    ),
    TemplateDef(
      id: 'artisan-flyer',
      title: 'Flyer savoir-faire',
      category: 'Artisanat',
      description: 'Mise en page éditoriale avec grande photo de réalisation.',
      formatId: 'flyer-a5',
      style: LayoutStyle.editorial,
    ),
    TemplateDef(
      id: 'it-card',
      title: 'Carte futuriste',
      category: 'Informatique',
      description: 'Fond nuit, halo néon et QR code vers le site.',
      formatId: 'business-card',
      style: LayoutStyle.neon,
    ),
    TemplateDef(
      id: 'it-flyer',
      title: 'Flyer dépannage express',
      category: 'Informatique',
      description: 'Néon, prestations listées et bouton d’appel.',
      formatId: 'flyer-a5',
      style: LayoutStyle.neon,
    ),
    TemplateDef(
      id: 'it-story',
      title: 'Story offre tech',
      category: 'Informatique',
      description: 'Format vertical pour les réseaux sociaux.',
      formatId: 'story',
      style: LayoutStyle.split,
      offer: '-15 %',
    ),
    TemplateDef(
      id: 'garden-flyer',
      title: 'Flyer jardin',
      category: 'Jardinage',
      description: 'Formes organiques, photo arrondie et promotion.',
      formatId: 'flyer-a5',
      style: LayoutStyle.nature,
      offer: '-15 %',
    ),
    TemplateDef(
      id: 'garden-card',
      title: 'Carte paysagiste',
      category: 'Jardinage',
      description: 'Ambiance naturelle et pictogramme feuillage.',
      formatId: 'business-card',
      style: LayoutStyle.nature,
    ),
    TemplateDef(
      id: 'hair-card',
      title: 'Carte salon chic',
      category: 'Coiffure',
      description: 'Fond profond, filets dorés, typographie serif.',
      formatId: 'business-card',
      style: LayoutStyle.elegant,
    ),
    TemplateDef(
      id: 'hair-flyer',
      title: 'Flyer promo coiffure',
      category: 'Coiffure',
      description: 'Esprit pop, bulles colorées et offre en étoile.',
      formatId: 'flyer-a5',
      style: LayoutStyle.pop,
      offer: '-20 %',
    ),
    TemplateDef(
      id: 'resto-menu',
      title: 'Menu bistrot',
      category: 'Restauration',
      description: 'Menu ardoise avec rubriques et prix alignés.',
      formatId: 'menu-a4',
      style: LayoutStyle.menu,
    ),
    TemplateDef(
      id: 'resto-loyalty',
      title: 'Carte de fidélité',
      category: 'Restauration',
      description: 'Dix tampons, le dixième offert.',
      formatId: 'loyalty-card',
      style: LayoutStyle.ticket,
    ),
    TemplateDef(
      id: 'shop-poster',
      title: 'Affiche soldes',
      category: 'Commerce',
      description: 'Bandeau à fort impact, offre géante et appel à l’action.',
      formatId: 'poster-a3',
      style: LayoutStyle.banner,
      offer: '-30 %',
    ),
    TemplateDef(
      id: 'shop-coupon',
      title: 'Bon de réduction',
      category: 'Commerce',
      description: 'Coupon détachable avec talon et QR code.',
      formatId: 'coupon',
      style: LayoutStyle.ticket,
      offer: '-10 %',
    ),
    TemplateDef(
      id: 'shop-label',
      title: 'Étiquette produit',
      category: 'Commerce',
      description: 'Étiquette sobre pour produits et emballages.',
      formatId: 'label-rect',
      style: LayoutStyle.minimal,
    ),
    TemplateDef(
      id: 'home-flyer',
      title: 'Flyer services',
      category: 'Services à domicile',
      description: 'Bloc couleur, liste de prestations et contact.',
      formatId: 'flyer-a5',
      style: LayoutStyle.split,
    ),
    TemplateDef(
      id: 'home-card',
      title: 'Carte minimaliste',
      category: 'Services à domicile',
      description: 'Beaucoup d’espace, informations essentielles.',
      formatId: 'business-card',
      style: LayoutStyle.minimal,
    ),
    TemplateDef(
      id: 'event-invite',
      title: 'Invitation élégante',
      category: 'Événementiel',
      description: 'Cadre doré et typographie classique.',
      formatId: 'invitation',
      style: LayoutStyle.elegant,
      headline: 'Vous êtes invités',
    ),
    TemplateDef(
      id: 'event-poster',
      title: 'Affiche soirée',
      category: 'Événementiel',
      description: 'Affiche pop pour concert, fête ou salon.',
      formatId: 'poster-a3',
      style: LayoutStyle.pop,
      headline: 'Grande soirée',
    ),
    TemplateDef(
      id: 'asso-poster',
      title: 'Affiche association',
      category: 'Associations',
      description: 'Appel aux bénévoles et informations pratiques.',
      formatId: 'poster-a3',
      style: LayoutStyle.split,
      headline: 'Rejoignez-nous !',
    ),
    TemplateDef(
      id: 'asso-post',
      title: 'Publication réseaux',
      category: 'Associations',
      description: 'Carré pour Facebook et Instagram.',
      formatId: 'social-post',
      style: LayoutStyle.pop,
      headline: 'Portes ouvertes',
    ),
    TemplateDef(
      id: 'art-flyer',
      title: 'Flyer exposition',
      category: 'Activités artistiques',
      description: 'Éditorial, grande image de l’œuvre.',
      formatId: 'flyer-a5',
      style: LayoutStyle.editorial,
      headline: 'Exposition',
    ),
    TemplateDef(
      id: 'art-story',
      title: 'Story atelier',
      category: 'Activités artistiques',
      description: 'Story verticale pour annoncer un atelier.',
      formatId: 'story',
      style: LayoutStyle.elegant,
      headline: 'Atelier créatif',
    ),
  ];

  static TemplateDef? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Activité d'exemple pour chaque catégorie.
  static BusinessProfile sampleProfile(String category) {
    final p = switch (category) {
      'Artisanat' => BusinessProfile(
        name: 'Atelier Bois & Fer',
        activity: 'Menuiserie et ferronnerie',
        slogan: 'Du sur-mesure qui dure.',
        services: const ['Agencement', 'Escaliers', 'Mobilier', 'Restauration'],
        phone: '06 21 43 65 87',
        email: 'contact@boisetfer.fr',
        website: 'boisetfer.fr',
        address: '8 rue des Artisans, Nantes',
        brandColors: const [
          Color(0xFF8A4B2A),
          Color(0xFFE0B07A),
          Color(0xFF2E6F6A),
        ],
      ),
      'Informatique' => BusinessProfile.example(),
      'Jardinage' => BusinessProfile(
        name: 'Jardins de Léa',
        activity: 'Entretien de jardins et paysagisme',
        slogan: 'Votre jardin entre de bonnes mains.',
        services: const ['Tonte', 'Taille de haies', 'Potager', 'Création'],
        phone: '07 12 98 45 33',
        email: 'lea@jardinsdelea.fr',
        website: 'jardinsdelea.fr',
        address: 'Aix-en-Provence',
        brandColors: const [
          Color(0xFF2F8F4E),
          Color(0xFFA8D672),
          Color(0xFFFF8A3D),
        ],
      ),
      'Coiffure' => BusinessProfile(
        name: 'Studio Mèche',
        activity: 'Salon de coiffure',
        slogan: 'Coupe, couleur, caractère.',
        services: const ['Coupe', 'Couleur', 'Balayage', 'Barbier'],
        phone: '04 78 22 11 00',
        email: 'bonjour@studiomeche.fr',
        website: 'studiomeche.fr',
        address: '3 place Bellecour, Lyon',
        brandColors: const [
          Color(0xFF2B1B2E),
          Color(0xFFE83E8C),
          Color(0xFFC9A646),
        ],
      ),
      'Restauration' => BusinessProfile(
        name: 'Le Petit Comptoir',
        activity: 'Bistrot de quartier',
        slogan: 'Cuisine maison, produits du marché.',
        services: const [
          'Blanquette de veau',
          'Poisson du jour',
          'Risotto aux cèpes',
        ],
        phone: '01 42 00 12 34',
        email: 'resa@petitcomptoir.fr',
        website: 'petitcomptoir.fr',
        address: '12 rue Oberkampf, Paris',
        hours: 'Mar–Sam 12h–14h30, 19h–22h30',
        brandColors: const [
          Color(0xFF8C2F39),
          Color(0xFFE9C46A),
          Color(0xFFC9A646),
        ],
      ),
      'Commerce' => BusinessProfile(
        name: 'Boutique Azur',
        activity: 'Prêt-à-porter',
        slogan: 'La mode qui vous ressemble.',
        services: const ['Femme', 'Homme', 'Accessoires'],
        phone: '04 93 55 66 77',
        email: 'contact@boutique-azur.fr',
        website: 'boutique-azur.fr',
        address: 'Nice',
        brandColors: const [
          Color(0xFF1E6BFF),
          Color(0xFF24C9C2),
          Color(0xFFFF6384),
        ],
      ),
      'Services à domicile' => BusinessProfile(
        name: 'Coup de Main',
        activity: 'Services à domicile',
        contactName: 'Sophie Durand',
        jobTitle: 'Gérante',
        slogan: 'On s’occupe de tout, vous profitez.',
        services: const [
          'Ménage',
          'Repassage',
          'Petit bricolage',
          'Garde d’enfants',
        ],
        phone: '06 55 44 33 22',
        email: 'sophie@coupdemain.fr',
        website: 'coupdemain.fr',
        address: 'Toulouse et alentours',
        brandColors: const [
          Color(0xFF24C9C2),
          Color(0xFF7545FF),
          Color(0xFFFFAA45),
        ],
      ),
      'Événementiel' => BusinessProfile(
        name: 'Les Nuits Lumière',
        activity: 'Organisation d’événements',
        slogan: 'Samedi 14 juin — 20 h — Salle des fêtes',
        services: const ['Concerts', 'DJ', 'Buffet'],
        phone: '06 10 20 30 40',
        email: 'info@nuitslumiere.fr',
        website: 'nuitslumiere.fr',
        address: 'Salle des fêtes, Annecy',
        brandColors: const [
          Color(0xFF7545FF),
          Color(0xFFFF6384),
          Color(0xFFFFC145),
        ],
      ),
      'Associations' => BusinessProfile(
        name: 'Les Amis du Quartier',
        activity: 'Association de quartier',
        slogan: 'Ensemble, faisons vivre notre quartier.',
        services: const ['Jardin partagé', 'Aide aux devoirs', 'Fête annuelle'],
        phone: '06 98 76 54 32',
        email: 'amis.quartier@asso.fr',
        website: 'amisduquartier.fr',
        address: 'Maison des associations, Lille',
        brandColors: const [
          Color(0xFFFF7A1A),
          Color(0xFF2F8F4E),
          Color(0xFF1E6BFF),
        ],
      ),
      'Activités artistiques' => BusinessProfile(
        name: 'Atelier Pigment',
        activity: 'Atelier d’art et galerie',
        slogan: 'Peintures récentes de Clara Vidal',
        services: const ['Expositions', 'Cours de peinture', 'Stages'],
        phone: '05 56 12 34 56',
        email: 'atelier@pigment.art',
        website: 'pigment.art',
        address: 'Bordeaux',
        brandColors: const [
          Color(0xFFD7263D),
          Color(0xFF1B998B),
          Color(0xFFF4D35E),
        ],
      ),
      _ => BusinessProfile.example(),
    };
    return p;
  }

  /// Instancie un modèle avec une fiche (la fiche d'exemple par défaut).
  static DesignDocument instantiate(
    TemplateDef template, {
    BusinessProfile? profile,
  }) {
    final p = profile ?? sampleProfile(template.category);
    var kit = BrandKit.fromProfile(p, layout: template.style);
    if (template.offer.isNotEmpty || template.headline != null) {
      kit = kit.copyWith(offer: template.offer, headline: template.headline);
    }
    final format = template.format;
    return LayoutEngine.build(
      style: template.style,
      widthMm: format.widthMm,
      heightMm: format.heightMm,
      kit: kit,
      profile: p,
      formatId: format.id,
      duplex: format.duplex,
    );
  }
}
