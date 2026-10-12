import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// "MY GARAGE HERO" wordmark with the IQ badge. Text-based placeholder until
/// official logo artwork is supplied.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.size = 1.0});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'MY GARAGE HERO',
          style: TextStyle(
            fontSize: 13 * size,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4 * size,
            color: BrandColors.white,
          ),
        ),
        SizedBox(width: 8 * size),
        IqBadge(size: size),
      ],
    );
  }
}

class IqBadge extends StatelessWidget {
  const IqBadge({super.key, this.size = 1.0});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * size, vertical: 2.5 * size),
      decoration: BoxDecoration(
        gradient: BrandColors.yellowGradient,
        borderRadius: BorderRadius.circular(6 * size),
      ),
      child: Text(
        'IQ',
        style: TextStyle(
          fontSize: 12 * size,
          fontWeight: FontWeight.w900,
          color: BrandColors.charcoal,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Stylised Boost N' Inflate IQ with animated signal rings, used on
/// onboarding and connection screens.
class IqHeroGraphic extends StatefulWidget {
  const IqHeroGraphic({
    super.key,
    this.size = 220,
    this.animate = true,
    this.active = false,
  });
  final double size;
  final bool animate;
  final bool active;

  @override
  State<IqHeroGraphic> createState() => _IqHeroGraphicState();
}

class _IqHeroGraphicState extends State<IqHeroGraphic>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant IqHeroGraphic old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_c.isAnimating) _c.repeat();
    if (!widget.animate && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) =>
            CustomPaint(painter: _HeroPainter(_c.value, widget.active)),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.t, this.active);
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;

    // Signal rings.
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = BrandColors.yellow.withValues(alpha: (1 - p) * 0.45);
      canvas.drawCircle(c, r * (0.42 + p * 0.58), ring);
    }

    // Glow.
    canvas.drawCircle(
      c,
      r * 0.46,
      Paint()
        ..shader = RadialGradient(
          colors: [
            BrandColors.yellow.withValues(alpha: active ? 0.35 : 0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 0.6)),
    );

    // Device body.
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: r * 0.62, height: r * 0.86),
      Radius.circular(r * 0.14),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF34393F), Color(0xFF1B1E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = BrandColors.yellow.withValues(alpha: 0.65),
    );

    // Display window with mini gauge.
    final screen = Rect.fromCenter(
      center: c.translate(0, -r * 0.12),
      width: r * 0.44,
      height: r * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, Radius.circular(r * 0.05)),
      Paint()..color = BrandColors.charcoal,
    );
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = r * 0.025
      ..color = BrandColors.yellow;
    final sweep = math.pi * (0.6 + 0.35 * math.sin(t * math.pi * 2).abs());
    canvas.drawArc(
      Rect.fromCircle(
        center: screen.center.translate(0, r * 0.05),
        radius: r * 0.1,
      ),
      math.pi,
      sweep,
      false,
      arc,
    );

    // Accent strip + buttons.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: c.translate(0, r * 0.16),
          width: r * 0.3,
          height: r * 0.035,
        ),
        Radius.circular(r * 0.02),
      ),
      Paint()..shader = BrandColors.yellowGradient.createShader(body.outerRect),
    );
    for (final dx in [-0.1, 0.0, 0.1]) {
      canvas.drawCircle(
        c.translate(r * dx, r * 0.28),
        r * 0.028,
        Paint()..color = const Color(0xFF41474E),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.t != t || old.active != active;
}
