import 'dart:convert';
import 'dart:ui';

import '../core/color_utils.dart';
import '../engine/font_catalog.dart';
import '../engine/icon_catalog.dart';
import '../models/app_settings.dart';
import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import '../models/formats.dart';
import '../layout/brand_kit.dart';
import 'ai_client.dart';
import 'design_schema.dart';

class AiDesignProposal {
  const AiDesignProposal({
    required this.title,
    required this.style,
    required this.rationale,
    required this.palette,
    required this.document,
    required this.provider,
    this.warnings = const [],
  });

  final String title;
  final String style;
  final String rationale;
  final List<Color> palette;
  final DesignDocument document;
  final String provider;
  final List<String> warnings;
}

class AiEditResult {
  const AiEditResult({
    required this.message,
    required this.page,
    required this.applied,
    this.warnings = const [],
  });

  final String message;
  final DesignPage page;
  final int applied;
  final List<String> warnings;
}

class AiChatTurn {
  const AiChatTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Agent graphique : génère et modifie des créations structurées.
class AiDesignService {
  AiDesignService(this.client);

  final AiClient client;

  static String profileSummary(BusinessProfile? p) {
    if (p == null) return 'Aucune fiche professionnelle renseignée.';
    final lines = <String>[
      'Nom de l’activité : ${p.name}',
      if (p.activity.isNotEmpty) 'Secteur : ${p.activity}',
      if (p.contactName.isNotEmpty)
        'Contact : ${p.contactName}${p.jobTitle.isEmpty ? '' : ' (${p.jobTitle})'}',
      if (p.slogan.isNotEmpty) 'Slogan actuel : ${p.slogan}',
      if (p.description.isNotEmpty) 'Description : ${p.description}',
      if (p.services.isNotEmpty) 'Prestations : ${p.services.join(', ')}',
      if (p.phone.isNotEmpty) 'Téléphone : ${p.phone}',
      if (p.email.isNotEmpty) 'E-mail : ${p.email}',
      if (p.website.isNotEmpty) 'Site : ${p.website}',
      if (p.address.isNotEmpty) 'Adresse : ${p.address}',
      if (p.hours.isNotEmpty) 'Horaires : ${p.hours}',
      if (p.socials.isNotEmpty)
        'Réseaux : ${p.socials.map((s) => '${s.network} ${s.url}').join(', ')}',
      if (p.brandColors.isNotEmpty)
        'Couleurs de marque : ${p.brandColors.map(colorToHex).join(', ')}',
      'Logo disponible : ${p.logoAssetId == null ? 'non' : 'oui (élément image avec role "logo")'}',
    ];
    return lines.join('\n');
  }

  static String typographyHint(Size size) {
    final minSide = size.shortestSide;
    final (body, titleMin, titleMax) = minSide < 70
        ? (7.0, 11.0, 18.0)
        : minSide < 120
        ? (9.0, 18.0, 40.0)
        : minSide < 220
        ? (11.0, 28.0, 72.0)
        : minSide < 350
        ? (16.0, 60.0, 140.0)
        : (22.0, 90.0, 220.0);
    return 'Repères typographiques pour ce format : texte courant ≈ ${body.toStringAsFixed(0)} pt '
        '(jamais moins de ${(body * 0.85).toStringAsFixed(1)} pt), titre entre ${titleMin.toStringAsFixed(0)} '
        'et ${titleMax.toStringAsFixed(0)} pt. Hauteur d’une ligne en mm ≈ taille en pt × 0,353 × interligne.';
  }

  static String _rules(Size size) =>
      '''
Règles de composition :
- Unités : millimètres, origine en haut à gauche de la page (${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)} mm). Rotation en degrés, sens horaire.
- Garde une marge de sécurité d’au moins ${(size.shortestSide * 0.05).clamp(3, 15).toStringAsFixed(0)} mm pour les textes. Les fonds et formes décoratives peuvent toucher les bords (fond perdu).
- Ordre des éléments = ordre des calques (le premier est dessous).
- ${typographyHint(size)}
- Prévois des boîtes de texte assez grandes : largeur suffisante pour éviter les coupures, hauteur ≥ nombre de lignes × taille × 0,353 × 1,25.
- Contraste élevé entre texte et fond. Hiérarchie claire : un titre dominant, des informations secondaires lisibles.
- Couleurs en hexadécimal #RRGGBB. Dégradés : fill {kind: "linear"|"radial", colors: [deux couleurs], angle en degrés (0 = gauche→droite, 90 = haut→bas)}.
- Polices autorisées : ${FontCatalog.families.map((f) => '"${f.family}" (${f.category})').join(', ')}.
- Pictogrammes (type "icon", iconKey) : ${IconCatalog.all.map((i) => i.key).join(', ')}.
- Formes (type "shape", shape) : ${ShapeKind.values.map((s) => s.name).join(', ')} ; cornerRadius en mm pour les rectangles.
- QR code : type "qr", carré, qrData = URL complète (https://…) ; fill blanc conseillé.
- Photo : type "image" avec role "photo" (emplacement que l’utilisateur remplira). Logo : type "image" avec role "logo" si un logo est disponible.
- N’invente jamais de coordonnées (téléphone, e-mail, adresse) : utilise exactement celles de la fiche, ou omets-les.
- Textes en français, percutants, sans fautes. 6 à 14 éléments par face.''';

