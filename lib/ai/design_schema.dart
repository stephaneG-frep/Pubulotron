import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../core/color_utils.dart';
import '../engine/font_catalog.dart';
import '../engine/icon_catalog.dart';
import '../engine/qr_payload.dart';
import '../models/business_profile.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import 'ai_client.dart';

/// Schémas JSON transmis aux modèles et validation des réponses.
class DesignSchema {
  static Map<String, dynamic> get fillSchema => {
    'type': 'object',
    'properties': {
      'kind': {
        'type': 'string',
        'enum': FillKind.values.map((k) => k.name).toList(),
      },
      'colors': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'angle': {'type': 'number'},
    },
    'required': ['kind', 'colors'],
    'additionalProperties': false,
  };

  static Map<String, dynamic> elementSchema({bool requireGeometry = true}) => {
    'type': 'object',
    'properties': {
      'type': {
        'type': 'string',
        'enum': ElementType.values.map((t) => t.name).toList(),
      },
      'name': {'type': 'string'},
      'role': {'type': 'string'},
      'x': {'type': 'number'},
      'y': {'type': 'number'},
      'width': {'type': 'number'},
      'height': {'type': 'number'},
      'rotation': {'type': 'number'},
      'opacity': {'type': 'number'},
      'text': {'type': 'string'},
      'fontFamily': {
        'type': 'string',
        'enum': FontCatalog.families.map((f) => f.family).toList(),
      },
      'fontSize': {'type': 'number'},
      'bold': {'type': 'boolean'},
      'italic': {'type': 'boolean'},
      'textAlign': {
        'type': 'string',
        'enum': TextAlignH.values.map((v) => v.name).toList(),
      },
      'verticalAlign': {
        'type': 'string',
        'enum': TextAlignV.values.map((v) => v.name).toList(),
      },
      'lineHeight': {'type': 'number'},
      'letterSpacing': {'type': 'number'},
      'color': {'type': 'string'},
      'fill': fillSchema,
      'strokeColor': {'type': 'string'},
      'strokeWidth': {'type': 'number'},
      'cornerRadius': {'type': 'number'},
      'shape': {
        'type': 'string',
        'enum': ShapeKind.values.map((s) => s.name).toList(),
      },
      'qrData': {'type': 'string'},
      'iconKey': {
        'type': 'string',
        'enum': IconCatalog.all.map((i) => i.key).toList(),
      },
      'imageFit': {
        'type': 'string',
        'enum': ['cover', 'contain'],
      },
    },
    'required': requireGeometry
        ? ['type', 'x', 'y', 'width', 'height']
        : <String>[],
    'additionalProperties': false,
  };

  static Map<String, dynamic> get faceSchema => {
    'type': 'object',
    'properties': {
      'background': fillSchema,
      'elements': {'type': 'array', 'items': elementSchema()},
    },
    'required': ['background', 'elements'],
    'additionalProperties': false,
  };

  static Map<String, dynamic> get designsSchema => {
    'type': 'object',
    'properties': {
      'designs': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'style': {'type': 'string'},
            'rationale': {'type': 'string'},
            'palette': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'front': faceSchema,
            'back': faceSchema,
          },
          'required': ['title', 'style', 'rationale', 'palette', 'front'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['designs'],
    'additionalProperties': false,
  };

  static Map<String, dynamic> get editSchema => {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
      'operations': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'op': {
              'type': 'string',
              'enum': ['update', 'add', 'delete', 'reorder', 'background'],
            },
            'id': {'type': 'string'},
            'changes': elementSchema(requireGeometry: false),
            'element': elementSchema(),
            'position': {
              'type': 'string',
              'enum': ['front', 'back', 'forward', 'backward'],
            },
            'fill': fillSchema,
          },
          'required': ['op'],
          'additionalProperties': false,
        },
      },
    },
    'required': ['message', 'operations'],
    'additionalProperties': false,
  };

  static Map<String, dynamic> get brandKitSchema => {
    'type': 'object',
    'properties': {
      'headline': {'type': 'string'},
      'slogan': {'type': 'string'},
      'offer': {'type': 'string'},
      'callToAction': {'type': 'string'},
      'body': {'type': 'string'},
      'services': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'primary': {'type': 'string'},
      'secondary': {'type': 'string'},
      'accent': {'type': 'string'},
      'dark': {'type': 'string'},
      'light': {'type': 'string'},
      'headingFont': {
        'type': 'string',
        'enum': FontCatalog.families.map((f) => f.family).toList(),
      },
      'bodyFont': {
        'type': 'string',
        'enum': FontCatalog.families.map((f) => f.family).toList(),
      },
      'layout': {'type': 'string'},
      'iconKey': {
        'type': 'string',
        'enum': IconCatalog.all.map((i) => i.key).toList(),
      },
      'rationale': {'type': 'string'},
    },
    'required': [
      'headline',
      'slogan',
      'callToAction',
      'primary',
      'secondary',
      'accent',
      'dark',
      'light',
      'headingFont',
      'bodyFont',
      'layout',
      'iconKey',
    ],
    'additionalProperties': false,
  };

  /// Extrait l'objet JSON d'une réponse (tolère les blocs ``` et le texte
  /// autour).
  static Object decodeJson(String raw) {
    var text = raw.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
    if (fence != null) text = fence.group(1)!.trim();
    try {
      return jsonDecode(text) as Object;
    } catch (_) {}
    final start = text.indexOf(RegExp(r'[\{\[]'));
    if (start >= 0) {
      final open = text[start];
      final close = open == '{' ? '}' : ']';
      final end = text.lastIndexOf(close);
      if (end > start) {
        try {
          return jsonDecode(text.substring(start, end + 1)) as Object;
        } catch (_) {}
      }
    }
    throw const AiException(
      AiErrorKind.invalidResponse,
      'La réponse de l’IA n’est pas un JSON valide.',
    );
  }
}

