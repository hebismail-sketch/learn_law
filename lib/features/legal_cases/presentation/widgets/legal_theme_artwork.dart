import 'package:flutter/material.dart';

import '../../../../core/app_theme.dart';

class LegalThemeArtwork extends StatelessWidget {
  const LegalThemeArtwork({super.key, required this.child});

  static const lightFilter = ColorFilter.mode(
    Color(0x99EAF1FC),
    BlendMode.screen,
  );

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isLight,
      builder: (context, isLight, _) =>
          isLight ? ColorFiltered(colorFilter: lightFilter, child: child) : child,
    );
  }
}
