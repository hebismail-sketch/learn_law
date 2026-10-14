import 'package:flutter/material.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;

  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const CustomPaint(painter: _StarsPainter()),
        child,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFCBD5E1);
    for (var index = 0; index < 150; index++) {
      final x = ((index * 67 + 19) % 997) / 997 * size.width;
      final y = ((index * 131 + 47) % 991) / 991 * size.height;
      final radius = 0.35 + (index % 4) * 0.12;
      final opacity = 0.12 + (index % 5) * 0.035;
      paint.color = const Color(0xFFCBD5E1).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    final glowPaint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var index = 0; index < 12; index++) {
      final x = ((index * 223 + 71) % 997) / 997 * size.width;
      final y = ((index * 317 + 113) % 991) / 991 * size.height;
      canvas.drawCircle(Offset(x, y), 1.1, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
