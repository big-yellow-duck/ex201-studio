import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/audio_math.dart';
import 'theme.dart';

class FrequencyChart extends StatelessWidget {
  final List<EqBand> bands;
  final double preamp, range;
  final int selected;
  final bool showHandles, compact;
  final void Function(int, double, double)? onDrag;
  const FrequencyChart({
    super.key,
    required this.bands,
    this.preamp = 0,
    this.range = 24,
    this.selected = 1,
    this.showHandles = true,
    this.compact = false,
    this.onDrag,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final height = compact ? 100.0 : (c.maxWidth < 500 ? 230.0 : 285.0),
          size = Size(c.maxWidth, height);
      int? nearest(Offset p) {
        final plot = plotRect(size, compact);
        int? result;
        double distance = 28;
        for (final b in bands.where((b) => b.enabled && b.valid)) {
          final pos = Offset(
            plot.left +
                math.log(b.frequency.clamp(20, 20000) / 20) /
                    math.ln10 /
                    3 *
                    plot.width,
            plot.center.dy - b.response(b.frequency) / range * plot.height / 2,
          );
          final d = (p - pos).distance;
          if (d < distance) {
            distance = d;
            result = b.band;
          }
        }
        return result;
      }

      return Semantics(
        label:
            'Calculated frequency response. Frequency from 20 Hz to 20 kHz, gain from minus $range to plus $range dB.',
        child: GestureDetector(
          onPanStart: onDrag == null
              ? null
              : (d) {
                  _dragBand = nearest(d.localPosition) ?? selected;
                },
          onPanUpdate: onDrag == null
              ? null
              : (d) {
                  final plot = plotRect(size, compact), p = d.localPosition;
                  final f =
                      20 *
                      math.pow(
                        1000,
                        ((p.dx - plot.left) / plot.width).clamp(0, 1),
                      );
                  final gain =
                      ((plot.center.dy - p.dy) / plot.height * 2 * range).clamp(
                        -36.0,
                        36.0,
                      );
                  onDrag!(_dragBand ?? selected, f.toDouble(), gain);
                },
          child: CustomPaint(
            size: size,
            painter: _FrequencyPainter(
              bands,
              preamp,
              range,
              selected,
              showHandles,
              compact,
            ),
          ),
        ),
      );
    },
  );
  static int? _dragBand;
}

Rect plotRect(Size size, bool compact) => Rect.fromLTRB(
  compact ? 4 : 42,
  compact ? 8 : 25,
  size.width - (compact ? 4 : 18),
  size.height - (compact ? 8 : 40),
);
void chartText(
  Canvas canvas,
  String text,
  Offset position, {
  Color color = StudioColors.muted,
  double size = 10,
  TextAlign align = TextAlign.left,
}) {
  final p = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: 'Manrope', fontSize: size, color: color),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  p.paint(
    canvas,
    position -
        Offset(
          align == TextAlign.center
              ? p.width / 2
              : align == TextAlign.right
              ? p.width
              : 0,
          0,
        ),
  );
}

