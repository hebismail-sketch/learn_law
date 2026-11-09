import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeController {
  AppThemeController._();

  static const _isLightPreferenceKey = 'is_light_theme';
  static final ValueNotifier<bool> isLight = ValueNotifier(false);
  static SharedPreferences? _preferences;

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _preferences = preferences;
    isLight.value = preferences.getBool(_isLightPreferenceKey) ?? false;
  }

  static Future<void> toggle() async {
    final preferences = _preferences ?? await SharedPreferences.getInstance();
    final newValue = !isLight.value;
    isLight.value = newValue;
    try {
      final saved = await preferences.setBool(_isLightPreferenceKey, newValue);
      if (!saved) throw StateError('Could not save the selected app theme.');

      _preferences = preferences;
    } catch (error, stackTrace) {
      if (isLight.value == newValue) isLight.value = !newValue;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

Widget rebuildWithAppTheme(WidgetBuilder builder) {
  return ValueListenableBuilder<bool>(
    valueListenable: AppThemeController.isLight,
    builder: (context, _, _) => builder(context),
  );
}

class AppColors {
  AppColors._();

  static const Color darkBackground = Color(0xFF0B101D);
  static const Color darkSurface = Color(0xFF161F36);
  static const Color darkRaisedSurface = Color(0xFF1E293B);
  static const Color lightBackground = Color(0xFFF3F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightRaisedSurface = Color(0xFFEAF1FA);

  static Color get background =>
      AppThemeController.isLight.value ? lightBackground : darkBackground;
  static Color get surface =>
      AppThemeController.isLight.value ? lightSurface : darkSurface;
  static Color get raisedSurface =>
      AppThemeController.isLight.value ? lightRaisedSurface : darkRaisedSurface;
  static Color get textPrimary =>
      AppThemeController.isLight.value ? const Color(0xFF17243A) : Colors.white;
  static Color get textSecondary => AppThemeController.isLight.value
      ? const Color(0xFF475569)
      : const Color(0xFFCBD5E1);
  static Color get textMuted => AppThemeController.isLight.value
      ? const Color(0xFF64748B)
      : const Color(0xFF94A3B8);
  static Color get border => AppThemeController.isLight.value
      ? const Color(0xFFD6E1EF)
      : const Color(0xFF3B4C7A);
  static Color get appBar => background;
  static Color get star => AppThemeController.isLight.value
      ? const Color(0xFF94A3B8)
      : const Color(0xFFCBD5E1);

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0EA5E9),
      brightness: AppThemeController.isLight.value
          ? Brightness.light
          : Brightness.dark,
      surface: surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: appBar,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      bodySmall: TextStyle(color: textMuted),
    ),
  );
}

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppThemeController.isLight,
      builder: (context, isLight, _) => IconButton(
        tooltip: isLight ? 'الوضع الداكن' : 'الوضع الفاتح',
        onPressed: () async {
          try {
            await AppThemeController.toggle();
          } catch (error, stackTrace) {
            debugPrint('Failed to save app theme: $error\n$stackTrace');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'تعذر حفظ إعدادات المظهر. حاول مرة أخرى.',
                    textAlign: TextAlign.right,
                  ),
                ),
              );
            }
          }
        },
        icon: Icon(
          isLight ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
        ),
        color: const Color(0xFF38BDF8),
      ),
    );
  }
}
