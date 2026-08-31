import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../domain/services/entitlement_manager.dart';

/// Service managing Google AdMob lifecycle, DPDP non-personalized fallback, and Pro-tier ad suppression.
/// Adheres strictly to docs/09_monetization_play_billing_and_admob.md.
class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  final EntitlementManager _entitlementManager = EntitlementManager();
  bool _isInitialized = false;

  // Statutory Test Ad Unit IDs
  static const String androidBannerTestId = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';

  static const String androidNativeTestId = 'ca-app-pub-3940256099942544/2247696110';
  static const String iosNativeTestId = 'ca-app-pub-3940256099942544/3986624511';

  static const String androidRewardedTestId = 'ca-app-pub-3940256099942544/5224354917';
  static const String iosRewardedTestId = 'ca-app-pub-3940256099942544/1712485313';

  /// Initializes AdMob SDK
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('AdMob initialization error: $e');
    }
  }

  /// Whether ads should be suppressed for the current user
  bool get shouldSuppressAds => _entitlementManager.isProOrEnterprise;

  /// Ad Request configuration respecting DPDP Act privacy rules
  AdRequest createAdRequest({bool isNonPersonalized = true}) {
    return AdRequest(
      nonPersonalizedAds: isNonPersonalized,
      keywords: const ['accounting', 'gst', 'business', 'finance', 'invoice'],
    );
  }

  String get bannerAdUnitId {
    if (kReleaseMode) {
      return Platform.isAndroid ? 'ca-app-pub-9999999999999999/1111111111' : 'ca-app-pub-9999999999999999/2222222222';
    }
    return Platform.isAndroid ? androidBannerTestId : iosBannerTestId;
  }

  String get nativeAdUnitId {
    if (kReleaseMode) {
      return Platform.isAndroid ? 'ca-app-pub-9999999999999999/3333333333' : 'ca-app-pub-9999999999999999/4444444444';
    }
    return Platform.isAndroid ? androidNativeTestId : iosNativeTestId;
  }

  String get rewardedAdUnitId {
    if (kReleaseMode) {
      return Platform.isAndroid ? 'ca-app-pub-9999999999999999/5555555555' : 'ca-app-pub-9999999999999999/6666666666';
    }
    return Platform.isAndroid ? androidRewardedTestId : iosRewardedTestId;
  }

  /// Loads a Rewarded Video Ad granting +2 bonus AI bill scans upon full view
  void showRewardedScanRefillAd({
    required VoidCallback onRewarded,
    required Function(String) onError,
  }) {
    if (shouldSuppressAds) {
      // Pro subscribers get automatic refill without watching ads
      onRewarded();
      return;
    }

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: createAdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) => ad.dispose(),
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              onError(err.message);
            },
          );
          ad.show(
            onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
              onRewarded();
            },
          );
        },
        onAdFailedToLoad: (LoadAdError err) {
          onError(err.message);
        },
      ),
    );
  }
}
