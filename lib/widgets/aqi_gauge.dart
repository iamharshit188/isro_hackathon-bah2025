import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../utils/aqi_utils.dart';

class AqiGauge extends StatefulWidget {
  final num aqi;
  final double size;

  const AqiGauge({super.key, required this.aqi, this.size = 200});

  @override
  AqiGaugeState createState() => AqiGaugeState();
}

class AqiGaugeState extends State<AqiGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();
  }

  @override
  void didUpdateWidget(AqiGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aqi != oldWidget.aqi) {
      _controller.reset();
      _controller.forward();
    }
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
        final aqiDetails = AqiUtils.getAqiDetails("PM2.5", widget.aqi.toDouble());
        final animatedAqi = _animation.value * widget.aqi;
        
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _AqiGaugePainter(
            aqi: animatedAqi,
            color: aqiDetails.color,
          ),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    animatedAqi.toInt().toString(),
                    style: TextStyle(
                      fontSize: widget.size * 0.25,
                      fontWeight: FontWeight.bold,
                      color: aqiDetails.color,
                    ),
                  ),
                  Text(
                    aqiDetails.category,
                    style: TextStyle(
                      fontSize: widget.size * 0.1,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AqiGaugePainter extends CustomPainter {
  final double aqi;
  final Color color;

  _AqiGaugePainter({required this.aqi, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 12.0;
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    // Background arc
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      backgroundPaint,
    );

    // Foreground arc
    final foregroundPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withValues(alpha: 0.5), color],
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final valueAngle = (aqi / 500).clamp(0, 1) * sweepAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      valueAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(_AqiGaugePainter oldDelegate) {
    return oldDelegate.aqi != aqi || oldDelegate.color != color;
  }
} 