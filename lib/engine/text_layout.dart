import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/units.dart';
import '../models/design_element.dart';
import 'font_catalog.dart';

/// Ligne de texte mise en page, en millimètres, relative au haut du bloc de texte.
class TextLineInfo {
  const TextLineInfo({
    required this.text,
    required this.left,
    required this.baseline,
    required this.width,
  });

  final String text;
  final double left;
  final double baseline;
  final double width;
}

class TextLayoutResult {
  const TextLayoutResult({
    required this.painter,
    required this.offsetY,
    required this.lines,
    required this.height,
    required this.variant,
    required this.color,
    required this.fontSizeMm,
    required this.letterSpacingMm,
  });

  /// Peintre Flutter, mis en page à [TextLayoutEngine.referenceScale] px/mm.
  final TextPainter painter;

  /// Décalage vertical (mm) dû à l'alignement vertical.
  final double offsetY;
  final List<TextLineInfo> lines;

  /// Hauteur totale du texte (mm).
  final double height;
  final FontVariant variant;

  /// Couleur effective (opacité de l'élément incluse).
  final Color color;
  final double fontSizeMm;
  final double letterSpacingMm;

  bool overflows(double boxHeight) => height > boxHeight + 0.01;
}

/// Mise en page du texte, calculée une seule fois par le moteur de texte de
/// Flutter. Le rendu écran peint ce résultat ; le rendu PDF place chaque
/// ligne sur les mêmes lignes de base.
class TextLayoutEngine {
  /// Échelle de mise en page (pixels logiques par millimètre). Fixe, pour que
  /// les retours à la ligne ne dépendent jamais du zoom.
  static const double referenceScale = 10;

  static final LinkedHashMap<String, TextLayoutResult> _cache = LinkedHashMap();
  static const int _cacheSize = 400;

  static const List<ui.FontFeature> _features = [
    ui.FontFeature.disable('kern'),
    ui.FontFeature.disable('liga'),
    ui.FontFeature.disable('clig'),
  ];

  static TextStyle styleFor(
    DesignElement e,
    FontVariant variant, {
    double opacity = 1,
  }) {
    final def = FontCatalog.byFamily(e.fontFamily);
    final alpha = (e.color.a * opacity).clamp(0.0, 1.0);
    return TextStyle(
      fontFamily: def.family,
      fontSize: pointsToMm(e.fontSize) * referenceScale,
      fontWeight: variant.bold ? FontWeight.w700 : FontWeight.w400,
      fontStyle: variant.italic ? FontStyle.italic : FontStyle.normal,
      letterSpacing: pointsToMm(e.letterSpacing) * referenceScale,
      height: e.lineHeight,
      leadingDistribution: TextLeadingDistribution.even,
      color: e.color.withValues(alpha: alpha),
      fontFeatures: _features,
    );
  }

  static String _key(DesignElement e, double opacity) => [
    e.text,
    e.fontFamily,
    e.fontSize,
    e.bold,
    e.italic,
    e.textAlign.index,
    e.verticalAlign.index,
    e.lineHeight,
    e.letterSpacing,
    e.width.toStringAsFixed(3),
    e.height.toStringAsFixed(3),
    e.color.toARGB32(),
    opacity.toStringAsFixed(3),
  ].join('|');

  static TextLayoutResult layout(DesignElement e, {double opacity = 1}) {
    final key = _key(e, opacity);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached;
    }
    final result = _compute(e, opacity);
    _cache[key] = result;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first)!.painter.dispose();
    }
    return result;
  }

  static TextLayoutResult _compute(DesignElement e, double opacity) {
    final def = FontCatalog.byFamily(e.fontFamily);
    final variant = def.resolve(bold: e.bold, italic: e.italic);
    final style = styleFor(e, variant, opacity: opacity);
    final painter = TextPainter(
      text: TextSpan(text: e.text, style: style),
      textAlign: switch (e.textAlign) {
        TextAlignH.left => TextAlign.left,
        TextAlignH.center => TextAlign.center,
        TextAlignH.right => TextAlign.right,
      },
      textDirection: TextDirection.ltr,
      strutStyle: StrutStyle(
        fontFamily: def.family,
        fontSize: style.fontSize,
        height: e.lineHeight,
        leadingDistribution: TextLeadingDistribution.even,
        forceStrutHeight: true,
      ),
    );
    final maxWidth = e.width * referenceScale;
    painter.layout(minWidth: maxWidth, maxWidth: maxWidth);

    final heightMm = painter.height / referenceScale;
    final offsetY = switch (e.verticalAlign) {
      TextAlignV.top => 0.0,
      TextAlignV.middle => (e.height - heightMm) / 2,
      TextAlignV.bottom => e.height - heightMm,
    };

    final metrics = painter.computeLineMetrics();
    final ranges = _lineRanges(painter, e.text);
    final lines = <TextLineInfo>[];
    for (var i = 0; i < metrics.length; i++) {
      final m = metrics[i];
      final range = i < ranges.length ? ranges[i] : null;
      final text = range == null
          ? ''
          : e.text.substring(range.start, range.end).trimRight();
      if (text.isEmpty) continue;
      lines.add(
        TextLineInfo(
          text: text.replaceAll('\n', ''),
          left: m.left / referenceScale,
          baseline: m.baseline / referenceScale,
          width: m.width / referenceScale,
        ),
      );
    }
    return TextLayoutResult(
      painter: painter,
      offsetY: offsetY,
      lines: lines,
      height: heightMm,
      variant: variant,
      color: style.color!,
      fontSizeMm: pointsToMm(e.fontSize),
      letterSpacingMm: pointsToMm(e.letterSpacing),
    );
  }

  static List<TextRange> _lineRanges(TextPainter painter, String text) {
    final ranges = <TextRange>[];
    var start = 0;
    var guard = 0;
    while (start < text.length && guard++ < 10000) {
      final boundary = painter.getLineBoundary(TextPosition(offset: start));
      var end = boundary.end;
      if (end <= start) {
        // Ligne vide (retour à la ligne consécutif).
        ranges.add(TextRange(start: start, end: start));
        start = text.codeUnitAt(start) == 0x0A ? start + 1 : start + 1;
        continue;
      }
      ranges.add(
        TextRange(
          start: boundary.start < start ? start : boundary.start,
          end: end,
        ),
      );
      if (end < text.length && text.codeUnitAt(end) == 0x0A) end++;
      start = end;
    }
    return ranges;
  }

  static void clearCache() {
    for (final r in _cache.values) {
      r.painter.dispose();
    }
    _cache.clear();
  }
}
