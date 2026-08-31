import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../data/services/admob_service.dart';
import '../../domain/services/entitlement_manager.dart';

/// Anchored adaptive banner ad widget that automatically collapses on Pro tier or load failures.
class AnchoredAdaptiveBannerWidget extends StatefulWidget {
  const AnchoredAdaptiveBannerWidget({super.key});

  @override
  State<AnchoredAdaptiveBannerWidget> createState() => _AnchoredAdaptiveBannerWidgetState();
}

class _AnchoredAdaptiveBannerWidgetState extends State<AnchoredAdaptiveBannerWidget> {
  final AdMobService _adMobService = AdMobService();
  final EntitlementManager _entitlementManager = EntitlementManager();

  BannerAd? _anchoredAdaptiveAd;
  bool _isLoaded = false;
  Orientation? _currentOrientation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.of(context).orientation;
    if (_currentOrientation == null || _currentOrientation != orientation) {
      _currentOrientation = orientation;
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    if (_adMobService.shouldSuppressAds) {
      return;
    }

    await _anchoredAdaptiveAd?.dispose();
    setState(() {
      _anchoredAdaptiveAd = null;
      _isLoaded = false;
    });

    final width = MediaQuery.of(context).size.width.truncate();
    final AdSize? size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);

    if (size == null) return;

    _anchoredAdaptiveAd = BannerAd(
      adUnitId: _adMobService.bannerAdUnitId,
      size: size,
      request: _adMobService.createAdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) {
            setState(() {
              _anchoredAdaptiveAd = ad as BannerAd;
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _isLoaded = false;
            });
          }
        },
      ),
    );

    return _anchoredAdaptiveAd!.load();
  }

  @override
  void dispose() {
    _anchoredAdaptiveAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adMobService.shouldSuppressAds || !_isLoaded || _anchoredAdaptiveAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.transparent,
      width: _anchoredAdaptiveAd!.size.width.toDouble(),
      height: _anchoredAdaptiveAd!.size.height.toDouble(),
      child: AdWidget(ad: _anchoredAdaptiveAd!),
    );
  }
}
