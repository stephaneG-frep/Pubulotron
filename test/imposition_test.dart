import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/print/imposition.dart';

Imposition compute(PrintSettings s, [double w = 85, double h = 55]) =>
    Imposition.compute(settings: s, cardWidthMm: w, cardHeightMm: h);

void expectNoOverlapAndInside(Imposition imp) {
  final sheet = Rect.fromLTWH(0, 0, imp.sheetWidthMm, imp.sheetHeightMm);
  final firstSheet = imp.slotsForSheet(0).toList();
  for (final slot in firstSheet) {
    final withBleed = slot.trim.inflate(imp.bleedMm);
    expect(withBleed.left >= -1e-9 && withBleed.top >= -1e-9, isTrue);
    expect(
      withBleed.right <= sheet.right + 1e-9 &&
          withBleed.bottom <= sheet.bottom + 1e-9,
      isTrue,
    );
    expect(slot.trim.width, imp.cardWidthMm, reason: 'carte déformée');
    expect(slot.trim.height, imp.cardHeightMm, reason: 'carte déformée');
    for (final other in firstSheet) {
      if (identical(other, slot)) continue;
      final overlap = slot.trim
          .inflate(imp.bleedMm)
          .intersect(other.trim.inflate(imp.bleedMm));
      expect(
        overlap.width <= 1e-9 || overlap.height <= 1e-9,
        isTrue,
        reason: 'cartes superposées',
      );
    }
  }
}

