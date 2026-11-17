import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import '../../app/theme.dart';

/// Line chart; `null` values are gaps (unknown days are never drawn as 0).
class UsageLineChart extends StatelessWidget {
  const UsageLineChart({super.key, required this.values, required this.labels, required this.semanticLabel, this.unit = 'GB', this.height = 260});
  final List<double?> values;
  final List<String> labels;
  final String semanticLabel, unit;
  final double height;
  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel, image: true,
    child: ExcludeSemantics(child: SizedBox(height: height, width: double.infinity, child: CustomPaint(
      painter: _LinePainter(values, labels, unit, DefaultTextStyle.of(context).style.copyWith(fontSize: 11, color: context.palette.muted), context.palette, MediaQuery.textScalerOf(context)),
    ))),
  );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.labels, this.unit, this.textStyle, this.palette, this.textScaler);
  final List<double?> values;
  final List<String> labels;
  final String unit;
  final TextStyle textStyle;
  final PortalPalette palette;
  final TextScaler textScaler;

  TextPainter _text(String text) => TextPainter(text: TextSpan(text: text, style: textStyle), textDirection: TextDirection.ltr, textScaler: textScaler)..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final known = values.whereType<double>();
    final rawMax = known.isEmpty ? 1.0 : known.reduce(math.max);
    final step = _niceStep(rawMax <= 0 ? 1 : rawMax / 4);
    final maxY = step * 4;
    final axisLabels = [for (var i = 0; i <= 4; i++) _text('${_trim(step * i)} $unit')];
    final left = axisLabels.map((t) => t.width).reduce(math.max) + 8;
    final bottom = textScaler.scale(14) + 12;
    const top = 8.0;
    final plot = Rect.fromLTRB(left, top, size.width - 8, size.height - bottom);
    if (plot.width <= 0 || plot.height <= 0) return;
    final grid = Paint()..color = palette.subtle..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.bottom - plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      axisLabels[i].paint(canvas, Offset(left - 8 - axisLabels[i].width, y - axisLabels[i].height / 2));
    }
    if (values.isEmpty) return;
    double x(int i) => values.length == 1 ? plot.center.dx : plot.left + plot.width * i / (values.length - 1);
    double y(double v) => plot.bottom - plot.height * (v / maxY).clamp(0, 1);
    final every = math.max(1, (labels.length / math.max(1, plot.width / 64)).ceil());
    for (var i = 0; i < labels.length && i < values.length; i += every) {
      final label = _text(labels[i]);
      label.paint(canvas, Offset((x(i) - label.width / 2).clamp(0, math.max(0, size.width - label.width)), plot.bottom + 6));
    }
    // Separate segments for consecutive known values; gaps stay empty.
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) { if (current.isNotEmpty) segments.add(current); current = []; continue; }
      current.add(Offset(x(i), y(v)));
    }
    if (current.isNotEmpty) segments.add(current);
    final fill = Paint()..color = palette.chartFill;
    final line = Paint()..color = palette.chartLine..strokeWidth = 2..style = PaintingStyle.stroke..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = PortalColors.primaryHover;
    for (final points in segments) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) { path.lineTo(p.dx, p.dy); }
      final area = Path.from(path)..lineTo(points.last.dx, plot.bottom)..lineTo(points.first.dx, plot.bottom)..close();
      canvas.drawPath(area, fill);
      canvas.drawPath(path, line);
      for (final p in points) { canvas.drawCircle(p, 3, dot); }
    }
  }

  static double _niceStep(double raw) {
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    return (normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10) * magnitude;
  }
  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.values != values || old.labels != labels || old.textStyle != textStyle || old.palette != palette || old.textScaler != textScaler;
}

/// Donut chart for used / remaining / overage.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.values, required this.colors, required this.semanticLabel, this.size = 200, this.thickness = .22, this.center});
  final List<double> values;
  final List<Color> colors;
  final String semanticLabel;
  final double size, thickness;
  final Widget? center;
  @override
  Widget build(BuildContext context) => Semantics(label: semanticLabel, image: true, child: ExcludeSemantics(child: SizedBox.square(
    dimension: size,
    child: Stack(alignment: Alignment.center, children: [
      Positioned.fill(child: CustomPaint(painter: _DonutPainter(values, colors, thickness, context.palette.subtle))),
      ?center,
    ]),
  )));
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.thickness, this.track);
  final List<double> values;
  final List<Color> colors;
  final double thickness;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * thickness;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2);
    final total = values.fold<double>(0, (sum, v) => sum + math.max(0, v));
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = math.max(0, values[i]) / total * math.pi * 2;
      if (sweep > 0) canvas.drawArc(rect, start, sweep, false, Paint()..color = colors[i % colors.length]..style = PaintingStyle.stroke..strokeWidth = stroke);
      start += sweep;
    }
  }
  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.values != values || old.colors != colors || old.track != track;
}
