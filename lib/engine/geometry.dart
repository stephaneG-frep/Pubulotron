import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/design_document.dart';
import '../models/design_element.dart';

/// Sommets normalisés (0..1, y vers le bas) des formes polygonales.
/// Utilisés à l'identique par le rendu écran et le rendu PDF.
List<Offset>? polygonFor(ShapeKind shape) {
  switch (shape) {
    case ShapeKind.rectangle:
    case ShapeKind.ellipse:
      return null;
    case ShapeKind.triangle:
      return const [Offset(0.5, 0), Offset(1, 1), Offset(0, 1)];
    case ShapeKind.diamond:
      return const [
        Offset(0.5, 0),
        Offset(1, 0.5),
        Offset(0.5, 1),
        Offset(0, 0.5),
      ];
    case ShapeKind.hexagon:
      return const [
        Offset(0.25, 0),
        Offset(0.75, 0),
        Offset(1, 0.5),
        Offset(0.75, 1),
        Offset(0.25, 1),
        Offset(0, 0.5),
      ];
    case ShapeKind.star:
      final points = <Offset>[];
      for (var i = 0; i < 10; i++) {
        final r = i.isEven ? 0.5 : 0.2;
        final a = -math.pi / 2 + i * math.pi / 5;
        points.add(
          Offset(0.5 + r * math.cos(a), 0.5 + r * math.sin(a) * 1.05 + 0.025),
        );
      }
      return points;
  }
}

/// Étend les éléments qui touchent un bord de la page jusque dans le fond
/// perdu, pour éviter tout liseré blanc après la découpe.
DesignPage expandForBleed(DesignPage page, Size pageMm, double bleedMm) {
  if (bleedMm <= 0) return page;
  const eps = 0.05;
  return page.copyWith(
    elements: [
      for (final e in page.elements)
        if (e.rotation % 360 == 0 &&
            (e.type == ElementType.shape || e.type == ElementType.image))
          _expandElement(e, pageMm, bleedMm, eps)
        else
          e,
    ],
  );
}

DesignElement _expandElement(
  DesignElement e,
  Size pageMm,
  double bleed,
  double eps,
) {
  var left = e.x;
  var top = e.y;
  var right = e.x + e.width;
  var bottom = e.y + e.height;
  if (left <= eps) left -= bleed;
  if (top <= eps) top -= bleed;
  if (right >= pageMm.width - eps) right += bleed;
  if (bottom >= pageMm.height - eps) bottom += bleed;
  if (left == e.x &&
      top == e.y &&
      right == e.x + e.width &&
      bottom == e.y + e.height) {
    return e;
  }
  return e.copyWith(x: left, y: top, width: right - left, height: bottom - top);
}

/// Poignées de redimensionnement.
enum ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left,
}

extension ResizeHandleAxes on ResizeHandle {
  /// -1 (bord gauche/haut), 0 (aucun), 1 (bord droit/bas).
  int get hx => switch (this) {
    ResizeHandle.topLeft || ResizeHandle.left || ResizeHandle.bottomLeft => -1,
    ResizeHandle.topRight ||
    ResizeHandle.right ||
    ResizeHandle.bottomRight => 1,
    _ => 0,
  };

  int get vy => switch (this) {
    ResizeHandle.topLeft || ResizeHandle.top || ResizeHandle.topRight => -1,
    ResizeHandle.bottomLeft ||
    ResizeHandle.bottom ||
    ResizeHandle.bottomRight => 1,
    _ => 0,
  };

  bool get isCorner => hx != 0 && vy != 0;

  Alignment get alignment => Alignment(hx.toDouble(), vy.toDouble());
}

Offset rotateVector(Offset v, double degrees) {
  final r = degrees * math.pi / 180;
  final c = math.cos(r);
  final s = math.sin(r);
  return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
}

/// Redimensionne un rectangle tourné en gardant fixe le bord ou le coin
/// opposé à la poignée. [delta] est le déplacement du pointeur en mm,
/// dans le repère de la page.
Rect resizeRotatedRect({
  required Rect rect,
  required double rotation,
  required ResizeHandle handle,
  required Offset delta,
  bool keepAspect = false,
  double minSize = 1,
}) {
  final local = rotateVector(delta, -rotation);
  var w = rect.width;
  var h = rect.height;
  if (handle.hx != 0) w = math.max(minSize, w + local.dx * handle.hx);
  if (handle.vy != 0) h = math.max(minSize, h + local.dy * handle.vy);
  if (keepAspect && handle.isCorner && rect.width > 0 && rect.height > 0) {
    final ratio = rect.width / rect.height;
    final scale = math.max(w / rect.width, h / rect.height);
    w = math.max(minSize, rect.width * scale);
    h = math.max(minSize, w / ratio);
  }
  // Point fixe : opposé à la poignée, exprimé dans le repère local centré.
  final fixedLocalOld = Offset(
    -handle.hx * rect.width / 2,
    -handle.vy * rect.height / 2,
  );
  final fixedLocalNew = Offset(-handle.hx * w / 2, -handle.vy * h / 2);
  final fixedWorld = rect.center + rotateVector(fixedLocalOld, rotation);
  final newCenter = fixedWorld - rotateVector(fixedLocalNew, rotation);
  return Rect.fromCenter(center: newCenter, width: w, height: h);
}

/// Angle (degrés) d'une poignée de rotation placée au-dessus de l'élément.
double rotationFromPointer(Offset center, Offset pointer, {bool snap = true}) {
  final v = pointer - center;
  var deg = math.atan2(v.dy, v.dx) * 180 / math.pi + 90;
  deg = (deg % 360 + 360) % 360;
  if (snap) {
    final nearest = (deg / 45).round() * 45.0;
    if ((deg - nearest).abs() < 4) deg = nearest % 360;
  }
  return deg;
}

