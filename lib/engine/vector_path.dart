import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../models/design_element.dart';
import 'geometry.dart';

sealed class PathCommand {
  const PathCommand();
}

class MoveTo extends PathCommand {
  const MoveTo(this.x, this.y);
  final double x;
  final double y;
}

class LineTo extends PathCommand {
  const LineTo(this.x, this.y);
  final double x;
  final double y;
}

class CubicTo extends PathCommand {
  const CubicTo(this.x1, this.y1, this.x2, this.y2, this.x, this.y);
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double x;
  final double y;
}

class ClosePath extends PathCommand {
  const ClosePath();
}

/// Tracé vectoriel indépendant du moteur de rendu (écran ou PDF).
class VectorPath {
  const VectorPath(this.commands, this.bounds);

  final List<PathCommand> commands;
  final Rect bounds;

  static const double _kappa = 0.5522847498;

  factory VectorPath.rect(Rect r, {double radius = 0}) {
    final rad = math.max(
      0.0,
      math.min(radius, math.min(r.width, r.height) / 2),
    );
    if (rad <= 0.001) {
      return VectorPath([
        MoveTo(r.left, r.top),
        LineTo(r.right, r.top),
        LineTo(r.right, r.bottom),
        LineTo(r.left, r.bottom),
        const ClosePath(),
      ], r);
    }
    final k = rad * (1 - _kappa);
    return VectorPath([
      MoveTo(r.left + rad, r.top),
      LineTo(r.right - rad, r.top),
      CubicTo(r.right - k, r.top, r.right, r.top + k, r.right, r.top + rad),
      LineTo(r.right, r.bottom - rad),
      CubicTo(
        r.right,
        r.bottom - k,
        r.right - k,
        r.bottom,
        r.right - rad,
        r.bottom,
      ),
      LineTo(r.left + rad, r.bottom),
      CubicTo(
        r.left + k,
        r.bottom,
        r.left,
        r.bottom - k,
        r.left,
        r.bottom - rad,
      ),
      LineTo(r.left, r.top + rad),
      CubicTo(r.left, r.top + k, r.left + k, r.top, r.left + rad, r.top),
      const ClosePath(),
    ], r);
  }

  factory VectorPath.ellipse(Rect r) {
    final cx = r.center.dx;
    final cy = r.center.dy;
    final rx = r.width / 2;
    final ry = r.height / 2;
    final ox = rx * _kappa;
    final oy = ry * _kappa;
    return VectorPath([
      MoveTo(cx + rx, cy),
      CubicTo(cx + rx, cy + oy, cx + ox, cy + ry, cx, cy + ry),
      CubicTo(cx - ox, cy + ry, cx - rx, cy + oy, cx - rx, cy),
      CubicTo(cx - rx, cy - oy, cx - ox, cy - ry, cx, cy - ry),
      CubicTo(cx + ox, cy - ry, cx + rx, cy - oy, cx + rx, cy),
      const ClosePath(),
    ], r);
  }

  factory VectorPath.polygon(Rect r, List<Offset> normalized) {
    final commands = <PathCommand>[];
    for (var i = 0; i < normalized.length; i++) {
      final p = normalized[i];
      final x = r.left + p.dx * r.width;
      final y = r.top + p.dy * r.height;
      commands.add(i == 0 ? MoveTo(x, y) : LineTo(x, y));
    }
    commands.add(const ClosePath());
    return VectorPath(commands, r);
  }

  /// Contour d'un élément dans son repère local (0, 0, largeur, hauteur).
  factory VectorPath.forElement(DesignElement e) {
    final box = Rect.fromLTWH(0, 0, e.width, e.height);
    if (e.type != ElementType.shape) {
      return VectorPath.rect(box, radius: e.cornerRadius);
    }
    if (e.shape == ShapeKind.ellipse) return VectorPath.ellipse(box);
    final polygon = polygonFor(e.shape);
    if (polygon == null) return VectorPath.rect(box, radius: e.cornerRadius);
    return VectorPath.polygon(box, polygon);
  }

  Path toFlutterPath() {
    final path = Path();
    for (final c in commands) {
      switch (c) {
        case MoveTo(:final x, :final y):
          path.moveTo(x, y);
        case LineTo(:final x, :final y):
          path.lineTo(x, y);
        case CubicTo(
          :final x1,
          :final y1,
          :final x2,
          :final y2,
          :final x,
          :final y,
        ):
          path.cubicTo(x1, y1, x2, y2, x, y);
        case ClosePath():
          path.close();
      }
    }
    return path;
  }
}

/// Rectangle occupé par une image de taille [image] dans [box] selon [fit].
Rect fitImageRect(Size image, Rect box, ImageFit fit) {
  if (image.width <= 0 || image.height <= 0) return box;
  switch (fit) {
    case ImageFit.fill:
      return box;
    case ImageFit.cover:
    case ImageFit.contain:
      final sx = box.width / image.width;
      final sy = box.height / image.height;
      final scale = fit == ImageFit.cover ? math.max(sx, sy) : math.min(sx, sy);
      return Rect.fromCenter(
        center: box.center,
        width: image.width * scale,
        height: image.height * scale,
      );
  }
}
