import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_config.dart';

/// 광고 라이프사이클 싱글턴:
/// UMP(GDPR) 동의 → SDK 초기화 → 배너 상태 / 전면 광고 캐시·노출 정책.
///
/// 정책:
/// - 배너: 홈 화면 하단 고정.
/// - 전면: 거래 저장 [AdConfig.interstitialEveryNSaves]회마다 1회,
///   최소 [AdConfig.interstitialCooldown] 간격. (카운터는 기기에 영속)
/// - 리워드 광고 없음 (보상으로 줄 게임적 가치가 없는 가계부 앱).
///
/// iOS 출시 시 ATT(App Tracking Transparency) 프롬프트를 여기에 추가할 것
/// (leeeo-fable ads_manager.dart 참고).
class AdsManager extends ChangeNotifier {
  AdsManager._();

  static final AdsManager instance = AdsManager._();

  static const String _kSaveCount = 'ads_tx_save_count';
  static const String _kLastInterstitialMs = 'ads_last_interstitial_ms';

  bool _initialized = false;
  bool _initStarted = false;
  bool _privacyOptionsRequired = false;
  InterstitialAd? _interstitial;
  Timer? _interstitialRetry;

  /// google_mobile_ads는 모바일 전용 (웹/데스크톱·테스트 환경 no-op).
  bool get adsSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get initialized => _initialized;

  bool get showBanner => _initialized;

  /// GDPR: EEA 사용자가 동의를 변경할 수 있는 진입점 노출 필요 여부.
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  /// 첫 프레임 이후 1회 호출. 어떤 경우에도 throw하지 않는다.
  Future<void> init() async {
    if (!adsSupported || _initStarted) return;
    _initStarted = true;
    try {
      await _gatherUmpConsent();
      _privacyOptionsRequired = await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      // Google 가이드: 동의가 광고 요청을 허용할 때만 SDK 초기화.
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        _initialized = true;
        _loadInterstitial();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('AdsManager.init failed: $e');
    }
  }

  /// UMP 개인정보 옵션 폼 (GDPR 재동의).
  void showPrivacyOptionsForm() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) {
        debugPrint('Privacy options error: ${error.errorCode} ${error.message}');
      }
    });
  }

  /// GDPR/EEA 동의 (Google UMP). EEA 밖에서는 즉시 완료되는 no-op.
  Future<void> _gatherUmpConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) {
            debugPrint('UMP form error: ${error.errorCode} ${error.message}');
          }
          if (!done.isCompleted) done.complete();
        });
      },
      (FormError error) {
        debugPrint('UMP update error: ${error.errorCode} ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future;
  }

  // ── 전면 광고 ─────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (!_initialized) return;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          _interstitial = null;
          _interstitialRetry?.cancel();
          _interstitialRetry =
              Timer(const Duration(seconds: 30), _loadInterstitial);
        },
      ),
    );
  }

  /// 거래 저장 성공 시 호출. 정책(N회마다 + 쿨다운)을 만족하면 전면 광고 노출.
  Future<void> onTransactionSaved() async {
    if (!_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_kSaveCount) ?? 0) + 1;
    await prefs.setInt(_kSaveCount, count);

    if (count % AdConfig.interstitialEveryNSaves != 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = prefs.getInt(_kLastInterstitialMs) ?? 0;
    if (now - last < AdConfig.interstitialCooldown.inMilliseconds) return;

    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    final done = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        final p = await SharedPreferences.getInstance();
        await p.setInt(
            _kLastInterstitialMs, DateTime.now().millisecondsSinceEpoch);
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();
        if (!done.isCompleted) done.complete();
      },
    );
    await ad.show();
    await done.future;
  }
}
