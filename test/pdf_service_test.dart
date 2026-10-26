import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/models/pubulotron_models.dart';
import 'package:pubulotron/services/pdf_service.dart';

PrintLayoutSpec cardSpec({int copies = 9, String orientation = 'portrait'}) {
  return PrintLayoutSpec(
    paperWidthMm: 210,
    paperHeightMm: 297,
    cardWidthMm: 85,
    cardHeightMm: 55,
    marginMm: 10,
    gapMm: 3,
    bleedMm: 2,
    copies: copies,
    orientation: orientation,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'calculates page count and placements using margins, gap, and bleed',
    () {
      final layout = PrintLayoutService.calculateLayout(cardSpec());

      expect(layout.columns, 2);
      expect(layout.rows, 4);
      expect(layout.copiesPerPage, 8);
      expect(layout.pageCount, 2);
      expect(layout.placements, hasLength(9));
      expect(layout.placements.first.leftMm, 12);
      expect(layout.placements.first.topMm, 12);
      expect(layout.placements.last.page, 1);
    },
  );

  test('rotates the paper dimensions for landscape', () {
    final layout = PrintLayoutService.calculateLayout(
      cardSpec(copies: 1, orientation: 'landscape'),
    );

    expect(layout.paperWidthMm, 297);
    expect(layout.paperHeightMm, 210);
    expect(layout.columns, 3);
    expect(layout.rows, 3);
  });

  test('rejects a layout that cannot fit any card', () {
    final spec = PrintLayoutSpec(
      paperWidthMm: 50,
      paperHeightMm: 50,
      cardWidthMm: 85,
      cardHeightMm: 55,
      marginMm: 10,
      gapMm: 3,
      bleedMm: 2,
      copies: 1,
    );

    expect(
      () => PrintLayoutService.calculateLayout(spec),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('rejects cut marks that would extend beyond the page', () {
    final spec = PrintLayoutSpec(
      paperWidthMm: 210,
      paperHeightMm: 297,
      cardWidthMm: 85,
      cardHeightMm: 55,
      marginMm: 0,
      gapMm: 3,
      bleedMm: 1,
      copies: 1,
    );

    expect(
      () => PrintLayoutService.calculateLayout(spec, cutMarks: true),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('builds a PDF from editable vector elements', () async {
    final elements = [
      CreativeElement(
        'Titre',
        0.1,
        0.1,
        180,
        60,
        const Color(0xFF7545FF),
        'text',
        textContent: 'Création française',
      ),
      CreativeElement(
        'Fond',
        0.4,
        0.5,
        100,
        80,
        const Color(0xFF24C9C2),
        'shape',
      ),
    ];

    final bytes = await PrintLayoutService.buildPdf(
      spec: cardSpec(copies: 1),
      elements: elements,
    );

    expect(utf8.decode(bytes.take(8).toList()), startsWith('%PDF-'));
    expect(bytes.length, greaterThan(500));
  });
}
