import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:pubulotron/engine/geometry.dart';
import 'package:pubulotron/engine/qr_payload.dart';
import 'package:pubulotron/engine/vector_path.dart';
import 'package:pubulotron/models/business_profile.dart';
import 'package:pubulotron/models/design_document.dart';
import 'package:pubulotron/models/design_element.dart';
import 'package:pubulotron/models/fill.dart';

DesignElement box(
  double x,
  double y,
  double w,
  double h, {
  bool locked = false,
  String? id,
}) => DesignElement(
  id: id,
  type: ElementType.shape,
  x: x,
  y: y,
  width: w,
  height: h,
  locked: locked,
);

void main() {
  group('resize', () {
    test('bottom-right handle keeps the top-left corner fixed', () {
      final r = resizeRotatedRect(
        rect: const Rect.fromLTWH(10, 10, 20, 10),
        rotation: 0,
        handle: ResizeHandle.bottomRight,
        delta: const Offset(5, 4),
      );
      expect(r, const Rect.fromLTWH(10, 10, 25, 14));
    });

    test('left handle keeps the right edge fixed', () {
      final r = resizeRotatedRect(
        rect: const Rect.fromLTWH(10, 10, 20, 10),
        rotation: 0,
        handle: ResizeHandle.left,
        delta: const Offset(-5, 3),
      );
      expect(r.right, closeTo(30, 1e-9));
      expect(r.width, closeTo(25, 1e-9));
      expect(r.height, closeTo(10, 1e-9));
    });

    test('rotated element keeps the opposite corner fixed in page space', () {
      const rect = Rect.fromLTWH(0, 0, 20, 10);
      Offset corner(Rect r, double rot, Offset local) =>
          r.center + rotateVector(local, rot);
      final before = corner(rect, 90, const Offset(-10, -5));
      final r = resizeRotatedRect(
        rect: rect,
        rotation: 90,
        handle: ResizeHandle.bottomRight,
        delta: const Offset(-4, 6),
      );
      final after = corner(r, 90, Offset(-r.width / 2, -r.height / 2));
      expect(after.dx, closeTo(before.dx, 1e-9));
      expect(after.dy, closeTo(before.dy, 1e-9));
      expect(r.width, closeTo(26, 1e-9));
      expect(r.height, closeTo(14, 1e-9));
    });

    test('aspect ratio is preserved on corners when requested', () {
      final r = resizeRotatedRect(
        rect: const Rect.fromLTWH(0, 0, 20, 10),
        rotation: 0,
        handle: ResizeHandle.bottomRight,
        delta: const Offset(20, 0),
        keepAspect: true,
      );
      expect(r.width / r.height, closeTo(2, 1e-9));
      expect(r.width, closeTo(40, 1e-9));
    });

    test('size never collapses below the minimum', () {
      final r = resizeRotatedRect(
        rect: const Rect.fromLTWH(0, 0, 5, 5),
        rotation: 0,
        handle: ResizeHandle.right,
        delta: const Offset(-50, 0),
      );
      expect(r.width, 1);
    });
  });

  test('rotation handle snaps near multiples of 45°', () {
    expect(rotationFromPointer(Offset.zero, const Offset(0, -10)), 0);
    expect(rotationFromPointer(Offset.zero, const Offset(10, 0.3)), 90);
    expect(
      rotationFromPointer(Offset.zero, const Offset(10, 0.3), snap: false),
      closeTo(91.7, 0.1),
    );
  });

  group('snap', () {
    test('snaps to the page centre and reports a guide', () {
      final result = computeSnap(
        moving: const Rect.fromLTWH(31, 5, 20, 10),
        page: const Size(85, 55),
        others: const [],
      );
      expect(result.offset.dx, closeTo(1.5, 1e-9));
      expect(result.guides, contains(const SnapGuide.vertical(42.5)));
    });

    test('snaps to another element edge', () {
      final result = computeSnap(
        moving: const Rect.fromLTWH(20.8, 30, 10, 5),
        page: const Size(200, 200),
        others: const [Rect.fromLTWH(0, 0, 20, 20)],
      );
      expect(result.offset.dx, closeTo(-0.8, 1e-9));
    });

    test('snaps to the grid when no guide is close', () {
      final result = computeSnap(
        moving: const Rect.fromLTWH(12.2, 17.6, 3, 3),
        page: const Size(200, 200),
        others: const [],
        gridMm: 5,
        guides: false,
      );
      expect(result.offset.dx, closeTo(-2.2, 1e-9));
      expect(result.offset.dy, closeTo(2.4, 1e-9));
    });
  });

  test('align on page and distribute', () {
    final a = box(5, 5, 10, 10);
    final aligned = alignElements([a], AlignMode.right, const Size(85, 55));
    expect(aligned.single.x, 75);
    final group = alignElements(
      [box(5, 5, 10, 10), box(20, 30, 4, 4), box(40, 0, 10, 10, locked: true)],
      AlignMode.top,
      const Size(85, 55),
    );
    expect(group.map((e) => e.y), [0, 0, 0]);
    final distributed = distributeElements([
      box(0, 0, 10, 10, id: 'a'),
      box(12, 0, 10, 10, id: 'b'),
      box(50, 0, 10, 10, id: 'c'),
    ], horizontal: true);
    expect(distributed[1].x, closeTo(25, 1e-9));
  });

  test('bleed extends only elements touching the edges', () {
    final page = DesignPage(
      elements: [
        box(0, 0, 85, 20, id: 'top'),
        box(10, 10, 5, 5, id: 'inside'),
        box(80, 50, 5, 5, id: 'corner'),
      ],
    );
    final expanded = expandForBleed(page, const Size(85, 55), 3);
    final top = expanded.elementById('top')!;
    expect(top.rect, const Rect.fromLTRB(-3, -3, 88, 20));
    expect(
      expanded.elementById('inside')!.rect,
      const Rect.fromLTWH(10, 10, 5, 5),
    );
    expect(
      expanded.elementById('corner')!.rect,
      const Rect.fromLTRB(80, 50, 88, 58),
    );
  });

  test('vector shapes and image fit', () {
    final ellipse = VectorPath.ellipse(const Rect.fromLTWH(0, 0, 10, 6));
    expect(ellipse.commands.whereType<CubicTo>(), hasLength(4));
    final rounded = VectorPath.rect(
      const Rect.fromLTWH(0, 0, 10, 6),
      radius: 50,
    );
    expect(rounded.commands.whereType<CubicTo>(), hasLength(4));
    final star = VectorPath.forElement(
      DesignElement(
        type: ElementType.shape,
        shape: ShapeKind.star,
        x: 0,
        y: 0,
        width: 10,
        height: 10,
      ),
    );
    expect(star.commands.whereType<LineTo>(), hasLength(9));
    final cover = fitImageRect(
      const Size(200, 100),
      const Rect.fromLTWH(0, 0, 10, 10),
      ImageFit.cover,
    );
    expect(cover, const Rect.fromLTWH(-5, 0, 20, 10));
    final contain = fitImageRect(
      const Size(200, 100),
      const Rect.fromLTWH(0, 0, 10, 10),
      ImageFit.contain,
    );
    expect(contain, const Rect.fromLTWH(0, 2.5, 10, 5));
  });

  group('QR codes', () {
    final profile = BusinessProfile.example().copyWith(
      bookingUrl: 'resa.techcare.fr',
      portfolioUrl: 'https://portfolio.techcare.fr',
      catalogUrl: 'techcare.fr/catalogue',
      socials: const [
        SocialLink(network: 'Instagram', url: 'instagram.com/techcare'),
      ],
    );

    test('payloads for every kind', () {
      expect(
        QrPayload.forKind(QrKind.website, profile),
        'https://techcare-repair.fr',
      );
      expect(
        QrPayload.forKind(QrKind.booking, profile),
        'https://resa.techcare.fr',
      );
      expect(
        QrPayload.forKind(QrKind.portfolio, profile),
        'https://portfolio.techcare.fr',
      );
      expect(
        QrPayload.forKind(QrKind.catalog, profile),
        'https://techcare.fr/catalogue',
      );
      expect(
        QrPayload.forKind(QrKind.social, profile),
        'https://instagram.com/techcare',
      );
      expect(
        QrPayload.forKind(QrKind.text, profile, custom: 'Bonjour'),
        'Bonjour',
      );
      expect(
        QrPayload.forKind(QrKind.website, profile, custom: 'autre.fr'),
        'https://autre.fr',
      );
    });

    test('vCard contains escaped contact details', () {
      final card = QrPayload.vCard(
        profile.copyWith(name: 'TechCare; Réparations'),
      );
      expect(card, startsWith('BEGIN:VCARD\nVERSION:3.0'));
      expect(card, contains('N:Martin;Alex;;;'));
      expect(card, contains(r'ORG:TechCare\; Réparations'));
      expect(card, contains('TEL;TYPE=WORK,VOICE:0612345678'));
      expect(card, contains('EMAIL;TYPE=WORK:contact@techcare-repair.fr'));
      expect(card, endsWith('END:VCARD'));
    });

    test('matrix generation is deterministic and square', () {
      final modules = QrPayload.modules('https://techcare-repair.fr');
      expect(modules, isNotEmpty);
      expect(
        QrPayload.modules('https://techcare-repair.fr').length,
        modules.length,
      );
      for (final m in modules) {
        expect(m.left + m.width, lessThanOrEqualTo(1.0001));
        expect(m.top + m.height, lessThanOrEqualTo(1.0001));
      }
      expect(QrPayload.modules(''), isEmpty);
      expect(QrPayload.svg('https://a.fr'), contains('<svg'));
    });
  });

  test('page background defaults to opaque white', () {
    expect(DesignPage().background, Fill.solid(const Color(0xFFFFFFFF)));
  });
}
