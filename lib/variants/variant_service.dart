import 'dart:math' as math;
import 'dart:ui';

import '../ai/ai_client.dart';
import '../ai/ai_design_service.dart';
import '../ai/design_schema.dart';
import '../core/color_utils.dart';
import '../core/ids.dart';
import '../layout/brand_kit.dart';
import '../layout/layout_engine.dart';
import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/formats.dart';
import '../models/project.dart';

/// Direction artistique d'une variante.
class ArtDirection {
  const ArtDirection(
    this.name,
    this.description, {
    this.offlineStyle = LayoutStyle.split,
    this.palette = const [],
  });

  final String name;
  final String description;

  /// Mise en page utilisée par le générateur hors ligne.
  final LayoutStyle offlineStyle;
  final List<Color> palette;

  static const defaults = [
    ArtDirection(
      'Moderne et minimaliste',
      'Beaucoup d’espace blanc, une seule couleur d’accent, typographie linéale nette, hiérarchie très claire.',
      offlineStyle: LayoutStyle.minimal,
    ),
    ArtDirection(
      'Futuriste avec dégradés',
      'Fond sombre, dégradés lumineux, formes géométriques, effet néon, typographie technologique.',
      offlineStyle: LayoutStyle.neon,
    ),
    ArtDirection(
      'Élégante et professionnelle',
      'Palette sobre et profonde, filets fins, typographie serif, composition centrée et rassurante.',
      offlineStyle: LayoutStyle.elegant,
    ),
    ArtDirection(
      'Colorée et créative',
      'Couleurs vives, formes organiques ou bulles, titre condensé, énergie et bonne humeur.',
      offlineStyle: LayoutStyle.pop,
    ),
    ArtDirection(
      'Originale et audacieuse',
      'Composition asymétrique, grand bloc de couleur, éléments en rotation, titre très dominant.',
      offlineStyle: LayoutStyle.split,
    ),
  ];
}

/// Avancement d'une génération de variantes.
class VariantProgress {
  const VariantProgress({
    required this.done,
    required this.total,
    required this.current,
    this.failures = const [],
  });

  final int done;
  final int total;

  /// Direction en cours de génération.
  final String current;
  final List<String> failures;

  double get ratio => total == 0 ? 1 : done / total;
}

class VariantRunResult {
  const VariantRunResult(this.created, this.failures, {this.aborted = false});

  final List<Project> created;

  /// Messages d'erreur, par direction.
  final List<String> failures;

  /// Vrai si la génération a été interrompue (clé refusée, modèle absent…).
  final bool aborted;
}

/// Résumé textuel de la mise en page d'un document (polices, fond,
/// position des éléments clés), transmis à l'IA pour éviter les redites.
String layoutSummary(DesignDocument doc, {String title = ''}) {
  final page = doc.front;
  String where(DesignElement e) {
    final cx = (e.x + e.width / 2) / doc.widthMm;
    final cy = (e.y + e.height / 2) / doc.heightMm;
    final h = cx < 0.36
        ? 'gauche'
        : cx > 0.64
        ? 'droite'
        : 'centre';
    final v = cy < 0.36
        ? 'haut'
        : cy > 0.64
        ? 'bas'
        : 'milieu';
    return '$v-$h';
  }

  final fonts = page.elements
      .where((e) => e.type == ElementType.text)
      .map((e) => e.fontFamily)
      .toSet();
  final key = <String>[];
  for (final e in page.elements) {
    final role = (e.role ?? '').toLowerCase();
    if (role == 'name' ||
        role == 'headline' ||
        role == 'qr' ||
        role == 'logo' ||
        role == 'photo' ||
        e.type == ElementType.qr) {
      key.add('${role.isEmpty ? e.type.name : role} en ${where(e)}');
    }
  }
  return [
    if (title.isNotEmpty) '« $title »',
    'fond ${page.background.isGradient ? 'en dégradé' : 'uni'} ${colorToHex(page.background.primary)}',
    'polices ${fonts.join(', ')}',
    ...key,
  ].join(' ; ');
}

