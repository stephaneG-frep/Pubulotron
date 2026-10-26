import 'dart:ui';

import '../engine/design_canvas.dart';
import '../engine/page_renderer.dart';
import '../engine/vector_path.dart';
import '../models/design_document.dart';
import '../models/fill.dart';
import 'imposition.dart';

/// Épaisseur des traits de coupe : 0,25 pt.
const double cutMarkWidthMm = 0.088;

/// Dessine une feuille d'imposition (recto ou verso) sur un canevas.
class SheetRenderer {
  static void paint(
    DesignCanvas canvas, {
    required DesignDocument document,
    required Imposition imposition,
    required int sheet,
    required bool back,
    ImageResolver? resolveImage,
    bool paperBackground = true,
  }) {
    final sheetRect = Rect.fromLTWH(
      0,
      0,
      imposition.sheetWidthMm,
      imposition.sheetHeightMm,
    );
    if (paperBackground) {
      canvas.fill(
        VectorPath.rect(sheetRect),
        Fill.solid(const Color(0xFFFFFFFF)),
        sheetRect,
      );
    }
    final page = back ? document.back : document.front;
    if (page == null) return;
    final bleed = imposition.bleedMm;
    final options = RenderOptions(bleedMm: bleed, resolveImage: resolveImage);
    for (final slot in imposition.slotsForSheet(sheet)) {
      final trim = back ? imposition.backTrim(slot.trim) : slot.trim;
      canvas.save();
      canvas.translate(trim.left - bleed, trim.top - bleed);
      canvas.clip(
        VectorPath.rect(
          Rect.fromLTWH(0, 0, trim.width + 2 * bleed, trim.height + 2 * bleed),
        ),
      );
      PageRenderer.paint(canvas, page, document.sizeMm, options: options);
      canvas.restore();
    }
    if (!back) {
      for (final mark in imposition.cutMarks) {
        canvas.stroke(
          VectorPath([
            MoveTo(mark.from.dx, mark.from.dy),
            LineTo(mark.to.dx, mark.to.dy),
          ], sheetRect),
          const Color(0xFF000000),
          cutMarkWidthMm,
        );
      }
    }
  }
}
