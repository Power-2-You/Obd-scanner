import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Premium arc gauge. Shows "Unavailable" with a muted track instead of a
/// value when the vehicle does not report the parameter.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    super.key,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    this.value,
    this.decimals = 0,
    this.size = 180,
    this.unavailableText = 'Unavailable',
    this.warnAbove,
    this.majorTicks = 8,
    this.tickLabel,
  });

  final String label;
  final String unit;
  final double min;
  final double max;
  final double? value;
  final int decimals;
  final double size;
  final String unavailableText;
  final double? warnAbove;
  final int majorTicks;
  final String Function(double)? tickLabel;

  @override
  Widget build(BuildContext context) {
    final available = value != null;
    final fraction = available
        ? ((value! - min) / (max - min)).clamp(0.0, 1.0)
        : 0.0;
    final warn = available && warnAbove != null && value! >= warnAbove!;

    return Semantics(
      label:
          '$label ${available ? '${value!.toStringAsFixed(decimals)} $unit' : unavailableText}',
      child: SizedBox(
        width: size,
        height: size * 0.86,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: fraction),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, f, _) => CustomPaint(
            painter: _ArcPainter(
              fraction: f,
              available: available,
              warn: warn,
              majorTicks: majorTicks,
            ),
            child: Padding(
              padding: EdgeInsets.only(top: size * 0.2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (available)
                    Text(
                      value!.toStringAsFixed(decimals),
                      style: TextStyle(
                        fontSize: size * 0.2,
                        fontWeight: FontWeight.w700,
                        color: warn ? BrandColors.caution : BrandColors.white,
                        fontFeatures: AppTheme.tabular,
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    )
                  else
                    Padding(
                      padding: EdgeInsets.only(top: size * 0.05),
                      child: Text(
                        unavailableText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: size * 0.075,
                          fontWeight: FontWeight.w600,
                          color: BrandColors.faint,
                        ),
                      ),
                    ),
                  SizedBox(height: size * 0.025),
                  Text(
                    available ? unit : '',
                    style: TextStyle(
                      fontSize: size * 0.07,
                      color: BrandColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: size * 0.07),
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: size * 0.058,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w800,
                      color: available ? BrandColors.yellow : BrandColors.faint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.fraction,
    required this.available,
    required this.warn,
    required this.majorTicks,
  });

  final double fraction;
  final bool available;
  final bool warn;
  final int majorTicks;

  static const start = math.pi * 0.75;
  static const sweep = math.pi * 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.06;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.width / 2),
      radius: size.width / 2 - stroke,
    );

    // Track.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = BrandColors.surfaceHigh,
    );

    // Ticks.
    final tickPaint = Paint()
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final c = rect.center;
    final rOuter = rect.width / 2 - stroke * 0.95;
    for (var i = 0; i <= majorTicks * 4; i++) {
      final a = start + sweep * i / (majorTicks * 4);
      final major = i % 4 == 0;
      final len = major ? stroke * 0.7 : stroke * 0.35;
      final lit = available && i / (majorTicks * 4) <= fraction;
      tickPaint.color = lit
          ? BrandColors.yellow.withValues(alpha: major ? 0.9 : 0.5)
          : BrandColors.outline.withValues(alpha: major ? 1 : 0.6);
      final p1 = c + Offset(math.cos(a), math.sin(a)) * rOuter;
      final p2 = c + Offset(math.cos(a), math.sin(a)) * (rOuter - len);
      canvas.drawLine(p1, p2, tickPaint);
    }

    if (!available || fraction <= 0) return;

    final color = warn ? BrandColors.caution : BrandColors.yellow;
    // Glow.
    canvas.drawArc(
      rect,
      start,
      sweep * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.6
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Value arc.
    canvas.drawArc(
      rect,
      start,
      sweep * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: warn
              ? [BrandColors.yellow, BrandColors.caution]
              : [
                  BrandColors.yellowDeep,
                  BrandColors.yellow,
                  const Color(0xFFF7E3A8),
                ],
          transform: const GradientRotation(0),
        ).createShader(rect),
    );
    // Tip.
    final tipA = start + sweep * fraction;
    canvas.drawCircle(
      c + Offset(math.cos(tipA), math.sin(tipA)) * (rect.width / 2),
      stroke * 0.42,
      Paint()..color = BrandColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) =>
      old.fraction != fraction ||
      old.available != available ||
      old.warn != warn;
}

/// Compact reading tile with optional sparkline.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.unit,
    this.value,
    this.decimals = 0,
    this.history,
    this.statusText,
    this.accent = BrandColors.yellow,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String unit;
  final double? value;
  final int decimals;
  final Iterable<double>? history;
  final String? statusText;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = value != null;
    return Material(
      color: BrandColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BrandColors.outline, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: available ? accent : BrandColors.faint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: BrandColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (available)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value!.toStringAsFixed(decimals),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: BrandColors.white,
                          fontFeatures: AppTheme.tabular,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        unit,
                        style: const TextStyle(
                          color: BrandColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  statusText ?? 'Unavailable',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BrandColors.faint,
                  ),
                ),
              SizedBox(
                height: 18,
                width: double.infinity,
                child: CustomPaint(
                  painter: _SparkPainter(
                    available && history != null ? history!.toList() : const [],
                    accent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color);
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      canvas.drawLine(
        Offset(0, size.height - 1),
        Offset(size.width, size.height - 1),
        Paint()
          ..color = BrandColors.outline
          ..strokeWidth = 1,
      );
      return;
    }
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if ((hi - lo).abs() < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y =
          size.height - (values[i] - lo) / (hi - lo) * (size.height - 2) - 1;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => true;
}

/// Convenience to get history from a queue.
Iterable<double>? historyOf(Map<int, ListQueue<double>> h, int pid) => h[pid];
