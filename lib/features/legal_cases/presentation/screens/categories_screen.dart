import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/app_theme.dart';
import '../../../../core/injection_container.dart';
import '../../../../core/sync/sync_refresh_listener.dart';
import '../bloc/legal_cubit.dart';
import '../bloc/legal_state.dart';
import '../../domain/entities/category_entity.dart';
import 'admin_hub_screen.dart';
import 'admin_login_screen.dart';
import 'global_search_screen.dart';
import 'subcategories_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _secretTapCount = 0;
  int _selectedTab = 0;
  Timer? _secretTapTimer;
  final Set<String> _favoriteCategoryIds = {};

  @override
  void initState() {
    super.initState();
    context.read<LegalCubit>().fetchCategories();
  }

  @override
  void dispose() {
    _secretTapTimer?.cancel();
    super.dispose();
  }

  void _handleSecretTap() {
    _secretTapTimer?.cancel();
    _secretTapCount++;
    _secretTapTimer = Timer(const Duration(seconds: 2), () {
      _secretTapCount = 0;
    });

    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _secretTapTimer?.cancel();
      _openAdminGate();
    }
  }

  Future<void> _openAdminGate() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    final isAuthorizedAdmin =
        currentUser?.email?.toLowerCase() == 'heba@gmail.com';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isAuthorizedAdmin
            ? const AdminHubScreen()
            : const AdminLoginScreen(),
      ),
    );

    if (mounted) context.read<LegalCubit>().fetchCategories();
  }

  void _toggleFavorite(CategoryEntity category) {
    final wasFavorite = _favoriteCategoryIds.contains(category.id);
    setState(() {
      if (wasFavorite) {
        _favoriteCategoryIds.remove(category.id);
      } else {
        _favoriteCategoryIds.add(category.id);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasFavorite
              ? 'تمت إزالة ${category.name} من المفضلة'
              : 'تمت إضافة ${category.name} إلى المفضلة',
          textAlign: TextAlign.right,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openCategory(CategoryEntity category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => sl<LegalCubit>()..fetchSubcategories(category.id),
          child: SubcategoriesScreen(category: category),
        ),
      ),
    );
  }

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return rebuildWithAppTheme(
      (context) => Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _HomeHeader(
                onTitleTap: _handleSecretTap,
                onThemeTap: AppThemeController.toggle,
              ),
              _SearchBar(onTap: _openSearch),
              Expanded(
                child: SyncRefreshListener(
                  onSyncComplete: () =>
                      context.read<LegalCubit>().refreshCategories(),
                  child: BlocBuilder<LegalCubit, LegalState>(
                    builder: (context, state) {
                      if (state is LegalLoading || state is LegalInitial) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF38BDF8),
                          ),
                        );
                      }
                      if (state is LegalError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              state.message,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        );
                      }
                      if (state is CategoriesLoaded) {
                        return _buildContent(state.categories);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              _BottomNavigationBar(
                selectedIndex: _selectedTab,
                onSelected: (index) => setState(() => _selectedTab = index),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<CategoryEntity> categories) {
    final visibleCategories = _selectedTab == 0
        ? categories
        : categories
              .where((category) => _favoriteCategoryIds.contains(category.id))
              .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 420 ? 12.0 : 20.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_selectedTab == 0) ...[
                    const _WelcomeBanner(),
                    const SizedBox(height: 18),
                  ],
                  if (visibleCategories.isEmpty)
                    _EmptyCategories(isFavorites: _selectedTab == 1)
                  else
                    for (
                      var index = 0;
                      index < visibleCategories.length;
                      index++
                    ) ...[
                      _CategoryCard(
                        key: ValueKey(
                          'home-category-${visibleCategories[index].id}',
                        ),
                        category: visibleCategories[index],
                        index: categories.indexOf(visibleCategories[index]),
                        isFavorite: _favoriteCategoryIds.contains(
                          visibleCategories[index].id,
                        ),
                        onTap: () => _openCategory(visibleCategories[index]),
                        onLongPress: () =>
                            _toggleFavorite(visibleCategories[index]),
                      ),
                      if (index != visibleCategories.length - 1)
                        const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onTitleTap, required this.onThemeTap});

  final VoidCallback onTitleTap;
  final VoidCallback onThemeTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showTagline = constraints.maxWidth >= 400;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.65),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33111D33),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/mizan.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTitleTap,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دليل المحاماة',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'التصنيفات الرئيسية',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showTagline)
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 150),
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Color(0xFFE9B96E), width: 2),
                      ),
                    ),
                    child: Text(
                      'معك في كل خطوة\nمن رحلتك القانونية',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  tooltip: AppThemeController.isLight.value
                      ? 'الوضع الداكن'
                      : 'الوضع الفاتح',
                  padding: EdgeInsets.zero,
                  onPressed: onThemeTap,
                  icon: Icon(
                    AppThemeController.isLight.value
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    size: 19,
                    color: isLight
                        ? AppColors.textSecondary
                        : const Color(0xFF9FB2D0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.6),
                ),
              ),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(32),
                child: SizedBox(
                  height: 62,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isLight
                                ? AppColors.raisedSurface
                                : const Color(0xFF20365A),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: isLight
                                ? AppColors.textSecondary
                                : const Color(0xFFB8C8E0),
                            size: 21,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            'ابحث عن أي قضية في التطبيق...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.search_rounded,
                          color: isLight
                              ? AppColors.textSecondary
                              : const Color(0xFFDAE6F8),
                          size: 25,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    return Container(
      key: const ValueKey('welcome-banner'),
      height: 186,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF34518A).withValues(alpha: isLight ? 0.3 : 0.7),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [Color(0xFFEAF1FC), Color(0xFFDCE7F7), Color(0xFFE9EEF7)]
              : const [Color(0xFF172D5E), Color(0xFF111D3A), Color(0xFF0D1930)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4013264B),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: RepaintBoundary(
        key: const ValueKey('welcome-banner-capture'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Solid panel base so the diagonal seam reads against a real colour.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: isLight
                      ? const [
                          Color(0xFFEAF1FC),
                          Color(0xFFDCE7F7),
                          Color(0xFFE4ECF8),
                        ]
                      : const [
                          Color(0xFF16284C),
                          Color(0xFF111D3A),
                          Color(0xFF13223F),
                        ],
                ),
              ),
            ),
            // Photo sits on the right, behind everything, cut by a diagonal edge.
            const _BannerArtwork(),
            // Decorative glows sit under the text column only (left side), so
            // they never wash over the photo like they did before.
            Positioned(
              left: -48,
              bottom: -68,
              child: Transform.rotate(
                angle: -0.45,
                child: Container(
                  width: 190,
                  height: 150,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6754D8).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(54),
                  ),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -30,
              child: Transform.rotate(
                angle: 0.35,
                child: Container(
                  width: 130,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C6BE8).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(46),
                  ),
                ),
              ),
            ),
            Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  flex: 12,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      10,
                      10,
                      10,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'ابدأ رحلتك في عالم',
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF17243A)
                                : Colors.white,
                            fontSize: 19,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'المحاماة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Color(0xFFE9B96E),
                            fontSize: 27,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'استكشف جميع التصنيفات القانونية\nبسهولة وتنظيم.',
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          style: TextStyle(
                            color: isLight
                                ? const Color(0xFF475569)
                                : const Color(
                                    0xFFBDCCE2,
                                  ).withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 42,
                          height: 2.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9B96E),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(flex: 9, child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Photo panel on the right of the welcome banner.
///
/// The left edge is a straight diagonal running top-right → bottom-left, so the
/// photo rises to the left exactly like the mockup. The photo is fully opaque:
/// the diagonal edge itself is the seam, no fade.
class _BannerArtwork extends StatelessWidget {
  const _BannerArtwork();

  static const _assetPath = 'assets/images/mizan.png';

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;

    return Positioned.fill(
      child: ClipPath(
        clipper: _SlantedLeftEdgeClipper(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Keep the full photo visible inside the slanted right-hand panel.
            FractionallySizedBox(
              alignment: Alignment.centerRight,
              widthFactor: 0.55,
              child: Image.asset(
                _assetPath,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x22000000),
                    BlendMode.srcATop,
                  ),
                  child: const _LegalIllustration(),
                ),
              ),
            ),
            // Slight darkening in the dark theme so the gold scale keeps the same
            // contrast against the panel as in the mockup.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(
                        0xFF0B1730,
                      ).withValues(alpha: isLight ? 0.0 : 0.12),
                      const Color(
                        0xFF0B1730,
                      ).withValues(alpha: isLight ? 0.0 : 0.26),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Straight diagonal left edge: the photo's top edge starts further left than
/// its bottom edge, so the panel rises towards the top — like the mockup.
class _SlantedLeftEdgeClipper extends CustomClipper<Path> {
  /// Where the top edge starts (fraction of width).
  /// Where the top edge starts (fraction of width) — further right, so the
  /// diagonal climbs from bottom-left to top-right like the mockup.
  static const _topInset = 0.46;

  /// Where the bottom edge starts (fraction of width) — further left.
  static const _bottomInset = 0.20;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width * _topInset, 0)
      ..lineTo(size.width * _bottomInset, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _LegalIllustration extends StatelessWidget {
  const _LegalIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 1,
            color: const Color(0xFF89A1C7).withValues(alpha: 0.12),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 22,
          child: Icon(
            Icons.eco_rounded,
            size: 62,
            color: const Color(0xFF537C69).withValues(alpha: 0.38),
          ),
        ),
        Positioned(
          left: 4,
          right: 8,
          bottom: 22,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF162744), Color(0xFF0B1425)],
              ),
              border: Border.all(color: const Color(0xFFAE854F), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88050B15),
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                color: Color(0xFFD0A66A),
                size: 24,
              ),
            ),
          ),
        ),
        Positioned(
          left: 22,
          bottom: 12,
          child: Transform.rotate(
            angle: -0.12,
            child: Container(
              width: 76,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD7B37E),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), blurRadius: 4),
                ],
              ),
            ),
          ),
        ),
        const Positioned(
          left: 10,
          right: 10,
          top: 12,
          bottom: 48,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Icon(
              Icons.balance_rounded,
              color: Color(0xFFE4B66D),
              size: 126,
              shadows: [
                Shadow(color: Color(0x66E4B66D), blurRadius: 16),
                Shadow(
                  color: Color(0xAA000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    super.key,
    required this.category,
    required this.index,
    required this.isFavorite,
    required this.onTap,
    required this.onLongPress,
  });

  final CategoryEntity category;
  final int index;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static const _colors = [
    Color(0xFF3477D5),
    Color(0xFF16A997),
    Color(0xFF8554D7),
    Color(0xFFC447A4),
    Color(0xFFD29A3D),
  ];
  static const _icons = [
    Icons.groups_rounded,
    Icons.edit_document,
    Icons.gavel_rounded,
    Icons.account_balance_rounded,
    Icons.work_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    final accent = _colors[index % _colors.length];
    final icon = _icons[index % _icons.length];
    final number = (index + 1).toString().padLeft(2, '0');
    final description = category.description?.trim().isNotEmpty == true
        ? category.description!.trim()
        : 'استكشف القضايا والإجراءات القانونية';

    return Container(
      height: 104,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isLight
              ? [
                  Color.lerp(accent, Colors.white, 0.89)!,
                  AppColors.lightSurface,
                  Color.lerp(accent, Colors.white, 0.86)!,
                ]
              : [
                  Color.lerp(accent, const Color(0xFF121D34), 0.78)!,
                  const Color(0xFF14213A),
                  Color.lerp(accent, const Color(0xFF111A2D), 0.78)!,
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.09),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 20,
            bottom: -34,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                width: 100,
                height: 70,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  textDirection: TextDirection.ltr,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLight
                            ? const Color(0xFFE6EDF7)
                            : const Color(0x332A3B5D),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: isLight
                            ? const Color(0xFF53647D)
                            : const Color(0xFFD7E4F8),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      constraints: const BoxConstraints(minWidth: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            category.name,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              height: 1.35,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            description,
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(21),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.38),
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: accent.withValues(alpha: 0.95),
                        size: 34,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isFavorite)
            Positioned(
              top: 5,
              right: 88,
              child: Icon(
                Icons.favorite_rounded,
                color: const Color(0xFFFF84A5).withValues(alpha: 0.9),
                size: 14,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.isFavorites});

  final bool isFavorites;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            isFavorites
                ? Icons.favorite_border_rounded
                : Icons.folder_off_rounded,
            color: AppColors.textMuted,
            size: 38,
          ),
          const SizedBox(height: 12),
          Text(
            isFavorites
                ? 'لا توجد تصنيفات في المفضلة بعد'
                : 'لا توجد تصنيفات مضافة حالياً',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isFavorites) ...[
            const SizedBox(height: 8),
            Text(
              'اضغط مطولاً على أي تصنيف لإضافته إلى هنا',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomNavigationBar extends StatelessWidget {
  const _BottomNavigationBar({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final isLight = AppThemeController.isLight.value;
    return Container(
      decoration: BoxDecoration(
        color: isLight ? AppColors.lightSurface : const Color(0xFF08142B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            textDirection: TextDirection.ltr,
            children: [
              _NavigationItem(
                icon: Icons.home_rounded,
                label: 'الرئيسية',
                isSelected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _NavigationItem(
                icon: Icons.favorite_border_rounded,
                label: 'المفضلة',
                isSelected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFFA47BFF)
        : const Color(0xFF91A2BD);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              width: isSelected ? 30 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
