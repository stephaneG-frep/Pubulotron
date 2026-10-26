import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import '../core/units.dart';
import '../data/asset_store.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import 'design_canvas.dart';
import 'flutter_canvas.dart';
import 'font_catalog.dart';
import 'icon_catalog.dart';
import 'image_cache.dart';
import 'text_layout.dart';
import 'vector_path.dart';

typedef AssetLoader = Future<ByteData> Function(String asset);

/// Ressources PDF (polices, images, pictogrammes) préparées avant le rendu,
/// car le dessin PDF est synchrone.
class PdfRenderResources {
  PdfRenderResources._(this.document);

  final PdfDocument document;
  final Map<String, PdfTtfFont> _fonts = {};
  final Map<String, (PdfImage, DesignImage)> _images = {};
  final Map<String, PdfImage> _icons = {};
  final List<String> missingImages = [];

  /// Résolution des pictogrammes tramés (pixels par côté).
  static const int iconResolution = 512;

  static Future<PdfRenderResources> prepare(
    PdfDocument document,
    Iterable<DesignDocument> designs, {
    AssetStore? store,
    AssetLoader? loadAsset,
    bool includePlaceholderIcon = false,
  }) async {
    final res = PdfRenderResources._(document);
    final loader = loadAsset ?? rootBundle.load;
    final fontAssets = <String>{};
    final assetIds = <String>{};
    final icons = <String, (PictogramDef, Color)>{};
    for (final design in designs) {
      for (final page in design.pages) {
        for (final e in page.elements) {
          if (!e.visible) continue;
          switch (e.type) {
            case ElementType.text:
              if (e.text.isNotEmpty) {
                fontAssets.add(
                  FontCatalog.byFamily(e.fontFamily)
                      .resolve(bold: e.bold, italic: e.italic)
                      .asset,
                );
              }
            case ElementType.image:
              if (e.assetId != null) assetIds.add(e.assetId!);
            case ElementType.icon:
              final def = IconCatalog.byKey(e.iconKey);
              icons[_iconKey(def, e.color)] = (def, e.color);
            case ElementType.shape:
            case ElementType.qr:
              break;
          }
        }
      }
    }
    for (final asset in fontAssets) {
      res._fonts[asset] = PdfTtfFont(document, await loader(asset));
    }
    for (final id in assetIds) {
      final bytes = store == null ? null : await store.read(id);
      if (bytes == null) {
        res.missingImages.add(id);
        continue;
      }
      try {
        res._images[id] = await _embedImage(document, id, bytes);
      } catch (_) {
        res.missingImages.add(id);
      }
    }
    for (final entry in icons.entries) {
      res._icons[entry.key] = await _rasterIcon(
        document,
        entry.value.$1,
        entry.value.$2,
      );
    }
    return res;
  }

  static String _iconKey(PictogramDef def, Color color) =>
      '${def.key}|${color.withValues(alpha: 1).toARGB32()}';

  static Future<(PdfImage, DesignImage)> _embedImage(
    PdfDocument doc,
    String id,
    Uint8List bytes,
  ) async {
    final decoded = await DesignImageCache.decode(bytes);
    final rgba = (await decoded.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    final width = decoded.width;
    final height = decoded.height;
    final design = DesignImage(id: id, width: width, height: height);
    final pixels = rgba.buffer.asUint8List();
    var opaque = true;
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] != 255) {
        opaque = false;
        break;
      }
    }
    decoded.dispose();
    if (opaque) {
      // Photo opaque : réencodage JPEG haute qualité, beaucoup plus léger.
      final jpeg = await Isolate.run(() {
        final image = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: pixels.buffer,
          numChannels: 4,
        );
        return img.encodeJpg(image, quality: 92);
      });
      return (PdfImage.jpeg(doc, image: jpeg), design);
    }
    return (
      PdfImage(doc, image: pixels, width: width, height: height, alpha: true),
      design,
    );
  }

  static Future<PdfImage> _rasterIcon(
    PdfDocument doc,
    PictogramDef def,
    Color color,
  ) async {
    const size = iconResolution;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = FlutterDesignCanvas.iconPainter(
      def,
      size.toDouble(),
      color.withValues(alpha: 1),
    );
    painter.paint(
      canvas,
      Offset((size - painter.width) / 2, (size - painter.height) / 2),
    );
    painter.dispose();
    final picture = recorder.endRecording();
    final image = await picture.toImage(size, size);
    picture.dispose();
    final rgba = (await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    image.dispose();
    return PdfImage(
      doc,
      image: rgba.buffer.asUint8List(),
      width: size,
      height: size,
      alpha: true,
    );
  }

  PdfTtfFont? font(String asset) => _fonts[asset];

  (PdfImage, DesignImage)? image(String id) => _images[id];

  DesignImage? designImage(String id) => _images[id]?.$2;

  PdfImage? icon(PictogramDef def, Color color) => _icons[_iconKey(def, color)];
}

/// Implémentation de [DesignCanvas] produisant du PDF vectoriel.
class PdfDesignCanvas implements DesignCanvas {
  PdfDesignCanvas(this.g, this.res);

  final PdfGraphics g;
  final PdfRenderResources res;