/// Boîte englobante d'un élément tourné.
Rect rotatedBounds(DesignElement e) {
  if (e.rotation % 360 == 0) return e.rect;
  final c = e.center;
  final corners = [
    Offset(-e.width / 2, -e.height / 2),
    Offset(e.width / 2, -e.height / 2),
    Offset(e.width / 2, e.height / 2),
    Offset(-e.width / 2, e.height / 2),
  ].map((p) => c + rotateVector(p, e.rotation));
  final xs = corners.map((p) => p.dx);
  final ys = corners.map((p) => p.dy);
  return Rect.fromLTRB(
    xs.reduce(math.min),
    ys.reduce(math.min),
    xs.reduce(math.max),
    ys.reduce(math.max),
  );
}

class SnapGuide {
  const SnapGuide.vertical(this.position) : vertical = true;
  const SnapGuide.horizontal(this.position) : vertical = false;

  final bool vertical;
  final double position;

  @override
  bool operator ==(Object other) =>
      other is SnapGuide &&
      other.vertical == vertical &&
      other.position == position;

  @override
  int get hashCode => Object.hash(vertical, position);
}

class SnapResult {
  const SnapResult(this.offset, this.guides);

  /// Correction à appliquer au déplacement, en mm.
  final Offset offset;
  final List<SnapGuide> guides;
}

/// Magnétisme : aligne un rectangle déplacé sur les bords et le centre de la
/// page et des autres éléments, puis éventuellement sur la grille.
SnapResult computeSnap({
  required Rect moving,
  required Size page,
  required Iterable<Rect> others,
  double threshold = 1.5,
  double? gridMm,
  bool guides = true,
}) {
  final xTargets = <double>[];
  final yTargets = <double>[];
  if (guides) {
    xTargets.addAll([0, page.width / 2, page.width]);
    yTargets.addAll([0, page.height / 2, page.height]);
    for (final r in others) {
      xTargets.addAll([r.left, r.center.dx, r.right]);
      yTargets.addAll([r.top, r.center.dy, r.bottom]);
    }
  }
  final xs = [moving.left, moving.center.dx, moving.right];
  final ys = [moving.top, moving.center.dy, moving.bottom];

  double? bestDx;
  double? guideX;
  for (final target in xTargets) {
    for (final x in xs) {
      final d = target - x;
      if (d.abs() <= threshold && (bestDx == null || d.abs() < bestDx.abs())) {
        bestDx = d;
        guideX = target;
      }
    }
  }
  double? bestDy;
  double? guideY;
  for (final target in yTargets) {
    for (final y in ys) {
      final d = target - y;
      if (d.abs() <= threshold && (bestDy == null || d.abs() < bestDy.abs())) {
        bestDy = d;
        guideY = target;
      }
    }
  }
  if (gridMm != null && gridMm > 0) {
    bestDx ??= (moving.left / gridMm).round() * gridMm - moving.left;
    bestDy ??= (moving.top / gridMm).round() * gridMm - moving.top;
  }
  return SnapResult(Offset(bestDx ?? 0, bestDy ?? 0), [
    if (guideX != null) SnapGuide.vertical(guideX),
    if (guideY != null) SnapGuide.horizontal(guideY),
  ]);
}

enum AlignMode { left, centerH, right, top, centerV, bottom }

/// Aligne les éléments : sur la page si un seul élément est concerné,
/// sinon sur la boîte englobante de la sélection.
List<DesignElement> alignElements(
  List<DesignElement> elements,
  AlignMode mode,
  Size page, {
  bool toPage = false,
}) {
  if (elements.isEmpty) return elements;
  final reference = toPage || elements.length == 1
      ? Offset.zero & page
      : elements.map((e) => e.rect).reduce((a, b) => a.expandToInclude(b));
  return [
    for (final e in elements)
      if (e.locked)
        e
      else
        switch (mode) {
          AlignMode.left => e.copyWith(x: reference.left),
          AlignMode.centerH => e.copyWith(x: reference.center.dx - e.width / 2),
          AlignMode.right => e.copyWith(x: reference.right - e.width),
          AlignMode.top => e.copyWith(y: reference.top),
          AlignMode.centerV => e.copyWith(
            y: reference.center.dy - e.height / 2,
          ),
          AlignMode.bottom => e.copyWith(y: reference.bottom - e.height),
        },
  ];
}

/// Répartit uniformément les espaces entre au moins trois éléments.
List<DesignElement> distributeElements(
  List<DesignElement> elements, {
  required bool horizontal,
}) {
  if (elements.length < 3) return elements;
  final sorted = [...elements]
    ..sort((a, b) => horizontal ? a.x.compareTo(b.x) : a.y.compareTo(b.y));
  final first = sorted.first;
  final last = sorted.last;
  final span = horizontal
      ? (last.x + last.width) - first.x
      : (last.y + last.height) - first.y;
  final total = sorted.fold<double>(
    0,
    (s, e) => s + (horizontal ? e.width : e.height),
  );
  final gap = (span - total) / (sorted.length - 1);
  var cursor = horizontal ? first.x : first.y;
  final placed = <String, DesignElement>{};
  for (final e in sorted) {
    placed[e.id] = e.locked
        ? e
        : horizontal
        ? e.copyWith(x: cursor)
        : e.copyWith(y: cursor);
    cursor += (horizontal ? e.width : e.height) + gap;
  }
  return [for (final e in elements) placed[e.id]!];
}