void main() {
  test('100 business cards on A4 portrait with 10 mm margins', () {
    final imp = compute(
      const PrintSettings(
        copies: 100,
        marginMm: 10,
        orientation: SheetOrientation.portrait,
        cutMarks: false,
      ),
    );
    expect(imp.columns, 2);
    expect(imp.rows, 5);
    expect(imp.perSheet, 10);
    expect(imp.sheetCount, 10);
    expect(imp.lastSheetCount, 10);
    expectNoOverlapAndInside(imp);
  });

  test('auto orientation picks the layout with the most copies', () {
    // 85×55 sur A4 avec 5 mm de marge : portrait 2×5 = 10, paysage 3×3 = 9.
    final imp = compute(
      const PrintSettings(copies: 25, marginMm: 5, cutMarks: false),
    );
    expect(imp.landscape, isFalse);
    expect(imp.perSheet, 10);
    expect(imp.sheetCount, 3);
    expect(imp.lastSheetCount, 5);
    // Carte 60×40 sur A4 marge 5 : portrait 3×7 = 21, paysage 4×5 = 20.
    final small = compute(
      const PrintSettings(copies: 1, marginMm: 5, cutMarks: false),
      60,
      40,
    );
    expect(small.perSheet, 21);
  });

  test('landscape orientation swaps the sheet dimensions', () {
    final imp = compute(
      const PrintSettings(
        orientation: SheetOrientation.landscape,
        marginMm: 10,
        cutMarks: false,
      ),
    );
    expect(imp.sheetWidthMm, 297);
    expect(imp.sheetHeightMm, 210);
    expect(imp.columns, 3);
    expect(imp.rows, 3);
  });

  test('bleed and gap reduce the number of copies and keep cards apart', () {
    final imp = compute(
      const PrintSettings(
        copies: 30,
        marginMm: 10,
        gapMm: 4,
        bleedMm: 3,
        orientation: SheetOrientation.portrait,
        cutMarks: false,
      ),
    );
    // Cellule 91×61 + 4 de gouttière : 2 colonnes, 4 rangées.
    expect(imp.columns, 2);
    expect(imp.rows, 4);
    final slots = imp.slotsForSheet(0).toList();
    expect(slots[1].trim.left - slots[0].trim.right, closeTo(4 + 2 * 3, 1e-9));
    expectNoOverlapAndInside(imp);
  });

  test('grid is centred on the sheet', () {
    final imp = compute(
      const PrintSettings(
        marginMm: 10,
        orientation: SheetOrientation.portrait,
        cutMarks: false,
      ),
    );
    expect(imp.gridRect.left, closeTo((210 - 170) / 2, 1e-9));
    expect(imp.gridRect.top, closeTo((297 - 275) / 2, 1e-9));
    final notCentred = compute(
      const PrintSettings(
        marginMm: 10,
        orientation: SheetOrientation.portrait,
        cutMarks: false,
        center: false,
      ),
    );
    expect(notCentred.gridRect.left, 10);
  });

  test('cut marks sit in the margin, outside the artwork', () {
    final imp = compute(
      const PrintSettings(
        copies: 10,
        marginMm: 10,
        bleedMm: 2,
        orientation: SheetOrientation.portrait,
      ),
    );
    expect(imp.cutMarks, isNotEmpty);
    // Cellule 89×59 : 2 colonnes × 4 rangées. Chaque colonne donne 2 abscisses
    // (marques en haut et en bas), chaque rangée 2 ordonnées (à gauche et à droite).
    expect([imp.columns, imp.rows], [2, 4]);
    expect(imp.cutMarks.length, imp.columns * 2 * 2 + imp.rows * 2 * 2);
    for (final mark in imp.cutMarks) {
      final segment = Rect.fromPoints(mark.from, mark.to);
      final intersection = segment.intersect(imp.gridRect);
      expect(
        intersection.width < 0 ||
            intersection.height < 0 ||
            (intersection.width == 0 && intersection.height == 0),
        isTrue,
      );
      expect(segment.left >= 0 && segment.top >= 0, isTrue);
      expect(
        segment.right <= imp.sheetWidthMm &&
            segment.bottom <= imp.sheetHeightMm,
        isTrue,
      );
    }
  });

  test('cut marks require enough margin', () {
    expect(
      () => compute(
        const PrintSettings(
          marginMm: 0,
          orientation: SheetOrientation.portrait,
          center: false,
        ),
      ),
      throwsA(isA<PrintLayoutException>()),
    );
  });

  test('duplex back positions mirror the front for long-edge flip', () {
    final imp = compute(
      const PrintSettings(
        copies: 3,
        marginMm: 10,
        orientation: SheetOrientation.portrait,
        duplex: true,
        center: false,
        cutMarks: false,
      ),
    );
    expect(imp.mirrorBackHorizontally, isTrue);
    final first = imp.slots.first.trim;
    final back = imp.backTrim(first);
    expect(back.left, closeTo(210 - first.left - 85, 1e-9));
    expect(back.top, first.top);
    // Paysage, retournement bord long : miroir haut-bas.
    final land = compute(
      const PrintSettings(
        marginMm: 10,
        orientation: SheetOrientation.landscape,
        duplex: true,
        cutMarks: false,
      ),
    );
    expect(land.mirrorBackHorizontally, isFalse);
    final t = land.slots.first.trim;
    expect(land.backTrim(t).top, closeTo(210 - t.top - 55, 1e-9));
    final shortEdge = compute(
      const PrintSettings(
        marginMm: 10,
        orientation: SheetOrientation.portrait,
        flip: DuplexFlip.shortEdge,
        cutMarks: false,
      ),
    );
    expect(shortEdge.mirrorBackHorizontally, isFalse);
  });

  test('custom paper and validation errors', () {
    final custom = compute(
      const PrintSettings(
        paperId: 'custom',
        paperWidthMm: 320,
        paperHeightMm: 450,
        marginMm: 5,
        cutMarks: false,
        orientation: SheetOrientation.portrait,
      ),
    );
    expect(custom.columns, 3);
    expect(custom.rows, 8);
    expect(
      () => compute(const PrintSettings(copies: 0)),
      throwsA(isA<PrintLayoutException>()),
    );
    expect(
      () => compute(const PrintSettings(marginMm: -1)),
      throwsA(isA<PrintLayoutException>()),
    );
    expect(
      () => compute(const PrintSettings(cutMarks: false), 400, 400),
      throwsA(isA<PrintLayoutException>()),
    );
    expect(
      () => compute(const PrintSettings(), double.nan, 10),
      throwsA(isA<PrintLayoutException>()),
    );
  });

  test('settings JSON round trip', () {
    const s = PrintSettings(
      paperId: 'A3',
      paperWidthMm: 297,
      paperHeightMm: 420,
      copies: 250,
      bleedMm: 3,
      duplex: true,
      flip: DuplexFlip.shortEdge,
    );
    final r = PrintSettings.fromJson(s.toJson());
    expect(r.toJson(), s.toJson());
  });
}
