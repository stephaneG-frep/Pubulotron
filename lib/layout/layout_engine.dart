import 'dart:math' as math;
import 'dart:ui';

import '../core/color_utils.dart';
import '../engine/qr_payload.dart';
import '../engine/text_layout.dart';
import '../models/business_profile.dart';
import '../models/design_document.dart';
import '../models/design_element.dart';
import '../models/fill.dart';
import 'brand_kit.dart';

/// Contexte de composition d'une face.
class _Ctx {
  _Ctx(this.w, this.h, this.kit, this.profile, {this.withQr = true})
    : u = math.min(w, h);

  final double w;
  final double h;
  final double u;
  final BrandKit kit;
  final BusinessProfile profile;
  final bool withQr;
  final List<DesignElement> out = [];

  bool get landscape => w > h * 1.15;
  bool get portrait => h > w * 1.15;
  double get margin => (u * 0.075).clamp(3.0, 22.0);
  double get titlePt => u * 0.24;
  double get bodyPt => u * 0.075 + 2.5;
  double get smallPt => math.max(6.0, bodyPt * 0.85);
  String get website => profile.website;
  bool get hasLogo => profile.logoAssetId != null;

  Rect r(double x, double y, double width, double height) =>
      Rect.fromLTWH(x, y, width, height);

  void rect(
    Rect r,
    Fill fill, {
    double radius = 0,
    String? name,
    String? role,
    Color? stroke,
    double strokeWidth = 0,
    double rotation = 0,
    double opacity = 1,
  }) {
    out.add(
      DesignElement(
        type: ElementType.shape,
        name: name ?? 'Forme',
        role: role,
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        fill: fill,
        cornerRadius: radius,
        strokeColor: stroke,
        strokeWidth: strokeWidth,
        rotation: rotation,
        opacity: opacity,
      ),
    );
  }

  void shape(
    ShapeKind kind,
    Rect r,
    Fill? fill, {
    String? name,
    double rotation = 0,
    double opacity = 1,
    Color? stroke,
    double strokeWidth = 0,
  }) {
    out.add(
      DesignElement(
        type: ElementType.shape,
        shape: kind,
        name: name ?? 'Décor',
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        fill: fill,
        rotation: rotation,
        opacity: opacity,
        strokeColor: stroke,
        strokeWidth: strokeWidth,
      ),
    );
  }

  /// Ajoute un texte et réduit sa taille jusqu'à ce qu'il tienne dans le cadre.
  void text(
    String value,
    Rect r, {
    required double pt,
    String? font,
    bool bold = false,
    bool italic = false,
    Color? color,
    TextAlignH align = TextAlignH.left,
    TextAlignV valign = TextAlignV.top,
    double lineHeight = 1.15,
    double letterSpacing = 0,
    String? name,
    String? role,
    double rotation = 0,
    Fill? background,
    double radius = 0,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    var element = DesignElement(
      type: ElementType.text,
      name: name ?? '',
      role: role,
      x: r.left,
      y: r.top,
      width: r.width,
      height: r.height,
      text: trimmed,
      fontFamily: font ?? kit.bodyFont,
      fontSize: pt,
      bold: bold,
      italic: italic,
      color: color ?? kit.dark,
      textAlign: align,
      verticalAlign: valign,
      lineHeight: lineHeight,
      letterSpacing: letterSpacing,
      rotation: rotation,
      fill: background,
      cornerRadius: radius,
    );
    out.add(fitText(element));
  }

  void icon(String key, Rect r, Color color, {String? name}) {
    out.add(
      DesignElement(
        type: ElementType.icon,
        name: name ?? 'Pictogramme',
        iconKey: key,
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        color: color,
      ),
    );
  }

  void qr(Rect r, {Color? color}) {
    if (!withQr) return;
    final data = QrPayload.forKind(QrKind.website, profile);
    if (!QrPayload.isEncodable(data) || website.isEmpty) return;
    final side = math.min(r.width, r.height);
    out.add(
      DesignElement(
        type: ElementType.qr,
        name: 'QR code site',
        role: 'qr',
        qrData: data,
        x: r.left + (r.width - side) / 2,
        y: r.top + (r.height - side) / 2,
        width: side,
        height: side,
        fill: Fill.solid(const Color(0xFFFFFFFF)),
        color: color ?? kit.dark,
        cornerRadius: side * 0.06,
      ),
    );
  }

  void photo(Rect r, {double radius = 0, String role = 'photo'}) {
    out.add(
      DesignElement(
        type: ElementType.image,
        name: 'Photo',
        role: role,
        x: r.left,
        y: r.top,
        width: r.width,
        height: r.height,
        cornerRadius: radius,
      ),
    );
  }

  /// Logo de la fiche si disponible, sinon pictogramme dans une pastille.
  void logoOrIcon(Rect r, {Color? badge, Color? iconColor}) {
    if (hasLogo) {
      out.add(
        DesignElement(
          type: ElementType.image,
          name: 'Logo',
          role: 'logo',
          assetId: profile.logoAssetId,
          imageFit: ImageFit.contain,
          x: r.left,
          y: r.top,
          width: r.width,
          height: r.height,
        ),
      );
      return;
    }
    if (badge != null) {
      shape(ShapeKind.ellipse, r, Fill.solid(badge), name: 'Pastille');
    }
    final inset = badge == null ? 0.0 : r.shortestSide * 0.22;
    icon(
      kit.iconKey,
      r.deflate(inset),
      iconColor ?? kit.primary,
      name: 'Emblème',
    );
  }

  List<(String, String)> get contactLines => [
    if (profile.phone.isNotEmpty) ('phone', profile.phone),
    if (profile.email.isNotEmpty) ('email', profile.email),
    if (profile.website.isNotEmpty) ('web', profile.website),
    if (profile.address.isNotEmpty) ('place', profile.address),
  ];

  /// Bloc de coordonnées avec pictogrammes, dans [r].
  void contacts(
    Rect r, {
    required Color color,
    Color? iconColor,
    double? pt,
    int maxLines = 4,
    bool icons = true,
  }) {
    final lines = contactLines.take(maxLines).toList();
    if (lines.isEmpty) return;
    var size = pt ?? bodyPt;
    var lineH = size * 0.3528 * 1.55;
    if (lineH * lines.length > r.height) {
      lineH = r.height / lines.length;
      size = lineH / (0.3528 * 1.55);
    }
    final iconSide = lineH * 0.78;
    for (var i = 0; i < lines.length; i++) {
      final y = r.top + i * lineH;
      final textLeft = icons ? r.left + iconSide * 1.45 : r.left;
      if (icons) {
        icon(
          lines[i].$1,
          Rect.fromLTWH(r.left, y + (lineH - iconSide) / 2, iconSide, iconSide),
          iconColor ?? color,
        );
      }
      text(
        lines[i].$2,
        Rect.fromLTWH(textLeft, y, r.right - textLeft, lineH),
        pt: size,
        color: color,
        valign: TextAlignV.middle,
        name: switch (lines[i].$1) {
          'phone' => 'Téléphone',
          'email' => 'E-mail',
          'web' => 'Site internet',
          _ => 'Adresse',
        },
        role: lines[i].$1,
        lineHeight: 1.1,
      );
    }
  }

  DesignPage page(Fill background, {String name = 'Recto'}) =>
      DesignPage(name: name, background: background, elements: List.of(out));
}

/// Réduit la police d'un texte jusqu'à ce qu'il tienne dans sa boîte.
DesignElement fitText(DesignElement element, {double minPt = 4}) {
  var e = element;
  for (var i = 0; i < 40; i++) {
    final layout = TextLayoutEngine.layout(e);
    final tooTall = layout.height > e.height + 0.01;
    final tooWide = layout.lines.any((l) => l.width > e.width + 0.05);
    final brokenWord = _breaksInsideWord(e.text, layout.lines.length);
    if (!tooTall && !tooWide && !brokenWord) return e;
    if (e.fontSize <= minPt) return e;
    e = e.copyWith(fontSize: math.max(minPt, e.fontSize * 0.92));
  }
  return e;
}

bool _breaksInsideWord(String text, int lines) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  final hardLines = '\n'.allMatches(text).length + 1;
  return lines > words + hardLines - 1;
}

