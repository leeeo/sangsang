import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전역 NavigatorKey - 401 시 로그인 화면으로 이동하는 데 사용
final navigatorKey = GlobalKey<NavigatorState>();

class ApiClient {
  // 빌드 시 --dart-define=API_URL=https://... 로 주입 가능.
  // 미지정 시 플랫폼에 따라 자동 분기:
  //   Android 에뮬레이터: 10.0.2.2  (호스트 localhost alias)
  //   iOS 시뮬레이터 / 기타: localhost
  static const _envUrl = String.fromEnvironment('API_URL');

  static String get _baseUrl {
    if (_envUrl.isNotEmpty) return _envUrl;
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:8000/api/v1';
  }

  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // 토큰 만료 또는 무효 → 토큰 삭제 후 로그인 화면으로
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('access_token');
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil('/login', (_) => false);
        }
        handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;
}

final apiClient = ApiClient();
