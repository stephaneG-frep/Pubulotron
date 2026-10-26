import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../core/color_utils.dart';

enum FillKind { solid, linear, radial }

/// Remplissage d'une forme ou d'un fond : couleur unie ou dégradé.
///
/// Pour un dégradé linéaire, [angle] est exprimé en degrés :
/// 0 = de gauche à droite, 90 = de haut en bas.
class Fill {
  Fill.solid(Color color) : this._internal(FillKind.solid, [color], 0);

  Fill.linear(Color from, Color to, {double angle = 90})
    : this._internal(FillKind.linear, [from, to], angle);

  Fill.radial(Color center, Color edge)
    : this._internal(FillKind.radial, [center, edge], 0);

  Fill._internal(this.kind, List<Color> colors, this.angle)
    : colors = List.unmodifiable(colors);

  final FillKind kind;
  final List<Color> colors;
  final double angle;

  /// Couleur principale (unie, ou première couleur du dégradé).
  Color get primary => colors.first;

  Color get secondary => colors.length > 1 ? colors[1] : primary;

  bool get isGradient => kind != FillKind.solid;

  List<Color> get stops => isGradient ? colors : [primary];

  /// Points de départ et d'arrivée relatifs à la boîte (-1..1), repère y vers le bas.
  (Alignment, Alignment) get linearAlignments {
    final rad = angle * math.pi / 180;
    final dx = math.cos(rad);
    final dy = math.sin(rad);
    return (Alignment(-dx, -dy), Alignment(dx, dy));
  }

  Gradient? toGradient() {
    switch (kind) {
      case FillKind.solid:
        return null;
      case FillKind.linear:
        final (begin, end) = linearAlignments;
        return LinearGradient(begin: begin, end: end, colors: colors);
      case FillKind.radial:
        return RadialGradient(colors: colors, radius: 0.5);
    }
  }

  Fill withPrimary(Color color) => switch (kind) {
    FillKind.solid => Fill.solid(color),
    FillKind.linear => Fill.linear(color, secondary, angle: angle),
    FillKind.radial => Fill.radial(color, secondary),
  };

  Fill withSecondary(Color color) => switch (kind) {
    FillKind.solid => Fill.linear(primary, color, angle: 90),
    FillKind.linear => Fill.linear(primary, color, angle: angle),
    FillKind.radial => Fill.radial(primary, color),
  };

  Fill withKind(FillKind newKind) => switch (newKind) {
    FillKind.solid => Fill.solid(primary),
    FillKind.linear => Fill.linear(
      primary,
      isGradient ? secondary : shade(primary, -0.25),
      angle: angle == 0 && kind != FillKind.linear ? 90 : angle,
    ),
    FillKind.radial => Fill.radial(
      primary,
      isGradient ? secondary : shade(primary, -0.25),
    ),
  };

  Fill withAngle(double value) => kind == FillKind.linear
      ? Fill.linear(primary, secondary, angle: value)
      : this;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'colors': stops.map(colorToHex).toList(),
    if (kind == FillKind.linear) 'angle': angle,
  };

  /// Lecture tolérante : accepte aussi une simple chaîne hexadécimale.
  static Fill? fromJson(Object? raw) {
    if (raw == null) return null;
    final direct = parseHexColor(raw);
    if (direct != null) return Fill.solid(direct);
    if (raw is! Map) return null;
    final colors = ((raw['colors'] as List?) ?? const [])
        .map(parseHexColor)
        .whereType<Color>()
        .toList();
    final single = parseHexColor(raw['color']);
    if (colors.isEmpty && single != null) colors.add(single);
    if (colors.isEmpty) return null;
    final kind = FillKind.values.firstWhere(
      (k) => k.name == raw['kind'],
      orElse: () => colors.length > 1 ? FillKind.linear : FillKind.solid,
    );
    if (kind == FillKind.solid || colors.length < 2) {
      return Fill.solid(colors.first);
    }
    if (kind == FillKind.radial) return Fill.radial(colors[0], colors[1]);
    final angle = (raw['angle'] as num?)?.toDouble() ?? 90;
    return Fill.linear(
      colors[0],
      colors[1],
      angle: angle.isFinite ? angle : 90,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Fill &&
      other.kind == kind &&
      other.angle == angle &&
      _listEquals(other.stops, stops);

  @override
  int get hashCode => Object.hash(kind, angle, Object.hashAll(stops));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