/// Compose des documents complets selon un style et un format.
class LayoutEngine {
  static DesignDocument build({
    required LayoutStyle style,
    required double widthMm,
    required double heightMm,
    required BrandKit kit,
    required BusinessProfile profile,
    String formatId = 'custom',
    bool duplex = false,
    bool withQr = true,
  }) {
    final front = _Ctx(widthMm, heightMm, kit, profile, withQr: withQr);
    final background = _compose(style, front);
    final pages = [front.page(background)];
    if (duplex) {
      final back = _Ctx(widthMm, heightMm, kit, profile, withQr: withQr);
      pages.add(back.page(_composeBack(style, back), name: 'Verso'));
    }
    return DesignDocument(
      widthMm: widthMm,
      heightMm: heightMm,
      formatId: formatId,
      pages: pages,
    );
  }

  static Fill _compose(LayoutStyle style, _Ctx c) => switch (style) {
    LayoutStyle.neon => _neon(c),
    LayoutStyle.editorial => _editorial(c),
    LayoutStyle.split => _split(c),
    LayoutStyle.pop => _pop(c),
    LayoutStyle.nature => _nature(c),
    LayoutStyle.minimal => _minimal(c),
    LayoutStyle.banner => _banner(c),
    LayoutStyle.ticket => _ticket(c),
    LayoutStyle.menu => _menu(c),
    LayoutStyle.elegant => _elegant(c),
  };

  // ---------------------------------------------------------------- styles

