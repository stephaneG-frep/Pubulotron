import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import 'design_canvas.dart';
import 'geometry.dart';
import 'icon_catalog.dart';
import 'qr_payload.dart';
import 'text_layout.dart';
import 'vector_path.dart';

typedef ImageResolver = DesignImage? Function(String assetId);

class RenderOptions {
  const RenderOptions({
    this.bleedMm = 0,
    this.showPlaceholders = false,
    this.resolveImage,
    this.hiddenElementIds = const {},
  });

  /// Fond perdu ajouté autour de la page (le repère reste la page rognée).
  final double bleedMm;

  /// Affiche un cadre « photo à ajouter » pour les images manquantes.
  final bool showPlaceholders;
  final ImageResolver? resolveImage;

  /// Éléments à ne pas peindre (ex. texte en cours d'édition).
  final Set<String> hiddenElementIds;
}

/// Part de marge blanche autour d'un QR code doté d'un fond.
const double qrQuietZone = 0.08;

/// Rendu d'une page, identique sur tous les canevas.
class PageRenderer {
  static void paint(
    DesignCanvas canvas,
    DesignPage page,
    Size pageMm, {
    RenderOptions options = const RenderOptions(),
  }) {
    final bleed = options.bleedMm;
    final source = bleed > 0 ? expandForBleed(page, pageMm, bleed) : page;
    canvas.save();
    if (bleed > 0) canvas.translate(bleed, bleed);
    final backgroundBox = Rect.fromLTRB(
      -bleed,
      -bleed,
      pageMm.width + bleed,
      pageMm.height + bleed,
    );
    canvas.fill(
      VectorPath.rect(backgroundBox),
      source.background,
      backgroundBox,
    );
    for (final element in source.elements) {
      if (!element.visible || options.hiddenElementIds.contains(element.id)) {
        continue;
      }
      paintElement(canvas, element, options);
    }
    canvas.restore();
  }

  static void paintElement(
    DesignCanvas canvas,
    DesignElement e,
    RenderOptions options,
  ) {
    if (e.width <= 0 || e.height <= 0 || e.opacity <= 0) return;
    canvas.save();
    canvas.translate(e.x + e.width / 2, e.y + e.height / 2);
    if (e.rotation % 360 != 0) canvas.rotate(e.rotation);
    canvas.translate(-e.width / 2, -e.height / 2);
    final box = Rect.fromLTWH(0, 0, e.width, e.height);
    switch (e.type) {
      case ElementType.shape:
        _paintShape(canvas, e, box);
      case ElementType.text:
        _paintText(canvas, e, box);
      case ElementType.image:
        _paintImage(canvas, e, box, options);
      case ElementType.qr:
        _paintQr(canvas, e, box);
      case ElementType.icon:
        canvas.icon(
          IconCatalog.byKey(e.iconKey),
          box,
          e.color,
          opacity: e.opacity,
        );
    }
    canvas.restore();
  }

  static void _paintStroke(
    DesignCanvas canvas,
    DesignElement e,
    VectorPath path,
  ) {
    final color = e.strokeColor;
    if (color != null && e.strokeWidth > 0) {
      canvas.stroke(path, color, e.strokeWidth, opacity: e.opacity);
    }
  }

  static void _paintShape(DesignCanvas canvas, DesignElement e, Rect box) {
    final path = VectorPath.forElement(e);
    final fill = e.fill;
    if (fill != null) canvas.fill(path, fill, box, opacity: e.opacity);
    _paintStroke(canvas, e, path);
  }

  static void _paintText(DesignCanvas canvas, DesignElement e, Rect box) {
    final background = VectorPath.rect(box, radius: e.cornerRadius);
    if (e.fill != null) {
      canvas.fill(background, e.fill!, box, opacity: e.opacity);
    }
    _paintStroke(canvas, e, background);
    if (e.text.isEmpty) return;
    final layout = TextLayoutEngine.layout(e, opacity: e.opacity);
    canvas.text(layout, Offset(0, layout.offsetY), opacity: e.opacity);
  }

  static void _paintImage(
    DesignCanvas canvas,
    DesignElement e,
    Rect box,
    RenderOptions options,
  ) {
    final clip = VectorPath.rect(box, radius: e.cornerRadius);
    final image = e.assetId == null
        ? null
        : options.resolveImage?.call(e.assetId!);
    if (image != null) {
      canvas.save();
      canvas.clip(clip);
      canvas.image(
        image,
        fitImageRect(image.size, box, e.imageFit),
        opacity: e.opacity,
      );
      canvas.restore();
    } else if (options.showPlaceholders) {
      canvas.fill(
        clip,
        Fill.linear(
          const Color(0xFFE4DEFF),
          const Color(0xFFC9F1EE),
          angle: 45,
        ),
        box,
        opacity: 0.9 * e.opacity,
      );
      final side = math.min(box.width, box.height) * 0.4;
      canvas.icon(
        IconCatalog.byKey('camera'),
        Rect.fromCenter(center: box.center, width: side, height: side),
        const Color(0xFF7545FF),
        opacity: 0.7 * e.opacity,
      );
    }
    _paintStroke(canvas, e, clip);
  }

  static void _paintQr(DesignCanvas canvas, DesignElement e, Rect box) {
    final background = VectorPath.rect(box, radius: e.cornerRadius);
    if (e.fill != null) {
      canvas.fill(background, e.fill!, box, opacity: e.opacity);
    }
    final modules = QrPayload.modules(e.qrData);
    if (modules.isEmpty) {
      canvas.stroke(
        background,
        e.color,
        math.min(box.width, box.height) * 0.02,
        opacity: e.opacity * 0.5,
      );
      return;
    }
    var side = math.min(box.width, box.height);
    if (e.fill != null) side *= 1 - 2 * qrQuietZone;
    final left = (box.width - side) / 2;
    final top = (box.height - side) / 2;
    // Léger chevauchement pour éviter les filets clairs entre modules.
    const overlap = 0.002;
    canvas.fillRects(
      [
        for (final m in modules)
          Rect.fromLTWH(
            left + m.left * side,
            top + m.top * side,
            m.width * side + overlap,
            m.height * side + overlap,
          ),
      ],
      e.color,
      opacity: e.opacity,
    );
    _paintStroke(canvas, e, background);
  }
}
