import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../monetization/ad_config.dart';
import '../monetization/ads_manager.dart';

/// 하단 고정 적응형 배너. [BannerAd] 라이프사이클을 스스로 관리하고,
/// 크기가 확정되는 즉시 높이를 예약해 레이아웃 밀림을 방지한다.
/// (leeeo-fable/Color Rush의 검증된 패턴)
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  AdSize? _size;
  bool _loaded = false;
  bool _loadRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  Future<void> _maybeLoad() async {
    if (_loadRequested || !AdsManager.instance.showBanner) return;
    _loadRequested = true;
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (size == null || !mounted) return;
    setState(() => _size = size);
    final ad = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) {
            setState(() {
              _ad = null;
              _loaded = false;
            });
          }
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AdsManager.instance,
      builder: (context, _) {
        if (!AdsManager.instance.showBanner) return const SizedBox.shrink();
        _maybeLoad();
        final size = _size;
        final ad = _ad;
        if (size == null) return const SizedBox.shrink();
        return SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: (_loaded && ad != null) ? AdWidget(ad: ad) : null,
        );
      },
    );
  }
}