  static Fill _neon(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    final bg = Fill.linear(
      shade(k.dark, -0.04),
      shade(k.primary, -0.28),
      angle: 35,
    );
    c.shape(
      ShapeKind.ellipse,
      c.r(c.w * 0.55, -c.h * 0.25, c.u * 0.95, c.u * 0.95),
      Fill.radial(k.primary, shade(k.dark, -0.04)),
      name: 'Halo',
    );
    c.rect(
      c.r(0, 0, c.u * 0.025, c.h),
      Fill.linear(k.secondary, k.primary, angle: 90),
      name: 'Liseré lumineux',
    );
    if (c.landscape) {
      final colW = c.w * 0.58;
      c.text(
        k.headline,
        c.r(m * 1.4, m, colW, c.h * 0.36),
        pt: c.titlePt,
        font: k.headingFont,
        bold: true,
        color: const Color(0xFFFFFFFF),
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.text(
        k.slogan,
        c.r(m * 1.4, m + c.h * 0.37, colW, c.h * 0.16),
        pt: c.bodyPt,
        color: k.secondary,
        role: 'slogan',
        name: 'Slogan',
        italic: true,
      );
      c.contacts(
        c.r(m * 1.4, c.h * 0.58, colW, c.h * 0.42 - m),
        color: const Color(0xFFFFFFFF),
        iconColor: k.accent,
        maxLines: 3,
      );
      final qrSide = math.min(c.w * 0.26, c.h * 0.42);
      c.qr(c.r(c.w - m - qrSide, c.h - m - qrSide, qrSide, qrSide));
      c.logoOrIcon(
        c.r(c.w - m - qrSide, m, qrSide * 0.7, qrSide * 0.7),
        iconColor: k.secondary,
      );
    } else {
      c.logoOrIcon(
        c.r(m * 1.4, m, c.u * 0.16, c.u * 0.16),
        iconColor: k.secondary,
      );
      c.text(
        k.headline,
        c.r(m * 1.4, c.h * 0.2, c.w - m * 2.4, c.h * 0.24),
        pt: c.titlePt * 1.1,
        font: k.headingFont,
        bold: true,
        color: const Color(0xFFFFFFFF),
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.0,
      );
      c.text(
        k.slogan,
        c.r(m * 1.4, c.h * 0.45, c.w - m * 2.4, c.h * 0.08),
        pt: c.bodyPt * 1.3,
        color: k.secondary,
        role: 'slogan',
        name: 'Slogan',
      );
      if (k.offer.isNotEmpty) {
        c.text(
          k.offer,
          c.r(m * 1.4, c.h * 0.54, c.w * 0.5, c.h * 0.12),
          pt: c.titlePt * 1.2,
          font: k.headingFont,
          bold: true,
          color: k.accent,
          role: 'offer',
          name: 'Offre',
        );
      } else {
        c.text(
          k.services.take(4).map((s) => '›  $s').join('\n'),
          c.r(m * 1.4, c.h * 0.55, c.w * 0.55, c.h * 0.18),
          pt: c.bodyPt,
          color: const Color(0xFFE6E1FF),
          role: 'services',
          name: 'Prestations',
          lineHeight: 1.35,
        );
      }
      c.rect(
        c.r(m * 1.4, c.h * 0.76, c.w * 0.55, c.h * 0.065),
        Fill.linear(k.accent, k.primary, angle: 0),
        radius: c.h * 0.0325,
        name: 'Bouton',
      );
      c.text(
        k.callToAction,
        c.r(m * 1.4, c.h * 0.76, c.w * 0.55, c.h * 0.065),
        pt: c.bodyPt * 1.1,
        bold: true,
        color: const Color(0xFFFFFFFF),
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        role: 'cta',
        name: 'Appel à l’action',
      );
      c.contacts(
        c.r(m * 1.4, c.h * 0.86, c.w * 0.6, c.h * 0.14 - m * 0.6),
        color: const Color(0xFFFFFFFF),
        iconColor: k.accent,
        maxLines: 3,
        pt: c.smallPt,
      );
      final qrSide = c.w * 0.22;
      c.qr(c.r(c.w - m - qrSide, c.h - m - qrSide, qrSide, qrSide));
    }
    return bg;
  }

  static Fill _editorial(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    final ink = k.dark;
    c.rect(
      c.r(m, m, c.w - 2 * m, c.u * 0.006 + 0.3),
      Fill.solid(k.primary),
      name: 'Filet supérieur',
    );
    if (c.landscape) {
      c.text(
        c.profile.activity.isEmpty
            ? k.slogan.toUpperCase()
            : c.profile.activity.toUpperCase(),
        c.r(m, m * 1.6, c.w - 2 * m, c.h * 0.1),
        pt: c.smallPt,
        color: k.primary,
        letterSpacing: 1.2,
        name: 'Surtitre',
      );
      c.text(
        k.headline,
        c.r(m, m * 1.6 + c.h * 0.11, c.w * 0.62, c.h * 0.32),
        pt: c.titlePt,
        font: 'Liberation Serif',
        bold: true,
        color: ink,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.rect(
        c.r(m, c.h * 0.6, c.u * 0.12, 0.5),
        Fill.solid(k.accent),
        name: 'Séparateur',
      );
      c.contacts(
        c.r(m, c.h * 0.65, c.w * 0.62, c.h * 0.35 - m),
        color: ink,
        iconColor: k.primary,
        maxLines: 3,
      );
      final side = math.min(c.w * 0.26, c.h * 0.42);
      c.qr(c.r(c.w - m - side, c.h - m - side, side, side), color: ink);
      c.logoOrIcon(
        c.r(c.w - m - side * 0.7, m * 1.8, side * 0.7, side * 0.7),
        iconColor: k.primary,
      );
    } else {
      c.text(
        c.profile.activity.isEmpty
            ? 'ÉDITION SPÉCIALE'
            : c.profile.activity.toUpperCase(),
        c.r(m, m * 1.5, c.w - 2 * m, c.h * 0.04),
        pt: c.smallPt,
        color: k.primary,
        letterSpacing: 1.5,
        name: 'Surtitre',
      );
      c.text(
        k.headline,
        c.r(m, c.h * 0.09, c.w - 2 * m, c.h * 0.2),
        pt: c.titlePt * 1.05,
        font: 'Liberation Serif',
        bold: true,
        color: ink,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.02,
      );
      c.photo(c.r(m, c.h * 0.31, c.w - 2 * m, c.h * 0.3));
      c.text(
        k.slogan,
        c.r(m, c.h * 0.63, c.w - 2 * m, c.h * 0.07),
        pt: c.bodyPt * 1.4,
        font: 'Liberation Serif',
        italic: true,
        color: k.primary,
        role: 'slogan',
        name: 'Slogan',
      );
      c.text(
        k.body.isNotEmpty ? k.body : k.services.join(' • '),
        c.r(m, c.h * 0.71, c.w * 0.62, c.h * 0.12),
        pt: c.bodyPt,
        color: ink,
        role: 'body',
        name: 'Texte',
        lineHeight: 1.3,
      );
      c.contacts(
        c.r(m, c.h * 0.85, c.w * 0.62, c.h * 0.15 - m),
        color: ink,
        iconColor: k.primary,
        pt: c.smallPt,
      );
      final side = c.w * 0.22;
      c.qr(c.r(c.w - m - side, c.h - m - side, side, side), color: ink);
    }
    return Fill.solid(k.light);
  }

  static Fill _split(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    const white = Color(0xFFFFFFFF);
    if (c.landscape) {
      final split = c.w * 0.42;
      c.rect(
        c.r(0, 0, split, c.h),
        Fill.linear(k.primary, shade(k.primary, -0.18), angle: 60),
        name: 'Bloc couleur',
      );
      c.logoOrIcon(
        c.r(m, m, c.u * 0.24, c.u * 0.24),
        badge: white.withValues(alpha: 0.18),
        iconColor: white,
      );
      c.text(
        k.headline,
        c.r(m, c.h * 0.45, split - 2 * m, c.h * 0.32),
        pt: c.titlePt * 0.9,
        font: k.headingFont,
        bold: true,
        color: white,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.78, split - 2 * m, c.h * 0.22 - m),
        pt: c.smallPt,
        color: white.withValues(alpha: 0.9),
        role: 'slogan',
        name: 'Slogan',
      );
      final left = split + m;
      if (c.profile.contactName.isNotEmpty) {
        c.text(
          c.profile.contactName,
          c.r(left, m, c.w - left - m, c.h * 0.14),
          pt: c.bodyPt * 1.4,
          font: k.headingFont,
          bold: true,
          color: k.dark,
          name: 'Nom',
          role: 'contactName',
        );
        c.text(
          c.profile.jobTitle,
          c.r(left, m + c.h * 0.15, c.w - left - m, c.h * 0.1),
          pt: c.smallPt,
          color: k.primary,
          name: 'Fonction',
        );
      }
      c.contacts(
        c.r(left, c.h * 0.42, c.w - left - m, c.h * 0.58 - m),
        color: k.dark,
        iconColor: k.primary,
      );
    } else {
      final split = c.h * 0.48;
      c.rect(
        c.r(0, 0, c.w, split),
        Fill.linear(k.primary, shade(k.primary, -0.2), angle: 70),
        name: 'Bloc couleur',
      );
      c.shape(
        ShapeKind.ellipse,
        c.r(c.w * 0.6, split - c.u * 0.22, c.u * 0.44, c.u * 0.44),
        Fill.solid(k.accent),
        name: 'Pastille',
      );
      c.icon(
        k.iconKey,
        c.r(c.w * 0.6 + c.u * 0.11, split - c.u * 0.11, c.u * 0.22, c.u * 0.22),
        white,
      );
      c.text(
        c.profile.name.toUpperCase(),
        c.r(m, m, c.w - 2 * m, c.h * 0.05),
        pt: c.smallPt,
        bold: true,
        letterSpacing: 1.2,
        color: white.withValues(alpha: 0.85),
        name: 'Activité',
      );
      c.text(
        k.headline,
        c.r(m, c.h * 0.1, c.w * 0.85 - m, c.h * 0.24),
        pt: c.titlePt * 1.1,
        font: k.headingFont,
        bold: true,
        color: white,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.0,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.35, c.w * 0.55, c.h * 0.1),
        pt: c.bodyPt * 1.2,
        color: white,
        role: 'slogan',
        name: 'Slogan',
      );
      final top = split + c.u * 0.25;
      if (k.offer.isNotEmpty) {
        c.text(
          k.offer,
          c.r(m, top - c.u * 0.14, c.w * 0.5, c.h * 0.1),
          pt: c.titlePt * 1.3,
          font: k.headingFont,
          bold: true,
          color: k.accent,
          role: 'offer',
          name: 'Offre',
        );
      }
      c.text(
        k.services.take(5).map((s) => '•  $s').join('\n'),
        c.r(m, top, c.w - 2 * m, c.h * 0.2),
        pt: c.bodyPt,
        color: k.dark,
        role: 'services',
        name: 'Prestations',
        lineHeight: 1.4,
      );
      c.rect(
        c.r(m, c.h * 0.77, c.w - 2 * m, c.h * 0.003 + 0.3),
        Fill.solid(k.primary.withValues(alpha: 0.3)),
        name: 'Séparateur',
      );
      c.contacts(
        c.r(m, c.h * 0.8, c.w * 0.65, c.h * 0.2 - m),
        color: k.dark,
        iconColor: k.primary,
        pt: c.smallPt,
      );
      final side = c.w * 0.2;
      c.qr(c.r(c.w - m - side, c.h - m - side, side, side), color: k.dark);
    }
    return Fill.solid(k.light);
  }