/// Couleur dominante perçue : moyenne du fond et des formes, pondérée par
/// leur surface visible sur la page.
Color dominantColor(DesignDocument doc) {
  final page = doc.front;
  final area = doc.widthMm * doc.heightMm;
  final bounds = Rect.fromLTWH(0, 0, doc.widthMm, doc.heightMm);
  final bg = page.background.stops;
  double r = 0, g = 0, b = 0;
  for (final c in bg) {
    r += c.r * area / bg.length;
    g += c.g * area / bg.length;
    b += c.b * area / bg.length;
  }
  var total = area;
  for (final e in page.elements) {
    final fill = e.fill;
    if (!e.visible || fill == null || e.type == ElementType.text) continue;
    final visible = e.rect.intersect(bounds);
    if (visible.width <= 0 || visible.height <= 0) continue;
    final w = visible.width * visible.height * e.opacity;
    for (final c in fill.stops) {
      r += c.r * w / fill.stops.length;
      g += c.g * w / fill.stops.length;
      b += c.b * w / fill.stops.length;
    }
    total += w;
  }
  return Color.from(
    alpha: 1,
    red: r / total,
    green: g / total,
    blue: b / total,
  );
}

/// Similarité de deux compositions (0 = très différentes, 1 = identiques).
double variantSimilarity(DesignDocument a, DesignDocument b) {
  double colorDistance(Color x, Color y) {
    final d = math.sqrt(
      math.pow(x.r - y.r, 2) + math.pow(x.g - y.g, 2) + math.pow(x.b - y.b, 2),
    );
    return (d / math.sqrt(3)).clamp(0.0, 1.0);
  }

  Set<String> fonts(DesignDocument d) => d.front.elements
      .where((e) => e.type == ElementType.text)
      .map((e) => e.fontFamily)
      .toSet();
  Offset? anchor(DesignDocument d, bool Function(DesignElement) test) {
    for (final e in d.front.elements) {
      if (test(e)) {
        return Offset(
          (e.x + e.width / 2) / d.widthMm,
          (e.y + e.height / 2) / d.heightMm,
        );
      }
    }
    return null;
  }

  bool isTitle(DesignElement e) => e.role == 'headline' || e.role == 'name';
  bool isQr(DesignElement e) => e.type == ElementType.qr;

  final fa = fonts(a);
  final fb = fonts(b);
  final union = fa.union(fb);
  final fontScore = union.isEmpty
      ? 1.0
      : fa.intersection(fb).length / union.length;
  final colorScore = 1 - colorDistance(dominantColor(a), dominantColor(b));
  double anchorScore(bool Function(DesignElement) test) {
    final pa = anchor(a, test);
    final pb = anchor(b, test);
    if (pa == null || pb == null) return pa == pb ? 1 : 0.5;
    return 1 - ((pa - pb).distance / math.sqrt2).clamp(0.0, 1.0);
  }

  final ca = a.front.elements.length;
  final cb = b.front.elements.length;
  final countScore = 1 - ((ca - cb).abs() / math.max(1, math.max(ca, cb)));
  return (fontScore * 0.25 +
          colorScore * 0.3 +
          anchorScore(isTitle) * 0.25 +
          anchorScore(isQr) * 0.1 +
          countScore * 0.1)
      .clamp(0.0, 1.0);
}

/// Génère des variantes graphiques d'un même format.
class VariantService {
  VariantService(this.ai);

  final AiDesignService ai;

  /// Seuil au-delà duquel une variante est jugée trop proche d'une autre.
  static const double similarityLimit = 0.86;

  static const _fatal = {
    AiErrorKind.missingKey,
    AiErrorKind.unauthorized,
    AiErrorKind.modelNotFound,
  };