  /// Place le repère en millimètres, axe y vers le bas, origine en haut à
  /// gauche d'une zone de [heightMm] de haut.
  void setupMillimetres(double heightMm) {
    g.setTransform(
      Matrix4.identity()
        ..translateByDouble(0, mmToPdf(heightMm), 0, 1)
        ..scaleByDouble(pdfPointsPerMm, -pdfPointsPerMm, 1, 1),
    );
  }

  PdfColor _color(Color c) => PdfColor(c.r, c.g, c.b);

  void _withOpacity(double opacity, void Function() draw) {
    final o = opacity.clamp(0.0, 1.0);
    g.saveContext();
    if (o < 0.999) g.setGraphicState(PdfGraphicState(opacity: o));
    draw();
    g.restoreContext();
  }

  void _path(VectorPath path) {
    for (final c in path.commands) {
      switch (c) {
        case MoveTo(:final x, :final y):
          g.moveTo(x, y);
        case LineTo(:final x, :final y):
          g.lineTo(x, y);
        case CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          g.curveTo(x1, y1, x2, y2, x, y);
        case ClosePath():
          g.closePath();
      }
    }
  }

  @override
  void save() => g.saveContext();

  @override
  void restore() => g.restoreContext();

  @override
  void translate(double dx, double dy) =>
      g.setTransform(Matrix4.translationValues(dx, dy, 0));

  @override
  void rotate(double degrees) =>
      g.setTransform(Matrix4.rotationZ(degToRad(degrees)));

  @override
  void clip(VectorPath path) {
    _path(path);
    g.clipPath();
  }

  @override
  void fill(VectorPath path, Fill fill, Rect box, {double opacity = 1}) {
    if (!fill.isGradient) {
      _withOpacity(opacity * fill.primary.a, () {
        g.setFillColor(_color(fill.primary));
        _path(path);
        g.fillPath();
      });
      return;
    }
    _withOpacity(opacity, () {
      _path(path);
      g.clipPath();
      final function = PdfBaseFunction.colorsAndStops(
        res.document,
        fill.colors.map(_color).toList(),
        null,
      );
      final PdfShading shading;
      if (fill.kind == FillKind.linear) {
        final (begin, end) = fill.linearAlignments;
        final a = begin.withinRect(box);
        final b = end.withinRect(box);
        shading = PdfShading(
          res.document,
          shadingType: PdfShadingType.axial,
          function: function,
          start: PdfPoint(a.dx, a.dy),
          end: PdfPoint(b.dx, b.dy),
          extendStart: true,
          extendEnd: true,
        );
      } else {
        final c = box.center;
        shading = PdfShading(
          res.document,
          shadingType: PdfShadingType.radial,
          function: function,
          start: PdfPoint(c.dx, c.dy),
          end: PdfPoint(c.dx, c.dy),
          radius0: 0,
          radius1: box.shortestSide * 0.5,
          extendStart: true,
          extendEnd: true,
        );
      }
      g.applyShader(shading);
    });
  }

  @override
  void stroke(
    VectorPath path,
    Color color,
    double width, {
    double opacity = 1,
  }) {
    _withOpacity(opacity * color.a, () {
      g.setStrokeColor(_color(color));
      g.setLineWidth(width);
      _path(path);
      g.strokePath();
    });
  }

  @override
  void fillRects(List<Rect> rects, Color color, {double opacity = 1}) {
    _withOpacity(opacity * color.a, () {
      g.setFillColor(_color(color));
      for (final r in rects) {
        g.drawRect(r.left, r.top, r.width, r.height);
      }
      g.fillPath();
    });
  }

  void _flippedAt(double x, double y, void Function() draw) {
    g.saveContext();
    g.setTransform(
      Matrix4.translationValues(x, y, 0)..scaleByDouble(1, -1, 1, 1),
    );
    draw();
    g.restoreContext();
  }

  @override
  void image(DesignImage image, Rect dest, {double opacity = 1}) {
    final embedded = res.image(image.id);
    if (embedded == null) return;
    _withOpacity(opacity, () {
      _flippedAt(dest.left, dest.bottom, () {
        g.drawImage(embedded.$1, 0, 0, dest.width, dest.height);
      });
    });
  }

  @override
  void text(TextLayoutResult layout, Offset origin, {double opacity = 1}) {
    final font = res.font(layout.variant.asset);
    if (font == null) return;
    _withOpacity(layout.color.a, () {
      g.setFillColor(_color(layout.color));
      for (final line in layout.lines) {
        _flippedAt(origin.dx + line.left, origin.dy + line.baseline, () {
          g.drawString(
            font,
            layout.fontSizeMm,
            line.text,
            0,
            0,
            charSpace: layout.letterSpacingMm == 0
                ? null
                : layout.letterSpacingMm,
          );
        });
      }
    });
  }

  @override
  void icon(PictogramDef icon, Rect box, Color color, {double opacity = 1}) {
    final image = res.icon(icon, color);
    final side = box.shortestSide;
    if (image == null || side <= 0) return;
    _withOpacity(opacity * color.a, () {
      _flippedAt(box.center.dx - side / 2, box.center.dy + side / 2, () {
        g.drawImage(image, 0, 0, side, side);
      });
    });
  }
}
