import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:venicare_doctor/src/ui/format.dart';
import 'package:venicare_shared/venicare_shared.dart';

/// Systolic/diastolic over time with the 140/90 reference lines. Points are
/// placed by real timestamp so gaps in measurement stay visible.
class PressureChart extends StatelessWidget {
  const PressureChart({super.key, required this.readings});

  final List<VitalReading> readings;

  @override
  Widget build(BuildContext context) {
    final points = readings
        .where((r) => r.systolic != null && r.diastolic != null)
        .toList();
    final scheme = Theme.of(context).colorScheme;
    if (points.length < 2) {
      return SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '血压记录少于 2 次，无法绘制趋势',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            _Legend(color: scheme.primary, label: '收缩压'),
            _Legend(color: scheme.tertiary, label: '舒张压'),
            _Legend(color: scheme.error, label: '参考线 140/90', dashed: true),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: CustomPaint(
            size: Size.infinite,
            painter: _PressurePainter(
              points: points,
              systolicColor: scheme.primary,
              diastolicColor: scheme.tertiary,
              referenceColor: scheme.error,
              gridColor: scheme.outlineVariant,
              labelStyle: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: dashed ? 1 : 3, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _PressurePainter extends CustomPainter {
  _PressurePainter({
    required this.points,
    required this.systolicColor,
    required this.diastolicColor,
    required this.referenceColor,
    required this.gridColor,
    required this.labelStyle,
  });

  final List<VitalReading> points;
  final Color systolicColor;
  final Color diastolicColor;
  final Color referenceColor;
  final Color gridColor;
  final TextStyle labelStyle;

  static const _left = 36.0;
  static const _bottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.expand((r) => [r.systolic!, r.diastolic!]);
    final lo = (math.min(values.reduce(math.min), 70) ~/ 10) * 10.0;
    final hi = ((math.max(values.reduce(math.max), 150) + 9) ~/ 10) * 10.0;
    final start = points.first.measuredAt.millisecondsSinceEpoch.toDouble();
    final end = points.last.measuredAt.millisecondsSinceEpoch.toDouble();
    final plot = Rect.fromLTRB(_left, 4, size.width - 8, size.height - _bottom);

    double x(DateTime at) =>
        plot.left +
        (at.millisecondsSinceEpoch - start) /
            math.max(end - start, 1) *
            plot.width;
    double y(num value) => plot.bottom - (value - lo) / (hi - lo) * plot.height;

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var v = lo; v <= hi; v += 20) {
      canvas.drawLine(Offset(plot.left, y(v)), Offset(plot.right, y(v)), grid);
      _text(canvas, trimNumber(v), Offset(0, y(v) - 7));
    }

    final reference = Paint()
      ..color = referenceColor
      ..strokeWidth = 1;
    for (final line in [
      ReferenceRanges.systolicHigh,
      ReferenceRanges.diastolicHigh,
    ]) {
      for (var dx = plot.left; dx < plot.right; dx += 8) {
        canvas.drawLine(
          Offset(dx, y(line)),
          Offset(math.min(dx + 4, plot.right), y(line)),
          reference,
        );
      }
    }

    _series(
      canvas,
      (r) => r.systolic!,
      ReferenceRanges.systolicHigh,
      systolicColor,
      x,
      y,
    );
    _series(
      canvas,
      (r) => r.diastolic!,
      ReferenceRanges.diastolicHigh,
      diastolicColor,
      x,
      y,
    );

    _text(
      canvas,
      formatDate(points.first.measuredAt),
      Offset(plot.left, plot.bottom + 4),
    );
    final endLabel = formatDate(points.last.measuredAt);
    _text(canvas, endLabel, Offset(plot.right - 64, plot.bottom + 4));
  }

  void _series(
    Canvas canvas,
    int Function(VitalReading) value,
    int highLine,
    Color color,
    double Function(DateTime) x,
    double Function(num) y,
  ) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (final (i, r) in points.indexed) {
      final p = Offset(x(r.measuredAt), y(value(r)));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);
    for (final r in points) {
      final v = value(r);
      final high = v >= highLine;
      canvas.drawCircle(
        Offset(x(r.measuredAt), y(v)),
        high ? 4 : 2.5,
        Paint()..color = high ? referenceColor : color,
      );
    }
  }

  void _text(Canvas canvas, String text, Offset at) {
    (TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, at);
  }

  @override
  bool shouldRepaint(_PressurePainter old) => old.points != points;
}
