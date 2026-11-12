import 'package:leeeo_app_core/leeeo_app_core.dart';

import 'app_theme.dart';

/// 공통 설정/정보 화면(leeeo_app_core)에 넘기는 상부상조 정보.
/// 정책 주소는 Play 등록정보에 넣은 공개 사이트(website/)와 같다.
LeeeoAppConfig buildAppInfo({String? version}) => LeeeoAppConfig(
      appName: '상부상조',
      version: version,
      privacyPolicyUrl: Uri.parse('https://leeeo.github.io/sangsang/privacy.html'),
      termsUrl: Uri.parse('https://leeeo.github.io/sangsang/terms.html'),
      // 지원 페이지(support.html)의 문의 주소. 기기의 메일 앱으로 연다.
      feedbackUrl: Uri(
        scheme: 'mailto',
        path: 'hello@leeeo.app',
        query: 'subject=${Uri.encodeComponent('상부상조 의견')}',
      ),
      theme: AppTheme.config,
    );
