/// Polices embarquées dans l'application. Les mêmes fichiers TTF servent à
/// l'affichage Flutter et à l'export PDF : le rendu est donc identique.
class FontFamilyDef {
  const FontFamilyDef({
    required this.family,
    required this.label,
    required this.category,
    required this.regular,
    this.bold,
    this.italic,
    this.boldItalic,
  });

  /// Nom de famille déclaré dans pubspec.yaml.
  final String family;
  final String label;
  final String category;
  final String regular;
  final String? bold;
  final String? italic;
  final String? boldItalic;

  bool get hasBold => bold != null;
  bool get hasItalic => italic != null;

  /// Variante réellement disponible pour une demande gras/italique.
  FontVariant resolve({required bool bold, required bool italic}) {
    if (bold && italic && boldItalic != null) {
      return FontVariant(boldItalic!, bold: true, italic: true);
    }
    if (bold && this.bold != null) {
      return FontVariant(this.bold!, bold: true, italic: false);
    }
    if (italic && this.italic != null) {
      return FontVariant(this.italic!, bold: false, italic: true);
    }
    return FontVariant(regular, bold: false, italic: false);
  }
}

class FontVariant {
  const FontVariant(this.asset, {required this.bold, required this.italic});

  final String asset;
  final bool bold;
  final bool italic;
}

class FontCatalog {
  static const _dir = 'assets/fonts';

  static const List<FontFamilyDef> families = [
    FontFamilyDef(
      family: 'Liberation Sans',
      label: 'Sans (Liberation)',
      category: 'Linéale',
      regular: '$_dir/LiberationSans-Regular.ttf',
      bold: '$_dir/LiberationSans-Bold.ttf',
      italic: '$_dir/LiberationSans-Italic.ttf',
      boldItalic: '$_dir/LiberationSans-BoldItalic.ttf',
    ),
    FontFamilyDef(
      family: 'Ubuntu',
      label: 'Ubuntu',
      category: 'Linéale moderne',
      regular: '$_dir/Ubuntu-R.ttf',
      bold: '$_dir/Ubuntu-B.ttf',
      italic: '$_dir/Ubuntu-RI.ttf',
      boldItalic: '$_dir/Ubuntu-BI.ttf',
    ),
    FontFamilyDef(
      family: 'Ubuntu Condensed',
      label: 'Condensée (titres)',
      category: 'Affichage',
      regular: '$_dir/Ubuntu-C.ttf',
    ),
    FontFamilyDef(
      family: 'Liberation Serif',
      label: 'Serif (Liberation)',
      category: 'Serif',
      regular: '$_dir/LiberationSerif-Regular.ttf',
      bold: '$_dir/LiberationSerif-Bold.ttf',
      italic: '$_dir/LiberationSerif-Italic.ttf',
      boldItalic: '$_dir/LiberationSerif-BoldItalic.ttf',
    ),
    FontFamilyDef(
      family: 'DejaVu Sans',
      label: 'DejaVu Sans',
      category: 'Linéale',
      regular: '$_dir/DejaVuSans.ttf',
      bold: '$_dir/DejaVuSans-Bold.ttf',
    ),
    FontFamilyDef(
      family: 'DejaVu Sans Mono',
      label: 'Machine à écrire',
      category: 'Chasse fixe',
      regular: '$_dir/DejaVuSansMono.ttf',
      bold: '$_dir/DejaVuSansMono-Bold.ttf',
    ),
  ];

  static const String defaultFamily = 'Liberation Sans';

  static FontFamilyDef byFamily(String family) {
    for (final def in families) {
      if (def.family.toLowerCase() == family.toLowerCase()) return def;
    }
    return families.first;
  }

  static bool isKnown(String family) =>
      families.any((def) => def.family.toLowerCase() == family.toLowerCase());

  /// Associe un nom de police libre (proposé par une IA) à une police embarquée.
  static String closest(String requested) {
    final value = requested.toLowerCase();
    if (isKnown(requested)) return byFamily(requested).family;
    if (value.contains('mono') ||
        value.contains('courier') ||
        value.contains('code')) {
      return 'DejaVu Sans Mono';
    }
    if (value.contains('condensed') ||
        value.contains('bebas') ||
        value.contains('oswald') ||
        value.contains('impact') ||
        value.contains('anton') ||
        value.contains('league')) {
      return 'Ubuntu Condensed';
    }
    if (value.contains('serif') && !value.contains('sans') ||
        value.contains('playfair') ||
        value.contains('times') ||
        value.contains('georgia') ||
        value.contains('garamond') ||
        value.contains('merriweather') ||
        value.contains('lora') ||
        value.contains('didot')) {
      return 'Liberation Serif';
    }
    if (value.contains('ubuntu') ||
        value.contains('montserrat') ||
        value.contains('poppins') ||
        value.contains('nunito') ||
        value.contains('quicksand') ||
        value.contains('comfortaa') ||
        value.contains('raleway')) {
      return 'Ubuntu';
    }
    if (value.contains('dejavu') || value.contains('verdana')) {
      return 'DejaVu Sans';
    }
    return defaultFamily;
  }
}
