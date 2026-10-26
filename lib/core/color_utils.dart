import 'package:flutter/painting.dart';

/// Lit une couleur au format `#RRGGBB`, `#AARRGGBB`, `RRGGBB` ou `#RGB`.
/// Renvoie `null` si la valeur est invalide.
Color? parseHexColor(Object? value) {
  if (value is int) return Color(value);
  if (value is! String) return null;
  var hex = value.trim();
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.startsWith('0x') || hex.startsWith('0X')) hex = hex.substring(2);
  if (hex.length == 3) {
    hex = hex.split('').map((c) => '$c$c').join();
  }
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

String colorToHex(Color color, {bool withAlpha = false}) {
  final argb = color.toARGB32();
  final hex = argb.toRadixString(16).padLeft(8, '0').toUpperCase();
  return '#${withAlpha && (argb >> 24) != 0xFF ? hex : hex.substring(2)}';
}

/// Couleur de texte lisible (noir ou blanc) sur un fond donné.
Color readableOn(Color background) => background.computeLuminance() > 0.45
    ? const Color(0xFF17213B)
    : const Color(0xFFFFFFFF);

/// Éclaircit (`amount` > 0) ou assombrit (`amount` < 0) une couleur.
Color shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
}
