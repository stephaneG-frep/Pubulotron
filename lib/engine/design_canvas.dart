import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../models/fill.dart';
import 'icon_catalog.dart';
import 'text_layout.dart';
import 'vector_path.dart';

/// Image prête à dessiner.
class DesignImage {
  const DesignImage({
    required this.id,
    required this.width,
    required this.height,
    this.decoded,
  });

  final String id;
  final int width;
  final int height;
  final ui.Image? decoded;

  Size get size => Size(width.toDouble(), height.toDouble());
}

/// Surface de dessin abstraite, en millimètres, axe y vers le bas.
///
/// Deux implémentations : le canevas Flutter (écran, PNG, JPEG) et le
/// canevas PDF vectoriel. Le même code de rendu pilote les deux.
abstract class DesignCanvas {
  void save();
  void restore();
  void translate(double dx, double dy);

  /// Rotation horaire en degrés.
  void rotate(double degrees);
  void clip(VectorPath path);

  /// [box] sert de référence aux dégradés.
  void fill(VectorPath path, Fill fill, Rect box, {double opacity = 1});
  void stroke(VectorPath path, Color color, double width, {double opacity = 1});
  void fillRects(List<Rect> rects, Color color, {double opacity = 1});

  /// Dessine l'image entière étirée dans [dest].
  void image(DesignImage image, Rect dest, {double opacity = 1});

  /// Peint un texte déjà mis en page, à partir de [origin] (coin haut gauche).
  void text(TextLayoutResult layout, Offset origin, {double opacity = 1});

  /// Pictogramme centré dans un carré inscrit dans [box].
  void icon(PictogramDef icon, Rect box, Color color, {double opacity = 1});
}