  /// Génère une variante par direction, en évitant de ressembler aux
  /// variantes existantes du groupe. Chaque variante est transmise à
  /// [onVariant] dès qu'elle est prête (pour être enregistrée aussitôt).
  Future<VariantRunResult> generate({
    required AiConfig? config,
    required String brief,
    required BusinessProfile? profile,
    required DesignFormat format,
    required List<ArtDirection> directions,
    String? groupId,
    List<Project> existing = const [],
    required Future<void> Function(Project variant) onVariant,
    void Function(VariantProgress progress)? onProgress,
  }) async {
    final group = groupId ?? newId('var');
    final created = <Project>[];
    final failures = <String>[];
    var nextIndex =
        existing.map((p) => p.variantIndex ?? 0).fold(0, math.max) + 1;
    for (var i = 0; i < directions.length; i++) {
      final direction = directions[i];
      onProgress?.call(
        VariantProgress(
          done: i,
          total: directions.length,
          current: direction.name,
          failures: failures,
        ),
      );
      try {
        final document = await generateOne(
          config: config,
          brief: brief,
          profile: profile,
          format: format,
          direction: direction,
          avoid: [...existing, ...created],
        );
        final project = Project(
          name: '${format.label} — ${direction.name}',
          document: document,
          brief: brief,
          profileId: profile?.id,
          variantGroupId: group,
          variantIndex: nextIndex++,
          variantStyle: direction.name,
        );
        await onVariant(project);
        created.add(project);
      } on AiException catch (e) {
        failures.add('${direction.name} : ${e.message}');
        if (_fatal.contains(e.kind)) {
          onProgress?.call(
            VariantProgress(
              done: i + 1,
              total: directions.length,
              current: '',
              failures: failures,
            ),
          );
          return VariantRunResult(created, failures, aborted: true);
        }
      }
    }
    onProgress?.call(
      VariantProgress(
        done: directions.length,
        total: directions.length,
        current: '',
        failures: failures,
      ),
    );
    return VariantRunResult(created, failures);
  }

  /// Une seule variante (aussi utilisé pour « Régénérer »).
  Future<DesignDocument> generateOne({
    required AiConfig? config,
    required String brief,
    required BusinessProfile? profile,
    required DesignFormat format,
    required ArtDirection direction,
    List<Project> avoid = const [],
  }) async {
    if (config == null) return _offline(profile, format, direction, brief);
    final avoidText = avoid.isEmpty
        ? ''
        : 'Variantes déjà produites, dont celle-ci doit se distinguer nettement (disposition, typographie, formes, couleurs, emplacement du QR code) :\n'
              '${avoid.map((p) => '- ${p.variantStyle ?? p.name} : ${layoutSummary(p.document)}').join('\n')}';
    String instructions(String extra) => [
      'Direction artistique imposée : ${direction.name}. ${direction.description}',
      if (direction.palette.isNotEmpty)
        'Palette suggérée : ${direction.palette.map(colorToHex).join(', ')}.',
      avoidText,
      extra,
    ].where((s) => s.isNotEmpty).join('\n');

    var proposals = await ai.generateDesigns(
      config: config,
      brief: brief,
      profile: profile,
      widthMm: format.widthMm,
      heightMm: format.heightMm,
      formatLabel: format.label,
      duplex: format.duplex,
      count: 1,
      extraInstructions: instructions(''),
    );
    var document = proposals.first.document;
    final tooClose = avoid.any(
      (p) => variantSimilarity(p.document, document) > similarityLimit,
    );
    if (tooClose) {
      proposals = await ai.generateDesigns(
        config: config,
        brief: brief,
        profile: profile,
        widthMm: format.widthMm,
        heightMm: format.heightMm,
        formatLabel: format.label,
        duplex: format.duplex,
        count: 1,
        extraInstructions: instructions(
          'ATTENTION : ta proposition précédente ressemblait trop à une variante existante. Change radicalement la disposition, les polices et la palette.',
        ),
      );
      document = proposals.first.document;
    }
    return document.copyWith(formatId: format.id);
  }