  static const _system =
      'Tu es le directeur artistique de Pubulotron, un studio publicitaire. Tu conçois des supports imprimés et '
      'numériques professionnels, lisibles et originaux. Tu réponds exclusivement en JSON valide, sans texte autour.';

  Future<List<AiDesignProposal>> generateDesigns({
    required AiConfig config,
    required String brief,
    required BusinessProfile? profile,
    required double widthMm,
    required double heightMm,
    String formatLabel = '',
    bool duplex = false,
    int count = 4,
  }) async {
    final size = Size(widthMm, heightMm);
    final user =
        '''
Brief du client : ${brief.trim().isEmpty ? 'Créer un support publicitaire pour mon activité.' : brief.trim()}

Support : ${formatLabel.isEmpty ? 'format personnalisé' : formatLabel} — ${widthMm.toStringAsFixed(1)} × ${heightMm.toStringAsFixed(1)} mm.
${duplex ? 'Recto verso : propose aussi un verso ("back") cohérent avec le recto.' : 'Recto seul (pas de "back").'}

Fiche professionnelle :
${profileSummary(profile)}

${_rules(size)}

Propose exactement $count designs nettement différents (composition, palette, typographie, ambiance), chacun avec un titre court, un style, une justification (rationale) d’une ou deux phrases et une palette.
Réponds au format {"designs": [...]}.''';
    final request = AiRequest(
      system: _system,
      user: user,
      jsonSchema: DesignSchema.designsSchema,
      maxTokens: 16000,
    );
    String raw = await client.complete(config, request);
    try {
      return parseDesigns(
        raw,
        size: size,
        profile: profile,
        provider: config.provider.label,
        formatId: _formatFor(widthMm, heightMm),
      );
    } on AiException catch (e) {
      if (e.kind != AiErrorKind.invalidResponse) rethrow;
      raw = await client.complete(
        config,
        AiRequest(
          system: _system,
          user:
              '$user\n\nATTENTION : ta réponse précédente était inutilisable (${e.message}). Respecte strictement le format JSON demandé.',
          jsonSchema: DesignSchema.designsSchema,
          maxTokens: 16000,
        ),
      );
      return parseDesigns(
        raw,
        size: size,
        profile: profile,
        provider: config.provider.label,
        formatId: _formatFor(widthMm, heightMm),
      );
    }
  }

  static String _formatFor(double w, double h) {
    for (final f in DesignFormats.all) {
      if ((f.widthMm - w).abs() < 0.01 && (f.heightMm - h).abs() < 0.01) {
        return f.id;
      }
    }
    return 'custom';
  }

  static DesignPage? _face(
    Object? raw,
    ElementSanitizer sanitizer,
    String name,
  ) {
    if (raw is! Map) return null;
    final elements = <DesignElement>[];
    for (final e in (raw['elements'] as List?) ?? const []) {
      final element = sanitizer.element(e);
      if (element != null) elements.add(element);
    }
    if (elements.isEmpty) return null;
    return DesignPage(
      name: name,
      background:
          sanitizer.fill(raw['background']) ??
          Fill.solid(const Color(0xFFFFFFFF)),
      elements: elements,
    );
  }

