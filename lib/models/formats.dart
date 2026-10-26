/// Formats de création proposés. Les formats « écran » sont définis à
/// 10 pixels par millimètre : exportés à 254 ppp, ils donnent la taille
/// exacte en pixels attendue par les réseaux sociaux.
class DesignFormat {
  const DesignFormat({
    required this.id,
    required this.label,
    required this.group,
    required this.widthMm,
    required this.heightMm,
    this.duplex = false,
    this.screen = false,
  });

  final String id;
  final String label;
  final String group;
  final double widthMm;
  final double heightMm;

  /// Recto verso proposé par défaut.
  final bool duplex;

  /// Format destiné à l'écran (réseaux sociaux).
  final bool screen;

  bool get isLandscape => widthMm > heightMm;

  String get sizeLabel => screen
      ? '${(widthMm * 10).round()} × ${(heightMm * 10).round()} px'
      : '${_fmt(widthMm)} × ${_fmt(heightMm)} mm';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

/// Résolution d'export recommandée pour les formats écran.
const double screenFormatDpi = 254;

class DesignFormats {
  static const businessCard = DesignFormat(
    id: 'business-card',
    label: 'Carte de visite',
    group: 'Cartes',
    widthMm: 85,
    heightMm: 55,
    duplex: true,
  );

  static const flyerA5 = DesignFormat(
    id: 'flyer-a5',
    label: 'Flyer A5',
    group: 'Flyers et affiches',
    widthMm: 148,
    heightMm: 210,
  );

  static const posterA3 = DesignFormat(
    id: 'poster-a3',
    label: 'Affiche A3',
    group: 'Flyers et affiches',
    widthMm: 297,
    heightMm: 420,
  );

  static const socialPost = DesignFormat(
    id: 'social-post',
    label: 'Publication carrée',
    group: 'Réseaux sociaux',
    widthMm: 108,
    heightMm: 108,
    screen: true,
  );

  static const story = DesignFormat(
    id: 'story',
    label: 'Story',
    group: 'Réseaux sociaux',
    widthMm: 108,
    heightMm: 192,
    screen: true,
  );

  static const List<DesignFormat> all = [
    businessCard,
    DesignFormat(
      id: 'business-card-us',
      label: 'Carte de visite US',
      group: 'Cartes',
      widthMm: 88.9,
      heightMm: 50.8,
      duplex: true,
    ),
    DesignFormat(
      id: 'loyalty-card',
      label: 'Carte de fidélité',
      group: 'Cartes',
      widthMm: 85,
      heightMm: 55,
      duplex: true,
    ),
    DesignFormat(
      id: 'invitation',
      label: 'Invitation A6',
      group: 'Cartes',
      widthMm: 148,
      heightMm: 105,
    ),
    DesignFormat(
      id: 'coupon',
      label: 'Bon de réduction',
      group: 'Cartes',
      widthMm: 150,
      heightMm: 70,
    ),
    DesignFormat(
      id: 'flyer-a6',
      label: 'Flyer A6',
      group: 'Flyers et affiches',
      widthMm: 105,
      heightMm: 148,
    ),
    flyerA5,
    DesignFormat(
      id: 'flyer-a4',
      label: 'Flyer A4',
      group: 'Flyers et affiches',
      widthMm: 210,
      heightMm: 297,
    ),
    posterA3,
    DesignFormat(
      id: 'poster-a2',
      label: 'Affiche A2',
      group: 'Flyers et affiches',
      widthMm: 420,
      heightMm: 594,
    ),
    DesignFormat(
      id: 'leaflet',
      label: 'Dépliant A4 3 volets',
      group: 'Flyers et affiches',
      widthMm: 297,
      heightMm: 210,
      duplex: true,
    ),
    DesignFormat(
      id: 'menu-a4',
      label: 'Menu A4',
      group: 'Restauration',
      widthMm: 210,
      heightMm: 297,
    ),
    DesignFormat(
      id: 'menu-dl',
      label: 'Menu DL',
      group: 'Restauration',
      widthMm: 99,
      heightMm: 210,
      duplex: true,
    ),
    DesignFormat(
      id: 'label-rect',
      label: 'Étiquette 70 × 37',
      group: 'Étiquettes',
      widthMm: 70,
      heightMm: 37,
    ),
    DesignFormat(
      id: 'label-round',
      label: 'Étiquette ronde 50 mm',
      group: 'Étiquettes',
      widthMm: 50,
      heightMm: 50,
    ),
    socialPost,
    DesignFormat(
      id: 'social-portrait',
      label: 'Publication portrait',
      group: 'Réseaux sociaux',
      widthMm: 108,
      heightMm: 135,
      screen: true,
    ),
    story,
    DesignFormat(
      id: 'facebook-cover',
      label: 'Couverture Facebook',
      group: 'Réseaux sociaux',
      widthMm: 85.1,
      heightMm: 31.5,
      screen: true,
    ),
  ];

  static DesignFormat? byId(String id) {
    for (final format in all) {
      if (format.id == id) return format;
    }
    return null;
  }

  static bool isScreen(String formatId) => byId(formatId)?.screen ?? false;
}

/// Formats de papier pour l'imprimerie.
class PaperFormat {
  const PaperFormat(this.id, this.label, this.widthMm, this.heightMm);

  final String id;
  final String label;
  final double widthMm;
  final double heightMm;

  static const a4 = PaperFormat('A4', 'A4 (210 × 297)', 210, 297);
  static const a3 = PaperFormat('A3', 'A3 (297 × 420)', 297, 420);
  static const a5 = PaperFormat('A5', 'A5 (148 × 210)', 148, 210);
  static const letter = PaperFormat(
    'LETTER',
    'Lettre US (216 × 279)',
    215.9,
    279.4,
  );

  static const List<PaperFormat> standard = [a4, a3, a5, letter];

  static PaperFormat? byId(String id) {
    for (final p in standard) {
      if (p.id == id) return p;
    }
    return null;
  }
}
