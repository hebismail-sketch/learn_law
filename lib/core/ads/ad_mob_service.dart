import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_theme.dart';

enum RewardedAdResult { earned, notEarned, unavailable }

abstract final class AdMobService {
  // Google sample ad units keep requests in test mode until launch.
  static const appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
  static const bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  static const _startupAdTimeout = Duration(seconds: 5);
  static const _rewardedAdLoadTimeout = Duration(seconds: 20);
  static const _interstitialNavigationInterval = 3;

  static Future<void>? _initialization;
  static bool _isInitialized = false;
  static InterstitialAd? _interstitialAd;
  static bool _isLoadingInterstitial = false;
  static bool _isShowingInterstitial = false;
  static int _pageNavigationsSinceInterstitial = 0;

  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() {
    if (!_isSupportedPlatform) return Future<void>.value();
    return _initialization ??= _initialize();
  }

  static Future<bool> get isReady async {
    final initialization = _initialization;
    if (initialization == null) return false;
    await initialization;
    return _isInitialized;
  }

  static Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      unawaited(_loadInterstitialAd());
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Google Mobile Ads initialization failed: $error\n$stackTrace',
      );
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Google Mobile Ads plugin is unavailable: $error\n$stackTrace',
      );
    }
  }

  static Future<T?> pushWithInterstitial<T>(
    BuildContext context,
    Route<T> route,
  ) async {
    _pageNavigationsSinceInterstitial++;
    if (_pageNavigationsSinceInterstitial >= _interstitialNavigationInterval) {
      _pageNavigationsSinceInterstitial = 0;
      await _showInterstitialAd();
    }

    if (!context.mounted) return null;
    return Navigator.of(context).push<T>(route);
  }

  static Future<void> _loadInterstitialAd() async {
    if (!_isSupportedPlatform ||
        !_isInitialized ||
        _isLoadingInterstitial ||
        _interstitialAd != null) {
      return;
    }

    _isLoadingInterstitial = true;
    try {
      InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _isLoadingInterstitial = false;
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (error) {
            _isLoadingInterstitial = false;
            debugPrint('Interstitial ad failed to load: $error');
          },
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      _isLoadingInterstitial = false;
      debugPrint('Interstitial ad request failed: $error\n$stackTrace');
    } on MissingPluginException catch (error, stackTrace) {
      _isLoadingInterstitial = false;
      debugPrint('Interstitial ad plugin is unavailable: $error\n$stackTrace');
    }
  }

  static Future<void> _showInterstitialAd() async {
    final ad = _interstitialAd;
    if (ad == null || _isShowingInterstitial) {
      unawaited(_loadInterstitialAd());
      return;
    }

    _interstitialAd = null;
    _isShowingInterstitial = true;
    final completer = Completer<void>();
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      _isShowingInterstitial = false;
      ad.dispose();
      unawaited(_loadInterstitialAd());
      completer.complete();
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (_) => finish(),
      onAdFailedToShowFullScreenContent: (_, error) {
        debugPrint('Interstitial ad failed to show: $error');
        finish();
      },
    );

    unawaited(
      ad.show().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Interstitial ad show failed: $error\n$stackTrace');
        finish();
      }),
    );
    await completer.future;
  }

  static Future<void> showStartupAppOpenAd() async {
    if (!_isSupportedPlatform) return;
    final initialization = _initialization;
    if (initialization == null) return;

    final completer = Completer<void>();
    var completed = false;
    Timer? timeout;

    void finish() {
      if (completed) return;
      completed = true;
      timeout?.cancel();
      completer.complete();
    }

    timeout = Timer(_startupAdTimeout, finish);
    final initialized = await isReady.timeout(
      _startupAdTimeout,
      onTimeout: () => false,
    );
    if (!initialized || completed) {
      finish();
      return completer.future;
    }

    try {
      AppOpenAd.load(
        adUnitId: appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (completed) {
              ad.dispose();
              return;
            }
            timeout?.cancel();
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                finish();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('App open ad failed to show: $error');
                ad.dispose();
                finish();
              },
            );
            unawaited(ad.show());
          },
          onAdFailedToLoad: (error) {
            debugPrint('App open ad failed to load: $error');
            finish();
          },
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('App open ad request failed: $error\n$stackTrace');
      finish();
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('App open ad plugin is unavailable: $error\n$stackTrace');
      finish();
    }

    await completer.future;
  }

  static Future<RewardedAdResult> showCategoryUnlockAd(
    bool Function() isStillRequested,
  ) async {
    if (!_isSupportedPlatform) return RewardedAdResult.unavailable;

    final initialized = await isReady.timeout(
      _rewardedAdLoadTimeout,
      onTimeout: () => false,
    );
    if (!initialized) return RewardedAdResult.unavailable;

    final completer = Completer<RewardedAdResult>();
    var completed = false;
    var earnedReward = false;
    Timer? loadTimeout;

    void finish(RewardedAdResult result) {
      if (completed) return;
      completed = true;
      loadTimeout?.cancel();
      completer.complete(result);
    }

    loadTimeout = Timer(
      _rewardedAdLoadTimeout,
      () => finish(RewardedAdResult.unavailable),
    );

    try {
      RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (completed || !isStillRequested()) {
              ad.dispose();
              finish(RewardedAdResult.unavailable);
              return;
            }

            loadTimeout?.cancel();
            ad.fullScreenContentCallback =
                FullScreenContentCallback<RewardedAd>(
                  onAdDismissedFullScreenContent: (ad) {
                    ad.dispose();
                    finish(
                      earnedReward
                          ? RewardedAdResult.earned
                          : RewardedAdResult.notEarned,
                    );
                  },
                  onAdFailedToShowFullScreenContent: (ad, error) {
                    debugPrint('Rewarded ad failed to show: $error');
                    ad.dispose();
                    finish(
                      earnedReward
                          ? RewardedAdResult.earned
                          : RewardedAdResult.unavailable,
                    );
                  },
                );

            unawaited(
              ad
                  .show(
                    onUserEarnedReward: (_, reward) {
                      debugPrint(
                        'Category unlock reward earned: '
                        '${reward.amount} ${reward.type}',
                      );
                      earnedReward = true;
                    },
                  )
                  .catchError((Object error, StackTrace stackTrace) {
                    debugPrint(
                      'Rewarded ad failed to show: $error\n$stackTrace',
                    );
                    ad.dispose();
                    finish(
                      earnedReward
                          ? RewardedAdResult.earned
                          : RewardedAdResult.unavailable,
                    );
                  }),
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded ad failed to load: $error');
            finish(RewardedAdResult.unavailable);
          },
        ),
      );
    } on PlatformException catch (error, stackTrace) {
      debugPrint('Rewarded ad request failed: $error\n$stackTrace');
      finish(RewardedAdResult.unavailable);
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('Rewarded ad plugin is unavailable: $error\n$stackTrace');
      finish(RewardedAdResult.unavailable);
    }

    return completer.future;
  }
}

