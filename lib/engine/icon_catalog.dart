import 'package:flutter/material.dart';

class PictogramDef {
  const PictogramDef(this.key, this.label, this.icon, this.tags);

  final String key;
  final String label;
  final IconData icon;
  final String tags;
}

/// Pictogrammes vectoriels disponibles. Les éléments référencent une clé
/// stable ; les IconData restent constantes pour permettre l'optimisation
/// de la police d'icônes à la compilation.
class IconCatalog {
  static const List<PictogramDef> all = [
    PictogramDef('phone', 'Téléphone', Icons.phone, 'contact appel'),
    PictogramDef('smartphone', 'Mobile', Icons.smartphone, 'contact portable'),
    PictogramDef('email', 'E-mail', Icons.email, 'contact mail courriel'),
    PictogramDef('web', 'Site web', Icons.language, 'internet site'),
    PictogramDef('place', 'Adresse', Icons.place, 'localisation lieu carte'),
    PictogramDef('schedule', 'Horaires', Icons.schedule, 'heure horloge'),
    PictogramDef(
      'calendar',
      'Agenda',
      Icons.calendar_month,
      'date rendez-vous événement',
    ),
    PictogramDef('star', 'Étoile', Icons.star, 'avis qualité'),
    PictogramDef('heart', 'Cœur', Icons.favorite, 'amour'),
    PictogramDef('check', 'Validé', Icons.check_circle, 'ok garantie'),
    PictogramDef('verified', 'Certifié', Icons.verified, 'qualité garantie'),
    PictogramDef('thumb', 'Pouce', Icons.thumb_up, 'avis'),
    PictogramDef('bolt', 'Éclair', Icons.bolt, 'rapide express énergie'),
    PictogramDef('rocket', 'Fusée', Icons.rocket_launch, 'lancement startup'),
    PictogramDef('idea', 'Idée', Icons.lightbulb, 'conseil'),
    PictogramDef('sparkle', 'Magie', Icons.auto_awesome, 'nouveau brillant'),
    PictogramDef('trophy', 'Trophée', Icons.emoji_events, 'récompense'),
    PictogramDef('diamond', 'Diamant', Icons.diamond, 'premium luxe'),
    PictogramDef('computer', 'Ordinateur', Icons.computer, 'informatique pc'),
    PictogramDef('laptop', 'Portable', Icons.laptop_mac, 'informatique'),
    PictogramDef('wifi', 'Wi-Fi', Icons.wifi, 'réseau internet'),
    PictogramDef('code', 'Code', Icons.code, 'développement informatique'),
    PictogramDef(
      'security',
      'Sécurité',
      Icons.security,
      'protection antivirus',
    ),
    PictogramDef('build', 'Clé', Icons.build, 'réparation outil'),
    PictogramDef('handyman', 'Bricolage', Icons.handyman, 'artisan outil'),
    PictogramDef(
      'construction',
      'Chantier',
      Icons.construction,
      'artisan bâtiment',
    ),
    PictogramDef('carpenter', 'Menuiserie', Icons.carpenter, 'artisan bois'),
    PictogramDef('plumbing', 'Plomberie', Icons.plumbing, 'artisan eau'),
    PictogramDef(
      'electric',
      'Électricité',
      Icons.electrical_services,
      'artisan',
    ),
    PictogramDef('paint', 'Peinture', Icons.format_paint, 'artisan déco'),
    PictogramDef(
      'cleaning',
      'Ménage',
      Icons.cleaning_services,
      'service domicile',
    ),
    PictogramDef('home', 'Maison', Icons.home, 'domicile immobilier'),
    PictogramDef('florist', 'Fleur', Icons.local_florist, 'jardin nature'),
    PictogramDef('eco', 'Feuille', Icons.eco, 'nature bio écologie jardin'),
    PictogramDef('park', 'Arbre', Icons.park, 'jardin nature'),
    PictogramDef('grass', 'Herbe', Icons.grass, 'jardin pelouse'),
    PictogramDef('yard', 'Potager', Icons.yard, 'jardin'),
    PictogramDef('sun', 'Soleil', Icons.wb_sunny, 'été météo'),
    PictogramDef('cut', 'Ciseaux', Icons.content_cut, 'coiffure coupe'),
    PictogramDef(
      'face',
      'Visage',
      Icons.face_retouching_natural,
      'beauté coiffure',
    ),
    PictogramDef('spa', 'Spa', Icons.spa, 'bien-être beauté'),
    PictogramDef(
      'restaurant',
      'Couverts',
      Icons.restaurant,
      'restauration repas',
    ),
    PictogramDef('cafe', 'Café', Icons.local_cafe, 'boisson restauration'),
    PictogramDef('pizza', 'Pizza', Icons.local_pizza, 'restauration'),
    PictogramDef('cake', 'Gâteau', Icons.cake, 'pâtisserie anniversaire'),
    PictogramDef('bar', 'Cocktail', Icons.local_bar, 'boisson bar'),
    PictogramDef('chef', 'Chef', Icons.soup_kitchen, 'cuisine'),
    PictogramDef('bag', 'Sac', Icons.shopping_bag, 'commerce boutique'),
    PictogramDef('cart', 'Panier', Icons.shopping_cart, 'commerce achat'),
    PictogramDef('offer', 'Étiquette', Icons.local_offer, 'promotion prix'),
    PictogramDef(
      'percent',
      'Pourcentage',
      Icons.percent,
      'promotion réduction',
    ),
    PictogramDef('gift', 'Cadeau', Icons.card_giftcard, 'fidélité offre'),
    PictogramDef('store', 'Boutique', Icons.storefront, 'commerce magasin'),
    PictogramDef('shipping', 'Livraison', Icons.local_shipping, 'transport'),
    PictogramDef('celebration', 'Fête', Icons.celebration, 'événement'),
    PictogramDef('music', 'Musique', Icons.music_note, 'concert événement'),
    PictogramDef('mic', 'Micro', Icons.mic, 'concert spectacle'),
    PictogramDef(
      'ticket',
      'Billet',
      Icons.confirmation_number,
      'événement entrée',
    ),
    PictogramDef('palette', 'Palette', Icons.palette, 'art peinture'),
    PictogramDef('brush', 'Pinceau', Icons.brush, 'art'),
    PictogramDef(
      'camera',
      'Appareil photo',
      Icons.photo_camera,
      'photographie',
    ),
    PictogramDef('theater', 'Théâtre', Icons.theater_comedy, 'art spectacle'),
    PictogramDef('groups', 'Groupe', Icons.groups, 'association équipe'),
    PictogramDef(
      'volunteer',
      'Solidarité',
      Icons.volunteer_activism,
      'association bénévole',
    ),
    PictogramDef(
      'handshake',
      'Partenariat',
      Icons.handshake,
      'association accord',
    ),
    PictogramDef('school', 'École', Icons.school, 'formation cours'),
    PictogramDef('sport', 'Sport', Icons.sports_soccer, 'club association'),
    PictogramDef('fitness', 'Fitness', Icons.fitness_center, 'sport santé'),
    PictogramDef('health', 'Santé', Icons.medical_services, 'soin'),
    PictogramDef('pets', 'Animaux', Icons.pets, 'vétérinaire toilettage'),
    PictogramDef('car', 'Voiture', Icons.directions_car, 'garage auto'),
    PictogramDef('elderly', 'Aide', Icons.elderly, 'services domicile'),
    PictogramDef('child', 'Enfant', Icons.child_care, 'garde services'),
    PictogramDef('arrow', 'Flèche', Icons.arrow_forward, 'direction'),
    PictogramDef('share', 'Partager', Icons.share, 'réseaux sociaux'),
    PictogramDef('qr', 'QR', Icons.qr_code_2, 'code'),
    PictogramDef('info', 'Info', Icons.info, 'information'),
  ];

  static final Map<String, PictogramDef> _byKey = {
    for (final p in all) p.key: p,
  };

  static PictogramDef byKey(String key) => _byKey[key] ?? _byKey['star']!;

  static bool isKnown(String key) => _byKey.containsKey(key);

  /// Pictogramme le plus proche d'un nom libre (ex. « laptop_chromebook »).
  static PictogramDef? closest(String name) {
    if (isKnown(name)) return _byKey[name];
    for (final token in name.toLowerCase().split(RegExp(r'[_\-\s]+'))) {
      if (token.length < 3) continue;
      final found = search(token);
      if (found.isNotEmpty) return found.first;
    }
    return null;
  }

  static List<PictogramDef> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (p) =>
              p.key.contains(q) ||
              p.label.toLowerCase().contains(q) ||
              p.tags.contains(q),
        )
        .toList();
  }
}