  static Fill _pop(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    const white = Color(0xFFFFFFFF);
    final tall = c.h > c.w * 1.25;
    c.shape(
      ShapeKind.ellipse,
      c.r(
        -c.u * 0.25,
        -c.u * 0.32,
        c.u * (tall ? 0.9 : 0.72),
        c.u * (tall ? 0.9 : 0.72),
      ),
      Fill.solid(k.secondary),
      name: 'Bulle',
    );
    c.shape(
      ShapeKind.ellipse,
      c.r(c.w - c.u * 0.3, c.h - c.u * 0.32, c.u * 0.6, c.u * 0.6),
      Fill.solid(k.accent),
      name: 'Bulle',
    );
    c.shape(
      ShapeKind.star,
      c.r(c.w - m - c.u * 0.3, m * 0.6, c.u * 0.3, c.u * 0.3),
      Fill.solid(k.primary),
      rotation: 12,
      name: 'Étoile',
    );
    if (k.offer.isNotEmpty) {
      c.text(
        k.offer,
        c.r(c.w - m - c.u * 0.3, m * 0.6 + c.u * 0.08, c.u * 0.3, c.u * 0.15),
        pt: c.titlePt * 0.55,
        font: k.headingFont,
        bold: true,
        color: white,
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        rotation: 12,
        role: 'offer',
        name: 'Offre',
      );
    }
    if (c.landscape) {
      c.text(
        k.headline,
        c.r(m, c.h * 0.2, c.w * 0.62, c.h * 0.36),
        pt: c.titlePt,
        font: 'Ubuntu Condensed',
        color: k.dark,
        role: 'headline',
        name: 'Titre',
        lineHeight: 0.95,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.57, c.w * 0.6, c.h * 0.13),
        pt: c.bodyPt,
        bold: true,
        color: k.primary,
        role: 'slogan',
        name: 'Slogan',
      );
      c.contacts(
        c.r(m, c.h * 0.72, c.w * 0.62, c.h * 0.28 - m),
        color: k.dark,
        iconColor: k.primary,
        maxLines: 2,
      );
    } else {
      c.text(
        k.headline.toUpperCase(),
        c.r(m, c.h * 0.2, c.w - 2 * m, c.h * 0.3),
        pt: c.titlePt * 1.35,
        font: 'Ubuntu Condensed',
        color: k.dark,
        role: 'headline',
        name: 'Titre',
        lineHeight: 0.95,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.51, c.w - 2 * m, c.h * 0.08),
        pt: c.bodyPt * 1.4,
        bold: true,
        color: k.primary,
        role: 'slogan',
        name: 'Slogan',
      );
      c.photo(c.r(m, c.h * 0.6, c.w * 0.5, c.h * 0.2), radius: c.u * 0.04);
      c.rect(
        c.r(m, c.h * 0.83, c.w * 0.55, c.h * 0.065),
        Fill.solid(k.dark),
        radius: c.h * 0.0325,
        name: 'Bouton',
      );
      c.text(
        k.callToAction,
        c.r(m, c.h * 0.83, c.w * 0.55, c.h * 0.065),
        pt: c.bodyPt * 1.1,
        bold: true,
        color: white,
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        role: 'cta',
        name: 'Appel à l’action',
      );
      c.contacts(
        c.r(c.w * 0.58, c.h * 0.62, c.w * 0.42 - m, c.h * 0.18),
        color: k.dark,
        iconColor: k.primary,
        pt: c.smallPt,
        maxLines: 3,
      );
    }
    return Fill.solid(shade(k.light, 0.0));
  }

  static Fill _nature(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    c.shape(
      ShapeKind.ellipse,
      c.r(-c.u * 0.35, c.h - c.u * 0.55, c.u * 1.0, c.u * 0.8),
      Fill.solid(k.primary.withValues(alpha: 0.18)),
      name: 'Feuillage',
    );
    c.shape(
      ShapeKind.ellipse,
      c.r(c.w - c.u * 0.5, -c.u * 0.3, c.u * 0.8, c.u * 0.7),
      Fill.solid(k.secondary.withValues(alpha: 0.25)),
      name: 'Feuillage',
    );
    if (c.landscape) {
      c.icon(k.iconKey, c.r(m, m, c.u * 0.18, c.u * 0.18), k.primary);
      c.text(
        k.headline,
        c.r(m, m + c.u * 0.22, c.w * 0.6, c.h * 0.3),
        pt: c.titlePt * 0.95,
        font: 'Liberation Serif',
        bold: true,
        color: shade(k.primary, -0.2),
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.6, c.w * 0.6, c.h * 0.12),
        pt: c.smallPt,
        italic: true,
        color: k.dark,
        role: 'slogan',
        name: 'Slogan',
      );
      c.contacts(
        c.r(c.w * 0.62, c.h * 0.35, c.w * 0.38 - m, c.h * 0.65 - m),
        color: k.dark,
        iconColor: k.primary,
        pt: c.smallPt,
        maxLines: 3,
        icons: true,
      );
    } else {
      c.icon(
        k.iconKey,
        c.r(c.w / 2 - c.u * 0.08, m, c.u * 0.16, c.u * 0.16),
        k.primary,
      );
      c.text(
        k.headline,
        c.r(m, c.h * 0.14, c.w - 2 * m, c.h * 0.18),
        pt: c.titlePt,
        font: 'Liberation Serif',
        bold: true,
        color: shade(k.primary, -0.22),
        align: TextAlignH.center,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.02,
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.33, c.w - 2 * m, c.h * 0.06),
        pt: c.bodyPt * 1.25,
        italic: true,
        color: k.dark,
        align: TextAlignH.center,
        role: 'slogan',
        name: 'Slogan',
      );
      c.photo(
        c.r(c.w * 0.18, c.h * 0.41, c.w * 0.64, c.h * 0.27),
        radius: c.u * 0.32,
      );
      if (k.offer.isNotEmpty) {
        c.shape(
          ShapeKind.ellipse,
          c.r(c.w * 0.68, c.h * 0.39, c.u * 0.24, c.u * 0.24),
          Fill.solid(k.accent),
          name: 'Pastille offre',
        );
        c.text(
          k.offer,
          c.r(c.w * 0.68, c.h * 0.39 + c.u * 0.07, c.u * 0.24, c.u * 0.1),
          pt: c.titlePt * 0.5,
          font: k.headingFont,
          bold: true,
          color: const Color(0xFFFFFFFF),
          align: TextAlignH.center,
          valign: TextAlignV.middle,
          role: 'offer',
          name: 'Offre',
        );
      }
      c.text(
        k.services.take(4).join('  •  '),
        c.r(m, c.h * 0.7, c.w - 2 * m, c.h * 0.08),
        pt: c.bodyPt,
        color: k.dark,
        align: TextAlignH.center,
        role: 'services',
        name: 'Prestations',
      );
      c.contacts(
        c.r(m, c.h * 0.8, c.w * 0.62, c.h * 0.2 - m),
        color: k.dark,
        iconColor: k.primary,
        pt: c.smallPt,
      );
      final side = c.w * 0.2;
      c.qr(
        c.r(c.w - m - side, c.h - m - side, side, side),
        color: shade(k.primary, -0.3),
      );
    }
    return Fill.linear(k.light, shade(k.light, -0.04), angle: 90);
  }

  static Fill _minimal(_Ctx c) {
    final k = c.kit;
    final m = c.margin * 1.2;
    if (c.landscape) {
      c.logoOrIcon(c.r(m, m, c.u * 0.16, c.u * 0.16), iconColor: k.primary);
      c.text(
        c.profile.contactName.isNotEmpty ? c.profile.contactName : k.headline,
        c.r(m, c.h * 0.4, c.w - 2 * m, c.h * 0.14),
        pt: c.bodyPt * 1.6,
        font: k.headingFont,
        bold: true,
        color: k.dark,
        role: 'headline',
        name: 'Nom',
      );
      c.text(
        c.profile.contactName.isNotEmpty
            ? '${c.profile.jobTitle}${c.profile.jobTitle.isEmpty ? '' : ' — '}${c.profile.name}'
            : k.slogan,
        c.r(m, c.h * 0.55, c.w - 2 * m, c.h * 0.1),
        pt: c.smallPt,
        color: k.primary,
        name: 'Fonction',
      );
      c.rect(
        c.r(m, c.h * 0.7, c.u * 0.1, 0.4),
        Fill.solid(k.accent),
        name: 'Filet',
      );
      c.text(
        c.contactLines.take(3).map((l) => l.$2).join('   ·   '),
        c.r(m, c.h * 0.76, c.w - 2 * m, c.h * 0.24 - m),
        pt: c.smallPt * 0.95,
        color: k.dark,
        name: 'Coordonnées',
        role: 'contacts',
      );
    } else {
      c.logoOrIcon(c.r(m, m, c.u * 0.12, c.u * 0.12), iconColor: k.primary);
      c.text(
        k.headline,
        c.r(m, c.h * 0.32, c.w - 2 * m, c.h * 0.2),
        pt: c.titlePt,
        font: k.headingFont,
        bold: true,
        color: k.dark,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.rect(
        c.r(m, c.h * 0.54, c.u * 0.12, 0.5),
        Fill.solid(k.accent),
        name: 'Filet',
      );
      c.text(
        k.slogan,
        c.r(m, c.h * 0.57, c.w - 2 * m, c.h * 0.08),
        pt: c.bodyPt * 1.2,
        color: k.primary,
        role: 'slogan',
        name: 'Slogan',
      );
      c.text(
        k.body,
        c.r(m, c.h * 0.66, c.w * 0.7, c.h * 0.12),
        pt: c.bodyPt,
        color: k.dark,
        role: 'body',
        name: 'Texte',
        lineHeight: 1.35,
      );
      c.contacts(
        c.r(m, c.h * 0.82, c.w * 0.65, c.h * 0.18 - m),
        color: k.dark,
        iconColor: k.primary,
        pt: c.smallPt,
        icons: false,
      );
      final side = c.w * 0.18;
      c.qr(c.r(c.w - m - side, c.h - m - side, side, side), color: k.dark);
    }
    return Fill.solid(const Color(0xFFFFFFFF));
  }

  static Fill _banner(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    const white = Color(0xFFFFFFFF);
    final offer = k.offer.isNotEmpty ? k.offer : 'PROMO';
    if (c.landscape) {
      c.rect(
        c.r(0, 0, c.w * 0.38, c.h),
        Fill.linear(k.accent, shade(k.accent, -0.15), angle: 90),
        name: 'Bandeau',
      );
      c.text(
        offer,
        c.r(m * 0.6, c.h * 0.18, c.w * 0.38 - m * 1.2, c.h * 0.4),
        pt: c.titlePt * 1.6,
        font: 'Ubuntu Condensed',
        color: white,
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        role: 'offer',
        name: 'Offre',
      );
      c.text(
        'OFFRE SPÉCIALE',
        c.r(m * 0.6, c.h * 0.6, c.w * 0.38 - m * 1.2, c.h * 0.12),
        pt: c.smallPt,
        bold: true,
        letterSpacing: 1,
        color: white,
        align: TextAlignH.center,
        name: 'Bandeau texte',
      );
      final left = c.w * 0.38 + m;
      c.text(
        k.headline,
        c.r(left, m, c.w - left - m, c.h * 0.32),
        pt: c.titlePt * 0.85,
        font: k.headingFont,
        bold: true,
        color: k.dark,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.text(
        k.slogan,
        c.r(left, m + c.h * 0.34, c.w - left - m, c.h * 0.16),
        pt: c.smallPt,
        color: k.primary,
        role: 'slogan',
        name: 'Slogan',
      );
      c.contacts(
        c.r(left, c.h * 0.62, c.w - left - m, c.h * 0.38 - m),
        color: k.dark,
        iconColor: k.accent,
        pt: c.smallPt,
        maxLines: 3,
      );
      return Fill.solid(k.light);
    }
    c.rect(
      c.r(0, c.h * 0.06, c.w, c.h * 0.36),
      Fill.linear(k.primary, shade(k.primary, -0.22), angle: 0),
      name: 'Bandeau',
    );
    c.text(
      'OFFRE EXCEPTIONNELLE',
      c.r(m, c.h * 0.09, c.w - 2 * m, c.h * 0.05),
      pt: c.bodyPt * 1.2,
      bold: true,
      letterSpacing: 2,
      color: white,
      align: TextAlignH.center,
      name: 'Surtitre',
    );
    c.text(
      offer,
      c.r(m, c.h * 0.14, c.w - 2 * m, c.h * 0.24),
      pt: c.titlePt * 2.4,
      font: 'Ubuntu Condensed',
      color: k.accent,
      align: TextAlignH.center,
      valign: TextAlignV.middle,
      role: 'offer',
      name: 'Offre',
    );
    c.text(
      k.headline,
      c.r(m, c.h * 0.46, c.w - 2 * m, c.h * 0.14),
      pt: c.titlePt,
      font: k.headingFont,
      bold: true,
      color: k.dark,
      align: TextAlignH.center,
      role: 'headline',
      name: 'Titre',
      lineHeight: 1.02,
    );
    c.text(
      k.slogan,
      c.r(m, c.h * 0.61, c.w - 2 * m, c.h * 0.06),
      pt: c.bodyPt * 1.2,
      color: k.primary,
      align: TextAlignH.center,
      role: 'slogan',
      name: 'Slogan',
    );
    c.rect(
      c.r(c.w * 0.2, c.h * 0.69, c.w * 0.6, c.h * 0.07),
      Fill.solid(k.accent),
      radius: c.h * 0.035,
      name: 'Bouton',
    );
    c.text(
      k.callToAction,
      c.r(c.w * 0.2, c.h * 0.69, c.w * 0.6, c.h * 0.07),
      pt: c.bodyPt * 1.2,
      bold: true,
      color: white,
      align: TextAlignH.center,
      valign: TextAlignV.middle,
      role: 'cta',
      name: 'Appel à l’action',
    );
    c.contacts(
      c.r(m, c.h * 0.8, c.w * 0.62, c.h * 0.2 - m),
      color: k.dark,
      iconColor: k.primary,
      pt: c.smallPt,
    );
    final side = c.w * 0.2;
    c.qr(c.r(c.w - m - side, c.h - m - side, side, side), color: k.dark);
    return Fill.solid(k.light);
  }

  static Fill _ticket(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    const white = Color(0xFFFFFFFF);
    final bg = Fill.linear(k.primary, shade(k.primary, -0.2), angle: 20);
    c.rect(
      c.r(m * 0.5, m * 0.5, c.w - m, c.h - m),
      Fill.solid(white.withValues(alpha: 0)),
      radius: c.u * 0.05,
      stroke: white.withValues(alpha: 0.6),
      strokeWidth: 0.35,
      name: 'Cadre',
    );
    c.text(
      k.headline,
      c.r(m * 1.2, m * 1.1, c.w * 0.62, c.h * 0.22),
      pt: c.titlePt * 0.75,
      font: k.headingFont,
      bold: true,
      color: white,
      role: 'headline',
      name: 'Titre',
    );
    final isLoyalty = k.offer.isEmpty;
    if (isLoyalty) {
      c.text(
        'CARTE DE FIDÉLITÉ',
        c.r(m * 1.2, m * 1.1 + c.h * 0.22, c.w * 0.6, c.h * 0.1),
        pt: c.smallPt,
        bold: true,
        letterSpacing: 1,
        color: k.accent,
        name: 'Type de carte',
      );
      const cols = 5;
      const rows = 2;
      final gridW = c.w - m * 2.4;
      final cell = math.min(gridW / cols, c.h * 0.36 / rows);
      for (var r = 0; r < rows; r++) {
        for (var i = 0; i < cols; i++) {
          final rect = c.r(
            m * 1.2 + i * (gridW / cols) + (gridW / cols - cell * 0.82) / 2,
            c.h * 0.46 + r * cell,
            cell * 0.82,
            cell * 0.82,
          );
          final last = r == rows - 1 && i == cols - 1;
          c.shape(
            ShapeKind.ellipse,
            rect,
            last
                ? Fill.solid(k.accent)
                : Fill.solid(white.withValues(alpha: 0.12)),
            stroke: white.withValues(alpha: 0.7),
            strokeWidth: 0.3,
            name: 'Tampon ${r * cols + i + 1}',
          );
          if (last) {
            c.icon(
              'gift',
              rect.deflate(rect.width * 0.2),
              white,
              name: 'Cadeau',
            );
          }
        }
      }
      c.text(
        '10e passage offert',
        c.r(m * 1.2, c.h - m * 1.1 - c.h * 0.08, c.w * 0.6, c.h * 0.08),
        pt: c.smallPt * 0.9,
        color: white,
        name: 'Règle',
      );
    } else {
      c.text(
        k.offer,
        c.r(m * 1.2, c.h * 0.32, c.w * 0.55, c.h * 0.36),
        pt: c.titlePt * 1.7,
        font: 'Ubuntu Condensed',
        color: k.accent,
        role: 'offer',
        name: 'Offre',
      );
      c.text(
        k.slogan,
        c.r(m * 1.2, c.h * 0.68, c.w * 0.6, c.h * 0.14),
        pt: c.smallPt,
        color: white,
        role: 'slogan',
        name: 'Conditions',
      );
      final stub = c.w * 0.68;
      for (var i = 0; i < 9; i++) {
        c.shape(
          ShapeKind.ellipse,
          c.r(stub - 0.6, c.h * 0.08 + i * c.h * 0.105, 1.2, 1.2),
          Fill.solid(white.withValues(alpha: 0.7)),
          name: 'Perforation',
        );
      }
      c.text(
        'BON',
        c.r(stub + m * 0.5, m * 1.1, c.w - stub - m * 1.5, c.h * 0.14),
        pt: c.smallPt,
        bold: true,
        letterSpacing: 2,
        color: white,
        align: TextAlignH.center,
        name: 'Talon',
      );
      c.qr(c.r(stub + m * 0.5, c.h * 0.3, c.w - stub - m * 1.5, c.h * 0.4));
      c.text(
        c.profile.phone,
        c.r(stub + m * 0.5, c.h * 0.74, c.w - stub - m * 1.5, c.h * 0.12),
        pt: c.smallPt * 0.9,
        color: white,
        align: TextAlignH.center,
        role: 'phone',
        name: 'Téléphone',
      );
    }
    return bg;
  }

  static Fill _menu(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    final ink = const Color(0xFFF8F1E4);
    c.rect(
      c.r(m * 0.6, m * 0.6, c.w - m * 1.2, c.h - m * 1.2),
      Fill.solid(const Color(0x00000000)),
      stroke: k.accent,
      strokeWidth: 0.4,
      name: 'Cadre',
    );
    c.icon(
      k.iconKey,
      c.r(c.w / 2 - c.u * 0.05, m * 1.3, c.u * 0.1, c.u * 0.1),
      k.accent,
    );
    c.text(
      k.headline,
      c.r(m * 1.5, m * 1.3 + c.u * 0.11, c.w - m * 3, c.h * 0.1),
      pt: c.titlePt * 0.8,
      font: 'Liberation Serif',
      bold: true,
      color: k.accent,
      align: TextAlignH.center,
      role: 'headline',
      name: 'Titre',
    );
    c.text(
      k.slogan,
      c.r(m * 1.5, m * 1.3 + c.u * 0.11 + c.h * 0.1, c.w - m * 3, c.h * 0.05),
      pt: c.bodyPt,
      italic: true,
      font: 'Liberation Serif',
      color: ink,
      align: TextAlignH.center,
      role: 'slogan',
      name: 'Accroche',
    );
    final sections = <(String, List<String>)>[
      (
        'ENTRÉES',
        ['Velouté de saison ........ 7 €', 'Salade du marché ........ 8 €'],
      ),
      (
        'PLATS',
        [
          for (final s in k.services.take(3)) '$s ........ 16 €',
          if (k.services.isEmpty) 'Plat du jour ........ 15 €',
        ],
      ),
      ('DESSERTS', ['Tarte maison ........ 6 €', 'Café gourmand ........ 7 €']),
    ];
    var y = c.h * 0.3;
    final available = c.h * 0.55;
    final sectionH = available / sections.length;
    for (final (title, items) in sections) {
      c.text(
        title,
        c.r(m * 1.5, y, c.w - m * 3, sectionH * 0.25),
        pt: c.bodyPt * 1.1,
        bold: true,
        letterSpacing: 1.5,
        color: k.accent,
        align: TextAlignH.center,
        name: 'Rubrique $title',
      );
      c.text(
        items.join('\n'),
        c.r(m * 1.5, y + sectionH * 0.28, c.w - m * 3, sectionH * 0.65),
        pt: c.bodyPt,
        color: ink,
        align: TextAlignH.center,
        lineHeight: 1.45,
        name: 'Plats $title',
      );
      y += sectionH;
    }
    c.text(
      [
        c.profile.address,
        c.profile.phone,
        c.profile.hours,
      ].where((s) => s.isNotEmpty).join('  ·  '),
      c.r(m * 1.5, c.h - m * 1.3 - c.h * 0.06, c.w - m * 3, c.h * 0.06),
      pt: c.smallPt,
      color: ink,
      align: TextAlignH.center,
      name: 'Infos pratiques',
    );
    return Fill.linear(
      const Color(0xFF1F2A2A),
      const Color(0xFF111818),
      angle: 90,
    );
  }

  static Fill _elegant(_Ctx c) {
    final k = c.kit;
    final m = c.margin;
    final gold = k.accent;
    const ivory = Color(0xFFF7F1E6);
    c.rect(
      c.r(m * 0.55, m * 0.55, c.w - m * 1.1, c.h - m * 1.1),
      Fill.solid(const Color(0x00000000)),
      stroke: gold,
      strokeWidth: 0.35,
      name: 'Cadre doré',
    );
    c.shape(
      ShapeKind.diamond,
      c.r(c.w / 2 - c.u * 0.03, m * 0.55 - c.u * 0.03, c.u * 0.06, c.u * 0.06),
      Fill.solid(gold),
      name: 'Ornement',
    );
    if (c.landscape) {
      c.text(
        k.headline,
        c.r(m * 1.3, c.h * 0.22, c.w - m * 2.6, c.h * 0.26),
        pt: c.titlePt * 0.95,
        font: 'Liberation Serif',
        color: ivory,
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        role: 'headline',
        name: 'Titre',
      );
      c.rect(
        c.r(c.w / 2 - c.u * 0.08, c.h * 0.52, c.u * 0.16, 0.35),
        Fill.solid(gold),
        name: 'Filet',
      );
      c.text(
        k.slogan,
        c.r(m * 1.3, c.h * 0.56, c.w - m * 2.6, c.h * 0.12),
        pt: c.smallPt,
        italic: true,
        font: 'Liberation Serif',
        color: gold,
        align: TextAlignH.center,
        role: 'slogan',
        name: 'Slogan',
      );
      c.text(
        c.contactLines.take(2).map((l) => l.$2).join('   ·   '),
        c.r(m * 1.3, c.h * 0.74, c.w - m * 2.6, c.h * 0.12),
        pt: c.smallPt * 0.95,
        color: ivory,
        align: TextAlignH.center,
        name: 'Coordonnées',
        role: 'contacts',
      );
    } else {
      c.text(
        c.profile.name.toUpperCase(),
        c.r(m * 1.5, c.h * 0.1, c.w - m * 3, c.h * 0.05),
        pt: c.smallPt,
        letterSpacing: 2.5,
        color: gold,
        align: TextAlignH.center,
        name: 'Activité',
      );
      c.text(
        k.headline,
        c.r(m * 1.5, c.h * 0.18, c.w - m * 3, c.h * 0.2),
        pt: c.titlePt * 1.1,
        font: 'Liberation Serif',
        color: ivory,
        align: TextAlignH.center,
        valign: TextAlignV.middle,
        role: 'headline',
        name: 'Titre',
        lineHeight: 1.05,
      );
      c.rect(
        c.r(c.w / 2 - c.u * 0.1, c.h * 0.4, c.u * 0.2, 0.4),
        Fill.solid(gold),
        name: 'Filet',
      );
      c.text(
        k.slogan,
        c.r(m * 1.5, c.h * 0.43, c.w - m * 3, c.h * 0.08),
        pt: c.bodyPt * 1.3,
        italic: true,
        font: 'Liberation Serif',
        color: gold,
        align: TextAlignH.center,
        role: 'slogan',
        name: 'Slogan',
      );
      c.photo(
        c.r(c.w * 0.25, c.h * 0.53, c.w * 0.5, c.h * 0.22),
        radius: c.u * 0.02,
      );
      c.text(
        k.callToAction,
        c.r(m * 1.5, c.h * 0.78, c.w - m * 3, c.h * 0.05),
        pt: c.bodyPt * 1.1,
        bold: true,
        color: ivory,
        align: TextAlignH.center,
        role: 'cta',
        name: 'Appel à l’action',
      );
      c.text(
        c.contactLines.take(3).map((l) => l.$2).join('\n'),
        c.r(m * 1.5, c.h * 0.84, c.w - m * 3, c.h * 0.1),
        pt: c.smallPt,
        color: ivory,
        align: TextAlignH.center,
        name: 'Coordonnées',
        role: 'contacts',
        lineHeight: 1.3,
      );
    }
    return Fill.linear(shade(k.dark, 0.02), shade(k.dark, -0.06), angle: 90);
  }

  /// Verso : logo / emblème centré, slogan et QR code.
  static Fill _composeBack(LayoutStyle style, _Ctx c) {
    final k = c.kit;
    final dark =
        style == LayoutStyle.neon ||
        style == LayoutStyle.elegant ||
        style == LayoutStyle.menu ||
        style == LayoutStyle.ticket;
    final bg = dark
        ? Fill.linear(shade(k.dark, -0.02), shade(k.primary, -0.3), angle: 45)
        : Fill.linear(k.primary, shade(k.primary, -0.18), angle: 45);
    final side = c.u * 0.32;
    if (c.landscape) {
      c.logoOrIcon(
        c.r(c.w * 0.12, (c.h - side) / 2, side, side),
        badge: const Color(0x33FFFFFF),
        iconColor: const Color(0xFFFFFFFF),
      );
      c.text(
        c.profile.name,
        c.r(
          c.w * 0.12 + side + c.margin,
          c.h * 0.3,
          c.w * 0.75 - side - c.margin * 2,
          c.h * 0.2,
        ),
        pt: c.titlePt * 0.8,
        font: k.headingFont,
        bold: true,
        color: const Color(0xFFFFFFFF),
        name: 'Nom',
        role: 'headline',
      );
      c.text(
        k.slogan,
        c.r(
          c.w * 0.12 + side + c.margin,
          c.h * 0.52,
          c.w * 0.75 - side - c.margin * 2,
          c.h * 0.2,
        ),
        pt: c.smallPt,
        color: const Color(0xFFFFFFFF),
        name: 'Slogan',
        role: 'slogan',
        italic: true,
      );
    } else {
      c.logoOrIcon(
        c.r((c.w - side) / 2, c.h * 0.28, side, side),
        badge: const Color(0x33FFFFFF),
        iconColor: const Color(0xFFFFFFFF),
      );
      c.text(
        c.profile.name,
        c.r(
          c.margin,
          c.h * 0.28 + side + c.margin,
          c.w - 2 * c.margin,
          c.h * 0.12,
        ),
        pt: c.titlePt * 0.8,
        font: k.headingFont,
        bold: true,
        color: const Color(0xFFFFFFFF),
        align: TextAlignH.center,
        name: 'Nom',
        role: 'headline',
      );
      c.text(
        k.slogan,
        c.r(
          c.margin,
          c.h * 0.28 + side + c.margin + c.h * 0.13,
          c.w - 2 * c.margin,
          c.h * 0.1,
        ),
        pt: c.bodyPt,
        color: const Color(0xFFFFFFFF),
        align: TextAlignH.center,
        italic: true,
        name: 'Slogan',
        role: 'slogan',
      );
    }
    return bg;
  }

  /// Styles proposés hors ligne pour un brief, du plus pertinent au moins.
  static List<LayoutStyle> stylesForBrief(String brief) {
    final b = brief.toLowerCase();
    final ordered = <LayoutStyle>[];
    void add(LayoutStyle s) {
      if (!ordered.contains(s)) ordered.add(s);
    }

    if (b.contains('futur') ||
        b.contains('tech') ||
        b.contains('informati') ||
        b.contains('néon')) {
      add(LayoutStyle.neon);
    }
    if (b.contains('promo') ||
        b.contains('%') ||
        b.contains('solde') ||
        b.contains('réduction')) {
      add(LayoutStyle.banner);
    }
    if (b.contains('jardin') ||
        b.contains('nature') ||
        b.contains('bio') ||
        b.contains('vert')) {
      add(LayoutStyle.nature);
    }
    if (b.contains('luxe') ||
        b.contains('élégan') ||
        b.contains('mariage') ||
        b.contains('premium')) {
      add(LayoutStyle.elegant);
    }
    if (b.contains('menu') || b.contains('restaurant')) add(LayoutStyle.menu);
    if (b.contains('fidélité') || b.contains('bon ') || b.contains('coupon')) {
      add(LayoutStyle.ticket);
    }
    for (final s in [
      LayoutStyle.split,
      LayoutStyle.pop,
      LayoutStyle.editorial,
      LayoutStyle.minimal,
      LayoutStyle.neon,
    ]) {
      add(s);
    }
    return ordered;
  }

  /// Palette déduite des couleurs citées dans un brief.
  static BrandKit kitForBrief(BrandKit base, String brief) {
    final b = brief.toLowerCase();
    Color? primary;
    Color? secondary;
    if (b.contains('bleu')) {
      primary = const Color(0xFF1E6BFF);
      secondary = const Color(0xFF24C9C2);
    } else if (b.contains('vert')) {
      primary = const Color(0xFF2F8F4E);
      secondary = const Color(0xFFA8D672);
    } else if (b.contains('rose')) {
      primary = const Color(0xFFE83E8C);
      secondary = const Color(0xFFFFB3C7);
    } else if (b.contains('rouge')) {
      primary = const Color(0xFFD7263D);
      secondary = const Color(0xFFFFAA45);
    } else if (b.contains('orange')) {
      primary = const Color(0xFFFF7A1A);
      secondary = const Color(0xFFFFD166);
    } else if (b.contains('violet')) {
      primary = const Color(0xFF7545FF);
      secondary = const Color(0xFF24C9C2);
    } else if (b.contains('noir') || b.contains('or ') || b.contains('doré')) {
      primary = const Color(0xFF2B2B2B);
      secondary = const Color(0xFFC9A646);
    }
    if (primary == null) return base;
    return BrandKit(
      headline: base.headline,
      slogan: base.slogan,
      offer: base.offer,
      callToAction: base.callToAction,
      body: base.body,
      services: base.services,
      primary: primary,
      secondary: secondary!,
      accent: base.accent,
      dark: base.dark,
      light: base.light,
      headingFont: base.headingFont,
      bodyFont: base.bodyFont,
      layout: base.layout,
      iconKey: base.iconKey,
      source: base.source,
    );
  }
}
