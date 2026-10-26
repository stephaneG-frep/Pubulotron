import 'dart:math' as math;
import 'dart:ui';

import '../engine/qr_payload.dart';
import '../layout/layout_engine.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import '../ui/theme.dart';

enum TextPreset { title, subtitle, body }

/// Crée des éléments aux proportions adaptées au format du document.
class ElementFactory {
  ElementFactory(this.page) : u = math.min(page.width, page.height);

  final Size page;
  final double u;

  DesignElement text(TextPreset preset, {String? content, Color? color}) {
    final (label, pt, bold, family, heightFactor) = switch (preset) {
      TextPreset.title => ('Votre titre', u * 0.2, true, 'Ubuntu', 0.2),
      TextPreset.subtitle => (
        'Sous-titre accrocheur',
        u * 0.11,
        false,
        'Ubuntu',
        0.12,
      ),
      TextPreset.body => (
        'Décrivez votre offre en quelques mots.',
        u * 0.075 + 2,
        false,
        'Liberation Sans',
        0.18,
      ),
    };
    final element = DesignElement(
      type: ElementType.text,
      name: switch (preset) {
        TextPreset.title => 'Titre',
        TextPreset.subtitle => 'Sous-titre',
        TextPreset.body => 'Paragraphe',
      },
      text: content ?? label,
      fontFamily: family,
      fontSize: pt,
      bold: bold,
      color: color ?? PubColors.night,
      x: page.width * 0.1,
      y: page.height * 0.4,
      width: page.width * 0.8,
      height: page.height * heightFactor,
    );
    return fitText(element);
  }

  DesignElement field(String label, String value, {Color? color}) => fitText(
    DesignElement(
      type: ElementType.text,
      name: label,
      text: value,
      fontSize: u * 0.075 + 2,
      color: color ?? PubColors.night,
      x: page.width * 0.1,
      y: page.height * 0.45,
      width: page.width * 0.8,
      height: math.max(
        page.height * 0.1,
        (u * 0.075 + 2) * 0.353 * 1.3 * ('\n'.allMatches(value).length + 1),
      ),
    ),
  );

  DesignElement shape(ShapeKind kind, {Color color = PubColors.violet}) {
    final side = u * 0.35;
    return DesignElement(
      type: ElementType.shape,
      name: switch (kind) {
        ShapeKind.rectangle => 'Rectangle',
        ShapeKind.ellipse => 'Cercle',
        ShapeKind.triangle => 'Triangle',
        ShapeKind.diamond => 'Losange',
        ShapeKind.star => 'Étoile',
        ShapeKind.hexagon => 'Hexagone',
      },
      shape: kind,
      fill: Fill.solid(color),
      cornerRadius: kind == ShapeKind.rectangle ? side * 0.08 : 0,
      x: (page.width - side) / 2,
      y: (page.height - side) / 2,
      width: kind == ShapeKind.rectangle ? side * 1.4 : side,
      height: side,
    );
  }

  DesignElement icon(String key, {Color color = PubColors.violet}) {
    final side = u * 0.2;
    return DesignElement(
      type: ElementType.icon,
      name: 'Pictogramme',
      iconKey: key,
      color: color,
      x: (page.width - side) / 2,
      y: (page.height - side) / 2,
      width: side,
      height: side,
    );
  }

  DesignElement image(
    String assetId,
    Size pixelSize, {
    String name = 'Photo',
    String role = 'photo',
    bool logo = false,
  }) {
    final maxW = page.width * (logo ? 0.3 : 0.6);
    final maxH = page.height * (logo ? 0.3 : 0.6);
    final ratio = pixelSize.width <= 0 || pixelSize.height <= 0
        ? 1.0
        : pixelSize.width / pixelSize.height;
    var w = maxW;
    var h = w / ratio;
    if (h > maxH) {
      h = maxH;
      w = h * ratio;
    }
    return DesignElement(
      type: ElementType.image,
      name: name,
      role: role,
      assetId: assetId,
      imageFit: logo ? ImageFit.contain : ImageFit.cover,
      x: (page.width - w) / 2,
      y: (page.height - h) / 2,
      width: w,
      height: h,
    );
  }

  DesignElement qr(
    String data, {
    String name = 'QR code',
    Color color = PubColors.night,
  }) {
    if (!QrPayload.isEncodable(data)) {
      throw ArgumentError('Contenu de QR code vide ou trop long.');
    }
    final side = math.max(14.0, u * 0.3);
    return DesignElement(
      type: ElementType.qr,
      name: name,
      role: 'qr',
      qrData: data,
      color: color,
      fill: Fill.solid(const Color(0xFFFFFFFF)),
      cornerRadius: side * 0.05,
      x: (page.width - side) / 2,
      y: (page.height - side) / 2,
      width: side,
      height: side,
    );
  }
}
