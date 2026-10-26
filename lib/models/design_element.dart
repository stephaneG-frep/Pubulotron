import 'package:flutter/painting.dart';

import '../core/color_utils.dart';
import '../core/ids.dart';
import 'fill.dart';

enum ElementType { text, shape, image, qr, icon }

enum ShapeKind { rectangle, ellipse, triangle, diamond, star, hexagon }

enum TextAlignH { left, center, right }

enum TextAlignV { top, middle, bottom }

enum ImageFit { cover, contain, fill }

const _unset = Object();

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

double _num(Object? value, double fallback) {
  if (value is num && value.isFinite) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

/// Élément graphique éditable. Toutes les dimensions sont en millimètres,
/// relatives au coin supérieur gauche de la page (hors fond perdu).
/// La rotation est en degrés, dans le sens horaire, autour du centre.
class DesignElement {
  DesignElement({
    String? id,
    required this.type,
    this.name = '',
    this.role,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.rotation = 0,
    this.opacity = 1,
    this.locked = false,
    this.visible = true,
    this.fill,
    this.strokeColor,
    this.strokeWidth = 0,
    this.cornerRadius = 0,
    this.shape = ShapeKind.rectangle,
    this.text = '',
    this.fontFamily = 'Liberation Sans',
    this.fontSize = 12,
    this.bold = false,
    this.italic = false,
    this.textAlign = TextAlignH.left,
    this.verticalAlign = TextAlignV.top,
    this.lineHeight = 1.2,
    this.letterSpacing = 0,
    this.color = const Color(0xFF17213B),
    this.assetId,
    this.imageFit = ImageFit.cover,
    this.qrData = '',
    this.iconKey = 'star',
  }) : id = id ?? newId('el');

  final String id;
  final ElementType type;
  final String name;

  /// Rôle sémantique facultatif (titre, téléphone…), utile à l'agent IA.
  final String? role;
  final double x;
  final double y;
  final double width;
  final double height;
  final double rotation;
  final double opacity;
  final bool locked;
  final bool visible;

  /// Remplissage de la forme, fond du texte, ou fond du QR code.
  final Fill? fill;
  final Color? strokeColor;
  final double strokeWidth;
  final double cornerRadius;
  final ShapeKind shape;

  final String text;
  final String fontFamily;

  /// Taille de police en points typographiques.
  final double fontSize;
  final bool bold;
  final bool italic;
  final TextAlignH textAlign;
  final TextAlignV verticalAlign;
  final double lineHeight;

  /// Approche en points.
  final double letterSpacing;

  /// Couleur du texte, du pictogramme ou des modules du QR code.
  final Color color;

  /// Identifiant du fichier image dans la médiathèque locale.
  final String? assetId;
  final ImageFit imageFit;
  final String qrData;
  final String iconKey;

  Rect get rect => Rect.fromLTWH(x, y, width, height);

  Offset get center => Offset(x + width / 2, y + height / 2);

  String get displayName {
    if (name.trim().isNotEmpty) return name;
    return switch (type) {
      ElementType.text =>
        text.trim().isEmpty ? 'Texte' : text.trim().split('\n').first,
      ElementType.shape => 'Forme',
      ElementType.image => 'Image',
      ElementType.qr => 'QR code',
      ElementType.icon => 'Pictogramme',
    };
  }

  DesignElement copyWith({
    String? id,
    ElementType? type,
    String? name,
    Object? role = _unset,
    double? x,
    double? y,
    double? width,
    double? height,
    double? rotation,
    double? opacity,
    bool? locked,
    bool? visible,
    Object? fill = _unset,
    Object? strokeColor = _unset,
    double? strokeWidth,
    double? cornerRadius,
    ShapeKind? shape,
    String? text,
    String? fontFamily,
    double? fontSize,
    bool? bold,
    bool? italic,
    TextAlignH? textAlign,
    TextAlignV? verticalAlign,
    double? lineHeight,
    double? letterSpacing,
    Color? color,
    Object? assetId = _unset,
    ImageFit? imageFit,
    String? qrData,
    String? iconKey,
  }) {
    return DesignElement(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      role: identical(role, _unset) ? this.role : role as String?,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      locked: locked ?? this.locked,
      visible: visible ?? this.visible,
      fill: identical(fill, _unset) ? this.fill : fill as Fill?,
      strokeColor: identical(strokeColor, _unset)
          ? this.strokeColor
          : strokeColor as Color?,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      shape: shape ?? this.shape,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      textAlign: textAlign ?? this.textAlign,
      verticalAlign: verticalAlign ?? this.verticalAlign,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      color: color ?? this.color,
      assetId: identical(assetId, _unset) ? this.assetId : assetId as String?,
      imageFit: imageFit ?? this.imageFit,
      qrData: qrData ?? this.qrData,
      iconKey: iconKey ?? this.iconKey,
    );
  }

  /// Copie avec un nouvel identifiant (duplication).
  DesignElement duplicate({double offset = 0}) =>
      copyWith(id: newId('el'), x: x + offset, y: y + offset, locked: false);

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'id': id,
      'type': type.name,
      if (name.isNotEmpty) 'name': name,
      if (role != null) 'role': role,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      if (rotation != 0) 'rotation': rotation,
      if (opacity != 1) 'opacity': opacity,
      if (locked) 'locked': true,
      if (!visible) 'visible': false,
      if (fill != null) 'fill': fill!.toJson(),
      if (strokeColor != null)
        'strokeColor': colorToHex(strokeColor!, withAlpha: true),
      if (strokeWidth != 0) 'strokeWidth': strokeWidth,
      if (cornerRadius != 0) 'cornerRadius': cornerRadius,
    };
    switch (type) {
      case ElementType.shape:
        json['shape'] = shape.name;
      case ElementType.text:
        json.addAll({
          'text': text,
          'fontFamily': fontFamily,
          'fontSize': fontSize,
          if (bold) 'bold': true,
          if (italic) 'italic': true,
          'textAlign': textAlign.name,
          'verticalAlign': verticalAlign.name,
          'lineHeight': lineHeight,
          if (letterSpacing != 0) 'letterSpacing': letterSpacing,
          'color': colorToHex(color, withAlpha: true),
        });
      case ElementType.image:
        json['assetId'] = assetId;
        json['imageFit'] = imageFit.name;
      case ElementType.qr:
        json['qrData'] = qrData;
        json['color'] = colorToHex(color, withAlpha: true);
      case ElementType.icon:
        json['iconKey'] = iconKey;
        json['color'] = colorToHex(color, withAlpha: true);
    }
    return json;
  }

  factory DesignElement.fromJson(Map<String, dynamic> json) {
    final type = _enumByName(
      ElementType.values,
      json['type'],
      ElementType.shape,
    );
    return DesignElement(
      id: json['id'] is String && (json['id'] as String).isNotEmpty
          ? json['id'] as String
          : null,
      type: type,
      name: json['name'] as String? ?? '',
      role: json['role'] as String?,
      x: _num(json['x'], 0),
      y: _num(json['y'], 0),
      width: _num(json['width'], 20).clamp(0.1, 10000).toDouble(),
      height: _num(json['height'], 10).clamp(0.1, 10000).toDouble(),
      rotation: _num(json['rotation'], 0),
      opacity: _num(json['opacity'], 1).clamp(0, 1).toDouble(),
      locked: json['locked'] == true,
      visible: json['visible'] != false,
      fill: Fill.fromJson(json['fill']),
      strokeColor: parseHexColor(json['strokeColor']),
      strokeWidth: _num(json['strokeWidth'], 0).clamp(0, 100).toDouble(),
      cornerRadius: _num(json['cornerRadius'], 0).clamp(0, 10000).toDouble(),
      shape: _enumByName(ShapeKind.values, json['shape'], ShapeKind.rectangle),
      text: json['text'] as String? ?? '',
      fontFamily: json['fontFamily'] as String? ?? 'Liberation Sans',
      fontSize: _num(json['fontSize'], 12).clamp(1, 2000).toDouble(),
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      textAlign: _enumByName(
        TextAlignH.values,
        json['textAlign'],
        TextAlignH.left,
      ),
      verticalAlign: _enumByName(
        TextAlignV.values,
        json['verticalAlign'],
        TextAlignV.top,
      ),
      lineHeight: _num(json['lineHeight'], 1.2).clamp(0.6, 4).toDouble(),
      letterSpacing: _num(json['letterSpacing'], 0),
      color: parseHexColor(json['color']) ?? const Color(0xFF17213B),
      assetId: json['assetId'] as String?,
      imageFit: _enumByName(ImageFit.values, json['imageFit'], ImageFit.cover),
      qrData: json['qrData'] as String? ?? '',
      iconKey: json['iconKey'] as String? ?? 'star',
    );
  }
}
