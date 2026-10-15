import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

class StarryBackground extends StatelessWidget {
  final Widget child;

  const StarryBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: AppThemeController.isLight,
          builder: (context, isLight, _) => ColoredBox(
            color: AppColors.background,
            child: CustomPaint(painter: _StarsPainter(isLight)),
          ),
        ),
        child,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  final bool isLight;

  const _StarsPainter(this.isLight);

  @override
  void paint(Canvas canvas, Size size) {
    final starColor = isLight
        ? const Color(0xFF7C91AC)
        : const Color(0xFFCBD5E1);
    final paint = Paint()..color = starColor;
    for (var index = 0; index < 150; index++) {
      final x = ((index * 67 + 19) % 997) / 997 * size.width;
      final y = ((index * 131 + 47) % 991) / 991 * size.height;
      final radius = 0.35 + (index % 4) * 0.12;
      final opacity = 0.12 + (index % 5) * 0.035;
      paint.color = starColor.withValues(alpha: opacity * (isLight ? 0.42 : 1));
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    final glowPaint = Paint()
      ..color = starColor.withValues(alpha: isLight ? 0.13 : 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var index = 0; index < 12; index++) {
      final x = ((index * 223 + 71) % 997) / 997 * size.width;
      final y = ((index * 317 + 113) % 991) / 991 * size.height;
      canvas.drawCircle(Offset(x, y), 1.1, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarsPainter oldDelegate) =>
      oldDelegate.isLight != isLight;
}
