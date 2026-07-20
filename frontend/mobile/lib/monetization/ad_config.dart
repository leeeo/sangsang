import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID 중앙 관리.
///
/// ══════════════════════════════════════════════════════════════════════
///  ★ 출시 전 반드시 교체하세요!
///
///  AdMob 콘솔에서 발급받은 "실제" 광고 단위 ID로 아래 `_real...` 4개를
///  교체해야 실제 수익이 발생합니다. (형식: ca-app-pub-숫자16자리/숫자10자리)
///
///  안전장치 (leeeo-fable/Color Rush와 동일한 패턴):
///  - 디버그 빌드는 항상 Google 공식 테스트 광고를 사용합니다.
///  - `_real...` 값이 아직 placeholder(X 포함)면 릴리즈에서도 테스트 광고로
///    폴백하여 계정 정지(자기 클릭/무효 트래픽) 위험을 차단합니다.
///
///  ※ AdMob "앱 ID"(~ 물결표 형식)는 이 파일이 아니라
///    android/app/src/main/AndroidManifest.xml 에 있습니다. 함께 교체하세요.
/// ══════════════════════════════════════════════════════════════════════
abstract final class AdConfig {
  // ── 실제 ID (Android: AdMob 발급 완료 / iOS: 출시 시 발급) ───────────
  static const String _realBannerAndroid =
      'ca-app-pub-9901401078434900/7971424121';
  static const String _realBannerIos =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
  static const String _realInterstitialAndroid =
      'ca-app-pub-9901401078434900/4350643231';
  static const String _realInterstitialIos =
      'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // ── Google 공식 테스트 ID (수정 금지) ────────────────────────────────
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/9214589741';
  static const String _testBannerIos =
      'ca-app-pub-3940256099942544/2435281174';
  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  static bool get _isAndroid =>
      defaultTargetPlatform == TargetPlatform.android;

  static String _pick({required String real, required String test}) {
    final notConfigured = real.contains('XXXX');
    return (kDebugMode || notConfigured) ? test : real;
  }

  static String get bannerUnitId => _isAndroid
      ? _pick(real: _realBannerAndroid, test: _testBannerAndroid)
      : _pick(real: _realBannerIos, test: _testBannerIos);

  static String get interstitialUnitId => _isAndroid
      ? _pick(real: _realInterstitialAndroid, test: _testInterstitialAndroid)
      : _pick(real: _realInterstitialIos, test: _testInterstitialIos);

  /// 전면 광고 최소 간격 (이 시간 내 재노출 금지).
  static const Duration interstitialCooldown = Duration(seconds: 60);

  /// 거래 저장 N회마다 전면 광고 1회. (가계부 특성상 과하지 않게)
  static const int interstitialEveryNSaves = 3;
}