class AppOpenAdStartupGate extends StatefulWidget {
  final Widget child;

  const AppOpenAdStartupGate({super.key, required this.child});

  @override
  State<AppOpenAdStartupGate> createState() => _AppOpenAdStartupGateState();
}

class _AppOpenAdStartupGateState extends State<AppOpenAdStartupGate> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_showStartupAd());
  }

  Future<void> _showStartupAd() async {
    await AdMobService.showStartupAppOpenAd();
    if (mounted) setState(() => _isReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return widget.child;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF38BDF8)),
            const SizedBox(height: 16),
            Text(
              'جارٍ فتح التطبيق...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class AdMobBanner extends StatefulWidget {
  const AdMobBanner({super.key});

  @override
  State<AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<AdMobBanner> {
  BannerAd? _bannerAd;
  BannerAd? _pendingAd;
  AdSize? _adSize;
  int? _requestedWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    if (width <= 0 || width == _requestedWidth) return;
    _requestedWidth = width;

    final currentAd = _bannerAd;
    final pendingAd = _pendingAd;
    _bannerAd = null;
    _pendingAd = null;
    _adSize = null;
    currentAd?.dispose();
    if (!identical(currentAd, pendingAd)) pendingAd?.dispose();

    unawaited(_loadBanner(width));
  }

  Future<void> _loadBanner(int width) async {
    if (!await AdMobService.isReady || !mounted || width != _requestedWidth) {
      return;
    }

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (size == null || !mounted || width != _requestedWidth) {
      if (size == null) debugPrint('No adaptive banner size is available.');
      return;
    }

    late final BannerAd banner;
    banner = BannerAd(
      adUnitId: AdMobService.bannerAdUnitId,
      request: const AdRequest(),
      size: size,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted || width != _requestedWidth) {
            banner.dispose();
            return;
          }
          _pendingAd = null;
          setState(() {
            _bannerAd = banner;
            _adSize = size;
          });
        },
        onAdFailedToLoad: (_, error) {
          debugPrint('Banner ad failed to load: $error');
          if (identical(_pendingAd, banner)) _pendingAd = null;
          banner.dispose();
        },
      ),
    );
    _pendingAd = banner;
    unawaited(banner.load());
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    if (!identical(_bannerAd, _pendingAd)) _pendingAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    final size = _adSize;
    if (ad == null || size == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: AppColors.background,
      alignment: Alignment.center,
      child: SizedBox(
        width: size.width.toDouble(),
        height: size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
