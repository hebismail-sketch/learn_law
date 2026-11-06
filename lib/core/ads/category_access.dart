import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import 'ad_mob_service.dart';
import 'category_unlock_store.dart';

typedef RewardedAdLoader =
    Future<RewardedAdResult> Function(bool Function() isStillRequested);

abstract final class CategoryAccess {
  static final _unlockStore = CategoryUnlockStore();

  static bool isAlwaysFree(String categoryName) {
    final normalized = categoryName
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه');
    return normalized.contains('الاحوال الشخصيه');
  }

  static Future<bool> isUnlocked(String categoryId) async {
    try {
      return await _unlockStore.isUnlocked(categoryId);
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Could not read category unlock: $error\n$stackTrace');
      return false;
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('Category unlock storage is unavailable: $error\n$stackTrace');
      return false;
    }
  }

  static Future<bool> requestAccess(
    BuildContext context, {
    required String categoryId,
    required String categoryName,
    RewardedAdLoader? rewardedAdLoader,
  }) async {
    if (isAlwaysFree(categoryName)) return true;
    if (await isUnlocked(categoryId)) return true;
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CategoryUnlockSheet(
        categoryId: categoryId,
        categoryName: categoryName,
        rewardedAdLoader:
            rewardedAdLoader ??
            (isStillRequested) =>
                AdMobService.showCategoryUnlockAd(isStillRequested),
      ),
    );
    return result ?? false;
  }
}

class _CategoryUnlockSheet extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final RewardedAdLoader rewardedAdLoader;

  const _CategoryUnlockSheet({
    required this.categoryId,
    required this.categoryName,
    required this.rewardedAdLoader,
  });

  @override
  State<_CategoryUnlockSheet> createState() => _CategoryUnlockSheetState();
}

class _CategoryUnlockSheetState extends State<_CategoryUnlockSheet> {
  bool _isLoading = false;
  String? _message;

  Future<void> _watchAd() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final result = await widget.rewardedAdLoader(() => mounted && _isLoading);
    if (!mounted) return;

    switch (result) {
      case RewardedAdResult.earned:
        try {
          final saved = await CategoryUnlockStore().unlockForThirtyDays(
            widget.categoryId,
          );
          if (!mounted) return;
          if (saved) {
            Navigator.of(context).pop(true);
            return;
          }
          _showFailure(
            'اكتملت المشاهدة، لكن تعذر حفظ فتح التصنيف. حاول مرة أخرى.',
          );
        } on PlatformException catch (error, stackTrace) {
          debugPrint('Could not save category unlock: $error\n$stackTrace');
          _showFailure('تعذر حفظ فتح التصنيف. حاول مرة أخرى.');
        } on MissingPluginException catch (error, stackTrace) {
          debugPrint(
            'Category unlock storage is unavailable: $error\n$stackTrace',
          );
          if (!mounted) return;
          _showFailure('تعذر حفظ فتح التصنيف. حاول مرة أخرى.');
        }
      case RewardedAdResult.notEarned:
        _showFailure('لم تكتمل المكافأة. شاهد الإعلان حتى يسجل AdMob إكماله.');
      case RewardedAdResult.unavailable:
        _showFailure(
          'تعذر تحميل الإعلان. تأكد من اتصال الإنترنت وحاول مرة أخرى.',
        );
    }
  }

  void _showFailure(String message) {
    setState(() {
      _isLoading = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.lock_open_rounded,
              color: Color(0xFF38BDF8),
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              'فتح ${widget.categoryName}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'شاهد إعلان المكافأة لفتح هذا التصنيف لمدة 30 يومًا. '
              'يمكنك إغلاق النافذة واستخدام التصنيفات المجانية.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFBBF24), height: 1.5),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _watchAd,
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_circle_outline_rounded),
                label: Text(
                  _isLoading
                      ? 'جارٍ تحميل الإعلان...'
                      : 'مشاهدة إعلان وفتح التصنيف 30 يومًا',
                ),
              ),
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('ليس الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
