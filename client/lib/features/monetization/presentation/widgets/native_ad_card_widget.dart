import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../data/services/admob_service.dart';

/// Native Ad Card widget styled with M3 design tokens and statutory "Ad / विज्ञापन" badge.
class NativeAdCardWidget extends StatefulWidget {
  const NativeAdCardWidget({super.key});

  @override
  State<NativeAdCardWidget> createState() => _NativeAdCardWidgetState();
}

class _NativeAdCardWidgetState extends State<NativeAdCardWidget> {
  final AdMobService _adMobService = AdMobService();
  NativeAd? _nativeAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadNativeAd();
  }

  void _loadNativeAd() {
    if (_adMobService.shouldSuppressAds) {
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: _adMobService.nativeAdUnitId,
      factoryId: 'listTile', // Android / iOS native ad factory
      request: _adMobService.createAdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _nativeAd = ad as NativeAd;
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
          if (mounted) {
            setState(() => _isLoaded = false);
          }
        },
      ),
    );

    _nativeAd!.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_adMobService.shouldSuppressAds || !_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LedgifyColors.cardBorderRadius),
        side: const BorderSide(color: LedgifyColors.surfaceVariant),
      ),
      color: LedgifyColors.surfaceCard,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Ad / विज्ञापन',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 72,
              child: AdWidget(ad: _nativeAd!),
            ),
          ],
        ),
      ),
    );
  }
}
