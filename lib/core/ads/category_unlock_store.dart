import 'package:shared_preferences/shared_preferences.dart';

class CategoryUnlockStore {
  static const accessDuration = Duration(days: 30);

  CategoryUnlockStore({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  Future<bool> isUnlocked(String categoryId) async {
    final preferences = await SharedPreferences.getInstance();
    final expiry = preferences.getInt(_key(categoryId));
    return expiry != null &&
        DateTime.fromMillisecondsSinceEpoch(expiry).isAfter(_clock());
  }

  Future<bool> unlockForThirtyDays(String categoryId) async {
    final preferences = await SharedPreferences.getInstance();
    final expiry = _clock().add(accessDuration).millisecondsSinceEpoch;
    return preferences.setInt(_key(categoryId), expiry);
  }

  String _key(String categoryId) => 'category_unlock_until_$categoryId';
}
