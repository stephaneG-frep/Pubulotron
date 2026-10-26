import 'package:flutter/painting.dart';

import '../core/units.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import '../models/project.dart';

/// Convertit les projets enregistrés par la première version de Pubulotron
/// (coordonnées relatives à un canevas 320 × 360) vers le modèle en mm.
class LegacyConverter {
  static bool isLegacyProject(Map<String, dynamic> json) =>
      json['document'] == null && json['elements'] is List;

  static Project convertProject(
    Map<String, dynamic> json, {
    double widthMm = 85,
    double heightMm = 55,
  }) {
    final elements = <DesignElement>[];
    for (final raw in (json['elements'] as List).whereType<Map>()) {
      final e = Map<String, dynamic>.from(raw);
      double n(String k, double f) => (e[k] as num?)?.toDouble() ?? f;
      final kind = e['kind'] as String? ?? 'shape';
      final color = Color((e['color'] as num?)?.toInt() ?? 0xFF7545FF);
      final x = n('x', 0) * widthMm;
      final y = n('y', 0) * heightMm;
      final w = n('width', 120) / 320 * widthMm;
      final h = n('height', 60) / 360 * heightMm;
      final rotation = radToDeg(n('rotation', 0));
      final opacity = n('opacity', 1).clamp(0.0, 1.0);
      final name = e['name'] as String? ?? '';
      final locked = e['locked'] == true;
      if (kind == 'image') {
        elements.add(
          DesignElement(
            type: ElementType.image,
            name: name,
            x: x,
            y: y,
            width: w,
            height: h,
            rotation: rotation,
            opacity: opacity,
            locked: locked,
            cornerRadius: 18 / 320 * widthMm,
          ),
        );
      } else if (kind == 'shape') {
        elements.add(
          DesignElement(
            type: ElementType.shape,
            name: name,
            x: x,
            y: y,
            width: w,
            height: h,
            rotation: rotation,
            opacity: opacity,
            locked: locked,
            fill: Fill.solid(color),
            cornerRadius: 12 / 320 * widthMm,
          ),
        );
      } else {
        final fontMm = n('fontSize', 16) / 320 * widthMm;
        elements.add(
          DesignElement(
            type: ElementType.text,
            name: name,
            x: x,
            y: y,
            width: w,
            height: h,
            rotation: rotation,
            opacity: opacity,
            locked: locked,
            fill: Fill.solid(color),
            cornerRadius: 12 / 320 * widthMm,
            text: e['textContent'] as String? ?? name,
            fontSize: (fontMm / mmPerPoint).clamp(4.0, 200.0),
            bold: true,
            textAlign: TextAlignH.center,
            verticalAlign: TextAlignV.middle,
            color: const Color(0xFFFFFFFF),
          ),
        );
      }
    }
    return Project(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Projet importé',
      brief: json['description'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      document: DesignDocument(
        widthMm: widthMm,
        heightMm: heightMm,
        formatId: 'business-card',
        pages: [
          DesignPage(
            background: Fill.solid(const Color(0xFF101828)),
            elements: elements,
          ),
        ],
      ),
    );
  }

  /// Lit un projet, ancien ou nouveau format.
  static Project readProject(Map<String, dynamic> json) =>
      isLegacyProject(json) ? convertProject(json) : Project.fromJson(json);
}
