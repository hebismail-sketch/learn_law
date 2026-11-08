import 'package:flutter/material.dart';

import '../../domain/entities/legal_case_entity.dart';
import '../state/legal_case_favorites.dart';

class LegalCaseFavoriteButton extends StatelessWidget {
  const LegalCaseFavoriteButton({super.key, required this.legalCase});

  final LegalCaseEntity legalCase;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LegalCaseFavorites.instance,
      builder: (context, _) {
        final isFavorite = LegalCaseFavorites.instance.contains(legalCase.id);
        return IconButton(
          tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
          onPressed: () async {
            try {
              await LegalCaseFavorites.instance.toggle(legalCase);
            } catch (error, stackTrace) {
              debugPrint(
                'Failed to save legal case favorite: $error\n$stackTrace',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تعذر حفظ القضية في المفضلة. حاول مرة أخرى.',
                      textAlign: TextAlign.right,
                    ),
                  ),
                );
              }
            }
          },
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
