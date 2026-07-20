/// 앱 동작 모드 스위치.
///
/// - `local`(기본): 서버 없이 기기 내 SQLite에 저장하는 로컬 우선 모드 (v1 출시 형태)
/// - `server`: 기존 FastAPI 백엔드 연동 모드 (향후 서버 도입 시
///   `--dart-define=APP_MODE=server` 로 빌드하면 기존 dio 코드 경로가 그대로 활성화됨)
abstract final class AppConfig {
  static const String mode =
      String.fromEnvironment('APP_MODE', defaultValue: 'local');

  static bool get isLocal => mode != 'server';
}
