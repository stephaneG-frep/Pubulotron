import 'package:flutter/painting.dart';

import '../core/ids.dart';
import 'design_element.dart';
import 'fill.dart';

/// Une face (recto ou verso) d'un document.
class DesignPage {
  DesignPage({
    String? id,
    this.name = 'Recto',
    Fill? background,
    List<DesignElement> elements = const [],
  }) : id = id ?? newId('page'),
       background = background ?? Fill.solid(const Color(0xFFFFFFFF)),
       elements = List.unmodifiable(elements);

  final String id;
  final String name;
  final Fill background;

  /// Calques, du plus bas (index 0) au plus haut.
  final List<DesignElement> elements;

  DesignElement? elementById(String id) {
    for (final element in elements) {
      if (element.id == id) return element;
    }
    return null;
  }

  DesignPage copyWith({
    String? id,
    String? name,
    Fill? background,
    List<DesignElement>? elements,
  }) => DesignPage(
    id: id ?? this.id,
    name: name ?? this.name,
    background: background ?? this.background,
    elements: elements ?? this.elements,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'background': background.toJson(),
    'elements': elements.map((e) => e.toJson()).toList(),
  };

  factory DesignPage.fromJson(Map<String, dynamic> json) => DesignPage(
    id: json['id'] as String?,
    name: json['name'] as String? ?? 'Recto',
    background: Fill.fromJson(json['background']),
    elements: ((json['elements'] as List?) ?? const [])
        .whereType<Map>()
        .map((raw) => DesignElement.fromJson(Map<String, dynamic>.from(raw)))
        .toList(),
  );
}

/// Document graphique complet : format physique et faces.
class DesignDocument {
  DesignDocument({
    required this.widthMm,
    required this.heightMm,
    this.formatId = 'custom',
    required List<DesignPage> pages,
  }) : assert(pages.isNotEmpty),
       pages = List.unmodifiable(pages);

  factory DesignDocument.blank({
    required double widthMm,
    required double heightMm,
    String formatId = 'custom',
    Fill? background,
  }) => DesignDocument(
    widthMm: widthMm,
    heightMm: heightMm,
    formatId: formatId,
    pages: [DesignPage(name: 'Recto', background: background)],
  );

  static const int schemaVersion = 3;

  final double widthMm;
  final double heightMm;
  final String formatId;
  final List<DesignPage> pages;

  bool get isDuplex => pages.length > 1;

  Size get sizeMm => Size(widthMm, heightMm);

  DesignPage get front => pages.first;

  DesignPage? get back => pages.length > 1 ? pages[1] : null;

  DesignDocument copyWith({
    double? widthMm,
    double? heightMm,
    String? formatId,
    List<DesignPage>? pages,
  }) => DesignDocument(
    widthMm: widthMm ?? this.widthMm,
    heightMm: heightMm ?? this.heightMm,
    formatId: formatId ?? this.formatId,
    pages: pages ?? this.pages,
  );

  DesignDocument replacePage(int index, DesignPage page) {
    final next = [...pages];
    next[index] = page;
    return copyWith(pages: next);
  }

  /// Redimensionne le document en mettant les éléments à l'échelle.
  DesignDocument resized(
    double newWidth,
    double newHeight, {
    bool scaleContent = true,
  }) {
    if (!scaleContent) return copyWith(widthMm: newWidth, heightMm: newHeight);
    final sx = newWidth / widthMm;
    final sy = newHeight / heightMm;
    final sText = sx < sy ? sx : sy;
    return DesignDocument(
      widthMm: newWidth,
      heightMm: newHeight,
      formatId: formatId,
      pages: [
        for (final page in pages)
          page.copyWith(
            elements: [
              for (final e in page.elements)
                e.copyWith(
                  x: e.x * sx,
                  y: e.y * sy,
                  width: e.width * sx,
                  height: e.height * sy,
                  fontSize: e.fontSize * sText,
                  cornerRadius: e.cornerRadius * sText,
                  strokeWidth: e.strokeWidth * sText,
                ),
            ],
          ),
      ],
    );
  }

  /// Tous les identifiants de médias référencés par le document.
  Set<String> get assetIds => {
    for (final page in pages)
      for (final element in page.elements)
        if (element.assetId != null) element.assetId!,
  };

  Map<String, dynamic> toJson() => {
    'schema': schemaVersion,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'formatId': formatId,
    'pages': pages.map((p) => p.toJson()).toList(),
  };

  factory DesignDocument.fromJson(Map<String, dynamic> json) {
    final pages = ((json['pages'] as List?) ?? const [])
        .whereType<Map>()
        .map((raw) => DesignPage.fromJson(Map<String, dynamic>.from(raw)))
        .take(2)
        .toList();
    double dim(Object? v, double fallback) =>
        v is num && v.isFinite && v > 0 ? v.toDouble() : fallback;
    return DesignDocument(
      widthMm: dim(json['widthMm'], 85),
      heightMm: dim(json['heightMm'], 55),
      formatId: json['formatId'] as String? ?? 'custom',
      pages: pages.isEmpty ? [DesignPage()] : pages,
    );
  }
}
