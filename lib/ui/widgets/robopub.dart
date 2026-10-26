import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// RoboPub, la mascotte : un petit robot publicitaire loufoque muni d'un
/// mégaphone, qui cligne des yeux et dont l'antenne clignote.
class RoboPub extends StatefulWidget {
  const RoboPub({super.key, this.size = 140, this.mood = RoboMood.happy});

  final double size;
  final RoboMood mood;

  @override
  State<RoboPub> createState() => _RoboPubState();
}

enum RoboMood { happy, thinking, worried }

class _RoboPubState extends State<RoboPub> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0.3;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'RoboPub, la mascotte de Pubulotron',
      image: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: _RoboPainter(_controller.value, widget.mood),
          ),
        ),
      ),
    );
  }
}

class _RoboPainter extends CustomPainter {
  _RoboPainter(this.t, this.mood);

  final double t;
  final RoboMood mood;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s);
    final bob = math.sin(t * math.pi * 2) * 2;
    canvas.translate(0, bob);

    // Ombre
    canvas.drawOval(
      Rect.fromCenter(center: Offset(50, 95 - bob), width: 46 - bob, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    // Antenne
    final antenna = Paint()
      ..color = PubColors.night
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 22), const Offset(50, 10), antenna);
    final blink = (math.sin(t * math.pi * 8) + 1) / 2;
    canvas.drawCircle(
      const Offset(50, 8),
      5 + blink,
      Paint()..color = Color.lerp(PubColors.orange, PubColors.rose, blink)!,
    );
    canvas.drawCircle(
      const Offset(48.5, 6.5),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    // Corps
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(30, 58, 40, 30),
      const Radius.circular(10),
    );
    canvas.drawRRect(
      body,
      Paint()..shader = PubColors.coolGradient.createShader(body.outerRect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(40, 66, 20, 12),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    // Petit écran du ventre : un « % » de promo
    final tp = TextPainter(
      text: const TextSpan(
        text: '%',
        style: TextStyle(
          color: PubColors.rose,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          fontFamily: 'Ubuntu',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(50 - tp.width / 2, 72 - tp.height / 2));
    tp.dispose();

    // Bras + mégaphone
    final wave = math.sin(t * math.pi * 4) * 6;
    final arm = Paint()
      ..color = PubColors.night
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(31, 66), Offset(18, 58 + wave), arm);
    canvas.drawLine(const Offset(69, 66), const Offset(80, 60), arm);
    final horn = Path()
      ..moveTo(78, 58)
      ..lineTo(94, 48)
      ..lineTo(94, 72)
      ..lineTo(78, 64)
      ..close();
    canvas.drawPath(horn, Paint()..color = PubColors.orange);
    canvas.drawPath(
      horn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = PubColors.night,
    );
    canvas.drawCircle(
      Offset(18, 58 + wave),
      4,
      Paint()..color = PubColors.rose,
    );

    // Tête
    final head = RRect.fromRectAndRadius(
      const Rect.fromLTWH(24, 20, 52, 40),
      const Radius.circular(16),
    );
    canvas.drawRRect(head, Paint()..color = PubColors.violet);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 27, 40, 26),
        const Radius.circular(11),
      ),
      Paint()..color = PubColors.night,
    );
    // Oreilles-boulons
    for (final x in [21.0, 79.0]) {
      canvas.drawCircle(Offset(x, 40), 4, Paint()..color = PubColors.turquoise);
    }

    // Yeux (clignement)
    final eyeOpen = (t % 0.5) > 0.47 ? 0.15 : 1.0;
    final eyePaint = Paint()..color = PubColors.turquoise;
    for (final x in [41.0, 59.0]) {
      final rect = Rect.fromCenter(
        center: Offset(x, 38),
        width: 9,
        height: 9 * eyeOpen,
      );
      canvas.drawOval(rect, eyePaint);
      if (eyeOpen > 0.5) {
        canvas.drawCircle(
          Offset(x + 1.5, 36.5),
          1.5,
          Paint()..color = Colors.white,
        );
      }
    }

    // Bouche
    final mouth = Paint()
      ..color = PubColors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    switch (mood) {
      case RoboMood.happy:
        canvas.drawArc(
          const Rect.fromLTWH(43, 40, 14, 9),
          0.2,
          math.pi - 0.4,
          false,
          mouth,
        );
      case RoboMood.thinking:
        canvas.drawLine(const Offset(45, 47), const Offset(55, 46), mouth);
      case RoboMood.worried:
        canvas.drawArc(
          const Rect.fromLTWH(43, 45, 14, 8),
          math.pi + 0.3,
          math.pi - 0.6,
          false,
          mouth,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoboPainter old) => old.t != t || old.mood != mood;
}
