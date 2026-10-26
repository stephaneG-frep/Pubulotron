import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/units.dart';
import '../../editor/editor_controller.dart';
import '../../engine/flutter_canvas.dart';
import '../../engine/geometry.dart';
import '../../engine/image_cache.dart';
import '../../models/design_element.dart';
import '../theme.dart';

/// Canevas interactif de l'atelier.
class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    super.key,
    required this.controller,
    required this.images,
    this.onEditText,
  });

  final EditorController controller;
  final DesignImageCache images;
  final void Function(DesignElement element)? onEditText;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  static const double _padding = 40;
  final _pageKey = GlobalKey();
  final _hScroll = ScrollController();
  final _vScroll = ScrollController();

  Offset? _dragStart;
  final Map<int, Offset> _pointers = {};
  double? _pinchStartDistance;
  double _pinchStartZoom = 1;

  EditorController get c => widget.controller;

  bool get _pinching => _pinchStartDistance != null;

  @override
  void dispose() {
    _hScroll.dispose();
    _vScroll.dispose();
    super.dispose();
  }

  bool get _shift => HardwareKeyboard.instance.isShiftPressed;

  bool get _noSnap => HardwareKeyboard.instance.isAltPressed;

  Offset _toPageMm(Offset global, double scale) {
    final box = _pageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    return box.globalToLocal(global) / scale;
  }

  // ----------------------------------------------------------- pincement

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _pinchStartDistance = (pts[0] - pts[1]).distance;
      _pinchStartZoom = c.zoom;
      c.endTransaction();
      _dragStart = null;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    if (_pinching && _pointers.length >= 2) {
      final pts = _pointers.values.toList();
      final d = (pts[0] - pts[1]).distance;
      if (_pinchStartDistance! > 10) {
        c.setZoom(_pinchStartZoom * d / _pinchStartDistance!);
      }
    }
  }

  void _onPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) _pinchStartDistance = null;
  }

  void _onSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent &&
        HardwareKeyboard.instance.isControlPressed) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        final dy = (e as PointerScrollEvent).scrollDelta.dy;
        c.setZoom(c.zoom * (dy > 0 ? 0.9 : 1.1));
      });
    }
  }

  // ----------------------------------------------------------- gestes éléments

  void _startMove(DesignElement e, DragStartDetails d) {
    if (_pinching) return;
    if (!c.selection.contains(e.id)) c.select(e.id, additive: _shift);
    _dragStart = d.globalPosition;
    c.beginMove();
  }

  void _updateMove(DragUpdateDetails d, double scale) {
    final start = _dragStart;
    if (start == null || _pinching) return;
    c.dragMove((d.globalPosition - start) / scale, snap: !_noSnap);
  }

  void _endGesture([_]) {
    _dragStart = null;
    c.endTransaction();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([c, widget.images]),
      builder: (context, _) => LayoutBuilder(builder: _buildViewport),
    );
  }

  Widget _buildViewport(BuildContext context, BoxConstraints constraints) {
    final doc = c.document;
    final fit = math
        .min(
          (constraints.maxWidth - 2 * _padding) / doc.widthMm,
          (constraints.maxHeight - 2 * _padding) / doc.heightMm,
        )
        .clamp(0.5, 200.0);
    final scale = fit * c.zoom;
    final pageW = doc.widthMm * scale;
    final pageH = doc.heightMm * scale;
    final contentW = math.max(constraints.maxWidth, pageW + 2 * _padding);
    final contentH = math.max(constraints.maxHeight, pageH + 2 * _padding);
    final left = (contentW - pageW) / 2;
    final top = (contentH - pageH) / 2;
    final scheme = Theme.of(context).colorScheme;

    final content = SizedBox(
      width: contentW,
      height: contentH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.clearSelection,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: pageW,
            height: pageH,
            child: DecoratedBox(
              key: _pageKey,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size(pageW, pageH),
                  painter: DesignPagePainter(
                    page: c.page,
                    pageMm: doc.sizeMm,
                    pixelsPerMm: scale,
                    images: widget.images,
                    showPlaceholders: true,
                  ),
                  foregroundPainter: _OverlayPainter(
                    scale: scale,
                    pageMm: doc.sizeMm,
                    grid: c.showGrid ? c.gridMm : null,
                    guides: c.activeGuides,
                    guideColor: PubColors.rose,
                    gridColor: scheme.primary,
                  ),
                ),
              ),
            ),
          ),
          for (final e in c.page.elements)
            if (e.visible) _hitBox(e, left, top, scale),
          for (final e in c.selectedElements)
            _selectionBox(e, left, top, scale, single: c.selection.length == 1),
        ],
      ),
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      onPointerSignal: _onSignal,
      child: Scrollbar(
        controller: _vScroll,
        child: SingleChildScrollView(
          controller: _vScroll,
          physics: c.zoom > 1.01 ? null : const NeverScrollableScrollPhysics(),
          child: Scrollbar(
            controller: _hScroll,
            notificationPredicate: (n) => n.depth == 0,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              physics: c.zoom > 1.01
                  ? null
                  : const NeverScrollableScrollPhysics(),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  Widget _rotated(
    DesignElement e,
    double left,
    double top,
    double scale, {
    required double pad,
    required Widget child,
  }) {
    return Positioned(
      left: left + e.x * scale - pad,
      top: top + e.y * scale - pad,
      width: e.width * scale + 2 * pad,
      height: e.height * scale + 2 * pad,
      child: Transform.rotate(angle: degToRad(e.rotation), child: child),
    );
  }

  Widget _hitBox(DesignElement e, double left, double top, double scale) {
    return _rotated(
      e,
      left,
      top,
      scale,
      pad: 0,
      child: MouseRegion(
        cursor: e.locked ? SystemMouseCursors.basic : SystemMouseCursors.move,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => c.select(e.id, additive: _shift),
          onDoubleTap: e.type == ElementType.text && !e.locked
              ? () => widget.onEditText?.call(e)
              : null,
          onPanStart: (d) => _startMove(e, d),
          onPanUpdate: (d) => _updateMove(d, scale),
          onPanEnd: _endGesture,
          onPanCancel: _endGesture,
          child: Semantics(
            label: '${e.displayName}${e.locked ? ', verrouillé' : ''}',
            button: true,
            selected: c.selection.contains(e.id),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _selectionBox(
    DesignElement e,
    double left,
    double top,
    double scale, {
    required bool single,
  }) {
    const handle = 12.0;
    const pad = 26.0;
    final color = e.locked ? Colors.grey : PubColors.violet;
    final showHandles = single && !e.locked;
    return _rotated(
      e,
      left,
      top,
      scale,
      pad: pad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: pad,
            top: pad,
            right: pad,
            bottom: pad,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
            ),
          ),
          if (e.locked)
            Positioned(
              right: pad - 10,
              top: pad - 10,
              child: const IgnorePointer(
                child: CircleAvatar(
                  radius: 10,
                  child: Icon(Icons.lock, size: 12),
                ),
              ),
            ),
          if (showHandles) ...[
            for (final h in ResizeHandle.values)
              if (h.isCorner ||
                  (e.width * scale > 40 && h.hx != 0) ||
                  (e.height * scale > 40 && h.vy != 0))
                Positioned(
                  left: pad + (h.hx + 1) / 2 * e.width * scale - handle / 2,
                  top: pad + (h.vy + 1) / 2 * e.height * scale - handle / 2,
                  width: handle,
                  height: handle,
                  child: MouseRegion(
                    cursor: _cursorFor(h, e.rotation),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) {
                        _dragStart = d.globalPosition;
                        c.beginResize(e.id);
                      },
                      onPanUpdate: (d) {
                        final start = _dragStart;
                        if (start == null || _pinching) return;
                        c.dragResize(
                          h,
                          (d.globalPosition - start) / scale,
                          keepAspect: _shift,
                        );
                      },
                      onPanEnd: _endGesture,
                      onPanCancel: _endGesture,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: PubColors.violet, width: 2),
                          borderRadius: BorderRadius.circular(
                            h.isCorner ? 3 : 6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            Positioned(
              left: pad + e.width * scale / 2 - 11,
              top: 0,
              width: 22,
              height: 22,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => c.beginRotate(e.id),
                  onPanUpdate: (d) => c.dragRotate(
                    _toPageMm(d.globalPosition, scale),
                    snap: !_noSnap,
                  ),
                  onPanEnd: _endGesture,
                  onPanCancel: _endGesture,
                  child: Tooltip(
                    message: 'Rotation (Alt : sans aimantation)',
                    child: Container(
                      decoration: const BoxDecoration(
                        color: PubColors.violet,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.rotate_right,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  MouseCursor _cursorFor(ResizeHandle h, double rotation) {
    final angle =
        (math.atan2(h.vy.toDouble(), h.hx.toDouble()) * 180 / math.pi +
            rotation) %
        180;
    final a = (angle + 180) % 180;
    if (a < 22.5 || a >= 157.5) return SystemMouseCursors.resizeLeftRight;
    if (a < 67.5) return SystemMouseCursors.resizeUpLeftDownRight;
    if (a < 112.5) return SystemMouseCursors.resizeUpDown;
    return SystemMouseCursors.resizeUpRightDownLeft;
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({
    required this.scale,
    required this.pageMm,
    required this.grid,
    required this.guides,
    required this.guideColor,
    required this.gridColor,
  });

  final double scale;
  final Size pageMm;
  final double? grid;
  final List<SnapGuide> guides;
  final Color guideColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final g = grid;
    if (g != null && g * scale >= 4) {
      final paint = Paint()
        ..color = gridColor.withValues(alpha: 0.18)
        ..strokeWidth = 1;
      for (var x = g; x < pageMm.width; x += g) {
        canvas.drawLine(
          Offset(x * scale, 0),
          Offset(x * scale, size.height),
          paint,
        );
      }
      for (var y = g; y < pageMm.height; y += g) {
        canvas.drawLine(
          Offset(0, y * scale),
          Offset(size.width, y * scale),
          paint,
        );
      }
      // Marge de sécurité de 3 mm pour l'impression.
      final safe = Rect.fromLTWH(
        3 * scale,
        3 * scale,
        size.width - 6 * scale,
        size.height - 6 * scale,
      );
      final dash = Paint()
        ..color = guideColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      _dashedRect(canvas, safe, dash);
    }
    final guidePaint = Paint()
      ..color = guideColor
      ..strokeWidth = 1.2;
    for (final guide in guides) {
      if (guide.vertical) {
        canvas.drawLine(
          Offset(guide.position * scale, -20),
          Offset(guide.position * scale, size.height + 20),
          guidePaint,
        );
      } else {
        canvas.drawLine(
          Offset(-20, guide.position * scale),
          Offset(size.width + 20, guide.position * scale),
          guidePaint,
        );
      }
    }
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) {
    const dash = 6.0;
    void line(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      for (var d = 0.0; d < total; d += dash * 2) {
        canvas.drawLine(
          a + dir * d,
          a + dir * math.min(d + dash, total),
          paint,
        );
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.scale != scale ||
      old.grid != grid ||
      old.guides != guides ||
      old.pageMm != pageMm;
}