/// Valide et normalise les éléments proposés par une IA.
class ElementSanitizer {
  ElementSanitizer({required this.pageSize, required this.profile});

  final Size pageSize;
  final BusinessProfile? profile;
  final List<String> warnings = [];

  static double? _finite(Object? v) {
    if (v is num && v.isFinite) return v.toDouble();
    if (v is String) {
      final parsed = double.tryParse(
        v.replaceAll(',', '.').replaceAll('mm', '').trim(),
      );
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  Fill? fill(Object? raw) => Fill.fromJson(raw);

  /// Renvoie un élément valide, ou `null` (avec avertissement) s'il est inutilisable.
  DesignElement? element(Object? raw, {String? keepId}) {
    if (raw is! Map) {
      warnings.add('Élément ignoré : format inattendu.');
      return null;
    }
    final map = raw.cast<String, dynamic>();
    final type = ElementType.values
        .where((t) => t.name == map['type'])
        .firstOrNull;
    if (type == null) {
      warnings.add('Élément ignoré : type « ${map['type']} » inconnu.');
      return null;
    }
    final x = _finite(map['x']);
    final y = _finite(map['y']);
    final w = _finite(map['width']);
    final h = _finite(map['height']);
    if (x == null || y == null || w == null || h == null) {
      warnings.add(
        'Élément « ${map['name'] ?? type.name} » ignoré : position ou taille manquante.',
      );
      return null;
    }
    final maxW = pageSize.width * 3;
    final maxH = pageSize.height * 3;
    final width = w.abs().clamp(0.5, maxW).toDouble();
    final height = h.abs().clamp(0.5, maxH).toDouble();
    final cx = x.clamp(-width, pageSize.width).toDouble();
    final cy = y.clamp(-height, pageSize.height).toDouble();
    if (cx != x || cy != y) {
      warnings.add(
        'Élément « ${map['name'] ?? type.name} » replacé dans la page.',
      );
    }

    final normalized = <String, dynamic>{
      ...map,
      'id': keepId,
      'x': cx,
      'y': cy,
      'width': width,
      'height': height,
    };
    final rotation = _finite(map['rotation']) ?? 0;
    normalized['rotation'] = rotation.clamp(-360, 360);
    if (map['fontFamily'] is String) {
      normalized['fontFamily'] = FontCatalog.closest(
        map['fontFamily'] as String,
      );
    }
    final fontSize = _finite(map['fontSize']);
    if (fontSize != null) {
      normalized['fontSize'] = fontSize.clamp(4, 400);
    }
    final lineHeight = _finite(map['lineHeight']);
    if (lineHeight != null) normalized['lineHeight'] = lineHeight.clamp(0.8, 3);
    for (final key in ['color', 'strokeColor']) {
      if (map[key] != null && parseHexColor(map[key]) == null) {
        warnings.add('Couleur « ${map[key]} » invalide ignorée.');
        normalized.remove(key);
      }
    }
    if (map['strokeWidth'] != null) {
      normalized['strokeWidth'] = (_finite(map['strokeWidth']) ?? 0).clamp(
        0,
        20,
      );
    }
    if (map['cornerRadius'] != null) {
      normalized['cornerRadius'] = (_finite(map['cornerRadius']) ?? 0).clamp(
        0,
        math.min(width, height) / 2,
      );
    }

    // Sans identifiant imposé, fromJson attribue un nouvel identifiant.
    var element = DesignElement.fromJson(normalized);

    switch (type) {
      case ElementType.text:
        if (element.text.trim().isEmpty) {
          warnings.add('Texte vide ignoré.');
          return null;
        }
        if (map['color'] == null && element.fill == null) {
          element = element.copyWith(color: const Color(0xFF17213B));
        }
      case ElementType.shape:
        if (element.fill == null &&
            (element.strokeColor == null || element.strokeWidth <= 0)) {
          element = element.copyWith(
            fill: Fill.solid(
              parseHexColor(map['color']) ?? const Color(0xFF7545FF),
            ),
          );
        }
      case ElementType.icon:
        final key = map['iconKey'];
        if (key is! String || !IconCatalog.isKnown(key)) {
          final guess = key is String ? IconCatalog.closest(key) : null;
          element = element.copyWith(iconKey: guess?.key ?? 'star');
          warnings.add(
            'Pictogramme « $key » remplacé par « ${guess?.label ?? 'Étoile'} ».',
          );
        }
      case ElementType.qr:
        var data = element.qrData.trim();
        if (data.isEmpty && profile != null) {
          data = QrPayload.forKind(QrKind.website, profile!);
        }
        if (!QrPayload.isEncodable(data)) {
          warnings.add('QR code ignoré : aucun contenu valide.');
          return null;
        }
        element = element.copyWith(qrData: data);
        if (element.fill == null) {
          element = element.copyWith(fill: Fill.solid(const Color(0xFFFFFFFF)));
        }
        if (element.width != element.height) {
          final side = math.min(element.width, element.height);
          element = element.copyWith(width: side, height: side);
        }
      case ElementType.image:
        // Une modification conserve l'image existante : l'IA ne choisit pas de fichier.
        if (keepId != null) break;
        final logo = profile?.logoAssetId;
        final isLogo =
            (element.role ?? '').toLowerCase().contains('logo') ||
            element.name.toLowerCase().contains('logo');
        element = element.copyWith(
          assetId: isLogo && logo != null ? logo : null,
          imageFit: isLogo ? ImageFit.contain : element.imageFit,
        );
    }
    return element;
  }
}
