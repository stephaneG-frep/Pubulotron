import 'dart:ui';

import '../core/color_utils.dart';
import '../engine/font_catalog.dart';
import '../engine/icon_catalog.dart';
import '../models/business_profile.dart';

/// Styles de mise en page du moteur de composition.
enum LayoutStyle {
  neon,
  editorial,
  split,
  pop,
  nature,
  minimal,
  banner,
  ticket,
  menu,
  elegant,
}

extension LayoutStyleInfo on LayoutStyle {
  String get label => switch (this) {
    LayoutStyle.neon => 'Néon futuriste',
    LayoutStyle.editorial => 'Éditorial',
    LayoutStyle.split => 'Bloc de couleur',
    LayoutStyle.pop => 'Pop',
    LayoutStyle.nature => 'Nature',
    LayoutStyle.minimal => 'Minimal',
    LayoutStyle.banner => 'Bandeau promo',
    LayoutStyle.ticket => 'Ticket',
    LayoutStyle.menu => 'Carte / menu',
    LayoutStyle.elegant => 'Élégant',
  };

  static LayoutStyle parse(String? value) {
    final v = (value ?? '').toLowerCase();
    for (final style in LayoutStyle.values) {
      if (v == style.name || v == style.label.toLowerCase()) return style;
    }
    if (v.contains('futur') ||
        v.contains('tech') ||
        v.contains('néon') ||
        v.contains('neon')) {
      return LayoutStyle.neon;
    }
    if (v.contains('nature') || v.contains('bio') || v.contains('jardin')) {
      return LayoutStyle.nature;
    }
    if (v.contains('promo') || v.contains('solde')) return LayoutStyle.banner;
    if (v.contains('luxe') || v.contains('élégan') || v.contains('premium')) {
      return LayoutStyle.elegant;
    }
    if (v.contains('pop') || v.contains('fun')) return LayoutStyle.pop;
    if (v.contains('minimal') || v.contains('sobre')) {
      return LayoutStyle.minimal;
    }
    if (v.contains('menu') || v.contains('restaurant')) return LayoutStyle.menu;
    return LayoutStyle.split;
  }
}

/// Identité graphique partagée par plusieurs supports (pack publicitaire).
class BrandKit {
  const BrandKit({
    required this.headline,
    required this.slogan,
    this.offer = '',
    required this.callToAction,
    this.body = '',
    this.services = const [],
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.dark,
    required this.light,
    this.headingFont = 'Ubuntu',
    this.bodyFont = 'Liberation Sans',
    this.layout = LayoutStyle.split,
    this.iconKey = 'star',
    this.rationale = '',
    this.source = 'local',
  });

  final String headline;
  final String slogan;
  final String offer;
  final String callToAction;
  final String body;
  final List<String> services;
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color dark;
  final Color light;
  final String headingFont;
  final String bodyFont;
  final LayoutStyle layout;
  final String iconKey;
  final String rationale;

  /// « local » ou nom du fournisseur IA.
  final String source;

  List<Color> get palette => [primary, secondary, accent, dark, light];

  BrandKit copyWith({LayoutStyle? layout, String? offer, String? headline}) =>
      BrandKit(
        headline: headline ?? this.headline,
        slogan: slogan,
        offer: offer ?? this.offer,
        callToAction: callToAction,
        body: body,
        services: services,
        primary: primary,
        secondary: secondary,
        accent: accent,
        dark: dark,
        light: light,
        headingFont: headingFont,
        bodyFont: bodyFont,
        layout: layout ?? this.layout,
        iconKey: iconKey,
        rationale: rationale,
        source: source,
      );

  /// Kit construit hors ligne à partir de la fiche professionnelle.
  factory BrandKit.fromProfile(
    BusinessProfile profile, {
    LayoutStyle layout = LayoutStyle.split,
    String brief = '',
  }) {
    final colors = profile.brandColors;
    final primary = colors.isNotEmpty ? colors[0] : const Color(0xFF7545FF);
    final secondary = colors.length > 1 ? colors[1] : const Color(0xFF24C9C2);
    final accent = colors.length > 2 ? colors[2] : const Color(0xFFFFAA45);
    final offer = RegExp(r'(-?\d{1,2}\s?%)').firstMatch(brief)?.group(1) ?? '';
    return BrandKit(
      headline: profile.name.isEmpty ? 'Votre activité' : profile.name,
      slogan: profile.slogan.isNotEmpty ? profile.slogan : profile.activity,
      offer: offer.isEmpty ? '' : (offer.startsWith('-') ? offer : '-$offer'),
      callToAction: profile.phone.isNotEmpty
          ? 'Appelez le ${profile.phone}'
          : 'Contactez-nous',
      body: profile.description,
      services: profile.services,
      primary: primary,
      secondary: secondary,
      accent: accent,
      dark: const Color(0xFF17213B),
      light: const Color(0xFFF8F7FC),
      headingFont: 'Ubuntu',
      bodyFont: 'Liberation Sans',
      layout: layout,
      iconKey: guessIcon('${profile.activity} ${profile.name} $brief'),
    );
  }

  factory BrandKit.fromJson(
    Map<String, dynamic> json, {
    required BusinessProfile profile,
    String source = 'local',
  }) {
    final base = BrandKit.fromProfile(profile);
    Color c(String key, Color fallback) => parseHexColor(json[key]) ?? fallback;
    String s(String key, String fallback) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : fallback;
    }

    final icon = json['iconKey'];
    return BrandKit(
      headline: s('headline', base.headline),
      slogan: s('slogan', base.slogan),
      offer: s('offer', ''),
      callToAction: s('callToAction', base.callToAction),
      body: s('body', base.body),
      services: ((json['services'] as List?) ?? base.services)
          .whereType<String>()
          .take(6)
          .toList(),
      primary: c('primary', base.primary),
      secondary: c('secondary', base.secondary),
      accent: c('accent', base.accent),
      dark: c('dark', base.dark),
      light: c('light', base.light),
      headingFont: FontCatalog.closest(s('headingFont', base.headingFont)),
      bodyFont: FontCatalog.closest(s('bodyFont', base.bodyFont)),
      layout: LayoutStyleInfo.parse(json['layout'] as String?),
      iconKey: icon is String && IconCatalog.isKnown(icon)
          ? icon
          : base.iconKey,
      rationale: s('rationale', ''),
      source: source,
    );
  }

  static String guessIcon(String text) {
    final t = text.toLowerCase();
    const rules = {
      'informati': 'computer',
      'ordinateur': 'computer',
      'dépann': 'build',
      'jardin': 'florist',
      'paysag': 'park',
      'coiff': 'cut',
      'beauté': 'spa',
      'restaur': 'restaurant',
      'pizza': 'pizza',
      'café': 'cafe',
      'boulang': 'cake',
      'pâtiss': 'cake',
      'bar ': 'bar',
      'boutique': 'store',
      'commerce': 'bag',
      'plomb': 'plumbing',
      'électri': 'electric',
      'menuis': 'carpenter',
      'peint': 'paint',
      'ménage': 'cleaning',
      'domicile': 'home',
      'concert': 'music',
      'musique': 'music',
      'fête': 'celebration',
      'mariage': 'celebration',
      'événement': 'celebration',
      'association': 'volunteer',
      'club': 'groups',
      'sport': 'sport',
      'art': 'palette',
      'photo': 'camera',
      'garage': 'car',
      'animal': 'pets',
      'chien': 'pets',
      'cours': 'school',
      'formation': 'school',
    };
    for (final entry in rules.entries) {
      if (t.contains(entry.key)) return entry.value;
    }
    return 'sparkle';
  }
}
