import 'package:flutter/material.dart';
import 'package:leeeo_ads/leeeo_ads.dart' show LeeeoPrivacyOptionsTile;
import 'package:leeeo_app_core/leeeo_app_core.dart';
import 'package:provider/provider.dart';

import '../../monetization/ads.dart';

/// 설정: 공통 설정/정보 화면 + 광고 개인정보 설정(UMP가 요구할 때만 보임).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => LeeeoSettingsScreen(
    config: context.read<LeeeoAppConfig>(),
    themeController: context.read<ThemeModeController>(),
    trailing: [LeeeoPrivacyOptionsTile(controller: appAds)],
  );
}
