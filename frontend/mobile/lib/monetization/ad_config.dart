import 'package:leeeo_ads/leeeo_ads.dart';

/// 상부상조 광고 설정. 실제 광고 단위 ID는 이 파일에만 둔다
/// (공통 패키지 leeeo_ads에는 Google 테스트 ID만 있다).
///
/// 안전장치 (leeeo_ads `resolveAdUnitId`):
/// - 디버그·프로파일 빌드는 항상 Google 공식 테스트 광고를 쓴다.
/// - 값이 비었거나 `XXXX` 자리표시자거나 형식이 틀리면 릴리즈에서도 테스트 광고로
///   바꿔 계정 정지(자기 클릭/무효 트래픽) 위험을 막는다.
///
/// AdMob "앱 ID"(~ 물결표 형식)는 이 파일이 아니라
/// android/app/src/main/AndroidManifest.xml, ios/Runner/Info.plist 에 있다.
abstract final class AdConfig {
  static const AdUnitIds units = AdUnitIds(
    // Android: AdMob 발급 완료
    androidBanner: 'ca-app-pub-9901401078434900/7971424121',
    androidInterstitial: 'ca-app-pub-9901401078434900/4350643231',
    // iOS: 출시 시 발급. 그 전까지는 테스트 광고.
    iosBanner: null,
    iosInterstitial: null,
  );

  static const LeeeoAdsConfig config = LeeeoAdsConfig(
    enabled: bool.fromEnvironment('ADS_ENABLED', defaultValue: true),
    units: units,
    audience: LeeeoAdAudience.general,
    // 거래 저장 3회마다 전면 광고 1회, 최소 60초 간격 (가계부 특성상 과하지 않게).
    interstitialPolicy: InterstitialPolicy(everyNth: 3, minInterval: Duration(seconds: 60)),
    // 리워드 광고 없음 (보상으로 줄 가치가 없는 기록 앱).
    preloadRewarded: false,
  );

  /// 예전 AdsManager의 저장 키를 그대로 써서 테스터 기기의 저장 횟수·마지막 노출
  /// 시각을 이어간다.
  static const SharedPreferencesFrequencyCapStore frequencyCapStore =
      SharedPreferencesFrequencyCapStore(
    opportunitiesKey: 'ads_tx_save_count',
    lastShownKey: 'ads_last_interstitial_ms',
  );
}
