import 'package:flutter/material.dart';

import '../models/design_document.dart';
import '../models/fill.dart';
import 'design_canvas.dart';
import 'icon_catalog.dart';
import 'image_cache.dart';
import 'page_renderer.dart';
import 'text_layout.dart';
import 'vector_path.dart';

/// Implémentation de [DesignCanvas] sur le canevas Flutter.
class FlutterDesignCanvas implements DesignCanvas {
  FlutterDesignCanvas(this.canvas);

  final Canvas canvas;

  Color _alpha(Color c, double opacity) =>
      c.withValues(alpha: (c.a * opacity).clamp(0.0, 1.0));

  @override
  void save() => canvas.save();

  @override
  void restore() => canvas.restore();

  @override
  void translate(double dx, double dy) => canvas.translate(dx, dy);

  @override
  void rotate(double degrees) =>
      canvas.rotate(degrees * 3.141592653589793 / 180);

  @override
  void clip(VectorPath path) => canvas.clipPath(path.toFlutterPath());

  @override
  void fill(VectorPath path, Fill fill, Rect box, {double opacity = 1}) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final gradient = fill.toGradient();
    if (gradient == null) {
      paint.color = _alpha(fill.primary, opacity);
    } else {
      paint
        ..shader = gradient.createShader(box)
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0));
    }
    canvas.drawPath(path.toFlutterPath(), paint);
  }

  @override
  void stroke(
    VectorPath path,
    Color color,
    double width, {
    double opacity = 1,
  }) {
    canvas.drawPath(
      path.toFlutterPath(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = _alpha(color, opacity),
    );
  }

  @override
  void fillRects(List<Rect> rects, Color color, {double opacity = 1}) {
    final path = Path();
    for (final r in rects) {
      path.addRect(r);
    }
    canvas.drawPath(path, Paint()..color = _alpha(color, opacity));
  }

  @override
  void image(DesignImage image, Rect dest, {double opacity = 1}) {
    final decoded = image.decoded;
    if (decoded == null) return;
    canvas.drawImageRect(
      decoded,
      Rect.fromLTWH(0, 0, decoded.width.toDouble(), decoded.height.toDouble()),
      dest,
      Paint()
        ..filterQuality = FilterQuality.high
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)),
    );
  }

  @override
  void text(TextLayoutResult layout, Offset origin, {double opacity = 1}) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(1 / TextLayoutEngine.referenceScale);
    layout.painter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  void icon(PictogramDef icon, Rect box, Color color, {double opacity = 1}) {
    final side = box.shortestSide;
    if (side <= 0) return;
    final painter = iconPainter(icon, 100, _alpha(color, opacity));
    canvas.save();
    canvas.translate(box.center.dx - side / 2, box.center.dy - side / 2);
    canvas.scale(side / 100);
    painter.paint(
      canvas,
      Offset((100 - painter.width) / 2, (100 - painter.height) / 2),
    );
    canvas.restore();
    painter.dispose();
  }

  /// Peintre d'un pictogramme à une taille donnée (en pixels logiques).
  static TextPainter iconPainter(PictogramDef icon, double size, Color color) {
    final data = icon.icon;
    return TextPainter(
      text: TextSpan(
        text: String.fromCharCode(data.codePoint),
        style: TextStyle(
          inherit: false,
          fontFamily: data.fontFamily,
          package: data.fontPackage,
          fontSize: size,
          height: 1,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }
}

/// Peint une page entière à une échelle donnée (pixels par mm).
class DesignPagePainter extends CustomPainter {
  DesignPagePainter({
    required this.page,
    required this.pageMm,
    required this.pixelsPerMm,
    this.images,
    this.bleedMm = 0,
    this.showPlaceholders = false,
    this.hiddenElementIds = const {},
  }) : super(repaint: images);

  final DesignPage page;
  final Size pageMm;
  final double pixelsPerMm;
  final DesignImageCache? images;
  final double bleedMm;
  final bool showPlaceholders;
  final Set<String> hiddenElementIds;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(pixelsPerMm);
    PageRenderer.paint(
      FlutterDesignCanvas(canvas),
      page,
      pageMm,
      options: RenderOptions(
        bleedMm: bleedMm,
        showPlaceholders: showPlaceholders,
        hiddenElementIds: hiddenElementIds,
        resolveImage: images == null
            ? null
            : (id) {
                final img = images!.get(id);
                return img == null
                    ? null
                    : DesignImage(
                        id: id,
                        width: img.width,
                        height: img.height,
                        decoded: img,
                      );
              },
      ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(DesignPagePainter old) =>
      old.page != page ||
      old.pageMm != pageMm ||
      old.pixelsPerMm != pixelsPerMm ||
      old.bleedMm != bleedMm ||
      old.showPlaceholders != showPlaceholders ||
      old.hiddenElementIds != hiddenElementIds;
}

/// Aperçu d'une page, à la taille disponible, proportions respectées.
class DesignPageView extends StatelessWidget {
  const DesignPageView({
    super.key,
    required this.document,
    this.pageIndex = 0,
    this.images,
    this.showPlaceholders = true,
    this.borderRadius = 0,
    this.shadow = true,
  });

  final DesignDocument document;
  final int pageIndex;
  final DesignImageCache? images;
  final bool showPlaceholders;
  final double borderRadius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final page = document.pages[pageIndex.clamp(0, document.pages.length - 1)];
    return AspectRatio(
      aspectRatio: document.widthMm / document.heightMm,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / document.widthMm;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: shadow
                  ? const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(
                    constraints.maxWidth,
                    constraints.maxWidth / document.widthMm * document.heightMm,
                  ),
                  painter: DesignPagePainter(
                    page: page,
                    pageMm: document.sizeMm,
                    pixelsPerMm: scale,
                    images: images,
                    showPlaceholders: showPlaceholders,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