  /// Analyse et valide la réponse de génération (testable sans réseau).
  static List<AiDesignProposal> parseDesigns(
    String raw, {
    required Size size,
    required BusinessProfile? profile,
    required String provider,
    String formatId = 'custom',
  }) {
    final decoded = DesignSchema.decodeJson(raw);
    List<Object?> items;
    if (decoded is List) {
      items = decoded;
    } else if (decoded is Map) {
      final list =
          decoded['designs'] ?? decoded['concepts'] ?? decoded['proposals'];
      items = list is List ? list : [decoded];
    } else {
      items = const [];
    }
    final proposals = <AiDesignProposal>[];
    for (final item in items) {
      if (item is! Map) continue;
      final sanitizer = ElementSanitizer(pageSize: size, profile: profile);
      // Tolère un design « à plat » (éléments directement dans l'objet).
      final front = _face(item['front'] ?? item, sanitizer, 'Recto');
      if (front == null) continue;
      final back = _face(item['back'], sanitizer, 'Verso');
      final palette = ((item['palette'] as List?) ?? const [])
          .map(parseHexColor)
          .whereType<Color>()
          .toList();
      proposals.add(
        AiDesignProposal(
          title: (item['title'] as String?)?.trim().isNotEmpty == true
              ? (item['title'] as String).trim()
              : 'Proposition ${proposals.length + 1}',
          style: (item['style'] as String?)?.trim() ?? '',
          rationale: (item['rationale'] as String?)?.trim() ?? '',
          palette: palette,
          provider: provider,
          warnings: List.unmodifiable(sanitizer.warnings),
          document: DesignDocument(
            widthMm: size.width,
            heightMm: size.height,
            formatId: formatId,
            pages: [front, ?back],
          ),
        ),
      );
    }
    if (proposals.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'L’IA n’a renvoyé aucun design exploitable. Réessayez ou reformulez la demande.',
      );
    }
    return proposals;
  }

  Future<AiEditResult> editPage({
    required AiConfig config,
    required DesignDocument document,
    required int pageIndex,
    required String instruction,
    BusinessProfile? profile,
    Set<String> selectedIds = const {},
    List<AiChatTurn> history = const [],
  }) async {
    final page = document.pages[pageIndex];
    final size = document.sizeMm;
    final pageJson = {
      'face': page.name,
      'background': page.background.toJson(),
      'elements': page.elements.map((e) {
        final json = e.toJson();
        if (e.type == ElementType.image) json['hasImage'] = e.assetId != null;
        return json;
      }).toList(),
    };
    final conversation = history.isEmpty
        ? ''
        : 'Échanges précédents :\n${history.take(12).map((t) => '${t.fromUser ? 'Utilisateur' : 'Assistant'} : ${t.text}').join('\n')}\n\n';
    final user =
        '''
${conversation}Création actuelle (${size.width.toStringAsFixed(1)} × ${size.height.toStringAsFixed(1)} mm) :
${jsonEncode(pageJson)}

${selectedIds.isEmpty ? 'Aucun élément sélectionné.' : 'Éléments sélectionnés par l’utilisateur : ${selectedIds.join(', ')}.'}

Fiche professionnelle :
${profileSummary(profile)}

${_rules(size)}

Demande de l’utilisateur : « ${instruction.trim()} »

Réponds par {"message": "...", "operations": [...]}.
- "update" : {"op":"update","id":"…","changes":{seulement les propriétés modifiées}}.
- "add" : {"op":"add","element":{élément complet}} (ajouté au premier plan).
- "delete" : {"op":"delete","id":"…"}.
- "reorder" : {"op":"reorder","id":"…","position":"front|back|forward|backward"}.
- "background" : {"op":"background","fill":{…}}.
N’applique que ce qui est demandé. Ne modifie pas les éléments verrouillés ("locked": true).
Si l’utilisateur pose une question ou demande un conseil, réponds dans "message" avec "operations": [].
"message" résume en une ou deux phrases ce que tu as fait, en français.''';
    final raw = await client.complete(
      config,
      AiRequest(
        system: _system,
        user: user,
        jsonSchema: DesignSchema.editSchema,
        maxTokens: 12000,
      ),
    );
    return applyEdit(raw, page, size, profile: profile);
  }

