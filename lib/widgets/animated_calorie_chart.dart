import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AnimatedCalorieChart extends StatefulWidget {
  final List<double> dataPoints;
  final Color lineColor;
  final Color gradientColor;

  const AnimatedCalorieChart({
    super.key,
    required this.dataPoints,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  State<AnimatedCalorieChart> createState() => _AnimatedCalorieChartState();
}

class _AnimatedCalorieChartState extends State<AnimatedCalorieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _SplineChartPainter(
            dataPoints: widget.dataPoints,
            progress: _animation.value,
            lineColor: widget.lineColor,
            gradientColor: widget.gradientColor,
          ),
        );
      },
    );
  }
}

class _SplineChartPainter extends CustomPainter {
  final List<double> dataPoints;
  final double progress;
  final Color lineColor;
  final Color gradientColor;

  _SplineChartPainter({
    required this.dataPoints,
    required this.progress,
    required this.lineColor,
    required this.gradientColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final double width = size.width;
    final double height = size.height;

    // Normalize data
    final double maxVal = dataPoints.reduce((a, b) => a > b ? a : b) * 1.2; 
    final double minVal = dataPoints.reduce((a, b) => a < b ? a : b) * 0.8;
    final double range = maxVal - minVal;

    final path = Path();
    final stepX = width / (dataPoints.length - 1);

    // Initial starting point
    final startY = height - ((dataPoints[0] - minVal) / range) * height;
    path.moveTo(0, startY);

    final List<Offset> points = [];
    points.add(Offset(0, startY));

    for (int i = 1; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = height - ((dataPoints[i] - minVal) / range) * height;
      points.add(Offset(x, y));
    }

    // Draw Smooth Quadratic Bezier Curves
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      
      // Calculate control point for smoothness
      final controlPointX = p0.dx + (p1.dx - p0.dx) / 2;
      final controlPointY = p0.dy;
      final controlPointX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlPointY2 = p1.dy;

      path.cubicTo(
        controlPointX, controlPointY, 
        controlPointX2, controlPointY2, 
        p1.dx * progress, p0.dy + (p1.dy - p0.dy) * progress,
      );
    }

    // Line Style
    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Background Gradient Area
    final fillPath = Path.from(path)
      ..lineTo(width * progress, height)
      ..lineTo(0, height)
      ..close();

    final Rect rect = Offset.zero & size;
    final paintFill = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [gradientColor.withValues(alpha: 0.5), gradientColor.withValues(alpha: 0.0)],
      )
      ..style = PaintingStyle.fill;

    // Draw to Canvas
    if (progress > 0.01) {
      canvas.drawPath(fillPath, paintFill);
      canvas.drawPath(path, paintLine);
    }
    
    // Draw dots
    final paintDotOuter = Paint()..color = lineColor..style = PaintingStyle.fill;
    final paintDotInner = Paint()..color = Colors.white..style = PaintingStyle.fill;

    for (int i = 0; i < points.length; i++) {
      if ((i * stepX) <= (width * progress)) {
        canvas.drawCircle(points[i], 6, paintDotOuter);
        canvas.drawCircle(points[i], 3, paintDotInner);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SplineChartPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.dataPoints != dataPoints;
  }
}
