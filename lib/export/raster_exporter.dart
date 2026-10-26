import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:image/image.dart' as img;

import '../core/units.dart';
import '../engine/design_canvas.dart';
import '../engine/flutter_canvas.dart';
import '../engine/image_cache.dart';
import '../engine/page_renderer.dart';
import '../models/design_document.dart';

enum RasterFormat { png, jpeg }

class RasterExportException implements Exception {
  const RasterExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Export PNG / JPEG d'une page, avec exactement le même moteur que l'aperçu.
class RasterExporter {
  RasterExporter(this.images);

  final DesignImageCache? images;

  /// Limite de sécurité pour la mémoire (pixels).
  static const int maxPixels = 80 * 1000 * 1000;

  static (int, int) pixelSize(
    DesignDocument doc,
    double dpi, {
    double bleedMm = 0,
  }) => (
    mmToPixelCount(doc.widthMm + 2 * bleedMm, dpi),
    mmToPixelCount(doc.heightMm + 2 * bleedMm, dpi),
  );

  Future<ui.Image> renderPage(
    DesignDocument doc, {
    int pageIndex = 0,
    double dpi = 300,
    double bleedMm = 0,
    bool opaqueWhite = false,
  }) async {
    if (dpi <= 0 || !dpi.isFinite) {
      throw const RasterExportException('Résolution invalide.');
    }
    final (width, height) = pixelSize(doc, dpi, bleedMm: bleedMm);
    if (width * height > maxPixels) {
      throw RasterExportException(
        'Image trop grande ($width × $height px). Réduisez la résolution.',
      );
    }
    final page = doc.pages[pageIndex.clamp(0, doc.pages.length - 1)];
    final cache = images;
    if (cache != null) {
      await cache.ensureLoaded({
        for (final e in page.elements)
          if (e.assetId != null) e.assetId!,
      });
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (opaqueWhite) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        Paint()..color = const Color(0xFFFFFFFF),
      );
    }
    // Échelle exacte : la largeur en pixels correspond au format physique.
    canvas.scale(
      width / (doc.widthMm + 2 * bleedMm),
      height / (doc.heightMm + 2 * bleedMm),
    );
    PageRenderer.paint(
      FlutterDesignCanvas(canvas),
      page,
      doc.sizeMm,
      options: RenderOptions(
        bleedMm: bleedMm,
        resolveImage: cache == null
            ? null
            : (id) {
                final image = cache.peek(id);
                return image == null
                    ? null
                    : DesignImage(
                        id: id,
                        width: image.width,
                        height: image.height,
                        decoded: image,
                      );
              },
      ),
    );
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }

  Future<Uint8List> export(
    DesignDocument doc, {
    int pageIndex = 0,
    double dpi = 300,
    RasterFormat format = RasterFormat.png,
    int jpegQuality = 92,
    double bleedMm = 0,
  }) async {
    final image = await renderPage(
      doc,
      pageIndex: pageIndex,
      dpi: dpi,
      bleedMm: bleedMm,
      opaqueWhite: format == RasterFormat.jpeg,
    );
    try {
      if (format == RasterFormat.png) {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }
      final rgba = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!;
      final width = image.width;
      final height = image.height;
      final pixels = rgba.buffer.asUint8List();
      return await Isolate.run(() {
        final raster = img.Image.fromBytes(
          width: width,
          height: height,
          bytes: pixels.buffer,
          numChannels: 4,
        );
        return img.encodeJpg(raster, quality: jpegQuality);
      });
    } finally {
      image.dispose();
    }
  }
}