  /// Valide et applique les opérations d'édition (testable sans réseau).
  static AiEditResult applyEdit(
    String raw,
    DesignPage page,
    Size size, {
    BusinessProfile? profile,
  }) {
    final decoded = DesignSchema.decodeJson(raw);
    if (decoded is! Map) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'Réponse de modification inattendue.',
      );
    }
    final sanitizer = ElementSanitizer(pageSize: size, profile: profile);
    final message = (decoded['message'] as String?)?.trim() ?? '';
    final operations = decoded['operations'];
    var elements = [...page.elements];
    var background = page.background;
    var applied = 0;
    int indexOf(String? id) =>
        id == null ? -1 : elements.indexWhere((e) => e.id == id);

    for (final op in operations is List ? operations : const []) {
      if (op is! Map) continue;
      final kind = op['op'];
      final id = op['id'] as String?;
      switch (kind) {
        case 'update':
          final index = indexOf(id);
          final changes = op['changes'];
          if (index < 0 || changes is! Map) {
            sanitizer.warnings.add(
              'Modification ignorée : élément « $id » introuvable.',
            );
            continue;
          }
          final base = elements[index];
          if (base.locked) {
            sanitizer.warnings.add(
              '« ${base.displayName} » est verrouillé : non modifié.',
            );
            continue;
          }
          final merged = {
            ...base.toJson(),
            ...changes.cast<String, dynamic>(),
            'type': base.type.name,
          };
          final updated = sanitizer.element(merged, keepId: base.id);
          if (updated == null) continue;
          elements[index] = updated.copyWith(
            locked: base.locked,
            assetId: base.assetId,
          );
          applied++;
        case 'add':
          final element = sanitizer.element(op['element']);
          if (element == null) continue;
          elements.add(element);
          applied++;
        case 'delete':
          final index = indexOf(id);
          if (index < 0) {
            sanitizer.warnings.add(
              'Suppression ignorée : élément « $id » introuvable.',
            );
            continue;
          }
          if (elements[index].locked) {
            sanitizer.warnings.add(
              '« ${elements[index].displayName} » est verrouillé : non supprimé.',
            );
            continue;
          }
          elements.removeAt(index);
          applied++;
        case 'reorder':
          final index = indexOf(id);
          if (index < 0) continue;
          final element = elements.removeAt(index);
          final target = switch (op['position']) {
            'front' => elements.length,
            'back' => 0,
            'forward' => (index + 1).clamp(0, elements.length),
            'backward' => (index - 1).clamp(0, elements.length),
            _ => index,
          };
          elements.insert(target, element);
          applied++;
        case 'background':
          final fill = sanitizer.fill(op['fill']);
          if (fill == null) {
            sanitizer.warnings.add('Fond ignoré : couleur invalide.');
            continue;
          }
          background = fill;
          applied++;
        default:
          sanitizer.warnings.add('Opération « $kind » inconnue ignorée.');
      }
    }
    if (applied == 0 && message.isEmpty) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'L’IA n’a proposé aucune modification exploitable.',
      );
    }
    return AiEditResult(
      message: message.isEmpty
          ? '$applied modification(s) appliquée(s).'
          : message,
      page: page.copyWith(elements: elements, background: background),
      applied: applied,
      warnings: sanitizer.warnings,
    );
  }

  Future<BrandKit> brandKit({
    required AiConfig config,
    required String brief,
    required BusinessProfile profile,
  }) async {
    final user =
        '''
Brief : ${brief.trim().isEmpty ? 'Créer toute la publicité de mon activité.' : brief.trim()}

Fiche professionnelle :
${profileSummary(profile)}

Analyse l’activité et définis une identité graphique cohérente pour un pack publicitaire (carte de visite, flyer, affiche, publication et story pour les réseaux sociaux) :
- headline : accroche principale (≤ 6 mots), slogan (≤ 10 mots), offer (promotion éventuelle, sinon chaîne vide), callToAction (≤ 6 mots), body (une phrase de présentation), services (3 à 5 prestations courtes).
- Palette : primary, secondary, accent, dark (texte sombre), light (fond clair), en #RRGGBB, contrastées et adaptées au secteur${profile.brandColors.isEmpty ? '' : ' (respecte les couleurs de marque)'}.
- headingFont et bodyFont parmi : ${FontCatalog.families.map((f) => f.family).join(', ')}.
- layout parmi : ${LayoutStyle.values.map((s) => s.name).join(', ')}.
- iconKey : pictogramme représentatif parmi : ${IconCatalog.all.map((i) => i.key).join(', ')}.
- rationale : justification en une phrase.''';
    final raw = await client.complete(
      config,
      AiRequest(
        system: _system,
        user: user,
        jsonSchema: DesignSchema.brandKitSchema,
        maxTokens: 4000,
      ),
    );
    final decoded = DesignSchema.decodeJson(raw);
    if (decoded is! Map) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'Identité graphique illisible.',
      );
    }
    return BrandKit.fromJson(
      decoded.cast<String, dynamic>(),
      profile: profile,
      source: config.provider.label,
    );
  }
}

extension AiConfigFromSettings on AppSettings {
  AiConfig aiConfig(String apiKey) =>
      AiConfig(provider: provider, apiKey: apiKey, model: modelFor(provider));
}
