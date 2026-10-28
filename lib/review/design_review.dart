import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../ai/ai_client.dart';
import '../ai/ai_design_service.dart';
import '../ai/design_schema.dart';
import '../core/units.dart';
import '../models/app_settings.dart';
import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';

enum FindingSeverity { info, warning, critical }

extension FindingSeverityLabel on FindingSeverity {
  String get label => switch (this) {
    FindingSeverity.info => 'Suggestion',
    FindingSeverity.warning => 'À améliorer',
    FindingSeverity.critical => 'Important',
  };
}

class ReviewFinding {
  const ReviewFinding({
    required this.severity,
    required this.title,
    required this.detail,
    this.elementId,
    this.source = 'analyse locale',
  });

  final FindingSeverity severity;
  final String title;
  final String detail;
  final String? elementId;

  /// « analyse locale » ou nom du fournisseur IA.
  final String source;
}

class ReviewReport {
  const ReviewReport({
    required this.summary,
    required this.findings,
    required this.imagesUsed,
    required this.limits,
  });

  final String summary;
  final List<ReviewFinding> findings;

  /// L'IA a-t-elle vu le rendu (analyse visuelle) ?
  final bool imagesUsed;

  /// Explication des limites de l'analyse.
  final String limits;
}

class ImprovementResult {
  const ImprovementResult({
    required this.page,
    required this.message,
    required this.applied,
    required this.guarded,
  });

  /// Face proposée (l'original n'est jamais modifié).
  final DesignPage page;
  final String message;
  final int applied;

  /// Corrections imposées par les garde-fous (coordonnées, QR…).
  final List<String> guarded;
}

/// Rapport de contraste WCAG entre deux couleurs.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

Color _average(Fill fill) {
  final stops = fill.stops;
  double r = 0, g = 0, b = 0;
  for (final c in stops) {
    r += c.r;
    g += c.g;
    b += c.b;
  }
  return Color.from(
    alpha: 1,
    red: r / stops.length,
    green: g / stops.length,
    blue: b / stops.length,
  );
}

/// Analyse structurelle locale (aucune connexion nécessaire).
class LocalDesignAnalyzer {
  static const contactRoles = {
    'phone',
    'email',
    'website',
    'web',
    'address',
    'place',
    'contact',
    'contacts',
    'hours',
  };

  /// Couleur estimée sous le centre d'un élément (fond ou forme en dessous).
  static Color backgroundUnder(DesignPage page, DesignElement target) {
    var color = _average(page.background);
    final center = target.center;
    for (final e in page.elements) {
      if (e.id == target.id) break;
      if (!e.visible || e.opacity < 0.5) continue;
      if ((e.type == ElementType.shape ||
              (e.type == ElementType.text && e.fill != null)) &&
          e.fill != null &&
          e.rect.contains(center)) {
        color = _average(e.fill!);
      }
    }
    if (target.fill != null) color = _average(target.fill!);
    return color;
  }

  static double minimumTextPt(Size page) {
    final side = page.shortestSide;
    return side < 70
        ? 6.0
        : side < 120
        ? 7.5
        : side < 220
        ? 9.0
        : 12.0;
  }

