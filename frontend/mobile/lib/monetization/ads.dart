import 'package:leeeo_ads/leeeo_ads.dart';

import 'ad_config.dart';

/// 앱 전체에서 하나만 쓰는 광고 컨트롤러.
/// `init()`: UMP 동의 → (iOS) ATT → 요청 설정 → SDK 초기화 → 전면 광고 미리 불러오기.
/// 웹·데스크톱·테스트 환경과 모든 실패는 "광고 없음"으로 끝나고 앱으로 예외를 던지지 않는다.
final LeeeoAdsController appAds = LeeeoAdsController(
  AdConfig.config,
  frequencyCapStore: AdConfig.frequencyCapStore,
);
