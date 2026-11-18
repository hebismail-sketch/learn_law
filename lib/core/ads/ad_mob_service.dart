import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_theme.dart';

abstract final class AdMobService {
  // Google sample ad units keep requests in test mode until launch.
  //
  // Replace all three with the unit ids from your own AdMob account, together
  // with the application id in AndroidManifest.xml, before publishing: the
  // sample units only ever return test inventory, and asking for them from a
  // published app is what the Ads policy review fails.
  static const appOpenAdUnitId = 'ca-app-pub-3940256099942544/9257395921';
  static const bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const _startupAdTimeout = Duration(seconds: 5);
  static const _interstitialNavigationInterval = 15;

  /// Postpone the engine bridge by this much so the first frame can be drawn
  /// first.
  static const _engineWarmUp = Duration(seconds: 2);

  static Future<void>? _initialization;
  static bool _isInitialized = false;
  static InterstitialAd? _interstitialAd;
  static bool _isLoadingInterstitial = false;
  static bool _isShowingInterstitial = false;
  static int _pageNavigationsSinceInterstitial = 0;

  /// A full-screen ad is on screen, so another one must not be requested.
  ///
  /// Opening the app and tapping a category can both want the screen within a
  /// second of each other; two simultaneous full-screen ads are dropped by the
  /// SDK (and read as a broken ad flow in AdMob).
  static bool _isFullScreenAdVisible = false;

  /// The caller does not wait more than this for a full-screen ad. A slow
  /// network must never postpone a tap the user already made.
  static const _showAdTimeout = Duration(seconds: 3);

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
      // The first frame belongs to the reader's home screen, not to the ads
      // SDK. `MobileAds.initialize()` starts a Play services binding and
      // background requests; yielding first is what keeps a cold start below
      // the "app does not respond" threshold the pre-launch report flags.
      await Future<void>.delayed(_engineWarmUp);
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
    // The route is pushed immediately; the ad, when due, is shown over it.
    // Waiting here put an interstitial between the tap and the page it opens,
    // which stalls navigation while the ad loads and can delay the first
    // screen after the startup ad.
    final navigator = Navigator.of(context);
    final pushed = navigator.push<T>(route);

    _pageNavigationsSinceInterstitial++;
    if (_pageNavigationsSinceInterstitial >= _interstitialNavigationInterval) {
      _pageNavigationsSinceInterstitial = 0;
      unawaited(_showInterstitialAd());
    }

    return pushed;
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
    if (ad == null || _isShowingInterstitial || _isFullScreenAdVisible) {
      unawaited(_loadInterstitialAd());
      return;
    }

    _interstitialAd = null;
    _isShowingInterstitial = true;
    _isFullScreenAdVisible = true;
    final completer = Completer<void>();
    var completed = false;

    void finish() {
      if (completed) return;
      completed = true;
      _isShowingInterstitial = false;
      _isFullScreenAdVisible = false;
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
    await completer.future.timeout(
      _showAdTimeout,
      onTimeout: () {
        // The SDK never called back. Release the state so the next ad can be
        // shown instead of the app looking like it lost its ads for good.
        finish();
      },
    );
  }

  static Future<void> showStartupAppOpenAd() async {
    if (!_isSupportedPlatform) return;
    final initialization = _initialization;
    if (initialization == null) return;
    // Never open on top of an ad that is already filling the screen.
    if (_isFullScreenAdVisible) return;

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
      // A short load timeout keeps the startup gate under five seconds no
      // matter how slow the network is: an ad still loading after that is
      // disposed and the app opens without it.
      timeout.cancel();
      timeout = Timer(_startupAdTimeout, finish);
      AppOpenAd.load(
        adUnitId: appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            if (completed || !_isInitialized) {
              ad.dispose();
              finish();
              return;
            }
            timeout?.cancel();
            _isFullScreenAdVisible = true;
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                _isFullScreenAdVisible = false;
                ad.dispose();
                finish();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('App open ad failed to show: $error');
                _isFullScreenAdVisible = false;
                ad.dispose();
                finish();
              },
            );
            unawaited(
              ad.show().catchError((Object error, StackTrace stackTrace) {
                debugPrint('App open ad show failed: $error\n$stackTrace');
                _isFullScreenAdVisible = false;
                ad.dispose();
                finish();
              }),
            );
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
}

class AppOpenAdStartupGate extends StatefulWidget {
  final Widget child;
  final Future<void> Function()? startupAdLoader;

  const AppOpenAdStartupGate({
    super.key,
    required this.child,
    this.startupAdLoader,
  });

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
    try {
      await (widget.startupAdLoader?.call() ??
              AdMobService.showStartupAppOpenAd())
          .timeout(
            AdMobService._startupAdTimeout,
            onTimeout: () {
              debugPrint('Startup ad timed out; continuing without blocking.');
            },
          );
    } catch (error, stackTrace) {
      debugPrint(
        'Startup ad failed; continuing without blocking: $error\n$stackTrace',
      );
    } finally {
      if (mounted) setState(() => _isReady = true);
    }
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
  static const _bannerRetryDelay = Duration(seconds: 8);
  static const _maxBannerRetries = 3;

  BannerAd? _bannerAd;
  BannerAd? _pendingAd;
  AdSize? _adSize;
  int? _requestedWidth;
  Timer? _retryTimer;
  int _retryCount = 0;

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
    _retryCount = 0;
    _retryTimer?.cancel();
    currentAd?.dispose();
    if (!identical(currentAd, pendingAd)) pendingAd?.dispose();

    unawaited(_loadBanner(width));
  }

  Future<void> _loadBanner(int width) async {
    final ready = await AdMobService.isReady;
    if (!ready || !mounted || width != _requestedWidth) return;

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
          _scheduleRetry(width);
        },
      ),
    );
    _pendingAd = banner;
    unawaited(banner.load());
  }

  /// A banner that failed to load is retried while this screen is open.
  ///
  /// Banners are requested as soon as the page opens, which on a cold start is
  /// often the moment the ads SDK is still initializing — the first request
  /// fails and the slot stayed empty until the page was opened again.
  void _scheduleRetry(int width) {
    _retryTimer?.cancel();
    _retryCount++;
    if (_retryCount > _maxBannerRetries) return;
    _retryTimer = Timer(_bannerRetryDelay, () {
      if (!mounted || width != _requestedWidth) return;
      unawaited(_loadBanner(width));
    });
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
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