  static List<ReviewFinding> analyze(DesignDocument doc, {int pageIndex = 0}) {
    final page = doc.pages[pageIndex.clamp(0, doc.pages.length - 1)];
    final findings = <ReviewFinding>[];
    final size = doc.sizeMm;
    final minPt = minimumTextPt(size);
    final texts = page.elements
        .where(
          (e) =>
              e.visible &&
              e.type == ElementType.text &&
              e.text.trim().isNotEmpty,
        )
        .toList();

    for (final e in texts) {
      final short = e.text.split('\n').first;
      final label = short.length > 30 ? '${short.substring(0, 29)}…' : short;
      final ratio = contrastRatio(e.color, backgroundUnder(page, e));
      final large = e.fontSize >= 18 || (e.bold && e.fontSize >= 14);
      if (ratio < (large ? 3 : 4.5)) {
        findings.add(
          ReviewFinding(
            severity: ratio < 2
                ? FindingSeverity.critical
                : FindingSeverity.warning,
            title: 'Contraste insuffisant',
            detail:
                '« $label » : contraste ${ratio.toStringAsFixed(1)}:1 avec le fond (minimum conseillé ${large ? 3 : 4.5}:1).',
            elementId: e.id,
          ),
        );
      }
      if (e.fontSize < minPt) {
        findings.add(
          ReviewFinding(
            severity: contactRoles.contains(e.role)
                ? FindingSeverity.critical
                : FindingSeverity.warning,
            title: 'Texte trop petit',
            detail:
                '« $label » est en ${e.fontSize.toStringAsFixed(1)} pt ; au moins ${minPt.toStringAsFixed(1)} pt pour ce format.',
            elementId: e.id,
          ),
        );
      }
      const safe = 3.0;
      if (e.rotation % 360 == 0 &&
          (e.x < safe ||
              e.y < safe ||
              e.x + e.width > size.width - safe ||
              e.y + e.height > size.height - safe)) {
        findings.add(
          ReviewFinding(
            severity: FindingSeverity.warning,
            title: 'Texte trop près du bord',
            detail:
                '« $label » entre dans la marge de sécurité de 3 mm : risque de coupe à l’impression.',
            elementId: e.id,
          ),
        );
      }
    }
    for (var i = 0; i < texts.length; i++) {
      for (var j = i + 1; j < texts.length; j++) {
        final overlap = texts[i].rect.intersect(texts[j].rect);
        if (overlap.width > 0.5 && overlap.height > 0.5) {
          final area = overlap.width * overlap.height;
          final smaller = math.min(
            texts[i].width * texts[i].height,
            texts[j].width * texts[j].height,
          );
          if (area > smaller * 0.15) {
            findings.add(
              ReviewFinding(
                severity: FindingSeverity.warning,
                title: 'Textes superposés',
                detail:
                    '« ${texts[i].displayName} » et « ${texts[j].displayName} » se chevauchent.',
                elementId: texts[j].id,
              ),
            );
          }
        }
      }
    }
    for (final e in page.elements.where(
      (e) => e.visible && e.type == ElementType.qr,
    )) {
      final side = math.min(e.width, e.height);
      if (side < 15) {
        findings.add(
          ReviewFinding(
            severity: FindingSeverity.critical,
            title: 'QR code trop petit',
            detail:
                'Le QR code mesure ${formatMm(side)} mm : prévoyez au moins 15 mm (20 mm pour une vCard).',
            elementId: e.id,
          ),
        );
      }
      final background = e.fill != null
          ? _average(e.fill!)
          : backgroundUnder(page, e);
      if (contrastRatio(e.color, background) < 4) {
        findings.add(
          ReviewFinding(
            severity: FindingSeverity.critical,
            title: 'QR code peu lisible',
            detail: 'Les modules du QR code ne contrastent pas assez avec leur fond : la lecture risque d’échouer.',
            elementId: e.id,
          ),
        );
      }
    }
    final fonts = texts.map((e) => e.fontFamily).toSet();
    if (fonts.length > 3) {
      findings.add(
        ReviewFinding(
          severity: FindingSeverity.info,
          title: 'Trop de polices',
          detail:
              '${fonts.length} polices différentes : deux suffisent généralement (une pour les titres, une pour le texte).',
        ),
      );
    }
    final empty = page.elements
        .where(
          (e) => e.visible && e.type == ElementType.image && e.assetId == null,
        )
        .length;
    if (empty > 0) {
      findings.add(
        ReviewFinding(
          severity: FindingSeverity.warning,
          title: 'Emplacement photo vide',
          detail:
              '$empty emplacement${empty > 1 ? 's' : ''} photo sans image : ${empty > 1 ? 'ils ne seront pas imprimés' : 'il ne sera pas imprimé'}.',
        ),
      );
    }
    if (texts.isNotEmpty) {
      final biggest = texts.map((e) => e.fontSize).reduce(math.max);
      final second = texts
          .map((e) => e.fontSize)
          .where((s) => s < biggest)
          .fold<double>(0, math.max);
      if (second > 0 && biggest / second < 1.3) {
        findings.add(
          const ReviewFinding(
            severity: FindingSeverity.info,
            title: 'Hiérarchie peu marquée',
            detail: 'Le titre est à peine plus grand que les autres textes : agrandissez-le pour guider le regard.',
          ),
        );
      }
    }
    return findings;
  }
}

/// Garde-fous appliqués à une amélioration automatique.
class ImprovementGuard {
  static bool _allowsDeletion(String instruction) => RegExp(
    r'\b(supprim|retir|enl[eè]v|effac)',
    caseSensitive: false,
  ).hasMatch(instruction);

  static bool _keepsAllTexts(String instruction) => RegExp(
    r'(conserv|gard|préserv|preserv)\w*\s+(mes|les|tous les)\s+textes',
    caseSensitive: false,
  ).hasMatch(instruction);

