import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_law/core/app_backend.dart';
import 'package:learn_law/core/app_theme.dart';
import 'package:learn_law/core/injection_container.dart';
import 'package:learn_law/core/sync/app_database.dart';
import 'package:learn_law/core/sync/connectivity_service.dart';
import 'package:drift/native.dart';
import 'package:learn_law/features/legal_cases/presentation/screens/admin_login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
    sl.registerSingleton(
      AppBackendRegistry(
        productionClient: Supabase.instance.client,
        reviewClient: null,
        connectivity: ConnectivityService(),
        databaseFactory: (_) => AppDatabase.forTesting(NativeDatabase.memory()),
      ),
    );
  });

  setUp(() => AppThemeController.isLight.value = false);
  tearDown(() => AppThemeController.isLight.value = false);
  tearDownAll(() async {
    await sl<AppBackendRegistry>().dispose();
    await sl.unregister<AppBackendRegistry>();
  });

  testWidgets('admin login page updates its background with the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: AppThemeController.isLight,
        builder: (context, _, _) =>
            MaterialApp(theme: AppColors.theme, home: const AdminLoginScreen()),
      ),
    );

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.darkBackground,
    );

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppColors.lightBackground,
    );
  });
}