  DesignDocument _offline(
    BusinessProfile? profile,
    DesignFormat format,
    ArtDirection direction,
    String brief,
  ) {
    final p = profile ?? BusinessProfile.example();
    var kit = LayoutEngine.kitForBrief(
      BrandKit.fromProfile(p, brief: brief),
      brief,
    ).copyWith(layout: direction.offlineStyle);
    if (direction.palette.length >= 2) {
      kit = BrandKit(
        headline: kit.headline,
        slogan: kit.slogan,
        offer: kit.offer,
        callToAction: kit.callToAction,
        body: kit.body,
        services: kit.services,
        primary: direction.palette[0],
        secondary: direction.palette[1],
        accent: direction.palette.length > 2
            ? direction.palette[2]
            : kit.accent,
        dark: kit.dark,
        light: kit.light,
        headingFont: kit.headingFont,
        bodyFont: kit.bodyFont,
        layout: direction.offlineStyle,
        iconKey: kit.iconKey,
      );
    }
    return LayoutEngine.build(
      style: direction.offlineStyle,
      widthMm: format.widthMm,
      heightMm: format.heightMm,
      kit: kit,
      profile: p,
      formatId: format.id,
      duplex: format.duplex,
    );
  }

  /// Directions artistiques proposées par l'IA pour une activité
  /// (« Surprends-moi ! »). Sans IA : les directions par défaut.
  Future<List<ArtDirection>> suggestDirections({
    required AiConfig? config,
    required String activity,
    required BusinessProfile? profile,
    int count = 5,
  }) async {
    if (config == null) return ArtDirection.defaults.take(count).toList();
    final raw = await ai.client.complete(
      config,
      AiRequest(
        system: 'Tu es le directeur artistique de Pubulotron. Tu réponds exclusivement en JSON valide.',
        user:
            '''
Activité décrite par l’utilisateur : « ${activity.trim()} »

Fiche professionnelle :
${AiDesignService.profileSummary(profile)}

Propose exactement $count directions artistiques très différentes et adaptées à cette activité (exemple pour un menuisier : artisan traditionnel, bois et nature, design contemporain, atelier industriel, création artistique).
Pour chacune : name (2 à 4 mots), description (une phrase concrète : ambiance, formes, typographie, mise en page), palette (3 couleurs #RRGGBB), layout parmi ${LayoutStyle.values.map((s) => s.name).join(', ')} (mise en page la plus proche).
Réponds au format {"directions": [...]}.''',
        jsonSchema: const {
          'type': 'object',
          'properties': {
            'directions': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string'},
                  'description': {'type': 'string'},
                  'palette': {
                    'type': 'array',
                    'items': {'type': 'string'},
                  },
                  'layout': {'type': 'string'},
                },
                'required': ['name', 'description', 'palette', 'layout'],
                'additionalProperties': false,
              },
            },
          },
          'required': ['directions'],
          'additionalProperties': false,
        },
        maxTokens: 4000,
      ),
    );
    return parseDirections(raw, count: count);
  }

  /// Lecture tolérante des directions (testable sans réseau).
  static List<ArtDirection> parseDirections(String raw, {int count = 5}) {
    final decoded = DesignSchema.decodeJson(raw);
    final list = decoded is Map ? decoded['directions'] : decoded;
    final directions = <ArtDirection>[];
    for (final item in list is List ? list : const []) {
      if (item is! Map) continue;
      final name = (item['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      directions.add(
        ArtDirection(
          name,
          (item['description'] as String?)?.trim() ?? '',
          offlineStyle: LayoutStyleInfo.parse(item['layout'] as String?),
          palette: ((item['palette'] as List?) ?? const [])
              .map(parseHexColor)
              .whereType<Color>()
              .toList(),
        ),
      );
    }
    if (directions.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'L’IA n’a proposé aucune direction artistique exploitable.',
      );
    }
    return directions.take(count).toList();
  }
}