  /// Éléments à protéger : coordonnées, nom, QR codes, logo.
  static bool isProtected(DesignElement e, BusinessProfile? profile) {
    final role = (e.role ?? '').toLowerCase();
    if (e.type == ElementType.qr) return true;
    if (role == 'logo' ||
        role == 'name' ||
        LocalDesignAnalyzer.contactRoles.contains(role)) {
      return true;
    }
    if (e.type == ElementType.text && profile != null) {
      final values = [
        profile.phone,
        profile.email,
        profile.website,
        profile.address,
        profile.name,
      ].where((v) => v.trim().length >= 4);
      if (values.any((v) => e.text.contains(v))) return true;
    }
    return false;
  }

  /// Corrige [candidate] pour respecter les contraintes ; renvoie la face
  /// corrigée et la liste des corrections.
  static (DesignPage, List<String>) enforce({
    required DesignPage original,
    required DesignPage candidate,
    required String instruction,
    BusinessProfile? profile,
  }) {
    final notes = <String>[];
    final keepTexts = _keepsAllTexts(instruction);
    final allowDelete = _allowsDeletion(instruction);
    final byId = {for (final e in candidate.elements) e.id: e};
    final elements = <DesignElement>[];
    for (final e in candidate.elements) {
      final o = original.elementById(e.id);
      if (o == null) {
        elements.add(e);
        continue;
      }
      var fixed = e;
      if (o.type == ElementType.qr && e.qrData != o.qrData) {
        fixed = fixed.copyWith(qrData: o.qrData);
        notes.add('Contenu du QR code conservé.');
      }
      if (o.type == ElementType.text &&
          e.text != o.text &&
          (keepTexts || isProtected(o, profile))) {
        fixed = fixed.copyWith(text: o.text);
        notes.add('Texte « ${o.displayName} » conservé.');
      }
      if (o.assetId != null && e.assetId != o.assetId) {
        fixed = fixed.copyWith(assetId: o.assetId);
      }
      elements.add(fixed);
    }
    // Éléments supprimés par l'IA : rétablis s'ils sont importants ou si la
    // demande n'autorise pas de suppression.
    for (var i = 0; i < original.elements.length; i++) {
      final o = original.elements[i];
      if (byId.containsKey(o.id)) continue;
      if (!allowDelete || isProtected(o, profile)) {
        elements.insert(math.min(i, elements.length), o);
        notes.add('« ${o.displayName} » rétabli (suppression non autorisée).');
      }
    }
    return (candidate.copyWith(elements: elements), notes.toSet().toList());
  }
}

/// Assistant « Améliore mon design ».
class DesignReviewService {
  DesignReviewService(this.ai);

  final AiDesignService ai;

  static const _system =
      'Tu es le directeur artistique de Pubulotron. Tu analyses des créations publicitaires et réponds exclusivement en JSON valide.';

  static const _adviceSchema = {
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'findings': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'severity': {
              'type': 'string',
              'enum': ['info', 'warning', 'critical'],
            },
            'title': {'type': 'string'},
            'detail': {'type': 'string'},
            'elementId': {'type': 'string'},
          },
          'required': ['severity', 'title', 'detail'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['summary', 'findings'],
    'additionalProperties': false,
  };

  String _context(
    DesignDocument doc,
    int pageIndex,
    List<ReviewFinding> local,
  ) {
    final page = doc.pages[pageIndex];
    final elements = page.elements.map((e) => e.toJson()).toList();
    return '''
Création : ${doc.widthMm.toStringAsFixed(1)} × ${doc.heightMm.toStringAsFixed(1)} mm (${page.name}).
Fond : ${page.background.toJson()}
Éléments (du dessous vers le dessus, unités mm, polices en points) :
$elements

Constats de l’analyse automatique locale :
${local.isEmpty ? 'aucun' : local.map((f) => '- ${f.title} : ${f.detail}').join('\n')}''';
  }

