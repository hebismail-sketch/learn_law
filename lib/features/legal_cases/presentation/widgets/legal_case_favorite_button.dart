import 'package:flutter/material.dart';

import '../state/legal_case_favorites.dart';

class LegalCaseFavoriteButton extends StatelessWidget {
  const LegalCaseFavoriteButton({
    super.key,
    required this.caseId,
    required this.onPressed,
  });

  final String caseId;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LegalCaseFavorites.instance,
      builder: (context, _) {
        final isFavorite = LegalCaseFavorites.instance.contains(caseId);
        return IconButton(
          tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: onPressed,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite
                ? const Color(0xFFFF5A7D)
                : const Color(0xFF94A3B8),
          ),
        );
      },
    );
  }
}