class _FrequencyPainter extends CustomPainter {
  final List<EqBand> bands;
  final double preamp, range;
  final int selected;
  final bool handles, compact;
  _FrequencyPainter(
    this.bands,
    this.preamp,
    this.range,
    this.selected,
    this.handles,
    this.compact,
  );
  @override
  void paint(Canvas canvas, Size size) {
    final plot = plotRect(size, compact),
        grid = Paint()
          ..color = StudioColors.line
          ..strokeWidth = .7;
    double x(double f) =>
        plot.left + math.log(f / 20) / math.ln10 / 3 * plot.width;
    double y(double g) =>
        plot.center.dy - g.clamp(-range, range) / range * plot.height / 2;
    if (!compact) {
      // Very subtle frequency regions give the logarithmic axis a visual anchor.
      canvas.drawRect(
        Rect.fromLTRB(x(20), plot.top, x(250), plot.bottom),
        Paint()..color = StudioColors.pale.withValues(alpha: .4),
      );
      for (final f in [20.0, 100.0, 1000.0, 10000.0, 20000.0]) {
        canvas.drawLine(
          Offset(x(f), plot.top),
          Offset(x(f), plot.bottom),
          grid,
        );
        chartText(
          canvas,
          f >= 1000 ? '${(f / 1000).round()}k' : '${f.round()}',
          Offset(x(f), plot.bottom + 11),
          align: TextAlign.center,
        );
      }
      for (final g in [-range, -range / 2, 0.0, range / 2, range]) {
        canvas.drawLine(
          Offset(plot.left, y(g)),
          Offset(plot.right, y(g)),
          Paint()
            ..color = g == 0 ? const Color(0xffa9b9a0) : StudioColors.line
            ..strokeWidth = g == 0 ? 1 : .7,
        );
        chartText(
          canvas,
          '${g > 0 ? '+' : ''}${g.round()}',
          Offset(plot.left - 9, y(g) - 7),
          align: TextAlign.right,
        );
      }
      chartText(canvas, 'LEVEL · dB', Offset(plot.left, 3), size: 8);
      chartText(
        canvas,
        'FREQUENCY · Hz',
        Offset(plot.right, plot.bottom + 28),
        size: 8,
        align: TextAlign.right,
      );
    } else {
      canvas.drawLine(Offset(plot.left, y(0)), Offset(plot.right, y(0)), grid);
    }
    Path curve(double Function(double) response) {
      final path = Path();
      for (var i = 0; i <= 360; i++) {
        final f = 20 * math.pow(1000, i / 360),
            p = Offset(x(f.toDouble()), y(response(f.toDouble())));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      return path;
    }

    canvas.save();
    canvas.clipRect(plot.inflate(1));
    for (final b in bands.where((b) => b.enabled && b.valid)) {
      canvas.drawPath(
        curve(b.response),
        Paint()
          ..color =
              (b.band == selected ? StudioColors.ochre : StudioColors.green)
                  .withValues(alpha: b.band == selected ? .65 : .15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = b.band == selected ? 1.7 : 1,
      );
    }
    final path = curve((f) => combinedDb(bands, preamp, f));
    final fill = Path.from(path)
      ..lineTo(plot.right, y(0))
      ..lineTo(plot.left, y(0))
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = StudioColors.green.withValues(alpha: .075),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = StudioColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = compact ? 2 : 2.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    if (handles && !compact) {
      for (final b in bands.where((b) => b.enabled && b.valid)) {
        final p = Offset(
          x(b.frequency.clamp(20, 20000)),
          y(b.response(b.frequency)),
        );
        canvas.drawCircle(
          p,
          b.band == selected ? 11 : 8,
          Paint()
            ..color = b.band == selected ? StudioColors.green : Colors.white,
        );
        canvas.drawCircle(
          p,
          b.band == selected ? 11 : 8,
          Paint()
            ..color = StudioColors.green
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3,
        );
        chartText(
          canvas,
          '${b.band}',
          p - Offset(0, b.band == selected ? 7 : 6),
          size: b.band == selected ? 10 : 8,
          align: TextAlign.center,
          color: b.band == selected ? Colors.white : StudioColors.green,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FrequencyPainter old) => true;
}

class DynamicsChart extends StatelessWidget {
  final double threshold, ratio;
  final bool expansion;
  const DynamicsChart({
    super.key,
    required this.threshold,
    required this.ratio,
    this.expansion = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Ideal ${expansion ? 'expander' : 'compressor'} curve, threshold $threshold dB, ratio $ratio to one.',
    child: SizedBox(
      height: 240,
      width: double.infinity,
      child: CustomPaint(
        painter: _DynamicsPainter(threshold, ratio, expansion),
      ),
    ),
  );
}

class _DynamicsPainter extends CustomPainter {
  final double threshold, ratio;
  final bool expansion;
  _DynamicsPainter(this.threshold, this.ratio, this.expansion);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTRB(40, 22, s.width - 16, s.height - 35);
    double x(double v) => r.left + (v + 90) / 90 * r.width;
    double y(double v) => r.bottom - (v.clamp(-90, 0) + 90) / 90 * r.height;
    for (final v in [-90.0, -60.0, -30.0, 0.0]) {
      c.drawLine(
        Offset(x(v), r.top),
        Offset(x(v), r.bottom),
        Paint()..color = StudioColors.line,
      );
      c.drawLine(
        Offset(r.left, y(v)),
        Offset(r.right, y(v)),
        Paint()..color = StudioColors.line,
      );
      chartText(
        c,
        '${v.round()}',
        Offset(x(v), r.bottom + 9),
        align: TextAlign.center,
      );
      chartText(
        c,
        '${v.round()}',
        Offset(r.left - 8, y(v) - 7),
        align: TextAlign.right,
      );
    }
    c.drawLine(
      Offset(x(-90), y(-90)),
      Offset(x(0), y(0)),
      Paint()
        ..color = const Color(0xffb6c6aa)
        ..strokeWidth = 1.3,
    );
    c.drawLine(
      Offset(x(threshold), r.top),
      Offset(x(threshold), r.bottom),
      Paint()
        ..color = StudioColors.ochre.withValues(alpha: .6)
        ..strokeWidth = 1,
    );
    final path = Path();
    for (var i = 0; i <= 180; i++) {
      final input = -90.0 + i / 2,
          output = expansion
              ? expandDb(input, threshold, ratio)
              : compressDb(input, threshold, ratio);
      if (i == 0) {
        path.moveTo(x(input), y(output));
      } else {
        path.lineTo(x(input), y(output));
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = StudioColors.green
        ..strokeWidth = 2.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    chartText(c, 'OUTPUT · dB', Offset(r.left, 0), size: 8);
    chartText(
      c,
      'INPUT · dB',
      Offset(r.right, s.height - 10),
      size: 8,
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class TimingChart extends StatelessWidget {
  final double attack, release;
  const TimingChart({super.key, required this.attack, required this.release});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 200,
    width: double.infinity,
    child: CustomPaint(painter: _TimingPainter(attack, release)),
  );
}

class _TimingPainter extends CustomPainter {
  final double attack, release;
  _TimingPainter(this.attack, this.release);
  @override
  void paint(Canvas c, Size s) {
    final r = Rect.fromLTRB(25, 25, s.width - 15, s.height - 32),
        hold = math.max(20.0, attack * 2),
        end = hold + math.max(20.0, release * 3),
        start = hold * .15;
    double x(double v) => r.left + v / end * r.width;
    double y(double v) => r.bottom - v / 12 * r.height;
    c.drawLine(
      Offset(r.left, r.bottom),
      Offset(r.right, r.bottom),
      Paint()..color = StudioColors.line,
    );
    final reference = Path()
      ..moveTo(x(0), y(0))
      ..lineTo(x(start), y(0))
      ..lineTo(x(start), y(9))
      ..lineTo(x(hold), y(9))
      ..lineTo(x(hold), y(0))
      ..lineTo(x(end), y(0));
    c.drawPath(
      reference,
      Paint()
        ..color = StudioColors.line
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
    final path = Path();
    double reduction = 0;
    for (var i = 0; i <= 250; i++) {
      final t = i * end / 250,
          target = t >= start && t < hold ? 9.0 : 0.0,
          tau = target > reduction ? attack : release;
      reduction = tau == 0
          ? target
          : target +
                (reduction - target) *
                    math.exp(-end / 250 / math.max(.001, tau));
      if (i == 0) {
        path.moveTo(x(t), y(reduction));
      } else {
        path.lineTo(x(t), y(reduction));
      }
    }
    c.drawPath(
      path,
      Paint()
        ..color = StudioColors.green
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    chartText(c, 'ILLUSTRATIVE GAIN REDUCTION', Offset(r.left, 0), size: 8);
    for (final t in [0.0, end / 2, end.toDouble()]) {
      chartText(
        c,
        '${t.round()} ms',
        Offset(x(t), r.bottom + 9),
        align: t == 0
            ? TextAlign.left
            : t == end
            ? TextAlign.right
            : TextAlign.center,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