  /// Mode Conseils : analyse sans modifier la création.
  Future<ReviewReport> advise({
    required AiConfig? config,
    required DesignDocument document,
    int pageIndex = 0,
    String instruction = '',
    BusinessProfile? profile,
    Uint8List? preview,
  }) async {
    final local = LocalDesignAnalyzer.analyze(document, pageIndex: pageIndex);
    if (config == null) {
      return ReviewReport(
        summary: local.isEmpty
            ? 'Aucun défaut technique détecté.'
            : '${local.length} point(s) relevé(s) par l’analyse automatique.',
        findings: local,
        imagesUsed: false,
        limits:
            'Analyse locale uniquement (sans IA) : contrastes, tailles, marges, QR codes et superpositions. '
            'Configurez un fournisseur IA pour des conseils de composition.',
      );
    }
    final response = await ai.client.completeDetailed(
      config,
      AiRequest(
        system: _system,
        user:
            '''
${_context(document, pageIndex, local)}

Fiche professionnelle :
${AiDesignService.profileSummary(profile)}

Demande de l’utilisateur : « ${instruction.trim().isEmpty ? 'Analyse ce design et dis-moi ce qui pourrait être amélioré.' : instruction.trim()} »

Mode conseils : n’applique aucune modification. Analyse la hiérarchie visuelle, les contrastes, les couleurs, les espacements, l’équilibre, la lisibilité, le QR code et les contraintes du format.
${preview != null ? 'Une image du rendu est jointe.' : ''}
Donne un résumé (2 à 3 phrases) et 3 à 8 constats concrets et actionnables, en français. Réponds au format {"summary": "...", "findings": [...]}.''',
        jsonSchema: _adviceSchema,
        maxTokens: 6000,
        images: [?preview],
      ),
    );
    final decoded = DesignSchema.decodeJson(response.text);
    if (decoded is! Map) {
      throw const AiException(
        AiErrorKind.invalidResponse,
        'Analyse IA illisible.',
      );
    }
    final aiFindings = <ReviewFinding>[];
    for (final f in (decoded['findings'] as List?) ?? const []) {
      if (f is! Map) continue;
      final title = (f['title'] as String?)?.trim() ?? '';
      if (title.isEmpty) continue;
      aiFindings.add(
        ReviewFinding(
          severity: FindingSeverity.values.firstWhere(
            (s) => s.name == f['severity'],
            orElse: () => FindingSeverity.info,
          ),
          title: title,
          detail: (f['detail'] as String?)?.trim() ?? '',
          elementId: f['elementId'] as String?,
          source: config.provider.label,
        ),
      );
    }
    return ReviewReport(
      summary: (decoded['summary'] as String?)?.trim() ?? '',
      findings: [...local, ...aiFindings],
      imagesUsed: response.imagesUsed,
      limits: response.imagesUsed
          ? 'L’IA a analysé le rendu visuel et la structure de la création.'
          : 'Ce modèle ne lit pas les images : l’analyse porte sur la structure de la création (positions, tailles, couleurs, textes), '
                'pas sur son apparence exacte. Choisissez un modèle compatible avec les images pour une analyse visuelle.',
    );
  }

  /// Mode Amélioration automatique : propose une nouvelle face, sans
  /// toucher à l'original.
  Future<ImprovementResult> improve({
    required AiConfig config,
    required DesignDocument document,
    int pageIndex = 0,
    required String instruction,
    BusinessProfile? profile,
    Uint8List? preview,
  }) async {
    final original = document.pages[pageIndex];
    final local = LocalDesignAnalyzer.analyze(document, pageIndex: pageIndex);
    final goal = instruction.trim().isEmpty
        ? 'Améliore la lisibilité et l’équilibre graphique de cette création.'
        : instruction.trim();
    final response = await ai.client.completeDetailed(
      config,
      AiRequest(
        system: _system,
        user:
            '''
${_context(document, pageIndex, local)}

Fiche professionnelle :
${AiDesignService.profileSummary(profile)}

Objectif de l’utilisateur : « $goal »

Mode amélioration automatique. Produis des opérations qui améliorent réellement la création (hiérarchie, contrastes, couleurs, espacements, alignements, tailles, formes décoratives).
Contraintes impératives :
- ne modifie pas les coordonnées professionnelles (téléphone, e-mail, site, adresse) ni le nom de l’activité, et n’en invente pas ;
- ne change pas le contenu ("qrData") des QR codes ;
- ne supprime pas d’élément important (textes, QR code, logo, photo) sauf demande explicite ;
- garde les identifiants ("id") existants et chaque élément éditable.
${preview != null ? 'Une image du rendu est jointe.' : ''}
Opérations disponibles : update (id + changes), add (element), delete (id), reorder (id + position), background (fill).
Réponds par {"message": "résumé des améliorations en une ou deux phrases", "operations": [...]}.''',
        jsonSchema: DesignSchema.editSchema,
        maxTokens: 12000,
        images: [?preview],
      ),
    );
    final edit = AiDesignService.applyEdit(
      response.text,
      original,
      document.sizeMm,
      profile: profile,
    );
    final (guardedPage, notes) = ImprovementGuard.enforce(
      original: original,
      candidate: edit.page,
      instruction: goal,
      profile: profile,
    );
    return ImprovementResult(
      page: guardedPage,
      message: edit.message,
      applied: edit.applied,
      guarded: [...notes, ...edit.warnings],
    );
  }
}
